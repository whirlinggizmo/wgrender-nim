# Building wgrender-nim

There is nothing to build first, and no build tool: `src/wgr/build.nim` compiles
wgrender into the program with Nim's own C compiler, from the sources and flags in
wgrender's [`build.json`](https://github.com/whirlinggizmo/wgrender-c/blob/main/build.json).
Parts of wgrender a program doesn't use are left out at link time, so it is no larger
than it would be linking a prebuilt `libwgrender.a`.

## What you need

- Nim 2.2
- a C compiler:
  - Linux and macOS: gcc or clang
  - Windows: the MinGW that choosenim installs (Nim's default), or MSVC (Visual Studio)
    with `--cc:vcc`
- for the web: Emscripten (emsdk), with `emcc` on `PATH`; on Windows that's `emcc.bat`,
  which the build names for Nim
- Python 3 for `nim serve` and the web page (wgrender's `tools/serve.py` and
  `tools/webdeploy.py`); emsdk brings one
- on Linux, the system's GL, X11 and ALSA dev packages, which sokol links:
  `python3 project/lib/wgrender-c/tools/deps.py install` (apt, dnf or pacman)

## Build an example

```sh
git clone --recursive https://github.com/whirlinggizmo/wgrender-nim.git
cd wgrender-nim/examples/simple     # or examples/stress
nim build desktop        # out/desktop/simple
nim build web            # out/web/: simple.js + simple.wasm, wgrender's page shell
nim build all            # both
nim serve                # http://localhost:8000/ (COOP/COEP headers, assets at /assets)
nim clean
```

`nim c -r src/simple.nim` builds and runs the desktop version in place. With MSVC:
`nim c --cc:vcc -r src/simple.nim`.

The web build is chosen by the environment, spelled as wgrender's own tools spell it:
`BACKEND=webgl2|webgpu`, `WEB_THREADS=1|0`, `WEB_DEBUG=0|1` (for example
`BACKEND=webgpu nim build web`). A threaded build needs a page with COOP/COEP headers,
which `nim serve` sends; `WEB_THREADS=0` runs on any static host.

Nim rebuilds a C file when it changes, but not when a header it includes does, so after
editing a wgrender header, build with `-f`.

## Which wgrender

In this order, as wgrender-hx finds it:

1. `-d:wgrenderDir=<path>`, or `WGRENDER_DIR`
2. a `../wgrender-c` checkout beside this one, so a change there is tried here without
   pushing it and moving the pin
3. `project/lib/wgrender-c`, the pinned submodule: what a clone has, and what
   `nimble install` puts in the package beside the binding

`-d:wgrPrebuilt` links a library wgrender built instead of compiling it in, for working
on wgrender itself: its CMake `desktop` preset (`-d:wgrHeadless` for `headless`),
`build/<preset>/libwgrender.a`, or for the web `tools/buildweb.py`'s
`build/<webdir>/libwgrender.a`. The error says which command builds it.

## Checks

```sh
cd tests && nim c -r tcalls.nim        # how calls are written, and what doesn't compile
python3 tools/coverage.py --check      # raw.nim against wgrender's headers (needs clang)
```

CI runs both, and builds both examples on the desktop.

## Benchmarks

`python3 tools/benchmarks.py` builds `simple` and `stress` for the web and measures them
with wgrender's harness against its C baseline (run wgrender's `tools/benchmarks.py`
first), into `bench/results.json` and [docs/benchmarks.md](docs/benchmarks.md). By
hand, not in CI; the stress scene needs Xvfb and a GPU.
