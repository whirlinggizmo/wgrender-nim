# The tests build wgrender in, as any program importing wgr does (src/wgr/build.nim,
# which also finds wgrender: WGRENDER_DIR, a ../wgrender-c checkout, or the submodule).
import std/os

const repoDir = currentSourcePath().parentDir() / ".."

switch("hints", "off")
switch("path", repoDir / "src")
# their cache in the repo's build/<platform>/<variant>/ (the wg* layout): a desktop build
let variant = when defined(windows): "windows/mingw" elif defined(macosx): "macos/release" else: "linux/release"
switch("nimcache", repoDir / "build" / variant / "nimcache")
