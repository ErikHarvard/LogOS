#!/usr/bin/env bash
# LogOS HAL.2d gate — a POINTER: signed mouse decode + a clamped live cursor.
# Boot the pointer kernel, inject motion (right, then LEFT for a negative dx) +
# a button via the QEMU monitor, and assert the LA driver SIGN-EXTENDED the
# deltas, read the button, and accumulated a bounded cursor:
#   - "ptr:"        — the driver started (aux enabled + reporting on, ACK drained);
#   - "seen 1 1"     — the two decode witnesses: ng=1 (a NEGATIVE dx was decoded,
#                      i.e. the 9-bit sign fold ran on the leftward move — unsigned
#                      decode could never set it) AND bt=1 (the left button, flags
#                      bit0, was seen down);
#   - "cursor X Y"   — the loop read its bounded 4 packets and printed the
#                      accumulated cursor, with 0<=X<=639 and 0<=Y<=479 (the
#                      CLAMP held — a decode/accumulate bug would escape the box);
#   - exit 33.
# QEMU only queues packets after 0xF4, so a pass also proves the init ran.
# Skips (rc 0) if QEMU is absent.
set -uo pipefail
cd "$(dirname "$0")/.."

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  HAL.2d pointer gate: qemu-system-x86_64 not installed"
    exit 0
fi

./kernel/build_pointer.sh >/dev/null 2>&1 || { echo "FAIL  HAL.2d gate: build_pointer.sh failed"; exit 1; }

OUTF=$(mktemp)
# Right, then LEFT (negative dx), then a click (press+release), then one more
# move — > PKTN(4) events so the bounded reader never starves.
{ sleep 2
  echo "mouse_move 40 0";  sleep 0.4
  echo "mouse_move -15 0"; sleep 0.4
  echo "mouse_button 1";   sleep 0.4
  echo "mouse_button 0";   sleep 0.4
  echo "mouse_move 0 -20"; sleep 0.4
  sleep 1
} | timeout 40 qemu-system-x86_64 \
        -kernel kernel/kernel_pointer.elf -m 256 \
        -serial "file:$OUTF" -monitor stdio -display none \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        -no-reboot -no-shutdown >/dev/null 2>&1
RC=$?
OUT=$(tr -d '\0' < "$OUTF"); rm -f "$OUTF"
seen=$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 300)

ok=1
printf '%s' "$OUT" | grep -qF 'ptr:' || { echo "FAIL  HAL.2d: 'ptr:' not on serial (rc=$RC, got: $seen)"; ok=0; }

SEENL=$(printf '%s' "$OUT" | grep -E '^seen [0-9]+ [0-9]+$' | tail -1)
if [ -z "$SEENL" ]; then
    echo "FAIL  HAL.2d: no 'seen NG BT' summary — the reader starved or MAIN exited early (rc=$RC, got: $seen)"; ok=0
else
    NG=$(printf '%s' "$SEENL" | awk '{print $2}')
    BT=$(printf '%s' "$SEENL" | awk '{print $3}')
    [ "$NG" -eq 1 ] || { echo "FAIL  HAL.2d: no negative dx decoded (ng=$NG) — the 9-bit sign fold never ran on the leftward move ($SEENL)"; ok=0; }
    [ "$BT" -eq 1 ] || { echo "FAIL  HAL.2d: left button never decoded down (bt=$BT) ($SEENL)"; ok=0; }
fi

CUR=$(printf '%s' "$OUT" | grep -E '^cursor -?[0-9]+ -?[0-9]+$' | tail -1)
if [ -z "$CUR" ]; then
    echo "FAIL  HAL.2d: no 'cursor X Y' line — the reader starved or MAIN exited early (rc=$RC, got: $seen)"; ok=0
else
    CX=$(printf '%s' "$CUR" | awk '{print $2}')
    CY=$(printf '%s' "$CUR" | awk '{print $3}')
    if [ "$CX" -lt 0 ] || [ "$CX" -gt 639 ] || [ "$CY" -lt 0 ] || [ "$CY" -gt 479 ]; then
        echo "FAIL  HAL.2d: cursor escaped the 640x480 clamp ($CUR)"; ok=0
    fi
    # net horizontal move was +40 then -15 (>0), so a WORKING accumulator lands
    # x>100; a no-op/broken add would leave it at the 100 origin.
    [ "$CX" -gt 100 ] || { echo "FAIL  HAL.2d: cursor did not accumulate right of origin (x=$CX, expected >100) — add/clamp is a no-op ($CUR)"; ok=0; }
fi

[ "$RC" -eq 33 ] || { echo "FAIL  HAL.2d: exit code != 33 (got $RC; $seen)"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  HAL.2d: pointer in Lingua Adamica — the LA driver sign-extended the 9-bit deltas (a leftward move decoded to a negative dx), read the button state (L1), and accumulated a cursor clamped to 640x480 ($CUR), exit 33. A real pointer the compositor can consume, bounded and correct."
[ "$ok" -eq 1 ]
