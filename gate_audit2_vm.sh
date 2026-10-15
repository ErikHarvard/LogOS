#!/bin/bash
# gate_audit2_vm.sh — regression gates for the LogOS_bug_audit_2.md fixes to the
# native SECD VM (secd.asm → secd.la) and the process/IPC modules. Each case
# FAILS on the unfixed tree and PASSES with its fix. Runs in a private temp dir
# (no fixed /tmp paths); needs gcc. Not wired into build.sh (one line hooks it in).
#   usage: ./gate_audit2_vm.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2_vm.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
./tiny_host secd.la >/dev/null 2>&1 || { echo "FAIL  gate: cannot emit logos_secd"; exit 1; }
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# vmc <prog.la> — compile a program for the SECD VM with codegen.la on the host
vmc() { cp "$1" logos_source.la && timeout 600 ./tiny_host codegen.la >/dev/null 2>&1; }
# vmrun <prog.la> — compile + run on the VM; sets OUT (stdout+stderr, '|'-joined) and RC
vmrun() {
    OUT=""; RC=0
    vmc "$1" || { OUT="codegen failed"; RC=255; return; }
    timeout 20 ./logos_secd >vm.out 2>&1 </dev/null || RC=$?
    OUT=$(tr '\n' '|' < vm.out)
}

# ── #69 VM write_file/write_exec: a failed open/write halts loudly ────────────
# Unfixed: open's -errno jumps straight to the epilogue that returns the content,
# so the program prints "after" and exits 0 while the host halts rc 1 with
# "cannot open". The write(2) result was never checked either (/dev/full: ENOSPC).
# Fixed: "secd: write_file: cannot open|write <path>" on stderr, rc 1, no "after".
wf_case() {   # <builtin> <path> <expected stderr fragment>
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(print("before"))(SEQ(%s("%s")("payload"))(print("after")))\n' "$1" "$2" > t_wf.la
    vmrun t_wf.la
    if [ "$RC" = 1 ] && [ "$OUT" = "before|$3|" ]; then pass "VM: $1($2) halts loudly (rc 1)"
    else fail "VM: $1($2) — rc=$RC out=[$OUT] (want before|$3| rc 1)"; fi
}
case_vm_writefail() {
    wf_case write_file /nonexistent_dir_zz/x.txt "secd: write_file: cannot open /nonexistent_dir_zz/x.txt"
    wf_case write_exec /nonexistent_dir_zz/x.bin "secd: write_exec: cannot open /nonexistent_dir_zz/x.bin"
    wf_case write_file /dev/full "secd: write_file: cannot write /dev/full"
    wf_case write_exec /dev/full "secd: write_exec: cannot write /dev/full"
    # the host is the reference: its /dev/full write must halt too (was silent)
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(write_file("/dev/full")("payload"))(print("after"))\n' > t_wfh.la
    local hrc=0 hout; hout=$(timeout 20 ./tiny_host t_wfh.la 2>&1) || hrc=$?
    if [ "$hrc" = 1 ] && [ "$hout" = "write_file: cannot write '/dev/full': No space left on device" ]; then pass "host: write_file(/dev/full) halts loudly (rc 1)"
    else fail "host: write_file(/dev/full) — rc=$hrc out=[$(echo "$hout" | tr '\n' '|')]"; fi
    # control: a writable path still works and returns the content
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(print(write_file("wf_ok.txt")("payload")))(print(read_file("wf_ok.txt")))\n' > t_wfok.la
    vmrun t_wfok.la
    if [ "$RC" = 0 ] && [ "$OUT" = "payload|payload|" ]; then pass "VM: write_file to a writable path still writes and returns the content"
    else fail "VM: write_file control — rc=$RC out=[$OUT]"; fi
}

# ── #128 VM pipe/clock_gettime return -errno like every other syscall builtin ──
# Unfixed: .pipe_fail / .clockgettime_fail hard-code "-1", discarding errno.
# pipe under `ulimit -n 4` (fds 0-2 open → no room for two more) must be -24
# (EMFILE); clock_gettime with a bad clockid must be -22 (EINVAL).
case_vm_errno() {
    printf 'glyph SEQ = la a. la b. b\nglyph MAIN = SEQ(print(concat("pipe=")(pipe("!"))))(print(concat("clock=")(clock_gettime("99"))))\n' > t_errno.la
    vmc t_errno.la || { fail "vm_errno: codegen"; return; }
    # run with ONLY fds 0-2 open (close whatever the harness inherited) and room for one more
    local out; out=$(timeout 20 bash -c 'exec </dev/null 2>&1; for f in /proc/$$/fd/*; do n=${f##*/}; [ "$n" -gt 2 ] && eval "exec $n>&-" 2>/dev/null; done; ulimit -n 4; exec ./logos_secd' | tr '\n' '|')
    if [ "$out" = "pipe=-24|clock=-22|" ]; then pass "VM: pipe/clock_gettime failures return -errno (-24, -22)"
    else fail "VM: pipe/clock_gettime failure values — out=[$out] (want pipe=-24|clock=-22|)"; fi
}

#CASES-BELOW

CASES="${*:-vm_writefail vm_errno}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2_vm: all passed"; exit 0; } || { echo "gate_audit2_vm: $FAILS failed"; exit 1; }
