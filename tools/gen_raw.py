#!/usr/bin/env python3
"""Generate src/wgr/raw.nim, the whole C API, from wgrender's public headers.

    tools/gen_raw.py            write it
    tools/gen_raw.py --check    say whether it is current, and exit non-zero if not

raw.nim is written whole and never edited: run this when wgrender's API moves. The
Nim layer over it, src/wgr.nim, is written by hand, and wraps what the examples and
programs use; everything else is here, in C's terms, for anything not wrapped yet.

What it reads, it reads the way the C compiler does, because it asks it: clang
(emsdk's, found as tools/coverage.py finds it) dumps the headers' AST, and every
function, struct, enum and callback typedef comes from that, with its exact types.
The constants are #defines, which an AST doesn't keep, so those are read from the
headers' text; they are plain integers. tools/coverage.py --check then checks what
this wrote against the headers, independently, by compiling assertions about it.

A function with a type this can't map (va_list, say) is left out and listed at the
end, so a gap is reported rather than silent. The file records the wgrender it came
from and a digest of the headers, which is what --check compares.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from coverage import find_clang, find_wgrender  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'src/wgr/raw.nim'
DIGEST_TAG = '## wgrender-headers: '

# C scalar types, as Nim names them
SCALARS = {
    'int': 'cint', 'unsigned int': 'cuint', 'float': 'cfloat', 'double': 'cdouble',
    'bool': 'bool', '_Bool': 'bool', 'char': 'cchar', 'unsigned char': 'uint8',
    'short': 'cshort', 'unsigned short': 'cushort', 'long': 'clong', 'unsigned long': 'culong',
    'long long': 'clonglong', 'unsigned long long': 'culonglong', 'size_t': 'csize_t',
    'int8_t': 'int8', 'int16_t': 'int16', 'int32_t': 'int32', 'int64_t': 'int64',
    'uint8_t': 'uint8', 'uint16_t': 'uint16', 'uint32_t': 'uint32', 'uint64_t': 'uint64',
}
# wgrender's own scalar typedefs
TYPEDEFS = {'wgr_handle_t': 'WgrHandle', 'wgr_color_t': 'WgrColor'}

NIM_KEYWORDS = set('''addr and as asm bind block break case cast concept const continue
converter defer discard distinct div do elif else end enum except export finally for from
func if import in include interface is isnot iterator let macro method mixin mod nil not
notin object of or out proc ptr raise ref return shl shr static template try tuple type
using var when while xor yield'''.split())


def ident(name):
    return f'`{name}`' if name in NIM_KEYWORDS else name


def camel(c_name):
    """vec2_t -> Vec2, wgr_mouse_state_t -> MouseState, wgr_frame_fn -> FrameFn."""
    name = re.sub(r'^wgr_', '', c_name)
    name = re.sub(r'_t$', '', name)
    return ''.join(part[:1].upper() + part[1:] for part in name.split('_'))


# --- what the headers declare ----------------------------------------------------

def read_ast(clang, wgrender, flags):
    """(structs, enums, callbacks, functions) from clang's AST of wgr.h: everything
    declared in wgrender's own include/, in the order it is declared."""
    with tempfile.NamedTemporaryFile('w', suffix='.c', delete=False) as f:
        f.write('#include "wgr.h"\n')
        source = f.name
    try:
        out = subprocess.run([clang, '-Xclang', '-ast-dump=json', '-fsyntax-only', *flags, source],
                             cwd=wgrender, capture_output=True, text=True, encoding='utf-8')
    finally:
        os.unlink(source)
    if out.returncode != 0:
        sys.exit(f'gen_raw: clang could not read wgrender\'s headers:\n{out.stderr}')
    unit = json.loads(out.stdout)

    include = (wgrender / 'include').resolve()
    structs, enums, callbacks, functions = {}, {}, {}, []
    pending_record, pending_enum = None, None
    current = None  # a node's loc names its file only when it changes
    for node in unit.get('inner', []):
        loc = node.get('loc', {})
        current = (loc.get('file') or loc.get('expansionLoc', {}).get('file')
                   or loc.get('spellingLoc', {}).get('file') or current)
        if not current or not Path(wgrender, current).resolve().is_relative_to(include):
            continue  # stdint.h and the like
        kind = node['kind']
        if kind == 'RecordDecl' and node.get('completeDefinition'):
            pending_record = [(f['name'], f['type']['qualType']) for f in node.get('inner', [])
                              if f['kind'] == 'FieldDecl']
            if node.get('name'):
                structs[node['name']] = pending_record
        elif kind == 'EnumDecl':
            values, last = [], -1
            for c in node.get('inner', []):
                if c['kind'] != 'EnumConstantDecl':
                    continue
                given = next((e.get('value') for e in c.get('inner', []) if 'value' in e), None)
                last = int(given) if given is not None else last + 1
                values.append((c['name'], last))
            pending_enum = values
            if node.get('name'):
                enums[node['name']] = values
        elif kind == 'TypedefDecl':
            name, qual = node['name'], node['type']['qualType']
            if qual.startswith('struct ') and pending_record is not None:
                structs[name] = pending_record
                pending_record = None
            elif qual.startswith('enum ') and pending_enum is not None:
                enums[name] = pending_enum
                pending_enum = None
            elif '(*)' in qual:
                callbacks[name] = qual
        elif kind == 'FunctionDecl' and node.get('name', '').startswith('wgr_'):
            ret = re.match(r'(.*?)\s*\(', node['type']['qualType']).group(1)
            params = [(p.get('name'), p['type']['qualType'])
                      for p in node.get('inner', []) if p['kind'] == 'ParmVarDecl']
            functions.append((node['name'], ret, params, bool(node.get('variadic'))))
    return structs, enums, callbacks, functions


def read_defines(wgrender):
    """The integer #defines: name -> Nim literal. Strings, macros and the like are left
    out (they are not values a call takes)."""
    out = {}
    for header in sorted((wgrender / 'include').glob('*.h')):
        for m in re.finditer(r'^#define\s+(WGR_\w+)[ \t]+(0[xX][0-9A-Fa-f]+|\d+)([uU]?)\b',
                             header.read_text(encoding='utf-8'), re.M):
            name, number, unsigned = m.groups()
            out[name] = f"{number}'u32" if unsigned else f'{number}.cint'
    return out


def callback_param_names(wgrender):
    """typedef void (*wgr_frame_fn)(float dt, float tick_fraction, void *user) -> names:
    the AST's function-pointer type carries only the types."""
    names = {}
    for header in sorted((wgrender / 'include').glob('*.h')):
        text = re.sub(r'/\*.*?\*/', ' ', header.read_text(encoding='utf-8'), flags=re.S)
        for m in re.finditer(r'typedef\s+[^;]*?\(\s*\*\s*(\w+)\s*\)\s*\(([^)]*)\)\s*;', text):
            params = [p.strip() for p in m.group(2).split(',') if p.strip() not in ('', 'void')]
            names[m.group(1)] = [(re.search(r'(\w+)\s*$', p).group(1) if re.search(r'[\s*]\w+\s*$', p) else None)
                                 for p in params]
    return names


# --- C types as Nim ones -------------------------------------------------------------

class Types:
    def __init__(self, structs, enums, callbacks):
        self.structs, self.enums, self.callbacks = structs, enums, callbacks

    def nim(self, c, where='param'):
        """The Nim type for a C type, or None. `where` is param, field, or callback (a
        callback's const char * stays const: clang rejects the mismatched function
        type otherwise)."""
        c = ' '.join(c.replace('struct ', '').replace('enum ', '').split())
        m = re.match(r'^(.*?)\s*\[(\d+)\]$', c)
        if m:
            inner = self.nim(m.group(1), where)
            return f'array[{m.group(2)}, {inner}]' if inner else None
        if c in ('const char *', 'const char*'):
            return 'WgrConstCstring' if where == 'callback' else 'cstring'
        if c in ('char *',):
            return 'cstring'
        if c in ('void *', 'const void *'):
            return 'pointer'
        if c.endswith('*'):
            inner = self.nim(re.sub(r'^const\s+', '', c[:-1].strip()), where)
            return f'ptr {inner}' if inner else None
        c = re.sub(r'^const\s+', '', c)
        if c in SCALARS:
            return SCALARS[c]
        if c in TYPEDEFS:
            return TYPEDEFS[c]
        if c in self.enums:
            return 'cint'
        if c in self.structs:
            return 'C' + camel(c)
        if c in self.callbacks:
            return 'Wgr' + camel(c)
        return None


# --- raw.nim ------------------------------------------------------------------------

def header_digest(wgrender):
    digest = hashlib.sha256()
    headers = sorted((wgrender / 'include').glob('*.h'))
    for h in headers:
        digest.update(h.name.encode())
        digest.update(h.read_bytes().replace(b'\r\n', b'\n'))  # the same on a CRLF checkout
    return digest.hexdigest()[:16], len(headers)


def generate(wgrender, clang, flags):
    structs, enums, callbacks, functions = read_ast(clang, wgrender, flags)
    types = Types(structs, enums, callbacks)
    cb_names = callback_param_names(wgrender)
    digest, count = header_digest(wgrender)
    version = re.findall(r'#define WGR_VERSION_(?:MAJOR|MINOR|PATCH)\s+(\d+)',
                         (wgrender / 'include/wgr_version.h').read_text(encoding='utf-8'))
    skipped = []

    out = [f'''## GENERATED by tools/gen_raw.py from wgrender's include/*.h: do not edit, run the tool.
##
## The C API as is: C names, C types. Most code wants the wrappers in `wgr` instead
## (Nim types, closures). Declarations import from wgrender's public headers
## (`header: "wgr.h"`); tools/coverage.py --check checks every one against them.
##
## wgrender {'.'.join(version) or '?'}, {count} headers.
{DIGEST_TAG}{digest}

import ./internal/build # compiles wgrender into the program, from its build.json

type
  WgrHandle* = cuint
  WgrColor* = uint32

  # wgrender passes strings to callbacks as `const char*`; Nim's cstring is `char*`,
  # and clang (emcc) rejects the mismatched callback type. Convert with `cstring(s)`.
  WgrConstCstring* {{.importc: "const char*", nodecl.}} = distinct cstring
''']

    # structs, in declaration order (a nested one is declared before its user)
    for c_name, fields in structs.items():
        lines = []
        for field, ctype in fields:
            t = types.nim(ctype, 'field')
            if t is None:
                sys.exit(f'gen_raw: {c_name}.{field}: no Nim type for {ctype!r}')
            lines.append(f'    {ident(field)}*: {t}')
        out.append(f'  C{camel(c_name)}* {{.importc: "{c_name}", bycopy, header: "wgr.h".}} = object\n'
                   + '\n'.join(lines) + '\n')

    # callbacks: `void (*)(float, void *)`
    for c_name, qual in callbacks.items():
        m = re.match(r'(.*?)\s*\(\*\)\((.*)\)$', qual)
        ret = types.nim(m.group(1), 'callback') if m.group(1) != 'void' else None
        ptypes = [p.strip() for p in m.group(2).split(',') if p.strip() and p.strip() != 'void']
        names = cb_names.get(c_name, [])
        params = []
        for k, p in enumerate(ptypes):
            t = types.nim(p, 'callback')
            if t is None:
                sys.exit(f'gen_raw: {c_name}: no Nim type for {p!r}')
            name = names[k] if k < len(names) and names[k] else f'a{k + 1}'
            params.append(f'{ident(name)}: {t}')
        out.append(f'  Wgr{camel(c_name)}* = proc ({"; ".join(params)}){": " + ret if ret else ""} {{.cdecl.}}')

    # constants: the enums' members, then the integer #defines
    consts = {}
    for values in enums.values():
        for name, value in values:
            consts[name] = f'{value}.cint' if value >= 0 else f'({value}).cint'
    for name, value in read_defines(wgrender).items():
        consts.setdefault(name, value)
    out.append('\nconst')
    out += [f'  {name}* = {value}' for name, value in consts.items()]

    out.append('\n{.push importc, cdecl, header: "wgr.h".}\n')
    for name, ret, params, variadic in functions:
        rt = None if ret == 'void' else types.nim(ret)
        nim_params, bad = [], None
        for k, (pname, ptype) in enumerate(params):
            t = types.nim(ptype)
            if t is None:
                bad = ptype
                break
            nim_params.append(f'{ident(pname or f"a{k + 1}")}: {t}')
        if bad or (ret != 'void' and rt is None):
            skipped.append(f'{name}: no Nim type for {bad or ret!r}')
            continue
        pragma = ' {.varargs.}' if variadic else ''
        out.append(f'proc {name}*({"; ".join(nim_params)}){": " + rt if rt else ""}{pragma}')
    out.append('\n{.pop.}')

    # Nim compares identifiers ignoring case after the first letter and underscores:
    # two C names that differ only so would be one Nim name
    seen = {}
    for n in [*consts, *(f[0] for f in functions), *structs, *callbacks]:
        key = n[0] + n[1:].replace('_', '').lower()
        if key in seen and seen[key] != n:
            sys.exit(f'gen_raw: {seen[key]} and {n} are the same identifier in Nim')
        seen[key] = n

    stats = (f'{len(functions) - len(skipped)} functions, {len(structs)} structs, '
             f'{len(callbacks)} callback types, {len(consts)} constants')
    return '\n'.join(out) + '\n', stats, skipped


def main():
    args = sys.argv[1:]
    if set(args) - {'--check'}:
        sys.exit(__doc__)
    wgrender = find_wgrender()
    clang = find_clang()
    if clang is None:
        sys.exit('gen_raw: no clang found (emsdk provides one; `emcc` on PATH leads to it)')
    flags = [l for l in (wgrender / 'compile_flags.txt').read_text(encoding='utf-8').splitlines() if l.strip()]
    text, stats, skipped = generate(wgrender, clang, flags)
    if '--check' in args:
        current = OUT.read_text(encoding='utf-8') if OUT.exists() else ''
        if current != text:
            print(f'src/wgr/raw.nim is stale against {wgrender}: run tools/gen_raw.py')
            return 1
        print(f'raw.nim: current ({stats})')
        return 0
    OUT.write_text(text, encoding='utf-8')
    print(f'src/wgr/raw.nim: {stats}')
    for s in skipped:
        print(f'  left out: {s}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
