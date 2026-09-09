#!/bin/sh
# gate_hal3c.sh — HAL.3c: the ATA wait is BOUNDED, so a disk that never becomes
# ready is DIAGNOSED instead of killing the kernel.
#
# ── THE BUG THIS GATE EXISTS FOR (found + reproduced 2026-08-18) ────────────
# ata.la's WAITDRQ had no fuel. On a channel that never becomes ready it
# recursed until it ran off into unmapped memory:
#     ata:|EXCEPTION 0d err=0000000000000000 rip=0000000007ffffc0
# Deterministic, and identical with a present-but-empty CD-ROM — two real fault
# modes, one silent crash with nothing naming the disk as the cause.
#
# ★ WHY NO GATE SAW IT: every ATA gate attaches a working disk. HAL.3 and HAL.3b
# are both [x] DONE + gated and both were RIGHT — they simply never presented
# the fault. A driver is not proven robust by a gate that only ever gives it a
# healthy device. That is the same blind spot HAL.5q/5r were built to close on
# the NIC, applied to the disk organ.
#
# ── THREE CHECKS ───────────────────────────────────────────────────────────
#   1. HEALTHY PATH UNCHANGED — with a real disk the driver still reads the
#      sector. The bound must not cost the working case.
#   2. FAULT DIAGNOSED — with no disk it prints "ata drq timeout st=<status>"
#      and "ata dead", and exits CLEANLY. No EXCEPTION.
#   3. RED PATH — the unbounded control (kernel/ata_ctrl.la, the driver exactly
#      as it was before) must still CRASH on the same input. Without this the
#      gate cannot tell you the bound did anything.
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  HAL.3c: qemu absent"; exit 0; }

# Sets BOOT_OUT (serial text) and BOOT_RC (timeout/qemu exit status).
#
# ★ THE EXIT STATUS IS THE POINT, AND THE OLD FORM THREW IT AWAY. Piping qemu
# into `tr` made $? the status of `tr`, which is always 0 — so a run that HUNG
# and was killed by `timeout` (rc 124) was indistinguishable from one that
# exited cleanly. That is precisely the difference this gate has to see.
# `#!/bin/sh` has no PIPESTATUS, so the output goes to a file instead.
#
# ★ CALL IT BARE, NEVER AS `X=$(boot ...)`. A value assigned inside a function
# invoked through command substitution is set in a SUBSHELL and lost — the same
# defect that once made gate_p1.sh unable to go GREEN.
# ★ A BUDGET KILL IS NOT ONE NUMBER. `timeout N` yields 124, but `timeout -k`
# yields 137 (SIGKILL) and a TERM path yields 143 — so asserting `= 124` makes
# this branch stop matching on an invocation-shape change, and the red path goes
# INERT AGAIN, which is the exact defect this gate was just repaired for. Accept
# any budget kill and PRINT the value. (Caught by ~/logos-hexis.sh's
# hardcoded-kill-code check, run against my own work before shipping.)
killed() { case "${1:-}" in 124|137|143) return 0 ;; *) return 1 ;; esac; }
boot() {  # $1 = elf, $2 = extra qemu args ("" for no disk)
    _bt=$(mktemp)
    timeout 60 qemu-system-x86_64 -kernel "$1" $2 -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown >"$_bt" 2>/dev/null
    BOOT_RC=$?
    BOOT_OUT=$(tr -d '\0' < "$_bt")
    rm -f "$_bt"
}

[ -x ./kernel/build_hal3.sh ] || { echo "SKIP  HAL.3c: build_hal3.sh absent"; exit 0; }
./kernel/build_hal3.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3c: build_hal3.sh failed"; exit 1; }

# ── 1. healthy path ────────────────────────────────────────────────────────
boot kernel/kernel_hal3.elf "-drive file=kernel/hal3disk.img,format=raw,if=ide"; H=$BOOT_OUT
if printf '%s' "$H" | grep -qF 'ata done' && printf '%s' "$H" | grep -qF 'LOGOS-DISK-OK-HAL3'; then
    echo "PASS  HAL.3c 1: with a real disk the bounded driver still reads the sector (healthy path unchanged)"
else
    echo "FAIL  HAL.3c 1: the bound broke the WORKING case: $(printf '%s' "$H" | tr '\n' '|' | head -c 160)"; ok=0
fi

# ── 2. the fault is diagnosed, not fatal ───────────────────────────────────
boot kernel/kernel_hal3.elf ""; F=$BOOT_OUT; F_RC=$BOOT_RC
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 160)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  HAL.3c 2: the kernel still faults on a never-ready channel: $fseen"; ok=0
elif killed "$F_RC"; then
    # ★ The old check asserted the diagnosis and called it "exits cleanly"
    # without ever testing that it exited. A driver can print its timeout line
    # and then hang; that is a failure and it used to read as a PASS.
    echo "FAIL  HAL.3c 2: the bounded driver printed a diagnosis but NEVER TERMINATED (rc=$F_RC): $fseen"; ok=0
elif printf '%s' "$F" | grep -qF 'ata drq timeout st=' && printf '%s' "$F" | grep -qF 'ata dead'; then
    echo "PASS  HAL.3c 2: a never-ready channel is DIAGNOSED and the kernel exits cleanly (rc=$F_RC) — $(printf '%s' "$F" | grep -o 'ata drq timeout st=[0-9]*')"
else
    echo "FAIL  HAL.3c 2: no diagnosis on serial (wanted 'ata drq timeout st=' + 'ata dead'): $fseen"; ok=0
fi

# ── 3. RED PATH: the unbounded control must still die ──────────────────────
#   ★ Without this the gate proves only that the FIXED driver behaves, which is
#   consistent with the bound doing nothing at all.
if [ -x ./kernel/build_hal3c_ctrl.sh ] && [ -f kernel/ata_ctrl.la ]; then
    ./kernel/build_hal3c_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3c: control build failed"; ok=0; }
    if [ -f kernel/kernel_hal3_ctrl.elf ]; then
        boot kernel/kernel_hal3_ctrl.elf ""; C=$BOOT_OUT; C_RC=$BOOT_RC
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 120)
        # ★ WHAT THE CONTROL MUST DO IS *NOT DIAGNOSE-AND-EXIT*. IT NEED NOT CRASH.
        # This assertion used to demand `EXCEPTION`, because in 2026-08 the
        # unbounded WAITDRQ recursed off into unmapped memory (EXCEPTION 0d).
        # It no longer does, and the driver did not change: `self("!")` is in
        # TAIL POSITION and the native backend gained TCO, so the same runaway
        # recursion is now an infinite LOOP in bounded stack. MEASURED
        # 2026-09-09: the control prints "ata:" and hangs for the full budget,
        # rc=124, no EXCEPTION — while the FIXED driver diagnoses and exits 33
        # in 3s. The bound is still load-bearing; only the failure MODE moved.
        # A substrate improvement silently disarmed the red path of five gates.
        # So test the property that actually discriminates: the fix DIAGNOSES
        # AND TERMINATES, the control does neither. Crash or hang both prove it.
        if printf '%s' "$C" | grep -qF 'ata dead'; then
            echo "FAIL  HAL.3c 3 [red-path]: the control DIAGNOSED ($cseen) — it is not the unbounded"
            echo "      driver, so this gate proves nothing. Check kernel/ata_ctrl.la still lacks DRQFUEL."; ok=0
        elif printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK (crash): the UNBOUNDED control dies on the same input ($cseen) — the bound is load-bearing"
        elif killed "$C_RC"; then
            echo "      red-path OK (hang): the UNBOUNDED control never terminates on the same input (rc=$C_RC, $cseen) — the bound is load-bearing"
        else
            echo "FAIL  HAL.3c 3 [red-path]: the control neither diagnosed, crashed, nor hung (rc=$C_RC, $cseen)"
            echo "      — it exited cleanly without the bound, which the unbounded driver cannot do."; ok=0
        fi
    else
        # ★ 2026-09-08: this branch had NO else, so a control build exiting 0
        # WITHOUT producing an ELF removed the red path in SILENCE while the gate
        # still PASSed. The build above fails loudly, so this covers only that
        # narrow case — but a red control that can vanish with no line of output
        # is the exact failure this gate exists to refuse in the driver.
        echo "FAIL  HAL.3c [red-path]: kernel/kernel_hal3_ctrl.elf absent although build_hal3c_ctrl.sh"
        echo "      reported success — the red control did not run, so this gate cannot show"
        echo "      it discriminates. A gate must never skip past its own control."; ok=0
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/ata_ctrl.la + build_hal3c_ctrl.sh not present."
fi

[ "$ok" = 1 ] && echo "PASS  HAL.3c: the ATA wait is bounded — a disk that never becomes ready is named on serial and the kernel exits cleanly, where before it recursed into unmapped memory and died with EXCEPTION 0d and no mention of the disk. Honest scope: this bounds and DIAGNOSES the fault; it does not yet re-initialise the channel and retry (that is the 5q/5r repair loop applied to the disk organ, still open)." || { echo "HAL.3c gate RED"; exit 1; }
