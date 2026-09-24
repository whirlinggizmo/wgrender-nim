# wgrender-nim

[wgrender](https://github.com/whirlinggizmo/wgrender-c) for Nim: as much of the API as
the `simple` example needs, which makes it wgrender's Nim entry in the
cross-binding benchmarks. It is not a complete binding yet.

```
wgrender.nimble          the package: srcDir src, `import wgr`
src/wgr.nim              the binding: Nim types, a distinct type per handle kind, closures
src/wgr/raw.nim          the C API as is, declared against wgrender's headers
src/wgr/build.nim        compiles wgrender into the program, from its mk/build.json
tests/tcalls.nim         how the calls are written, and that a wrong handle kind doesn't compile
examples/simple/         the port of wgrender's examples/simple.c (src/simple.nim)
examples/stress/         the port of wgrender's benchmark scene, tools/bench/stress.c
                         (every example builds with the same config.nims)
project/lib/wgrender-c   wgrender, pinned (git submodule)
tools/benchmarks.py      this port against the C -> docs/benchmarks.md
tools/coverage.py        raw.nim against wgrender's headers, and wgr.nim wrapping all of it (CI)
```

## Calling it

The calls read as Nim rather than C. A call on a handle is its action, written on the
handle; a constructor is `new<Kind>`; anything else is a plain proc:

```nim
let model = newModel(mesh)          # wgr_model_create
model.setPosition((1.0, 2.0, 3.0))  # wgr_model_set_position
model.setPosition(1, 2, 3)          # the same, x, y and z (see below)
beginFrame()                        # wgr_render_begin_frame
drawText("hi", 10, 10, 18, ColorBlack)    # wgr_text_draw: the built-in font
font.drawText("hi", 10, 40, 24, ColorBlue) # wgr_text_draw_ex: a font of its own
wgr.endFrame()                      # any call, qualified by the module
```

The handle kinds are distinct types, and the calls are overloaded on them, so a
Sprite3d where a Model belongs doesn't compile. A call without a handle carries its
section as a noun only where its action alone would be ambiguous: `drawText`,
`measureText`, `setAssetHost`, `ensureAssetAsync`, and `setLogLevel` with the `log*`
calls (std/logging has `debug`, `info`, `warn` and `error` of its own). `bool` results
are discardable. The types stay Nim's: strings, ints, floats, tuples, enums and
closures, never the C types.

`setPosition`, `setRotation` and `setScale` also take `x, y, z` beside the `Vec3`, so
`m.setPosition(1, 2, 3)` takes plain int literals; wgrender-hx takes only a `Vec3`.

`nim c -r tests/tcalls.nim` checks how calls are written, and what doesn't compile.

`raw.nim` is written by hand, so `tools/coverage.py --check` keeps it honest: clang
compiles a `_Static_assert` per declaration against wgrender's headers (every function's
parameter and return types, every imported struct field, every copied constant), and
every `raw` proc must be called from `wgr.nim`. CI runs it, with `tcalls` and both
examples, whenever the submodule moves.

## Build

```sh
git clone --recursive https://github.com/whirlinggizmo/wgrender-nim.git
cd wgrender-nim/examples/simple     # or examples/stress
nim build desktop        # out/desktop/simple
nim build web            # out/web/: simple.js + simple.wasm, wgrender's page shell
nim serve                # http://localhost:8000/
```

There is nothing to build first. `src/wgr/build.nim` compiles wgrender into the program
with Nim's own C compiler, from the sources and flags in wgrender's `mk/build.json`, so
a build needs Nim and a C compiler and nothing else: no make, no shell. On Windows that
is Nim's default MinGW, or MSVC with `--cc:vcc`; for the web, Emscripten (`emcc.bat` on
Windows). Unused parts of wgrender are left out at link time, so a program is no larger
than linking a prebuilt `libwgrender.a` would make it. `-d:wgrPrebuilt` links the one
wgrender's make built instead, for working on wgrender itself; and since Nim rebuilds a
C file when it changes but not when a header it includes does, build with `-f` after
editing a wgrender header.

`BACKEND`, `WEB_THREADS` and `WEB_DEBUG` in the environment choose the web build, as
they do for wgrender's own.

wgrender is found in this order, as wgrender-hx finds it: `-d:wgrenderDir=<path>` or
`WGRENDER_DIR`, then a `../wgrender-c` checkout beside this one (so a change there is
tried here without pushing it and moving the pin), then the pinned submodule, which is
what a clone has, and what `nimble install` puts in the package beside the binding.

## Benchmarks

`tools/benchmarks.py` builds `simple` and `stress` for the web and measures them with
wgrender's harness (`tools/bench/` in wgrender), against wgrender's C baseline, into
`bench/results.json` and [docs/benchmarks.md](docs/benchmarks.md). Run wgrender's own
`tools/benchmarks.py --all` to refresh every binding at once, or its plain run first
and then this one. By hand, not in CI; the stress scene needs Xvfb and a GPU.
