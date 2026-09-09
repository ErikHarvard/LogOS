#!/bin/sh
# gate_ps2_bounded.sh <driver> <tag> — Freeze Audit II / Q3 red-path.
#
# Proves a PS/2 driver's OWED waits are bounded: the fixed driver DIAGNOSES an
# unanswered ACK and STOPS, while the pre-fix driver dies on the same input.
#
#   <driver>_faulted  = the FIXED driver, 0xF4 removed so no ACK is owed
#   <driver>_ctrl     = the PRE-FIX driver, same fault
#
# ★ WHAT THIS PROVES AND WHAT IT DOES NOT. A bound claims only "this loop
# terminates", so a self-inflicted never-satisfied wait is a fair test of it.
# It is NOT evidence of fault tolerance: a REPAIR would claim the device was
# fixed, which needs a fault both realistic and persistent -- a standard HAL.3d
# failed twice (SELFREPAIR_3d_DESIGN.md).
#
# ★ AND IT MUST CHECK THE DRIVER STOPS, not merely that it printed. mouse.la's
# first cut diagnosed correctly and then read packets from the device it had
# just declared dead, faulting a second time (EXCEPTION 03) -- a bound that
# reports and continues has MOVED the crash, not removed it.
set -u
[ $# -eq 2 ] || { echo "usage: gate_ps2_bounded.sh <driver> <tag>"; exit 2; }
D=$1; TAG=$2
cd "$(dirname "$0")/.." || exit 1
ok=1
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  ${D}_bounded: qemu absent"; exit 0; }

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
boot() {
    _bt=$(mktemp)
    timeout 45 qemu-system-x86_64 -kernel "$1" -m 256 -serial stdio -display none \
      -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown >"$_bt" 2>/dev/null
    BOOT_RC=$?
    BOOT_OUT=$(tr -d '\0' < "$_bt")
    rm -f "$_bt"
}

# ★ A MISNAMED DRIVER MUST NOT SKIP TO GREEN. This gate is invoked from build.sh
#  with a literal argument, so a typo there would previously have produced
#  "SKIP ... exit 0" and let the build continue believing a driver was covered —
#  the exact skip-to-green shape this Q3 work exists to remove, reproduced in a
#  gate written to remove it. Found by running it with a bogus name rather than
#  by reading it.
#  The distinction: an absent DRIVER SOURCE means the caller named something that
#  is not a driver (a configuration error -> FAIL). An absent build SCRIPT for a
#  real driver means this red-path harness was never built for it (-> SKIP).
if [ ! -f "kernel/${D}.la" ]; then
    echo "FAIL  ${D}_bounded: kernel/${D}.la does not exist — '${D}' is not a driver."
    echo "      Refusing to SKIP: a misnamed argument must not read as coverage."
    exit 1
fi
[ -x "./kernel/build_${D}_faulted.sh" ] || { echo "SKIP  ${D}_bounded: kernel/${D}.la exists but no faulted build script — red-path harness not built for this driver"; exit 0; }
./kernel/build_${D}_faulted.sh >/dev/null 2>&1 || { echo "FAIL  ${D}_bounded: faulted build failed"; exit 1; }
boot "kernel/kernel_${D}_faulted.elf"; F=$BOOT_OUT; F_RC=$BOOT_RC
fseen=$(printf '%s' "$F" | tr '\n' '|' | head -c 170)
if printf '%s' "$F" | grep -q 'EXCEPTION'; then
    echo "FAIL  ${D}_bounded 1: the BOUNDED driver still faults: $fseen"; ok=0
elif [ "$F_RC" = 124 ]; then
    echo "FAIL  ${D}_bounded 1: the BOUNDED driver printed a diagnosis but NEVER TERMINATED (rc=124): $fseen"; ok=0
elif printf '%s' "$F" | grep -qF "$TAG dead" && printf '%s' "$F" | grep -q "$TAG .* timeout st="; then
    echo "PASS  ${D}_bounded 1: unanswered ACK diagnosed and the kernel STOPPED cleanly — $(printf '%s' "$F" | grep -o "$TAG [a-z0-9 ]*timeout st=[0-9]*")"
else
    echo "FAIL  ${D}_bounded 1: no diagnosis (wanted '$TAG ... timeout st=' + '$TAG dead'): $fseen"; ok=0
fi

if [ -x "./kernel/build_${D}_ctrl.sh" ] && [ -f "kernel/${D}_ctrl.la" ]; then
    ./kernel/build_${D}_ctrl.sh >/dev/null 2>&1 || { echo "FAIL  ${D}_bounded: control build failed"; ok=0; }
    if [ -f "kernel/kernel_${D}_ctrl.elf" ]; then
        boot "kernel/kernel_${D}_ctrl.elf"; C=$BOOT_OUT; C_RC=$BOOT_RC
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
        if printf '%s' "$C" | grep -qF "$TAG dead"; then
            echo "FAIL  ${D}_bounded 2 [red-path]: the control DIAGNOSED ($cseen) — it is not the unbounded"
            echo "      driver, so this gate proves nothing. Check kernel/${D}_ctrl.la still lacks its bound."; ok=0
        elif printf '%s' "$C" | grep -q 'EXCEPTION'; then
            echo "      red-path OK (crash): the UNBOUNDED pre-fix driver dies on the same input ($cseen) — the bound is load-bearing"
        elif [ "$C_RC" = 124 ]; then
            echo "      red-path OK (hang): the UNBOUNDED pre-fix driver never terminates on the same input (rc=124, $cseen) — the bound is load-bearing"
        else
            echo "FAIL  ${D}_bounded 2 [red-path]: the control neither diagnosed, crashed, nor hung (rc=$C_RC, $cseen)"; ok=0
        fi
    else
        # ★ 2026-09-08: this branch had NO else, so a control build that exited 0
        # WITHOUT producing an ELF removed the red path in silence and the gate
        # still PASSed — the discriminating half gone with no line in the output.
        # The build above fails loudly, so this fires only on that narrow case;
        # narrow is not the same as impossible, and a red control that can vanish
        # quietly is the defect this whole gate exists to refuse.
        echo "FAIL  ${D}_bounded [red-path]: kernel/kernel_${D}_ctrl.elf is absent although"
        echo "      build_${D}_ctrl.sh reported success — the red control did not run, so this"
        echo "      gate cannot show it discriminates. A gate must never skip past its control."
        ok=0
    fi
else
    echo "      NOTE: red-path SKIPPED — kernel/${D}_ctrl.la absent."
fi

[ "$ok" = 1 ] && echo "PASS  ${D}_bounded: OWED waits bounded — an unanswered handshake or ACK is named on serial with the stage that stalled and the driver STOPS, where the pre-fix version recursed until it faulted. The USER wait (packet byte 0) is deliberately still unbounded." || { echo "${D}_bounded gate RED"; exit 1; }
