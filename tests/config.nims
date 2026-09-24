# The tests build wgrender in, as any program importing wgr does (src/wgr/build.nim,
# which also finds wgrender: WGRENDER_DIR, a ../wgrender-c checkout, or the submodule).
import std/os

const repoDir = currentSourcePath().parentDir() / ".."

switch("hints", "off")
switch("path", repoDir / "src")
switch("nimcache", repoDir / ".nimcache/tests")
