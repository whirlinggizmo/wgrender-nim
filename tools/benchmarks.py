#!/usr/bin/env python3
"""wgrender-nim against the C: the `simple` example compiled Nim -> C -> one wasm,
beside wgrender's own C build of it.

    tools/benchmarks.py          build it, measure it, write bench/results.json and
                                 docs/benchmarks.md
    tools/benchmarks.py --doc    only regenerate docs/benchmarks.md

The harness is wgrender's (tools/bench/measure.py) and so is the C baseline: run
wgrender's tools/benchmarks.py first, on the same machine, so its bench/results.json
is there to compare against. wgrender is found as the example's build finds it:
WGRENDER_DIR, else ../wgrender-c beside this repository, else the submodule.
results.json records which.

Run by hand, not in CI. Commit bench/results.json and docs/benchmarks.md afterwards.
"""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def find_wgrender():
    """The same order as examples/simple/config.nims."""
    if os.environ.get('WGRENDER_DIR'):
        return pathlib.Path(os.environ['WGRENDER_DIR']).resolve(), 'WGRENDER_DIR'
    if (ROOT / '../wgrender-c/include/wgr.h').is_file():
        return (ROOT / '../wgrender-c').resolve(), 'sibling checkout'
    return (ROOT / 'project/lib/wgrender-c').resolve(), 'submodule'


WGRENDER, SOURCE = find_wgrender()
if not (WGRENDER / 'tools/bench/measure.py').is_file():
    sys.exit(f'no wgrender benchmark harness in {WGRENDER} (git submodule update --init, or set WGRENDER_DIR)')
sys.path.insert(0, str(WGRENDER / 'tools/bench'))
import measure  # noqa: E402
RESULTS = ROOT / 'bench/results.json'
DOC = ROOT / 'docs/benchmarks.md'
EXAMPLE = ROOT / 'examples/simple'


def measure_all():
    for example in (EXAMPLE, ROOT / 'examples/stress'):
        measure.run(['nim', 'build', 'web'], cwd=example, env=dict(measure.WEB_VARS, WGRENDER_DIR=str(WGRENDER)))
    nim = subprocess.run(['nim', '--version'], capture_output=True, text=True).stdout.splitlines()[0]
    site = EXAMPLE / 'out/web/webgl2-nothreads'  # measure.WEB_VARS: no threads
    page = {'probe': 'simple.js'}
    config = {
        'id': 'nim', 'label': 'Nim -> C', 'project': 'wgrender-nim', 'example': 'simple',
        'toolchain': nim.split(' [')[0].replace(' Compiler Version', ''),
        # the page is wgrender's example shell, which fetches examples.json for its picker
        'sizes': measure.sizes([site / 'simple.wasm', site / 'simple.js',
                                site / 'index.html', site / 'examples.json']),
        'frame': measure.frame(site, 'nim', **page),
        'gc': measure.gc(site, 'nim', **page),
        'stress': measure.stress(ROOT / 'examples/stress/out/web/webgl2-nothreads', 'nim', '/?n={n}', 'stress.js'),
    }
    return measure.write_results(RESULTS, 'wgrender-nim', measure.wgrender_info(WGRENDER, SOURCE), [config])


def main():
    baseline_path = WGRENDER / 'bench/results.json'
    if not baseline_path.is_file():
        sys.exit(f'no C baseline at {baseline_path}: run {WGRENDER / "tools/benchmarks.py"} first')
    baseline = measure.load_results(baseline_path)
    ours = measure.load_results(RESULTS) if '--doc' in sys.argv[1:] else measure_all()
    lead = ('`simple` compiled Nim -> C -> one wasm, beside the C. The C row and the call costs '
            'are wgrender\'s baseline (its `bench/results.json`); every binding is collected in '
            'wgrender\'s `docs/benchmarks.md`.')
    DOC.parent.mkdir(exist_ok=True)
    DOC.write_text(measure.render_doc('wgrender-nim benchmarks', lead, [baseline, ours], baseline,
                                      'tools/benchmarks.py'))
    print(f'wrote {DOC}')


if __name__ == '__main__':
    main()
