# wgrender for Nim. The binding is src/ (import wgr); wgrender itself is C, compiled
# into the program by Nim's own C compiler (src/wgr/internal/build.nim): no build tool needed.
version       = "0.1.0"
author        = "Rob Knopf"
description   = "wgrender for Nim"
license       = "MIT"
srcDir        = "src"
# The package is src/: the binding, and wgrender itself (the submodule, src/wgr/wgrender-c),
# since src/wgr/internal/build.nim compiles wgrender into the program from its sources.
# Of wgrender, only what that takes: build.json, include/, src/, deps/ (less clay, which
# only its examples use), shaders/ (wgr.glsl, for a program's own shaders) and LICENSE.
# nimble leaves out every tests/ itself.
skipDirs      = @["src/wgr/wgrender-c/bench",
                   "src/wgr/wgrender-c/build",
                   "src/wgr/wgrender-c/cmake",
                   "src/wgr/wgrender-c/deps/clay",
                   "src/wgr/wgrender-c/docs",
                   "src/wgr/wgrender-c/examples",
                   "src/wgr/wgrender-c/tools"]

requires "nim >= 2.2.0"
# httpFetcher (-d:wgrIncludeFetcher): imported only with that define, so a program
# without it compiles and links none of it
requires "puppy >= 2.1.2"
