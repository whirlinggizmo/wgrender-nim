## wgrender itself, compiled into the program by Nim's own C compiler: no make, no
## prebuilt library, whatever the toolchain (gcc or clang, MinGW, MSVC with --cc:vcc,
## emcc for the web). raw.nim imports this, so any program that imports wgr gets it.
##
## How to compile wgrender comes from its build.json (its build as data): the sources, and per target the defines, flags and
## link libraries. Each source is a `{.compile.}` with wgrender's own flags, so its
## defines and include paths don't reach the program's C; only the public headers'
## directory is global.
##
## Which wgrender: -d:wgrenderDir=<path>, else WGRENDER_DIR, else a wgrender-c checkout
## beside this repository, else the pinned submodule (in the repository, or in the
## package nimble installed: installDirs carries it).
##
## Which target: -d:emscripten (the examples' web build) is the web, with BACKEND,
## WEB_THREADS and WEB_DEBUG from the environment as for wgrender's own web build;
## anything else is this OS's desktop build, headless with -d:wgrHeadless.
##
## -d:wgrPrebuilt links a libwgrender.a wgrender built instead, for working on wgrender
## itself: its CMake `desktop` or `headless` preset (build/<preset>/), or for the web
## its tools/buildweb.py (build/<webdir>/). Nim recompiles a {.compile.} file when it changes, not when a
## header it includes does, so after editing a wgrender header, build with -f.

import std/[json, macros, os, sequtils, strutils]

const wgrenderDirDefine {.strdefine: "wgrenderDir".} = ""

proc slashes(path: string): string =
  ## A web build cross-compiles (--os:linux), and then Nim's path procs split only on
  ## '/', so a Windows C:\... path would have no parent. Forward slashes work for both,
  ## and every Windows tool takes them.
  path.replace('\\', '/')

proc findWgrender(): string {.compileTime.} =
  let here = currentSourcePath().slashes.parentDir()   # src/wgr
  let repo = here.parentDir().parentDir()
  var candidates: seq[string]
  if wgrenderDirDefine.len > 0: candidates.add wgrenderDirDefine.slashes
  if getEnv("WGRENDER_DIR").len > 0: candidates.add getEnv("WGRENDER_DIR").slashes
  candidates.add [repo.parentDir() / "wgrender-c", repo / "project" / "lib" / "wgrender-c",
                  # installed by nimble: src/ is the package root, the submodule beside it
                  here.parentDir() / "project" / "lib" / "wgrender-c"]
  for dir in candidates:
    if fileExists(dir / "include" / "wgr.h"):
      return dir.normalizedPath
  error("wgr: no wgrender found (looked in " & candidates.join(", ") &
        "). git submodule update --init, or -d:wgrenderDir=<path>")

proc webDir(): string {.compileTime.} =
  let backend = if getEnv("BACKEND").len > 0: getEnv("BACKEND") else: "webgl2"
  result = backend
  if getEnv("WEB_THREADS", "1") == "0": result.add "-nothreads"
  if getEnv("WEB_DEBUG", "0") == "1": result.add "-debug"

proc desktopTarget(): string {.compileTime.} =
  result = when defined(windows): "windows" elif defined(macosx): "macos" else: "linux"
  if defined(wgrHeadless): result.add "-headless"

proc quoted(s: string): string =
  if ' ' in s: '"' & s & '"' else: s

proc forCompiler(flag: string): string =
  ## gcc/clang's spelling, as mk/build.json has it, in MSVC's where that's the compiler
  when defined(vcc):
    if flag.startsWith("-D"): "/D" & flag[2 .. ^1]
    elif flag.startsWith("-I"): "/I" & quoted(flag[2 .. ^1])
    elif flag.startsWith("-std="): "/std:c11" # MSVC has c11 and c17; gnu11 is gcc's
    elif flag == "-O2": "/O2"
    elif flag == "/Gy": flag
    else: ""                                   # gcc-only (warnings): nothing to pass
  else:
    if flag.startsWith("-I"): "-I" & quoted(flag[2 .. ^1]) else: flag

proc linkLib(name: string): string =
  when defined(vcc): name & ".lib" else: "-l" & name

macro compileWgrender(): untyped =
  let dir = findWgrender()
  let manifest = parseJson(staticRead(dir / "build.json"))
  result = newStmtList()

  proc pragma(name, value: string): NimNode =
    nnkPragma.newTree(nnkExprColonExpr.newTree(ident(name), newLit(value)))

  result.add pragma("passC", forCompiler("-I" & dir / "include"))

  var cflags, ldflags: seq[string]
  var libs: seq[string]
  var frameworks: seq[string]
  var staticRuntime = false
  when defined(emscripten):
    let target = manifest["web"][webDir()]
    for f in target["cflags"]: cflags.add f.getStr
    # wgrender keeps (and exports) every public function in a web build, which an
    # archive only pays for per object linked; compiled in, every object is linked, so
    # let the linker drop what the program never calls (exports_internal.h)
    cflags.add "-DWGRI_KEEP="
    for f in target["program_cflags"]: result.add pragma("passC", f.getStr)
    for f in target["ldflags"]: ldflags.add f.getStr
  else:
    let target = manifest["desktop"][desktopTarget()]
    for f in manifest["opt"]: cflags.add f.getStr
    for d in target["defines"]: cflags.add "-D" & d.getStr
    for l in target["libs"]: libs.add l.getStr
    if target.hasKey("frameworks"):
      for f in target["frameworks"]: frameworks.add f.getStr
    staticRuntime = target{"static"}.getBool(false) and not defined(vcc)

  when defined(wgrPrebuilt):
    let build = when defined(emscripten): webDir()
                elif defined(wgrHeadless): "headless"
                else: "desktop"
    let lib = dir / "build" / build / "libwgrender.a"
    if not fileExists(lib):
      error("wgr: -d:wgrPrebuilt, but no " & lib & ": build it in wgrender first (" &
            (when defined(emscripten): "python3 tools/buildweb.py" else:
              "cmake --preset " & build & " && cmake --build --preset " & build & " --target wgrender") & ")")
    result.add pragma("passL", lib)
  else:
    var perFile = @["-std=" & manifest["std"].getStr]
    for d in manifest["include"]: perFile.add "-I" & dir / d.getStr
    for d in manifest["system_include"]: perFile.add "-I" & dir / d.getStr # -isystem is gcc's; -I serves
    perFile.add cflags
    # Each function in a section of its own, so the linker drops what the program never
    # calls, as it would never pull an unreferenced object out of an archive; without
    # it, compiling wgrender in costs ~100 KB over linking libwgrender.a.
    when defined(vcc):
      perFile.add "/Gy"
    else:
      perFile.add ["-ffunction-sections", "-fdata-sections"]
    let flags = perFile.mapIt(forCompiler(it)).filterIt(it.len > 0).join(" ")
    for src in manifest["sources"]:
      result.add nnkPragma.newTree(newCall(ident"compile", newLit(dir / src.getStr), newLit(flags)))

  when not defined(wgrPrebuilt) and not defined(emscripten): # wasm-ld collects by default
    result.add pragma("passL", when defined(vcc): "/link /OPT:REF"
                               elif defined(macosx): "-Wl,-dead_strip"
                               else: "-Wl,--gc-sections")
  for l in libs: result.add pragma("passL", linkLib(l))
  for f in frameworks: result.add pragma("passL", "-framework " & f)
  if staticRuntime: result.add pragma("passL", "-static")
  for f in ldflags: result.add pragma("passL", f)

compileWgrender()
