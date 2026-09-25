# wgrender for Nim. The binding is src/ (import wgr); wgrender itself is C, compiled
# into the program by Nim's own C compiler (src/wgr/internal/build.nim): no build tool needed.
version       = "0.1.0"
author        = "Rob Knopf"
description   = "wgrender for Nim"
license       = "MIT"
srcDir        = "src"
# The binding, and wgrender itself (the submodule): src/wgr/internal/build.nim compiles
# wgrender into the program from its sources, so the package has to carry them.
installFiles  = @["wgr.nim"]
installDirs   = @["wgr", "project"]

requires "nim >= 2.2.0"
