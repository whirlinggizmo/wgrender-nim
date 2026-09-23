# wgrender-nim

[wgrender](https://github.com/whirlinggizmo/wgrender-c) for Nim: as much of the API as
the `simple` example needs, which makes it wgrender's Nim entry in the
cross-binding benchmarks. It is not a complete binding yet.

```
wgrender.nimble          the package: srcDir src, `import wgr`
src/wgr.nim              the binding: Nim types, a distinct type per handle kind, closures
src/wgr/raw.nim          the C API as is, declared against wgrender's headers
examples/simple/         the port of wgrender's examples/simple.c (src/simple.nim)
examples/stress/         the port of wgrender's benchmark scene, tools/bench/stress.c
                         (every example builds with the same config.nims)
project/lib/wgrender-c   wgrender, pinned (git submodule)
tools/benchmarks.py      this port against the C -> docs/benchmarks.md
```

## Build

```sh
git clone --recursive https://github.com/whirlinggizmo/wgrender-nim.git
cd wgrender-nim/examples/simple     # or examples/stress
nim build desktop        # out/desktop/simple (Linux)
nim build web            # out/web/: simple.js + simple.wasm, wgrender's page shell
nim serve                # http://localhost:8000/
```

The web build needs Emscripten, and wgrender's own requirements (see its README).
`BACKEND`, `WEB_THREADS` and `WEB_DEBUG` are wgrender's make variables, read from the
environment.

wgrender is found in this order, as wgrender-hx finds it: `WGRENDER_DIR`, then a
`../wgrender-c` checkout beside this one (so a change there is tried here without
pushing it and moving the pin), then the pinned submodule, which is what a clone has.

## Benchmarks

`tools/benchmarks.py` builds `simple` and `stress` for the web and measures them with
wgrender's harness (`tools/bench/` in wgrender), against wgrender's C baseline, into
`bench/results.json` and [docs/benchmarks.md](docs/benchmarks.md). Run wgrender's own
`tools/benchmarks.py --all` to refresh every binding at once, or its plain run first
and then this one. By hand, not in CI; the stress scene needs Xvfb and a GPU.
