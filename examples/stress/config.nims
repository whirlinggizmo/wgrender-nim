# Build config for a wgrender example: this directory's name is the example's, and its
# source is src/<name>.nim. Every example's config.nims is this same file.
#
#   nim build desktop     out/desktop/<name> (wgrender compiled in, by src/wgr/build.nim)
#   nim build web         out/web/: <name>.js/.wasm + wgrender's page shell
#   nim build all         both
#   nim serve             serve out/web on http://localhost:8000 (wgrender's tools/serve.py:
#                         COOP/COEP headers for threads, examples/assets at /assets,
#                         gzip-compressed responses)
#   nim clean             remove out/ and .nimcache/
#
# Run these from this directory. `nim c -r src/<name>.nim` still builds and runs the
# desktop version in place.
#
# Web options are wgrender's web build settings, read from the environment:
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
  name = thisDir.lastPathPart
  mainEntry = thisDir / "src" / name & ".nim"
  outDir = thisDir / "out"
  wgrenderSibling = repoDir / "../wgrender-c"
  wgrenderSubmodule = repoDir / "project/lib/wgrender-c"

let wgrenderDir = absolutePath(
  if existsEnv("WGRENDER_DIR"): getEnv("WGRENDER_DIR")
  elif fileExists(wgrenderSibling / "include/wgr.h"): wgrenderSibling
  else: wgrenderSubmodule)

switch("hints", "off")
switch("path", repoDir / "src") # the binding: wgr.nim, wgr/raw.nim

# wgrender itself is compiled by src/wgr/build.nim, into the program, from its
# build.json: nothing here builds or links it. What's left is the target.
when defined(emscripten):
  switch("nimcache", thisDir / ".nimcache/web")
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
  switch("nimcache", thisDir / ".nimcache/desktop")
  switch("define", "wgrAssetBase=" & wgrenderDir / "examples/assets")

proc buildDesktop() =
  echo name & " (desktop) -> out/desktop/" & name
  exec "nim c --out:" & quoteShell(outDir / "desktop" / name) & " " & mainEntry.quoteShell

proc buildWeb() =
  let site = outDir / "web"
  mkDir(site)
  echo name & " (web) -> out/web/"
  exec "nim c -d:emscripten --out:" & quoteShell(site / name & ".js") & " " & mainEntry.quoteShell
  # wgrender's page shell, opening this example by default (its default is "hello"),
  # finished by wgrender's deploy script: versioned file names and examples.json.
  let shell = thisDir / ".nimcache/web/index.html"
  writeFile(shell, readFile(wgrenderDir / "examples/web/index.html")
    .replace("""params.get("ex") || "hello"""", "params.get(\"ex\") || \"" & name & "\""))
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
