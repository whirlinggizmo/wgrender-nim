# Build config for a wgrender example: this directory's name is the example's, and its
# source is src/<name>.nim. Every example's config.nims is this same file.
#
#   nim build desktop     out/<platform>/<variant>/<name>: out/linux/release/, out/windows/mingw/,
#                         ... (wgrender compiled in, by src/wgr/internal/build.nim); with MSVC,
#                         nim build --cc:vcc desktop: out/windows/msvc/
#   nim build web         out/web/<variant>/ (out/web/webgl2 by default): <name>.js/.wasm +
#                         the page (web/index.html)
#   nim build all         both
#   nim serve             serve the web build on http://localhost:8000 (tools/serve.py:
#                         COOP/COEP headers for threads, wgrender's examples/assets at
#                         /assets, gzip-compressed responses)
#   nim webcheck          load the web build in a headless browser; fail on a console
#                         error, a program that never starts, or a blank screen
#                         (tools/webcheck.py; the screenshot goes to build/web/<variant>/)
#   nim clean             remove out/ (what the builds made) and build/ (their work: Nim's cache)
#
# The wg* layout (whirlinggizmo/.github CONVENTIONS.md, "Build directories"): what a
# build makes in out/<platform>/<variant>/, its work in build/<platform>/<variant>/
# (Nim's cache in build/linux/release/nimcache, build/web/webgl2/nimcache, ...).
#
# Run these from this directory. `nim c -r src/<name>.nim` still builds and runs the
# desktop version in place.
#
# Web options are wgrender's web build settings, read from the environment:
#   BACKEND=webgl2|webgpu   WEB_THREADS=1|0   WEB_DEBUG=0|1   (e.g. BACKEND=webgpu nim build web)
# wgrender, in order:
#   1. WGRENDER_DIR=/path/to/wgrender
#   2. ../wgrender-c beside this repository: a checkout you are working on, so a change
#      there is tried here without pushing it and moving the pin
#   3. project/lib/wgrender-c, the pinned submodule, which is what a clone has

import std/[os, strutils]

const
  thisDir = currentSourcePath().parentDir()
  repoDir = thisDir / "../.."
  name = thisDir.lastPathPart
  mainEntry = thisDir / "src" / name & ".nim"
  outDir = thisDir / "out"
  workDir = thisDir / "build"
  wgrenderSibling = repoDir / "../wgrender-c"
  wgrenderSubmodule = repoDir / "project/lib/wgrender-c"

let wgrenderDir = absolutePath(
  if existsEnv("WGRENDER_DIR"): getEnv("WGRENDER_DIR")
  elif fileExists(wgrenderSibling / "include/wgr.h"): wgrenderSibling
  else: wgrenderSubmodule)

proc ccFromCmdLine(): string =
  ## The C compiler the command line names (--cc:vcc), or "" for Nim's default. Read
  ## from the arguments because Nim applies --cc after this file runs, so
  ## defined(vcc) is still false here.
  for i in 1..paramCount():
    let p = paramStr(i)
    for prefix in ["--cc:", "--cc="]:
      if p.startsWith(prefix): result = p[prefix.len..^1]

proc desktopVariant(): string =
  ## <platform>/<variant>: release, or on Windows the toolchain: msvc (--cc:vcc),
  ## clang (--cc:clang), else mingw (Nim's default there)
  when defined(windows):
    case ccFromCmdLine()
    of "vcc": "windows/msvc"
    of "clang": "windows/clang"
    else: "windows/mingw"
  elif defined(macosx): "macos/release"
  else: "linux/release"

proc webVariant(): string =
  ## web/<variant>, from the web settings (threaded unless WEB_THREADS=0)
  result = "web/" & (if getEnv("BACKEND").len > 0: getEnv("BACKEND") else: "webgl2")
  if getEnv("WEB_THREADS", "1") == "0": result.add "-nothreads"
  if getEnv("WEB_DEBUG", "0") == "1": result.add "-debug"

switch("hints", "off")
switch("path", repoDir / "src") # the binding: wgr.nim, wgr/raw.nim

# wgrender itself is compiled by src/wgr/internal/build.nim, into the program, from its
# build.json: nothing here builds or links it. What's left is the target.
when defined(emscripten):
  switch("nimcache", workDir / webVariant() / "nimcache")
  switch("os", "linux")
  switch("cpu", "wasm32")
  switch("cc", "clang")
  # emcc is a batch file on Windows, which Nim has to name
  switch("clang.exe", when defined(windows): "emcc.bat" else: "emcc")
  switch("clang.linkerexe", when defined(windows): "emcc.bat" else: "emcc")
  switch("define", "noSignalHandler")
  switch("define", "useMalloc")
  # Nim code only runs on the main thread; wgrender's workers are its own
  switch("threads", "off")
  # Release unless WEB_DEBUG=1, like wgrender's own web builds
  if getEnv("WEB_DEBUG", "0") != "1":
    switch("define", "release")
    # Nim's own nim.cfg is read before this file, while the OS is still the host's and
    # release is not yet defined: on Windows it gives clang a -g link, and emcc then
    # keeps DWARF and skips most of its optimization (simple: 1.16 MB of wasm, 0.72).
    switch("clang.options.linker", "")
else:
  switch("nimcache", workDir / desktopVariant() / "nimcache")
  switch("define", "wgrAssetBase=" & wgrenderDir / "examples/assets")
  # this build's work directory, relative to the example (it runs from there), for a
  # program that keeps files of its own there, such as fetch's download cache
  switch("define", "wgrWorkDir=build/" & desktopVariant())

proc python(): string =
  ## python3 where there is one, else python (Windows)
  if findExe("python3").len > 0: "python3" else: "python"

proc desktopOut(): string = outDir / desktopVariant()

proc webOut(): string = outDir / webVariant()

proc buildDesktop() =
  echo name & " (desktop) -> " & relativePath(desktopOut(), thisDir) & "/" & name
  # the compiler the command line chose, passed on (nim build --cc:vcc desktop)
  let cc = ccFromCmdLine()
  exec "nim c " & (if cc.len > 0: "--cc:" & cc & " " else: "") & "--out:" &
       quoteShell(desktopOut() / name) & " " & mainEntry.quoteShell

proc buildWeb() =
  let site = webOut()
  mkDir(site)
  echo name & " (web) -> " & relativePath(site, thisDir) & "/"
  exec "nim c -d:emscripten --out:" & quoteShell(site / name & ".js") & " " & mainEntry.quoteShell
  # this repository's page, opening this example, finished by tools/webdeploy.py:
  # versioned file names and examples.json
  let page = readFile(repoDir / "web/index.html")
  const first = """/*wgr:first*/"simple""""
  if first notin page:
    quit "web/index.html: no " & first & " to open this example with", 1
  let shell = workDir / webVariant() / "index.html"
  writeFile(shell, page.replace(first, "/*wgr:first*/\"" & name & "\""))
  exec python() & " " & quoteShell(repoDir / "tools/webdeploy.py") & " " &
       site.quoteShell & " " & shell.quoteShell
  echo "built " & relativePath(site, thisDir) & " — `nim serve`, then open http://localhost:8000/"

task build, "Build: nim build desktop|web|all":
  let target = if paramCount() >= 2: paramStr(paramCount()) else: ""
  case target
  of "desktop": buildDesktop()
  of "web": buildWeb()
  of "all":
    buildDesktop()
    buildWeb()
  else:
    quit "usage: nim build desktop|web|all", 1

task serve, "Serve the web build on http://localhost:8000":
  exec python() & " " & quoteShell(repoDir / "tools/serve.py") & " 8000 " &
       quoteShell(webOut()) & " --assets " & quoteShell(wgrenderDir / "examples/assets") & " --gzip"

task webcheck, "Load the web build in a headless browser; fail if it doesn't run":
  exec python() & " " & quoteShell(repoDir / "tools/webcheck.py") & " " & quoteShell(webOut()) &
       " " & quoteShell(wgrenderDir) & " " & quoteShell(workDir / webVariant() / "check.png")

task clean, "Remove build outputs":
  rmDir(outDir)
  rmDir(workDir)
