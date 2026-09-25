# The tests build wgrender in, as any program importing wgr does (src/wgr/build.nim,
# which also finds wgrender: WGRENDER_DIR, a ../wgrender-c checkout, or the submodule).
import std/[os, strutils]

const repoDir = currentSourcePath().parentDir() / ".."

switch("hints", "off")
switch("path", repoDir / "src")
# their cache in the repo's build/<platform>/<variant>/ (the wg* layout): a desktop build,
# named on Windows for the compiler the command line chose (--cc:vcc), since Nim
# applies --cc after this file runs
var cc = ""
for i in 1..paramCount():
  for prefix in ["--cc:", "--cc="]:
    if paramStr(i).startsWith(prefix): cc = paramStr(i)[prefix.len..^1]
let variant = when defined(windows): "windows/" & (if cc == "vcc": "msvc" elif cc == "clang": "clang" else: "mingw")
              elif defined(macosx): "macos/release" else: "linux/release"
switch("nimcache", repoDir / "build" / variant / "nimcache")
