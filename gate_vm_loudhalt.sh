#!/usr/bin/env bash
# gate_vm_loudhalt.sh — the native SECD VM must never exit 0 on a malformed stream.
#
# WHAT IT GUARDS. secd.asm's dispatch loop had three fall-through paths that
# ended in `jmp .halt`, i.e. a clean exit(0) with no output: an opcode byte
# outside 0..5, an unknown builtin id in .apply_bi, and an unknown curried
# builtin id in .apply_pa. Fuzzing 143,602 corrupted instruction streams
# against that VM found 0 crashes but 8.2 % SILENT exit-0 runs — one random
# corruption in twelve was accepted as a successful program. All three now
# route to .badstream ("secd: malformed program", rc 1), which is the same
# loud path a truncated or unbalanced body already took.
#
# WHAT IT RUNS. Hand-built streams in the VM's own encoding
# (glyph entry = NAME 00 <body> 05, table ends with 00; VAR = 02 name 00,
# STR = 01 s 00, APP = <f><a> 04):
#   (1) a control: MAIN = print("ok")            -> prints ok, rc 0
#   (2) MAIN = "hi" then opcode 0x07             -> must halt loudly
#   (3) MAIN = "hi" then opcode 0xFF             -> must halt loudly
#   (4) MAIN = "hi" then opcode 0x06             -> must halt loudly (the first
#                                                   unassigned opcode)
#   (5) a stray HALT (00) mid-body: print("hi") never applied -> must halt loudly
#   (6) 00 where MAIN's RET belongs                           -> must halt loudly
#   (7) 00 inside a glyph that MAIN calls (dump non-empty)    -> must halt loudly
# (5)-(7): HALT is valid ONLY as the final byte of the VM's own bootstrap
# (after MAIN returns with an empty dump); anywhere else it used to exit 0
# silently with the program unfinished.
# The two unknown-builtin-id paths cannot be reached from a stream (ids are
# assigned internally after a successful name lookup), so they are covered by
# code inspection + the fuzz count, not by a fixture here.
#
# ISOLATION. Builds tiny_host and emits the VM from the committed secd.la byte
# table in a private mktemp dir; touches no tracked file and no fixed /tmp path.
# Needs: gcc. Runs in ~1 s.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 )      # emits $T/logos_secd

ok=1
# run_stream <printf-format bytes> -> sets rc, out, err
run_stream() {
    printf "$1" > "$T/logos_program.bin"
    rc=0
    out=$( cd "$T" && ./logos_secd 2>"$T/err" ) || rc=$?
    err=$(cat "$T/err")
}

# (1) control: a well-formed stream still runs
run_stream 'MAIN\0\002print\0\001ok\0\004\005\0'
if [ "$rc" = 0 ] && [ "$out" = "ok" ]; then
    echo "PASS  vm loud-halt gate: control stream print(\"ok\") runs (rc 0)"
else
    echo "FAIL  vm loud-halt gate: control stream broke — rc=$rc out='$out' err='$err'"; ok=0
fi

# (2)-(4) unknown opcodes must halt loudly, never exit 0
for op in '\007' '\377' '\006'; do
    run_stream "MAIN\0\001hi\0${op}\005\0"
    if [ "$rc" = 1 ] && [ "$err" = "secd: malformed program" ] && [ -z "$out" ]; then
        echo "PASS  vm loud-halt gate: unknown opcode (octal $op) -> 'secd: malformed program', rc 1"
    else
        echo "FAIL  vm loud-halt gate: unknown opcode $op — rc=$rc out='$out' err='$err' (want rc 1 + 'secd: malformed program'; rc 0 = the silent .halt regression)"; ok=0
    fi
done

# (5)-(7) a HALT byte anywhere but the bootstrap's final byte is malformed
for c in 'stray 00 mid-body|MAIN\0\002print\0\001hi\0\000\004\005\0' \
         '00 where RET belongs|MAIN\0\001hi\0\000\0' \
         '00 inside a called glyph|F\0\001x\0\000\005MAIN\0\002print\0\002F\0\004\005\0'; do
    label=${c%%|*}; run_stream "${c#*|}"
    if [ "$rc" = 1 ] && [ "$err" = "secd: malformed program" ] && [ -z "$out" ]; then
        echo "PASS  vm loud-halt gate: $label -> 'secd: malformed program', rc 1"
    else
        echo "FAIL  vm loud-halt gate: $label — rc=$rc out='$out' err='$err' (want rc 1 + 'secd: malformed program'; rc 0 = mid-stream HALT accepted silently)"; ok=0
    fi
done

[ "$ok" = 1 ] || exit 1
