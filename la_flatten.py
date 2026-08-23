#!/usr/bin/env python3
"""Resolve `import` OFFLINE, producing one flat .la with no import at all.

WHY. codegen.la implements the module system in Lingua Adamica, and mangling a
2100-line module through it is pathological: compiling asmelfobj.la (which
imports asm.la) sat at 11.8 GB for 30+ minutes. The C host's own import is fast
(a plain `./tiny_host asmelfobj.la` on a small fixture takes 10s), so the cost
is specific to the self-hosted path, and the VM needs a compiled stream to run
at all. Flattening ahead of time sidesteps it entirely.

WHAT IT MUST PRESERVE — this is the whole correctness argument. The module
system's guarantee is that a module's PRIVATE glyphs cannot collide with anyone
else's: they are alpha-renamed to fresh names and every reference within that
module is rewritten to match. asm.la and elfobj.la collide on 15 names, and the
collision is not cosmetic — `CONS`/`NIL` are Scott-encoded in asm.la
(l(nil)(cons)) and fold-encoded in elfobj.la (l(f)(z)). They are different
functions with the same name. Getting this wrong would not fail loudly; it
would silently build lists one module cannot read.

So: for each module, every glyph NOT in its `export` line is renamed with a
per-module prefix, and references are rewritten token-wise (respecting string
literals and comments, so a name appearing inside a quoted string is untouched).
An EXPORTED name keeps its spelling — which is why elfobj's exported CONS/NIL
stay put while asm.la's private ones are renamed away, exactly as the real
import would do.

VERIFIED, not assumed: the flattened program is run against the same fixtures as
the import version and must produce byte-identical objects.
"""
import sys, re

IDENT_EXTRA = set("_")

def is_ident_char(c):
    return c.isalnum() or c in IDENT_EXTRA or ord(c) > 127

def split_tokens(src):
    """Yield (kind, text) where kind is 'ident' | 'other'. Strings and comments
    are emitted as 'other' verbatim so nothing inside them is ever renamed."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '#':                       # comment to end of line
            j = src.find('\n', i)
            j = n if j < 0 else j
            yield ('other', src[i:j]); i = j
        elif c == '"':                     # string literal, with escapes
            j = i + 1
            while j < n:
                if src[j] == '\\': j += 2; continue
                if src[j] == '"': j += 1; break
                j += 1
            yield ('other', src[i:j]); i = j
        elif is_ident_char(c):
            j = i
            while j < n and is_ident_char(src[j]): j += 1
            yield ('ident', src[i:j]); i = j
        else:
            yield ('other', c); i += 1

def load(path):
    src = open(path, encoding='utf-8').read()
    exports = set()
    body = []
    for line in src.split('\n'):
        s = line.strip()
        if s.startswith('export '):
            exports.update(s.split()[1:]); continue
        if s.startswith('import('):
            continue
        body.append(line)
    body = '\n'.join(body)
    defined = set(re.findall(r'^glyph\s+([^\s=]+)', body, re.M))
    return body, defined, exports

def mangle(path, prefix):
    body, defined, exports = load(path)
    private = defined - exports
    out = []
    for kind, text in split_tokens(body):
        if kind == 'ident' and text in private:
            out.append(prefix + text)
        else:
            out.append(text)
    return ''.join(out), sorted(private), sorted(exports)

def main():
    if len(sys.argv) < 4:
        print("usage: flatten.py <driver.la> <out.la> <module.la:prefix> ...", file=sys.stderr)
        sys.exit(2)
    driver, out = sys.argv[1], sys.argv[2]
    chunks = []
    for spec in sys.argv[3:]:
        mod, prefix = spec.rsplit(':', 1)
        text, priv, exp = mangle(mod, prefix)
        chunks.append(f"# ===== {mod} (privates renamed {prefix}*) =====\n{text}")
        print(f"{mod}: {len(priv)} private renamed, {len(exp)} exported kept: {' '.join(exp)}",
              file=sys.stderr)
    dbody, ddef, dexp = load(driver)
    chunks.append(f"# ===== {driver} =====\n{dbody}")
    open(out, 'w', encoding='utf-8').write('\n'.join(chunks))
    print(f"-> {out}", file=sys.stderr)

main()
