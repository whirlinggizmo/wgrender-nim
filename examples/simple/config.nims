# Build config for the wgrender simple example.
#
#   nim build desktop     out/desktop/simple (builds wgrender's desktop lib first)
#   nim build web         out/web/: simple.js/.wasm + wgrender's page shell
#   nim build all         both
#   nim serve             serve out/web on http://localhost:8000 (wgrender's tools/serve.py:
#                         COOP/COEP headers for threads, examples/assets at /assets,
#                         gzip-compressed responses)
#   nim clean             remove out/ and .nimcache/
#
# Run these from this directory. `nim c -r simple.nim` still builds and runs the
# desktop version in place.
#
# Web options are wgrender's make variables, read from the environment:
#   BACKEND=webgl2|webgpu   WEB_THREADS=1|0   WEB_DEBUG=0|1   (e.g. BACKEND=webgpu nim build web)
# wgrender, in order (the same as wgrender-hx):
#   1. WGRENDER_DIR=/path/to/wgrender
#   2. ../wgrender-c beside this repository: a checkout you are working on, so a change
#      there is tried here without pushing it and moving the pin
#   3. project/lib/wgrender-c, the pinned submodule, which is what a clone has

import std/[os, strutils]

const
  thisDir = currentSourcePath().parentDir()
  repoDir = thisDir / "../.."
  mainEntry = thisDir / "simple.nim"
  outDir = thisDir / "out"
  wgrenderSibling = repoDir / "../wgrender-c"
  wgrenderSubmodule = repoDir / "project/lib/wgrender-c"

let wgrenderDir = absolutePath(
  if existsEnv("WGRENDER_DIR"): getEnv("WGRENDER_DIR")
  elif fileExists(wgrenderSibling / "include/wgr.h"): wgrenderSibling
  else: wgrenderSubmodule)

# wgrender's make variables for the web build, passed through to every make call.
proc webMakeVars(): string =
  for v in ["BACKEND", "WEB_THREADS", "WEB_DEBUG"]:
    if existsEnv(v):
      result.add " " & v & "=" & getEnv(v)

# wgrender's web compile/link flags (`make print-web-flags`: lib, cflags, ldflags lines),
# so this build always matches how the web library was built.
proc webFlags(): tuple[lib, cflags, ldflags: string] =
  let output = gorge("make --no-print-directory -s -C " & wgrenderDir.quoteShell &
                     " print-web-flags" & webMakeVars())
  for line in output.splitLines():
    let parts = line.split(':', maxsplit = 1)
    if parts.len != 2: continue
    let value = parts[1].strip()
    case parts[0].strip()
    of "lib": result.lib = wgrenderDir / value
    of "cflags": result.cflags = value.replace("-Iinclude", "-I" & wgrenderDir / "include")
    of "ldflags": result.ldflags = value
  if result.lib.len == 0:
    raise newException(ValueError, "could not read wgrender web flags:\n" & output)

switch("hints", "off")
switch("path", repoDir) # the binding: wgr.nim, wgr/raw.nim

when defined(emscripten):
  let web = webFlags()
  switch("nimcache", thisDir / ".nimcache/web")
  switch("os", "linux")
  switch("cpu", "wasm32")
  switch("cc", "clang")
  switch("clang.exe", "emcc")
  switch("clang.linkerexe", "emcc")
  switch("define", "noSignalHandler")
  switch("define", "useMalloc")
  # Nim code only runs on the main thread; wgrender's workers are its own. The objects
  # still get wgrender's cflags (-pthread) so they can link into shared memory.
  switch("threads", "off")
  # Release unless WEB_DEBUG=1, like wgrender's own web builds
  if getEnv("WEB_DEBUG", "0") != "1":
    switch("define", "release")
  switch("passC", web.cflags)
  switch("passL", web.lib)
  switch("passL", web.ldflags)
else:
  switch("nimcache", thisDir / ".nimcache/desktop")
  switch("define", "wgrAssetBase=" & wgrenderDir / "examples/assets")
  switch("passC", "-I" & wgrenderDir / "include")
  # wgrender's native library directory is named for the OS (build/linux, build/macos)
  switch("passL", wgrenderDir / (when defined(macosx): "build/macos" else: "build/linux") / "libwgrender.a")
  for lib in ["GL", "X11", "Xi", "Xcursor", "Xrandr", "asound", "dl", "m", "pthread"]:
    switch("passL", "-l" & lib)

proc buildDesktop() =
  echo "wgrender (desktop)"
  exec "make --no-print-directory -C " & wgrenderDir.quoteShell
  echo "simple (desktop) -> out/desktop/simple"
  exec "nim c --out:" & quoteShell(outDir / "desktop/simple") & " " & mainEntry.quoteShell

proc buildWeb() =
  echo "wgrender (web)"
  exec "make --no-print-directory -C " & wgrenderDir.quoteShell & " web" & webMakeVars()
  let site = outDir / "web"
  mkDir(site)
  echo "simple (web) -> out/web/"
  exec "nim c -d:emscripten --out:" & quoteShell(site / "simple.js") & " " & mainEntry.quoteShell
  # wgrender's page shell, opening this example by default (its default is "hello"),
  # finished by wgrender's deploy script: versioned file names and examples.json.
  let shell = thisDir / ".nimcache/web/index.html"
  writeFile(shell, readFile(wgrenderDir / "examples/web/index.html")
    .replace("""params.get("ex") || "hello"""", """params.get("ex") || "simple""""))
  exec "python3 " & quoteShell(wgrenderDir / "tools/webdeploy.py") & " " &
       site.quoteShell & " " & shell.quoteShell
  echo "built out/web — `nim serve`, then open http://localhost:8000/"

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

task serve, "Serve out/web on http://localhost:8000":
  exec "python3 " & quoteShell(wgrenderDir / "tools/serve.py") & " 8000 " &
       quoteShell(outDir / "web") & " --gzip"

task clean, "Remove build outputs":
  rmDir(outDir)
  rmDir(thisDir / ".nimcache")
