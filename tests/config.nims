# The tests link wgrender's desktop library, as examples/*/config.nims does: WGRENDER_DIR,
# else a ../wgrender-c checkout beside this repository, else the submodule.
import std/os

const
  repoDir = currentSourcePath().parentDir() / ".."
  wgrenderSibling = repoDir / "../wgrender-c"
  wgrenderSubmodule = repoDir / "project/lib/wgrender-c"

let wgrenderDir = absolutePath(
  if existsEnv("WGRENDER_DIR"): getEnv("WGRENDER_DIR")
  elif fileExists(wgrenderSibling / "include/wgr.h"): wgrenderSibling
  else: wgrenderSubmodule)

switch("hints", "off")
switch("path", repoDir / "src")
switch("nimcache", repoDir / ".nimcache/tests")
switch("passC", "-I" & wgrenderDir / "include")
switch("passL", wgrenderDir / (when defined(macosx): "build/macos" else: "build/linux") / "libwgrender.a")
for lib in ["GL", "X11", "Xi", "Xcursor", "Xrandr", "asound", "dl", "m", "pthread"]:
  switch("passL", "-l" & lib)
