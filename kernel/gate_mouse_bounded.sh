#!/bin/sh
# gate_mouse_bounded.sh — Freeze Audit II / Q3: the mouse driver's OWED waits are
# bounded, so a controller that never answers is DIAGNOSED instead of killing the
# kernel.
#
# ── THE ADJUDICATION THIS GATE ENCODES ──────────────────────────────────────
#   waiting for a USER            -> correctly unbounded (packet byte 0)
#   waiting for a response OWED   -> must be bounded (IBF handshake, 0xFA ACK,
#      by the device                packet bytes 1-2)
# Bounding byte 0 as well would make an idle user look like a broken device, so
# it is deliberately left alone and this gate does not test it.
#
# ── WHY A SELF-INFLICTED FAULT IS LEGITIMATE HERE ───────────────────────────
# A BOUND claims only "this loop terminates". Any never-satisfied condition
# tests that, so removing the command whose ACK we then wait for is a fair red
# path. A REPAIR would claim the DEVICE was fixed, which needs a fault that is
# realistic AND persistent -- the standard HAL.3d failed twice (see
# SELFREPAIR_3d_DESIGN.md). Do not read this gate as proving fault-tolerance.
#
# Three kernels, one fault:
#   kernel_mouse.elf          healthy device      -> must still work (gate_mouse.sh)
#   kernel_mouse_faulted.elf  fault + bounded     -> must DIAGNOSE, exit cleanly
#   kernel_mouse_ctrl.elf     fault + UNBOUNDED   -> must DIE (the pre-fix driver)
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  mouse_bounded: qemu absent"; exit 0; }

# Sets BOOT_OUT (serial text) and BOOT_RC (timeout/qemu exit status).
#
# ★ THE EXIT STATUS IS THE POINT, AND THE OLD FORM THREW IT AWAY. Piping qemu
# into `tr` made $? the status of `tr` (always 0), so a run that HUNG and was
# killed by `timeout` (rc 124) looked identical to one that exited cleanly —
# exactly the difference the red path below has to see. `#!/bin/sh` has no
# PIPESTATUS, so the output goes to a file instead.
#
# ★ CALL IT BARE, NEVER `X=$(boot ...)`. A value assigned inside a function
# invoked through command substitution is set in a SUBSHELL and lost — the same
# defect that once made gate_p1.sh unable to go GREEN.
# ★ A BUDGET KILL IS NOT ONE NUMBER. `timeout N` yields 124, but `timeout -k`
# yields 137 (SIGKILL) and a TERM path yields 143 — so asserting `= 124` makes
# this branch stop matching on an invocation-shape change, and the red path goes
# INERT AGAIN, which is the exact defect this gate was just repaired for. Accept
# any budget kill and PRINT the value. (Caught by ~/logos-hexis.sh's
# hardcoded-kill-code check, run against my own work before shipping.)
killed() { case "${1:-}" in 124|137|143) return 0 ;; *) return 1 ;; esac; }
boot() {
    _bt=$(mktemp)
    timeout 45 qemu-system-x86_64 -kernel "$1" -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown >"$_bt" 2>/dev/null
    BOOT_RC=$?
    BOOT_OUT=$(tr -d '\0' < "$_bt")
    rm -f "$_bt"
}

# ── 1. bounded + fault: diagnose, do not die ───────────────────────────────
./kernel/build_mouse_faulted.sh >/dev/null 2>&1 || { echo "FAIL  mouse_bounded: faulted build failed"; exit 1; }
boot kernel/kernel_mouse_faulted.elf; F=$BOOT_OUT; F_RC=$BOOT_RC
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 160)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  mouse_bounded 1: the BOUNDED driver still faults on an unanswered wait: $fseen"; ok=0
elif killed "$F_RC"; then
    echo "FAIL  mouse_bounded 1: the BOUNDED driver printed a diagnosis but NEVER TERMINATED (rc=$F_RC): $fseen"; ok=0
elif printf '%s' "$F" | grep -qF 'mouse dead' && printf '%s' "$F" | grep -q 'mouse ack timeout st='; then
    echo "PASS  mouse_bounded 1: an unanswered ACK is diagnosed and the kernel exits cleanly — $(printf '%s' "$F" | grep -o 'mouse ack timeout st=[0-9]*')"
else
    echo "FAIL  mouse_bounded 1: no diagnosis (wanted 'mouse ack timeout st=' + 'mouse dead'): $fseen"; ok=0
fi

# ── 2. RED PATH: the pre-fix driver, same fault, must die ──────────────────
#   ★ Without this the gate shows only that the FIXED driver behaves, which is
#   equally consistent with the bound doing nothing at all.
if [ -x ./kernel/build_mouse_ctrl.sh ] && [ -f kernel/mouse_ctrl.la ]; then
    ./kernel/build_mouse_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  mouse_bounded: control build failed"; ok=0; }
    if [ -f kernel/kernel_mouse_ctrl.elf ]; then
        boot kernel/kernel_mouse_ctrl.elf; C=$BOOT_OUT; C_RC=$BOOT_RC
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 140)
        # ★ WHAT THE CONTROL MUST DO IS *NOT DIAGNOSE-AND-EXIT*. IT NEED NOT CRASH.
        # This demanded `EXCEPTION` because in 2026-08 the unbounded wait recursed
        # off into unmapped memory. It no longer does, and the DRIVER DID NOT
        # CHANGE: the recursive call is in TAIL POSITION and the native backend
        # gained TCO, so the same runaway recursion is now an infinite LOOP in
        # bounded stack. MEASURED 2026-09-09 on all five controls: rc=124, no
        # EXCEPTION, hung for the whole budget — while each FIXED driver
        # diagnoses and exits 33 in seconds. The bound is still load-bearing;
        # only the failure MODE moved, and a substrate improvement silently
        # disarmed the red path of five gates at once.
        # So assert the property that actually discriminates: the fix DIAGNOSES
        # AND TERMINATES; the control does neither. Crash or hang both prove it.
        if printf '%s' "$C" | grep -qF 'mouse dead'; then
            echo "FAIL  mouse_bounded 2 [red-path]: the control DIAGNOSED ($cseen) — it is not the unbounded driver, so this gate proves nothing"; ok=0
        elif printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK (crash): the UNBOUNDED pre-fix driver dies on the same input ($cseen) — the bound is load-bearing"
        elif killed "$C_RC"; then
            echo "      red-path OK (hang): the UNBOUNDED pre-fix driver never terminates on the same input (rc=$C_RC, $cseen) — the bound is load-bearing"
        else
            echo "FAIL  mouse_bounded 2 [red-path]: the control neither diagnosed, crashed, nor hung (rc=$C_RC, $cseen)"; ok=0
        fi
    else
        # ★ 2026-09-08: this branch had NO else (same shape as gate_ps2_bounded.sh),
        # so a control build exiting 0 without producing an ELF removed the red path
        # in silence while the gate still PASSed. The build above fails loudly, so
        # this covers only that narrow case — but a red control that can disappear
        # without a line of output is exactly what this gate refuses in the driver.
        echo "FAIL  mouse_bounded [red-path]: kernel/kernel_mouse_ctrl.elf is absent although"
        echo "      build_mouse_ctrl.sh reported success — the red control did not run, so this"
        echo "      gate cannot show it discriminates. A gate must never skip past its control."
        ok=0
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/mouse_ctrl.la + build_mouse_ctrl.sh absent."
fi

[ "$ok" = 1 ] && echo "PASS  mouse_bounded: the PS/2 mouse driver's OWED waits are bounded — an IBF handshake, a 0xFA ACK or a packet continuation byte that never arrives is now named on serial with the stage that stalled and the kernel exits cleanly, where the pre-fix driver recursed until it faulted (EXCEPTION 0e). The USER wait (packet byte 0) is deliberately still unbounded: an idle user is not a broken device." || { echo "mouse_bounded gate RED"; exit 1; }
