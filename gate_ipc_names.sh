#!/bin/sh
# gate_ipc_names.sh — `send`/`recv` mean one thing on every engine: the VM's
# AF_UNIX sockets. Native's bare-metal kernel channel is a different pair,
# chan_send(chan)(msg) / chan_recv(chan).
#
# WHAT IT GUARDS. Native compiled send/recv as its kernel-channel builtins
# (recv(chan) unary, an INT channel, 256-byte messages, send returning the msg),
# while the VM's send(fd)(data) / recv(fd)(maxbytes) are sockets. A program
# meant for one engine ran on the other with a different meaning instead of
# halting:
#   * print(recv("3")("100"))           native: "attempt to apply a
#                                       non-function", rc 70;
#   * send("3")("x") then print("sent") native: printed "sent", rc 0 (the
#                                       string went in as a channel number and
#                                       the call failed silently).
# Ruling (2026-10-08): native's pair is chan_send/chan_recv; on native, bare
# send/recv are another engine's builtins, so reaching one halts "native: <name>:
# not supported on this engine", as socket/bind/connect already do.
# What chan_send/chan_recv DO needs the bare-metal kernel; kernel/gate_k6c3.sh,
# gate_k6c3b.sh and gate_hh2c.sh check it under QEMU.
# Host and the VM list chan_send/chan_recv as another engine's builtins, so a
# program that mentions them on a branch never taken loads there too (an unbound
# name is one no engine defines), and reaching one halts loudly.
#
# ISOLATION: private mktemp dir; touches no tracked file. Needs gcc. ~6 min (the
# native backend compiles each case through tiny_host native_codegen3.la).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/secd.la" "$ROOT/codegen.la" "$ROOT/native_codegen3.la" "$T/"
( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 && cp codegen.la logos_source.la \
    && ./tiny_host codegen.la >/dev/null 2>&1 && cp logos_program.bin compiler.bin )
ok=1

PRELUDE='glyph SEQ = la a. la b. b'

# native_compile <program text>: sets crc (compile rc); the binary is
# $T/native_codegen3_out when crc is 0.
native_compile() {
    printf '%s\n%s\n' "$PRELUDE" "$1" > "$T/native_input.la"; rm -f "$T/native_codegen3_out"
    crc=0; ( cd "$T" && timeout 600 ./tiny_host native_codegen3.la >/dev/null 2>"$T/ce" ) || crc=$?
    [ "$crc" = 0 ] && [ ! -x "$T/native_codegen3_out" ] && crc=1
    return 0
}

# native_halts <label> <program text> <builtin name>: compiles, and reaching the
# builtin halts rc 1 with exactly "native: <name>: not supported on this engine".
native_halts() {
    want="native: $3: not supported on this engine"
    native_compile "$2"
    if [ "$crc" != 0 ]; then echo "FAIL  ipc names (native, $1): did not compile: $(cat "$T/ce")"; ok=0; return 0; fi
    rc=0; out=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/e" ) || rc=$?
    if [ "$rc" = 1 ] && [ -z "$out" ] && [ "$(cat "$T/e")" = "$want" ]; then echo "PASS  ipc names (native, $1): rc 1, '$want'"
    else echo "FAIL  ipc names (native, $1): rc=$rc out='$out' err='$(cat "$T/e")' (want rc 1, no output, '$want')"; ok=0; fi
}

# native_runs <label> <program text> <want stdout>
native_runs() {
    native_compile "$2"
    if [ "$crc" != 0 ]; then echo "FAIL  ipc names (native, $1): did not compile: $(cat "$T/ce")"; ok=0; return 0; fi
    rc=0; out=$( cd "$T" && timeout 20 ./native_codegen3_out 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = "$3" ]; then echo "PASS  ipc names (native, $1): out '$3'"
    else echo "FAIL  ipc names (native, $1): rc=$rc out='$out' err='$(cat "$T/e")' (want rc 0, out '$3')"; ok=0; fi
}

native_halts 'recv reached'  'glyph MAIN = print(recv("3")("100"))' recv
native_halts 'send reached'  'glyph MAIN = SEQ(send("3")("x"))(print("sent"))' send
native_runs  'chan_send/chan_recv on a branch never taken' \
    'glyph MAIN = (la t. la f. t)(la _. print("ok"))(la _. chan_send(0)(chan_recv(0)))("!")' ok

# chan_send/chan_recv compile as builtins; running them needs the kernel channel.
native_compile 'glyph MAIN = SEQ(chan_send(0)("x"))(print(chan_recv(0)))'
if [ "$crc" = 0 ]; then echo "PASS  ipc names (native, chan_send/chan_recv compile as builtins)"
else echo "FAIL  ipc names (native, chan_send/chan_recv compile as builtins): $(cat "$T/ce")"; ok=0; fi

# host_vm <label> <program text> <want stdout, or "halt:<host stderr>|<VM stderr>">
host_vm() {
    printf '%s\n%s\n' "$PRELUDE" "$2" > "$T/p.la"
    rc=0; out=$( cd "$T" && ./tiny_host p.la 2>"$T/e" ) || rc=$?
    hv_verdict "host, $1" "$out" "$(cat "$T/e")" "$rc" "$3" 1
    cp "$T/p.la" "$T/logos_source.la"; cp "$T/compiler.bin" "$T/logos_program.bin"
    rc=0; ( cd "$T" && timeout 60 ./logos_secd >/dev/null 2>"$T/e" ) || rc=$?
    if [ "$rc" = 0 ]; then rc=0; out=$( cd "$T" && timeout 20 ./logos_secd 2>"$T/e" ) || rc=$?; else out=""; fi
    hv_verdict "secd, $1" "$out" "$(cat "$T/e")" "$rc" "$3" 2
}
hv_verdict() {   # $1 label, $2 out, $3 err, $4 rc, $5 want, $6 field of a halt spec
    case "$5" in
    halt:*) want=$(printf '%s' "${5#halt:}" | cut -d'|' -f"$6")
        if [ "$4" = 1 ] && [ -z "$2" ] && [ "$3" = "$want" ]; then echo "PASS  ipc names ($1): rc 1, '$want'"
        else echo "FAIL  ipc names ($1): rc=$4 out='$2' err='$3' (want rc 1, no output, '$want')"; ok=0; fi ;;
    *)  if [ "$4" = 0 ] && [ "$2" = "$5" ]; then echo "PASS  ipc names ($1): out '$5'"
        else echo "FAIL  ipc names ($1): rc=$4 out='$2' err='$3' (want rc 0, out '$5')"; ok=0; fi ;;
    esac
}

host_vm 'chan_send/chan_recv on a branch never taken' \
    'glyph MAIN = (la t. la f. t)(la _. print("ok"))(la _. chan_send(0)(chan_recv(0)))("!")' ok
# Reaching another engine's builtin halts as it does for any other (peek, spawn):
# the VM's run-time message does not name the builtin.
host_vm 'chan_recv reached' 'glyph MAIN = print(chan_recv(0))' \
    "halt:host: unbound variable 'chan_recv'|secd: unbound variable"

[ "$ok" = 1 ] || exit 1
