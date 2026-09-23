# wgrender for Nim. The binding is src/ (import wgr); wgrender itself is C, built by
# its own Makefile (project/lib/wgrender-c, or see README), not by nimble.
version       = "0.1.0"
author        = "Rob Knopf"
description   = "wgrender for Nim"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.2.0"
