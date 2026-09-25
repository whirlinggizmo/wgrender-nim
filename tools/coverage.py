#!/usr/bin/env python3
"""Does the binding still match wgrender's C API?

    tools/coverage.py --check           fail on any mismatch (what CI runs)
    tools/coverage.py --list            also list what src/wgr.nim doesn't wrap yet
    tools/coverage.py --require-clang   fail rather than skip without clang (CI)

src/wgr/raw.nim is generated (tools/gen_raw.py), and this checks the generator's work
independently: raw.nim's procs import with `header: "wgr.h"`, so the C compiler sees
the real prototype of a call, but only of a call something makes (an unused
declaration is never emitted), and Nim runs it with -w, so a parameter declared cint
where C now takes a float would convert without a word. So this checks every
declaration against wgrender's headers itself:

  - every proc raw.nim imports is one wgrender declares, with the same parameter and
    return types, and the same variadic-ness
  - every C struct it imports has the fields raw.nim gives it, of the same types
  - every constant it copies has the header's value
  - every function the headers declare is in raw.nim

It does that the way the C compiler would, because it asks it: it writes a C file of
_Static_asserts from raw.nim's declarations (the function's type against the one
raw.nim declares, with __builtin_types_compatible_p) and compiles it with clang
-fsyntax-only against wgrender's headers and compile_flags.txt. clang is emsdk's,
found from the emcc on PATH, else a clang on PATH, else under $EMSDK. src/wgr.nim
wraps part of raw.nim by hand, so what it doesn't wrap yet is a count, not a failure.

wgrender is WGRENDER_DIR, else a ../wgrender-c checkout beside this one, else the
submodule, as examples/*/config.nims find it.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'src/wgr/raw.nim'
WRAPPERS = ROOT / 'src/wgr.nim'


def find_wgrender():
    if os.environ.get('WGRENDER_DIR'):
        return Path(os.environ['WGRENDER_DIR']).resolve()
    sibling = ROOT.parent / 'wgrender-c'
    if (sibling / 'include/wgr.h').is_file():
        return sibling.resolve()
    return (ROOT / 'project/lib/wgrender-c').resolve()


def find_clang():
    """emsdk's clang (what the web build uses), else one on PATH, else under $EMSDK."""
    def at(directory):
        for leaf in ('clang', 'clang.exe'):
            if (directory / leaf).exists():
                return str(directory / leaf)
        return None
    emcc = shutil.which('emcc')
    if emcc:
        found = at(Path(emcc).resolve().parent.parent / 'bin')
        if found:
            return found
    for name in ('clang', 'clang-23', 'clang-22', 'clang-21'):
        if shutil.which(name):
            return shutil.which(name)
    if os.environ.get('EMSDK'):
        return at(Path(os.environ['EMSDK']) / 'upstream' / 'bin')
    return None


# --- raw.nim -------------------------------------------------------------------

# Nim's C types, as C writes them
BASIC = {'cint': 'int', 'cuint': 'unsigned int', 'cfloat': 'float', 'cdouble': 'double',
         'bool': '_Bool', 'pointer': 'void *', 'cstring': 'char *', 'uint32': 'uint32_t',
         'int32': 'int32_t', 'uint8': 'uint8_t', 'cchar': 'char'}


def split_top(text, sep):
    """Split on `sep` outside brackets."""
    parts, depth, cur = [], 0, ''
    for ch in text:
        depth += ch in '([{'
        depth -= ch in ')]}'
        if ch == sep and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts]


def params_of(text):
    """`a, b: cint; c: cfloat` -> [('a', 'cint'), ('b', 'cint'), ('c', 'cfloat')]"""
    out = []
    for group in split_top(text, ';'):
        if not group:
            continue
        names, _, typ = group.partition(':')
        for name in names.split(','):
            out.append((name.strip(), typ.strip()))
    return out


def parse_raw():
    """raw.nim's type aliases, callback types, imported structs, constants and procs."""
    lines = RAW.read_text(encoding='utf-8').splitlines()
    aliases, callbacks, structs, consts, procs = {}, {}, {}, {}, []
    in_push = False
    i = 0
    while i < len(lines):
        line = lines[i].split('##')[0].rstrip()
        stripped = line.strip()
        if stripped.startswith('{.push importc'):
            in_push = True
        elif stripped.startswith('{.pop.}'):
            in_push = False
        m = re.match(r'(\w+)\*\s*\{\.importc:\s*"([^"]+)"[^}]*\.\}\s*=\s*object', stripped)
        if m:
            fields = []
            i += 1
            while i < len(lines) and (lines[i].startswith('    ') or not lines[i].strip()):
                f = lines[i].split('##')[0].strip()
                if f:
                    names, _, typ = f.partition(':')
                    for name in names.split(','):
                        fields.append((name.strip().rstrip('*'), typ.strip()))
                i += 1
            structs[m.group(1)] = (m.group(2), fields)
            continue
        m = re.match(r'(\w+)\*\s*\{\.importc:\s*"([^"]+)",\s*nodecl\.\}\s*=', stripped)
        if m:
            aliases[m.group(1)] = m.group(2)
        m = re.match(r'(\w+)\*\s*=\s*proc\s*\((.*)\)\s*(?::\s*(\w+))?\s*\{\.cdecl\.\}', stripped)
        if m:
            callbacks[m.group(1)] = (params_of(m.group(2)), m.group(3))
        elif re.match(r'(\w+)\*\s*=\s*(\w+)$', stripped) and not in_push:
            name, target = re.match(r'(\w+)\*\s*=\s*(\w+)$', stripped).groups()
            aliases.setdefault(name, target)
        m = re.match(r'(WGR_\w+)\*\s*=\s*(.+)$', stripped)
        if m:
            consts[m.group(1)] = m.group(2).strip()
        if in_push and stripped.startswith('proc '):
            text = stripped
            while text.count('(') > text.count(')'):
                i += 1
                text += ' ' + lines[i].split('##')[0].strip()
            m = re.match(r'proc (\w+)\*\s*\((.*)\)\s*(?::\s*([\w\[\], ]+?))?\s*(\{\..*\.\})?$', text)
            if not m:
                sys.exit(f'coverage: cannot read raw.nim: {text}')
            procs.append({'name': m.group(1), 'params': params_of(m.group(2)),
                          'ret': m.group(3), 'varargs': 'varargs' in (m.group(4) or '')})
        i += 1
    return aliases, callbacks, structs, consts, procs


def c_type(nim, aliases, callbacks, structs, as_c=None):
    """A raw.nim type as C writes it. `as_c` is the C side's own type, taken where
    raw.nim's is the same thing in Nim's terms: an enum is passed as cint, which is
    what C passes it as, and a cstring is `const char *` where C says so, Nim having
    no const (the pointer is the same; Nim just can't promise not to write through it)."""
    nim = nim.strip()
    if as_c and (nim == 'cint' and as_c[1].startswith('enum ')
                 or nim == 'cstring' and as_c[0] == 'const char *'):
        return as_c[0]
    m = re.match(r'array\[(\d+),\s*(\w+)\]', nim)
    if m:
        return ('array', c_type(m.group(2), aliases, callbacks, structs), m.group(1))
    if nim in structs:
        return structs[nim][0]
    if nim in callbacks:
        params, ret = callbacks[nim]
        args = ', '.join(c_type(t, aliases, callbacks, structs) for _, t in params) or 'void'
        return f'{c_type(ret, aliases, callbacks, structs) if ret else "void"} (*)({args})'
    if nim in aliases:
        target = aliases[nim]
        return target if target not in BASIC and target not in aliases and target not in structs \
            and ' ' in target or target.endswith('*') else c_type(target, aliases, callbacks, structs)
    if nim in BASIC:
        return BASIC[nim]
    sys.exit(f'coverage: no C type for raw.nim type {nim!r}: add it to BASIC')


def c_literal(nim):
    """`0xFF'u32` -> `0xFFu`, `3.cint` -> `3`."""
    value = re.sub(r"'[iu]\d+$", '', nim)
    value = re.sub(r'\.c\w+$', '', value)
    return value + ('u' if "'u" in nim else '')


# --- wgrender's headers ------------------------------------------------------------

def header_functions(clang, wgrender, flags):
    """name -> (return type, [(param type, desugared)], variadic) for every wgr_ function."""
    with tempfile.NamedTemporaryFile('w', suffix='.c', delete=False) as f:
        f.write('#include "wgr.h"\n')
        source = f.name
    try:
        out = subprocess.run([clang, '-Xclang', '-ast-dump=json', '-Xclang', '-ast-dump-filter=wgr_',
                              '-fsyntax-only', *flags, source], cwd=wgrender,
                             capture_output=True, text=True)
    finally:
        os.unlink(source)
    if out.returncode != 0:
        sys.exit(f'coverage: clang could not read wgrender\'s headers:\n{out.stderr}')
    functions, enum_typedefs = {}, set()
    decoder, text, pos = json.JSONDecoder(), out.stdout, 0
    while True:
        start = text.find('{', pos)
        if start < 0:
            break
        node, pos = decoder.raw_decode(text, start)
        if node.get('kind') == 'TypedefDecl' and node['type']['qualType'].startswith('enum '):
            enum_typedefs.add(node['name'])  # before the functions that return one
        if node.get('kind') != 'FunctionDecl' or not node.get('name', '').startswith('wgr_'):
            continue
        params = [(p['type']['qualType'], p['type'].get('desugaredQualType', p['type']['qualType']))
                  for p in node.get('inner', []) if p.get('kind') == 'ParmVarDecl']
        ret = re.match(r'(.*?)\s*\(', node['type']['qualType']).group(1)
        # clang doesn't desugar a function's return type: an enum typedef stays its name
        desugared = f'enum {ret}' if ret in enum_typedefs else ret
        functions[node['name']] = ((ret, desugared), params, bool(node.get('variadic')))
    return functions


# --- the checks ----------------------------------------------------------------------

def asserts(raw, functions):
    """The C file of _Static_asserts, and what each one checks."""
    aliases, callbacks, structs, consts, procs = raw
    enums = {q for _, ps, _ in functions.values() for q, d in ps if d.startswith('enum ')}
    enums |= {r for (r, d), _, _ in functions.values() if d.startswith('enum ')}

    def ret_as_c(c_ret):
        return (c_ret, 'enum ' if c_ret in enums else c_ret)
    lines = ['#include "wgr.h"', '#include <stddef.h>']

    def check(cond, what):
        lines.append(f'_Static_assert({cond}, "{what}");')

    for p in procs:
        name = p['name']
        if name not in functions:
            continue  # reported by name, below
        (c_ret, _), c_params, c_variadic = functions[name]
        args = []
        for k, (_, typ) in enumerate(p['params']):
            c_param = c_params[k] if k < len(c_params) else None
            args.append(render(c_type(typ, aliases, callbacks, structs, as_c=c_param)))
        if p['varargs']:
            args.append('...')
        ret = render(c_type(p['ret'], aliases, callbacks, structs, as_c=ret_as_c(c_ret))) if p['ret'] else 'void'
        check(f'__builtin_types_compatible_p(__typeof__({name}), {ret} ({", ".join(args) or "void"}))',
              f'raw.nim: {name} is not declared as wgrender declares it')
    for nim, (cname, fields) in structs.items():
        for field, typ in fields:
            t = c_type(typ, aliases, callbacks, structs)
            decl = f'{t[1]} [{t[2]}]' if isinstance(t, tuple) else render(t)
            check(f'__builtin_types_compatible_p(__typeof__((({cname} *)0)->{field}), {decl})',
                  f'raw.nim: {nim}.{field} is not {cname}.{field}')
    for name, value in consts.items():
        check(f'({name}) == ({c_literal(value)})', f'raw.nim: {name} is not wgrender\'s value')
    return '\n'.join(lines) + '\n'


def render(t):
    return f'{t[1]} [{t[2]}]' if isinstance(t, tuple) else t


def main():
    args = sys.argv[1:]
    if set(args) - {'--check', '--list', '--require-clang'}:
        sys.exit(__doc__)
    wgrender = find_wgrender()
    raw = parse_raw()
    procs = raw[4]
    problems = []

    # raw.nim is generated whole (tools/gen_raw.py); wgr.nim wraps part of it by hand
    wrappers = WRAPPERS.read_text(encoding='utf-8')
    wrapped = [p for p in procs if re.search(rf'\b{p["name"]}\b', wrappers)]

    clang = find_clang()
    if clang is None:
        if '--require-clang' in args:
            sys.exit('coverage: no clang, and --require-clang was given (emsdk provides one)')
        print('coverage: no clang found (emsdk provides one; `emcc` on PATH leads to it); '
              'checked the wrappers only')
    else:
        flags = [l for l in (wgrender / 'compile_flags.txt').read_text().splitlines() if l.strip()]
        functions = header_functions(clang, wgrender, flags)
        for p in procs:
            if p['name'] not in functions:
                problems.append(f'raw.nim: {p["name"]} is not a wgrender function')
        with tempfile.NamedTemporaryFile('w', suffix='.c', delete=False) as f:
            f.write(asserts(raw, functions))
            source = f.name
        try:
            out = subprocess.run([clang, '-fsyntax-only', *flags, source], cwd=wgrender,
                                 capture_output=True, text=True)
        finally:
            os.unlink(source)
        for line in out.stderr.splitlines():
            m = re.search(r'error: (?:static assertion failed[^"]*"(.*)"|(.*))$', line)
            if m:
                problems.append(m.group(1) or f'raw.nim: {m.group(2)}')
        unbound = sorted(set(functions) - {p['name'] for p in procs})
        for name in unbound:
            problems.append(f'raw.nim: no {name}, which wgrender declares: run tools/gen_raw.py')
        unwrapped = sorted({p['name'] for p in procs} - {p['name'] for p in wrapped})
        print(f'coverage: raw.nim declares {len(procs)} of wgrender\'s {len(functions)} functions, '
              f'{len(raw[2])} structs, {len(raw[3])} constants; wgr.nim wraps {len(wrapped)}')
        if '--list' in args:
            print('not wrapped in wgr.nim yet:')
            for name in unwrapped:
                print(f'  {name}')

    for problem in problems:
        print(f'  {problem}')
    if problems:
        print(f'coverage: {len(problems)} problem(s)')
        return 1
    print('coverage: raw.nim matches wgrender')
    return 0


if __name__ == '__main__':
    sys.exit(main())
