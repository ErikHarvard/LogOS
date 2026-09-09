#!/bin/sh
# gate_hal3bc.sh — HAL.3bc: the ATA WRITE path's waits are BOUNDED, so a channel
# that never becomes ready is diagnosed BY STAGE instead of killing the kernel.
#
# The write twin of gate_hal3c.sh. ata3b.la had THREE unbounded waits where the
# read path had one — DRQ before pushing the sector, BSY after the cache flush,
# DRQ again on the read-back — so a wedged channel had three ways to die with
# nothing on serial naming the disk. The flush wait is the worst of them: it
# sits AFTER 512 bytes have already been pushed, which is exactly where giving
# up without a word costs most.
#
# ★ WHY THE STAGE IS NAMED, not just the timeout: "which of the three waits gave
# up" is the difference between a drive that never accepted the write and one
# that never flushed it. A bare "timeout" would collapse those into one symptom.
#
# Same three checks as HAL.3c: healthy path unchanged / fault diagnosed /
# red-path against the unbounded original, which must still crash.
set -u
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  HAL.3bc: qemu absent"; exit 0; }
[ -x ./kernel/build_hal3b.sh ] || { echo "SKIP  HAL.3bc: build_hal3b.sh absent"; exit 0; }

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
boot() {  # $1 = elf, $2 = extra qemu args ("" for no disk)
    _bt=$(mktemp)
    timeout 60 qemu-system-x86_64 -kernel "$1" $2 -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown >"$_bt" 2>/dev/null
    BOOT_RC=$?
    BOOT_OUT=$(tr -d '\0' < "$_bt")
    rm -f "$_bt"
}

./kernel/build_hal3b.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3bc: build_hal3b.sh failed"; exit 1; }

# ── 1. healthy path unchanged ──────────────────────────────────────────────
boot kernel/kernel_hal3b.elf "-drive file=kernel/hal3bdisk.img,format=raw,if=ide"; H=$BOOT_OUT
if printf '%s' "$H" | grep -qF 'ata3b done' && printf '%s' "$H" | grep -qF 'LOGOS-WROTE-THIS-HAL3B'; then
    echo "PASS  HAL.3bc 1: with a real disk the bounded write path still round-trips the sector"
else
    echo "FAIL  HAL.3bc 1: the bounds broke the WORKING case: $(printf '%s' "$H" | tr '\n' '|' | head -c 180)"; ok=0
fi

# ── 2. the fault is diagnosed, by stage, and is not fatal ──────────────────
boot kernel/kernel_hal3b.elf ""; F=$BOOT_OUT; F_RC=$BOOT_RC
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 180)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  HAL.3bc 2: the kernel still faults on a never-ready channel: $fseen"; ok=0
elif [ "$F_RC" = 124 ]; then
    echo "FAIL  HAL.3bc 2: the bounded driver printed a diagnosis but NEVER TERMINATED (rc=124): $fseen"; ok=0
elif printf '%s' "$F" | grep -qF 'ata3b dead' && printf '%s' "$F" | grep -q 'ata3b .* timeout st='; then
    echo "PASS  HAL.3bc 2: a never-ready channel is diagnosed and the kernel exits cleanly — $(printf '%s' "$F" | grep -o 'ata3b [a-z ]*timeout st=[0-9]*')"
else
    echo "FAIL  HAL.3bc 2: no staged diagnosis on serial (wanted 'ata3b <stage> timeout st=' + 'ata3b dead'): $fseen"; ok=0
fi

# ── 2b. the stage named must be the FIRST wait, not a later one ────────────
#   With no drive at all, the failure must be reported at 'write drq' — the
#   first wait. If it named 'flush bsy' or 'readback drq' the driver would have
#   walked past a wait that never succeeded, which is the bug in a new costume.
if printf '%s' "$F" | grep -qF 'ata3b write drq timeout'; then
    echo "PASS  HAL.3bc 2b: the stage named is the FIRST wait ('write drq') — the driver stopped where it actually stalled"
elif printf '%s' "$F" | grep -q 'ata3b .* timeout'; then
    echo "FAIL  HAL.3bc 2b: diagnosed at '$(printf '%s' "$F" | grep -o 'ata3b [a-z ]*timeout')' but with NO drive the first wait must be the one that fails — a later stage means an earlier wait was walked past"; ok=0
fi

# ── 3. RED PATH: the unbounded control must still die ──────────────────────
if [ -x ./kernel/build_hal3bc_ctrl.sh ] && [ -f kernel/ata3b_ctrl.la ]; then
    ./kernel/build_hal3bc_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  HAL.3bc: control build failed"; ok=0; }
    if [ -f kernel/kernel_hal3b_ctrl.elf ]; then
        boot kernel/kernel_hal3b_ctrl.elf ""; C=$BOOT_OUT; C_RC=$BOOT_RC
        cseen=$(printf '%s' "$C" | tr '\n' '|' | head -c 120)
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
        if printf '%s' "$C" | grep -qF 'ata3b dead'; then
            echo "FAIL  HAL.3bc 3 [red-path]: the control DIAGNOSED ($cseen) — it is not the unbounded"
            echo "      driver, so this gate proves nothing. Check kernel/ata3b_ctrl.la still lacks its fuel."; ok=0
        elif printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK (crash): the UNBOUNDED control dies on the same input ($cseen) — the bounds are load-bearing"
        elif [ "$C_RC" = 124 ]; then
            echo "      red-path OK (hang): the UNBOUNDED control never terminates on the same input (rc=124, $cseen) — the bounds are load-bearing"
        else
            echo "FAIL  HAL.3bc 3 [red-path]: the control neither diagnosed, crashed, nor hung (rc=$C_RC, $cseen)"; ok=0
        fi
    else
        # ★ 2026-09-08: this branch had NO else, so a control build exiting 0
        # WITHOUT producing an ELF removed the red path in SILENCE while the gate
        # still PASSed. The build above fails loudly, so this covers only that
        # narrow case — but a red control that can vanish with no line of output
        # is the exact failure this gate exists to refuse in the driver.
        echo "FAIL  HAL.3bc [red-path]: kernel/kernel_hal3b_ctrl.elf absent although build_hal3bc_ctrl.sh"
        echo "      reported success — the red control did not run, so this gate cannot show"
        echo "      it discriminates. A gate must never skip past its own control."; ok=0
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/ata3b_ctrl.la + build_hal3bc_ctrl.sh not present."
fi

[ "$ok" = 1 ] && echo "PASS  HAL.3bc: the ATA WRITE path's three waits are bounded — a channel that never becomes ready is named on serial WITH THE STAGE THAT STALLED and the kernel exits cleanly, where before it recursed into unmapped memory and died. (The write control faults as EXCEPTION 06 and the read control as 0d -- runaway recursion lands wherever it lands, so the check greps for ANY exception and this line no longer names one it cannot promise.) Honest scope: this bounds and DIAGNOSES; it does not re-initialise the channel and retry, and a mid-write stall still leaves the sector unwritten — it just says so." || { echo "HAL.3bc gate RED"; exit 1; }
