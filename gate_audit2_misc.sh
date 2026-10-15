#!/bin/bash
# gate_audit2_misc.sh — regression gates for the LogOS_bug_audit_2.md
# performance/misc fixes (slice M). Each red/green case FAILS on the unfixed
# tree and PASSES with its fix. Runs in a private temp dir (no fixed /tmp
# paths); needs gcc, nasm and python3. Not wired into build.sh (other open
# batches edit it) — one line to hook it in.
#   usage: ./gate_audit2_misc.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_misc.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la "$REPO"/str_at_fixture.bin .
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# vmc <prog.la> <out.bin> — compile for the SECD VM with codegen.la on the host
vmc() { cp "$1" logos_source.la && rm -f logos_program.bin \
        && timeout 300 ./tiny_host codegen.la >/dev/null 2>&1 && mv logos_program.bin "$2"; }
# best <bin> — best-of-3 wall seconds of the VM running <bin>; output → run.out
best() {
    local b=999 i s e t
    for i in 1 2 3; do
        cp "$1" logos_program.bin
        s=$(date +%s.%N); timeout 120 ./logos_secd > run.out 2>&1; e=$(date +%s.%N)
        t=$(echo "$e - $s" | bc); [ "$(echo "$t < $b" | bc)" = 1 ] && b=$t
    done
    echo "$b"
}

# The VM under test is the one secd.la SHIPS: its decimal literal, decoded here
# independently of BYTES. Guard (not a red/green case): it must equal
# `nasm -f bin secd.asm`, else the regeneration was skipped and the timing case
# below would be measuring a VM that is not the source.
vm_from_secd_la() {
    python3 -I - secd.la logos_secd <<'PY' || return 1
import sys
src, out = sys.argv[1], sys.argv[2]
pre = 'glyph SECD = BYTES("'
line = [l for l in open(src, encoding='utf-8').read().split('\n') if l.startswith(pre)]
assert len(line) == 1, "no single SECD literal"
open(out, 'wb').write(bytes(int(t) for t in line[0][len(pre):].rstrip(')').rstrip('"').split()))
PY
    chmod +x logos_secd
    nasm -f bin "$REPO/secd.asm" -o secd_nasm.bin || return 1
    cmp -s logos_secd secd_nasm.bin
}

# ── #68 VM CLOSE re-scans the whole body (skipbody) per closure ───────────────
# Two programs identical except for the size of a string literal inside a lambda
# that is created (never called) on every iteration of a 200000-step Z loop:
# 0 bytes vs 5000 bytes. Unfixed, every CLOSE of that lambda and of the
# enclosing loop body walks the 5000 bytes, so the big program runs ~10x slower
# (measured 1.9 s vs 0.15 s). Fixed (memoised skipbody), body size does not
# matter after the first scan. Bound: big <= 3*small + 0.5 s. Equality: both
# print 200000 — LOOP(n)(0) adds 1 per step, so the value is n by construction.
case_vm_close_skip() {
    vm_from_secd_la || { fail "#68: secd.la's VM literal != nasm -f bin secd.asm (regenerate secd.la)"; return; }
    local n
    for n in 0 5000; do
        python3 -I - "$n" > "t_close_$n.la" <<'PY'
import sys
n = int(sys.argv[1])
print('glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))')
print('glyph IF = la c. la t. la e. c(t)(e)("!")')
print('glyph LOOP = Z(la self. la n. la acc.')
print('    (la dead. IF(int_eq(n)(0))(la _. acc)(la _. self(sub(n)(1))(add(acc)(1))))'
      '(la x. concat(x)("' + 'a' * n + '")))')
print('glyph MAIN = print(int_to_str(LOOP(200000)(0)))')
PY
        vmc "t_close_$n.la" "t_close_$n.bin" || { fail "#68: codegen of t_close_$n.la"; return; }
    done
    local t0 o0 t1 o1
    t0=$(best t_close_0.bin); o0=$(cat run.out)
    t1=$(best t_close_5000.bin); o1=$(cat run.out)
    if [ "$o0" != 200000 ] || [ "$o1" != 200000 ]; then
        fail "#68: wrong result — small=[$o0] big=[$o1] (expected 200000)"; return
    fi
    if [ "$(echo "$t1 <= 3 * $t0 + 0.5" | bc)" = 1 ]; then
        pass "#68: closure creation is independent of body size (0 B body ${t0}s, 5000 B body ${t1}s; both print 200000)"
    else
        fail "#68: closure creation scales with body size (0 B body ${t0}s, 5000 B body ${t1}s > 3x+0.5s)"
    fi
}

# ── #68 equality: the memoised VM still agrees with the C host ────────────────
# Not red/green (the unfixed VM agrees too) — it guards the fix against a wrong
# memo hit: glyph-table walks and nested closures over real programs, compared
# byte-for-byte with tiny_host running the same source.
case_vm_close_agree() {
    [ -x logos_secd ] || vm_from_secd_la || { fail "#68 agree: no VM"; return; }
    local p ok=1 msg=""
    for p in ladder seal_test str_at_test bitwise_test; do
        vmc "$p.la" "a_$p.bin" || { ok=0; msg="$msg $p:codegen"; continue; }
        timeout 60 ./tiny_host "$p.la" > "h_$p.out" 2>&1
        cp "a_$p.bin" logos_program.bin; timeout 60 ./logos_secd > "v_$p.out" 2>&1
        cmp -s "h_$p.out" "v_$p.out" || { ok=0; msg="$msg $p:differs"; }
        [ -s "h_$p.out" ] || { ok=0; msg="$msg $p:empty"; }
    done
    [ $ok = 1 ] && pass "#68 agree: VM == host on ladder, seal_test, str_at_test, bitwise_test" \
                || fail "#68 agree:$msg"
}

CASES="${*:-vm_close_skip vm_close_agree}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_misc: all passed"; exit 0; } || { echo "gate_audit2_misc: $FAILS failed"; exit 1; }
