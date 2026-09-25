#!/usr/bin/env python3
"""Every example on one page, for a static host (the Pages workflow publishes it):
https://whirlinggizmo.github.io/wgrender-nim/

    tools/site.py            build every example for the web, then assemble the site
    tools/site.py --no-build assemble it from the examples' existing web builds

Each example is one wasm program with wgrender compiled in, as wgrender's own C
examples are, so they share one directory the way wgrender's site does: every
example's .js and .wasm, wgrender's page shell (its picker lists them; `simple` opens
first), the picker's examples.json and the page's versions from wgrender's
tools/webdeploy.py, and wgrender's examples/assets beside them (not the benchmarks'),
which the examples load as "assets", relative to the page.

The builds are WebGL2 without threads (WEB_THREADS=0): a static host such as GitHub
Pages sends no COOP/COEP headers, and a threaded build won't start without them. The
site is a web build of this repository's, so it goes where one goes:
out/web/webgl2-nothreads/, its work in build/web/webgl2-nothreads/.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from coverage import find_wgrender  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
VARIANT = 'webgl2-nothreads'
WEB = {'BACKEND': 'webgl2', 'WEB_THREADS': '0', 'WEB_DEBUG': '0'}
FIRST = 'simple'  # what the page opens with


def examples():
    return sorted(d for d in (ROOT / 'examples').iterdir() if (d / 'config.nims').is_file())


def main():
    args = sys.argv[1:]
    if set(args) - {'--no-build'}:
        sys.exit(__doc__)
    wgrender = find_wgrender()
    nim = shutil.which('nim') or 'nim'
    if '--no-build' not in args:
        for example in examples():
            print(f'+ nim build web  ({example.name}, WEB_THREADS=0)', flush=True)
            subprocess.run([nim, 'build', 'web'], cwd=example, check=True, env=dict(os.environ, **WEB))

    site = ROOT / 'out/web' / VARIANT
    work = ROOT / 'build/web' / VARIANT
    shutil.rmtree(site, ignore_errors=True)
    site.mkdir(parents=True)
    work.mkdir(parents=True, exist_ok=True)
    built = []
    for example in examples():
        name, build = example.name, example / 'out/web' / VARIANT
        files = [build / f'{name}.js', build / f'{name}.wasm']
        if not all(f.exists() for f in files):
            print(f'{name}: no web build without threads, skipping (tools/site.py builds them)', file=sys.stderr)
            continue
        for f in files:
            shutil.copy2(f, site / f.name)
        built.append(name)
    if not built:
        sys.exit('site: nothing built')

    shell = work / 'index.html'
    text = (wgrender / 'examples/web/index.html').read_text(encoding='utf-8')
    if 'params.get("ex") || "hello"' not in text:
        sys.exit(f'site: {wgrender}/examples/web/index.html no longer defaults to "hello": update this')
    text = text.replace('params.get("ex") || "hello"', f'params.get("ex") || "{FIRST}"')
    text = text.replace('<title>wgrender examples</title>', '<title>wgrender examples, in Nim</title>')
    shell.write_text(text, encoding='utf-8')
    subprocess.run([sys.executable, wgrender / 'tools/webdeploy.py', site, shell], check=True)
    shutil.copytree(wgrender / 'examples/assets', site / 'assets', ignore=shutil.ignore_patterns('bench'))
    size = sum(f.stat().st_size for f in site.rglob('*') if f.is_file())
    print(f'site -> {site} ({len(built)} examples: {", ".join(built)}; {size:,} bytes with assets)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
