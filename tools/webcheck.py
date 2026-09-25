#!/usr/bin/env python3
"""Load an example's web build in a headless browser and fail if it doesn't run.

    tools/webcheck.py SITE WGRENDER_DIR SHOT     (what `nim webcheck` runs)

Serves SITE with tools/serve.py (COOP/COEP headers, so a threaded build runs too;
WGRENDER_DIR's examples/assets at /assets), loads it for 8 s, moves the mouse over the middle of the canvas, and fails
on a console error, an uncaught exception, the browser's own error log, a program that
never started (wgrender logs its backend when it does), or a screen of one colour.
The screenshot goes to SHOT, the build's work directory rather than its site. The
browser plumbing is tools/weblib.py, a Chromium-based browser (Chrome, Chromium,
Brave, Edge) found as it finds one.
"""
import base64
import re
import sys
import time
import urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))  # an embedded Python (Windows) doesn't add it
import weblib  # noqa: E402


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    site, wgrender, shot = (Path(a).resolve() for a in sys.argv[1:])
    if not any(site.glob('*.wasm')) or not (site / 'index.html').exists():
        sys.exit(f'FAILED: no web build in {site}: build it first (nim build web)')

    processes = weblib.RunProcesses('nim-webcheck')
    errors, lines, started = [], [], []
    try:
        port = weblib.free_port()
        processes.spawn([weblib.PYTHON, HERE / 'serve.py', port, site, '--assets', wgrender / 'examples/assets'])
        weblib.wait_for(f'http://127.0.0.1:{port}/examples.json', 'tools/serve.py')
        debug_base, browser = weblib.launch_browser(processes, weblib.find_browser(), 'headless')
        target = browser.send('Target.createTarget', {'url': 'about:blank'})['targetId']
        tab = weblib.open_session(f'ws://{urllib.parse.urlsplit(debug_base).netloc}/devtools/page/{target}')

        def on_event(msg):
            p = msg.get('params', {})
            if msg['method'] == 'Runtime.consoleAPICalled':
                text = ' '.join(str(a['value']) if 'value' in a else a.get('description', '') for a in p['args'])
                lines.append(text)
                if 'libwgrender:' in text and 'backend' in text:
                    started.append(text)
                if p.get('type') == 'error' or re.search(r'\[(ERROR|FATAL)', text):
                    errors.append(text)
            elif msg['method'] == 'Runtime.exceptionThrown':
                d = p['exceptionDetails']
                errors.append((d.get('exception') or {}).get('description') or d.get('text'))
            elif msg['method'] == 'Log.entryAdded' and p['entry']['level'] == 'error' \
                    and p['entry']['source'] != 'network':
                errors.append(f'[{p["entry"]["source"]}] {p["entry"].get("text", "")}')

        tab.on_event(on_event)
        for domain in ('Runtime', 'Log', 'Page'):
            tab.send(f'{domain}.enable')
        tab.send('Page.navigate', {'url': f'http://127.0.0.1:{port}/'})
        time.sleep(8)
        # the middle of the canvas (below the page's 38px bar), a little low
        x, y = tab.send('Runtime.evaluate', {
            'expression': "(() => { const r = document.getElementById('canvas').getBoundingClientRect();"
                          " return [r.left + r.width / 2, r.top + r.height / 2 + 20]; })()",
            'returnByValue': True})['result']['value']
        tab.send('Input.dispatchMouseEvent', {'type': 'mouseMoved', 'x': x, 'y': y})
        time.sleep(1)
        data = tab.send('Page.captureScreenshot', {'format': 'png'})['data']
        shot.parent.mkdir(parents=True, exist_ok=True)
        shot.write_bytes(base64.b64decode(data))
        if not started:
            errors.append('the program never started (wgrender logged no backend)')
        if weblib.distinct_colours(tab, data) < 2:
            errors.append(f'the screen is one flat colour: nothing was drawn ({shot})')
        for line in lines:
            print(f'  console: {line}')
        print(f'screenshot: {shot}')
    finally:
        processes.stop()
    if errors:
        sys.exit('FAILED:\n  ' + '\n  '.join(str(e) for e in errors))
    print('ok')


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as e:  # weblib's: a browser or server that didn't come up
        sys.exit(f'webcheck: {e}')
