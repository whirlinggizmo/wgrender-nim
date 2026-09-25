# Building wgrender-nim

There is nothing to build first, and no build tool: `src/wgr/internal/build.nim` compiles
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
cd wgrender-nim/examples/simple     # or any other in examples/
nim build desktop        # out/linux/release/simple (out/windows/mingw/, out/macos/release/)
nim build web            # out/web/webgl2/: simple.js + simple.wasm, wgrender's page shell
nim build all            # both
nim serve                # http://localhost:8000/ (COOP/COEP headers, assets at /assets)
nim webcheck             # load the web build in a headless browser, fail if it doesn't run
nim clean
```

`nim c -r src/simple.nim` builds and runs the desktop version in place. With MSVC:
`nim build --cc:vcc desktop` (into `out/windows/msvc/`), or `nim c --cc:vcc -r
src/simple.nim`. On Windows the output and cache directories are named for the compiler:
`msvc` for `--cc:vcc`, `clang` for `--cc:clang`, `mingw` for Nim's default.

The web build is chosen by the environment, spelled as wgrender's own tools spell it:
`BACKEND=webgl2|webgpu`, `WEB_THREADS=1|0`, `WEB_DEBUG=0|1` (for example
`BACKEND=webgpu nim build web`). A threaded build needs a page with COOP/COEP headers,
which `nim serve` sends; `WEB_THREADS=0` runs on any static host.

`python3 tools/site.py` builds every example that way (WebGL2, `WEB_THREADS=0`) and
gathers them on one page with wgrender's page shell and its assets, into
`out/web/webgl2-nothreads/`: what `.github/workflows/pages.yml` publishes to
https://whirlinggizmo.github.io/wgrender-nim/. The examples load their assets from
`assets` beside the page, so the site works at a domain root or under a path.

Nim rebuilds a C file when it changes, but not when a header it includes does, so after
editing a wgrender header, build with `-f`.

## Which wgrender

In this order:

1. `-d:wgrenderDir=<path>`, or `WGRENDER_DIR`
2. a `../wgrender-c` checkout beside this one, so a change there is tried here without
   pushing it and moving the pin
3. `project/lib/wgrender-c`, the pinned submodule: what a clone has, and what
   `nimble install` puts in the package beside the binding

`-d:wgrPrebuilt` links a library wgrender built instead of compiling it in, for working
on wgrender itself, from wgrender's `out/<platform>/<variant>/` (the wg* layout,
whirlinggizmo/.github CONVENTIONS.md): its CMake `<os>-release` preset (`-d:wgrHeadless`
for `<os>-headless`; on Windows `windows-mingw`, or `windows-msvc` with `--cc:vcc`), or
for the web `tools/buildweb.py`'s `out/web/<webdir>/libwgrender.a`. The error says which command builds it.

## Checks

```sh
cd tests && nim c -r tcalls.nim        # how calls are written, and what doesn't compile
cd tests && WGR_HEADLESS_FRAMES=2 nim c -d:wgrHeadless -r tevents.nim   # events, running headless
python3 tools/gen_raw.py --check       # raw.nim is what the headers make (needs clang)
python3 tools/coverage.py --check      # raw.nim against wgrender's headers (needs clang)
```

CI runs all three, and builds every example in examples/ on the desktop. After wgrender's API moves,
`python3 tools/gen_raw.py` regenerates `src/wgr/raw.nim`.

## Benchmarks

`python3 tools/benchmarks.py` builds `simple` and `stress` for the web and measures them
with wgrender's harness against its C baseline (run wgrender's `tools/benchmarks.py`
first), into `bench/results.json` and [docs/benchmarks.md](docs/benchmarks.md). By
hand, not in CI; the stress scene needs Xvfb and a GPU.
