#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  P3 GATE — `pspawn`: A PROCESS CREATED AFTER BOOT, BY RING 3.
#
#  P1 built its three processes AT BOOT, through the low identity map, before any
#  CR3 was a process's. P3 does the same work AT RUNTIME, from ring 3, under a
#  process's CR3 — where that map is gone, so every write goes through the high
#  alias. See LOGOSINIT_SCOPE.md §5.0.4.
#
#  ★ THE DISCRIMINATOR IS DEPTH, AND THIS IS THE WHOLE DESIGN OF THE GATE.
#  P1's was easy ("nothing hardcoded for two produces a third"). P3's is not: a
#  transcript showing a FOURTH process is exactly what `P1_NPROC equ 4` would also
#  print. So the gate asserts that CHILD 4 ITSELF SPAWNS CHILD 5. Nothing pre-baked
#  yields a fifth process created BY the fourth — and it is also the property P5
#  needs, since init spawns every other organ and init's children must too.
#
#  GREEN — seven assertions:
#    1. pid 1/2/3 with val A1/B2/C3      the boot-built table is untouched
#    2. "PSPAWN pid=1 -> child 4"        ★ the pid reached RING 3. Printed by the
#                                        PROCESS from the syscall's return value; a
#                                        kernel-printed line would prove creation
#                                        but not that LA can DRIVE it.
#    3. "P1 pid=4 val=D4"                the runtime-created process RAN, and read
#                                        ITS OWN tag through the shared P1_VAL_VA —
#                                        D4 not A1 is the new-address-space evidence
#    4. "PSPAWN pid=4 -> child 5" and "P1 pid=5 val=E5"   ★ THE DISCRIMINATOR
#    5. each child's line follows the PSPAWN that created it (ordering)
#    6. "P1 pcb pid=04/05 state=03 fault=ff"  the children are IN THE TABLE — P2's
#                                        "announcing is not recording", at creation
#    7. "P1 table drained" + exit 33     five processes drained, kernel alive
#
#  REDS — five. Run: gate_p3.sh --red|--r2|--r3|--r4|--r5
#    --red  R1 BASELINE, and its shape is the sharpest argument in this gate: the
#           probe WITHOUT the handler. Syscall 57 is unknown, so syscall_entry's
#           `xor rax,rax` returns 0 and no child exists — but the machine STILL
#           EXITS 33. The baseline is green by exit code and wrong by content, so a
#           gate keyed on "non-green exit" would pass it for the wrong reason.
#    --r2   THE ADDRESS SPACE IS REALLY BUILT. Child gets the PARENT'S CR3; val
#           must collapse D4 -> A1.
#    --r3   ★ ANNOUNCING IS NOT CREATING. Allocate and return a pid, record nothing.
#           The PSPAWN line still prints and no fourth process runs.
#    --r4   ★ DEPTH HAS POWER. A spawned process may not spawn: child 5 must vanish
#           while child 4 remains. The ONLY control separating P3 from P1_NPROC=4.
#    --r5   BOUNDED AND LOUD. Budget never decremented, so every process spawns: the
#           table must FILL, pspawn must return -1 ("NO CHILD"), and the machine
#           must still drain and exit 33 — `secd: heap exhausted` at the table.
#
#  ★ EVERY CONTROL md5s THE ELF AND FAILS IF THE PERTURBATION WAS ABSORBED. An
#  absorbed break and a working assertion are indistinguishable from the gate's
#  response alone, so a green from an unverified break is a false finding against a
#  working check (LOGOSINIT_SCOPE.md §5.0.3, guard 1 — paid for during P2).
#
#  Shell discipline (§5.0.3): no `set -e` (it kills the verdict block on the failing
#  path), no EXIT trap, and run_variant sets CLEAN/RC in the CALLER — a status
#  assigned inside a function called in $( ) dies in the subshell.
# ════════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-}"
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "SKIP  P3 pspawn gate: qemu-system-x86_64 not installed"; exit 0
fi

run_variant() {   # $@ = build_p3.sh flags ; sets CLEAN, RC, BUILDFAIL, ELFSUM
    if ! ./kernel/build_p3.sh "$@" >/dev/null 2>&1; then
        BUILDFAIL=1; CLEAN=""; RC=-1; ELFSUM="none"; return
    fi
    BUILDFAIL=0
    ELFSUM=$(md5sum kernel/kernel_p3.elf | cut -c1-12)
    CLEAN=$(timeout 25 qemu-system-x86_64 \
            -kernel kernel/kernel_p3.elf -m 512 \
            -serial stdio -display none \
            -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
            -no-reboot -no-shutdown 2>/dev/null)
    RC=$?
    CLEAN=$(printf '%s' "$CLEAN" | tr -d '\0')
}
has() { printf '%s' "$CLEAN" | grep -qF "$1"; }
# Every control compares against the GREEN build's ELF. A byte-identical image means
# the perturbation never reached the artifact, so the gate was asked nothing.
absorbed_check() {  # $1 = good sum, $2 = this variant's sum, $3 = label
    if [ "$1" = "$2" ]; then
        echo "FAIL  P3 $3: the perturbation produced a BYTE-IDENTICAL ELF ($2)."
        echo "      It was ABSORBED, so this control asked the gate nothing — and a green"
        echo "      here would have been a false finding against a working assertion."
        return 1
    fi
    return 0
}

case "$MODE" in
--red)
    run_variant; GOODSUM="$ELFSUM"
    run_variant --nofix
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P3 R1: --nofix failed to build. A control that cannot build is a control that is not running (§5.0.3 guard 3)"; exit 1; }
    # ★ ADDED after Track B's link.la finding (SYM_VHIGH: defined, exported, called
    # by NOTHING, while the header said the check was made). This helper was called
    # in R2-R5 and NOT here — at the one control whose reasoning is subtlest — while
    # this gate's own header claimed EVERY control makes the check. Prose describing
    # a protection is not the protection, and it reads exactly like evidence.
    absorbed_check "$GOODSUM" "$ELFSUM" "R1" || exit 1
    if has 'P1 pid=4'; then
        echo "FAIL  P3 R1 PASSED — the build WITHOUT pspawn still produced a fourth process."
        echo "      Then pspawn is not what makes assertion 3 pass. REWRITE THE GATE."; exit 1; fi
    if has 'PSPAWN pid=1 -> child 0' && [ "$RC" -eq 33 ] && has 'P1 table drained'; then
        echo "PASS  P3 R1 baseline: shape = ANNOUNCED-BUT-UNIMPLEMENTED. Syscall 57 is unknown,"
        echo "      so syscall_entry's 'xor rax,rax' hands ring 3 child 0, no fourth process is"
        echo "      created, and the table drains normally."
        echo "      ★ NOTE THE EXIT CODE IS 33 — the SAME as the green run. This baseline is"
        echo "      green by exit code and wrong by CONTENT, so a gate keyed on 'not green'"
        echo "      would have passed it for the wrong reason. It is the argument for asserting"
        echo "      transcript content rather than status, made by the control itself."; exit 0; fi
    echo "FAIL  P3 R1: shape = UNEXPECTED (rc=$RC). Expected 'child 0', exit 33, table drained."
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)"; exit 1 ;;
--r2)
    run_variant; GOODSUM="$ELFSUM"
    run_variant --sharedcr3
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P3 R2: --sharedcr3 failed to build"; exit 1; }
    absorbed_check "$GOODSUM" "$ELFSUM" "R2" || exit 1
    if has 'P1 pid=4 val=A1' && ! has 'P1 pid=4 val=D4'; then
        echo "PASS  P3 R2 the address space is really built at runtime: handed the PARENT'S CR3"
        echo "      instead of the PML4 pspawn builds, child 4 reads val=A1 — the parent's frame —"
        echo "      not its own D4. So assertion 3 COULD have failed, and a runtime-built address"
        echo "      space is what makes it pass. (good elf $GOODSUM -> shared elf $ELFSUM)"; exit 0; fi
    echo "FAIL  P3 R2: with the parent's CR3 the child STILL read its own value (rc=$RC)."
    echo "      No arrangement of memory could have failed that assertion. REWRITE."
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)"; exit 1 ;;
--r3)
    run_variant; GOODSUM="$ELFSUM"
    run_variant --phantom
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P3 R3: --phantom failed to build"; exit 1; }
    absorbed_check "$GOODSUM" "$ELFSUM" "R3" || exit 1
    if has 'PSPAWN pid=1 -> child 4' && ! has 'P1 pid=4'; then
        echo "PASS  P3 R3 announcing is not creating: the phantom implementation allocates the"
        echo "      pid and RETURNS it — 'PSPAWN pid=1 -> child 4' prints exactly as in the green"
        echo "      run — while recording nothing, and no fourth process ever runs. The return"
        echo "      value alone cannot tell the two apart, which is why assertion 3 asserts the"
        echo "      CHILD'S OWN transcript line and assertion 6 asserts its PCB. This is P2's"
        echo "      'announcing is not recording' one station earlier, at creation."
        echo "      (good elf $GOODSUM -> phantom elf $ELFSUM)"; exit 0; fi
    echo "FAIL  P3 R3: the phantom build did not produce the announce-without-create shape (rc=$RC)."
    echo "      Expected 'PSPAWN pid=1 -> child 4' present AND 'P1 pid=4' absent."
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)"; exit 1 ;;
--r4)
    run_variant; GOODSUM="$ELFSUM"
    run_variant --nodepth
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P3 R4: --nodepth failed to build"; exit 1; }
    absorbed_check "$GOODSUM" "$ELFSUM" "R4" || exit 1
    if has 'P1 pid=4 val=D4' && ! has 'P1 pid=5'; then
        echo "PASS  P3 R4 DEPTH HAS POWER — the control that matters most. With a spawned process"
        echo "      forbidden to spawn, child 4 is still created (val=D4) but child 5 NEVER"
        echo "      EXISTS. So assertion 4 is falsifiable, and it is the only assertion in this"
        echo "      gate that a bigger boot table ('P1_NPROC equ 4') could not also satisfy:"
        echo "      a fourth process is cheap, a fifth created BY the fourth is not."
        echo "      (good elf $GOODSUM -> nodepth elf $ELFSUM)"; exit 0; fi
    echo "FAIL  P3 R4: forbidding a spawned process to spawn did not remove child 5 (rc=$RC)."
    echo "      Then the depth assertion measures nothing and P3 is not distinguished from a"
    echo "      larger boot table. REWRITE THE GATE."
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 240)"; exit 1 ;;
--r5)
    run_variant; GOODSUM="$ELFSUM"
    run_variant --flood
    [ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P3 R5: --flood failed to build"; exit 1; }
    absorbed_check "$GOODSUM" "$ELFSUM" "R5" || exit 1
    ok=1
    has 'NO CHILD'        || { echo "FAIL  P3 R5: the table filled but pspawn never reported it. Exhaustion must be REPORTED, not discovered as a hang"; ok=0; }
    has 'P1 pid=8 val=H8' || { echo "FAIL  P3 R5: the table did not fill to capacity (no pid 8) — the flood control did not flood"; ok=0; }
    has 'P1 table drained' || { echo "FAIL  P3 R5: the kernel did not survive table exhaustion"; ok=0; }
    [ "$RC" -eq 33 ]      || { echo "FAIL  P3 R5: exit code != 33 (got $RC) — exhaustion must not wedge or halt the machine"; ok=0; }
    [ "$ok" -eq 1 ] && { echo "PASS  P3 R5 bounded and loud: with the budget never decremented every process spawns,"
        echo "      the table fills to capacity (pid 8 runs), the next pspawn returns -1 and ring 3"
        echo "      prints 'NO CHILD', and the machine still drains and exits 33. A finite table"
        echo "      that says so — 'secd: heap exhausted' at the process table, not a hang."
        echo "      (good elf $GOODSUM -> flood elf $ELFSUM)"; exit 0; }
    echo "      Got: $(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)"; exit 1 ;;
"") ;;
*)  echo "usage: gate_p3.sh [--red|--r2|--r3|--r4|--r5]" >&2; exit 2 ;;
esac

# ── the real gate ───────────────────────────────────────────────────────────
run_variant
[ "$BUILDFAIL" -eq 1 ] && { echo "FAIL  P3 gate: build_p3.sh failed"; exit 1; }
seen=$(printf '%s' "$CLEAN" | tr '\n' ' ' | head -c 300)
ok=1

has 'P1 pid=1 val=A1' || { echo "FAIL  P3: process 1 did not complete normally — pspawn broke the ordinary path (rc=$RC, got: $seen)"; ok=0; }
has 'P1 pid=2 val=B2' || { echo "FAIL  P3: process 2 did not run — the boot-built table must be untouched (rc=$RC, got: $seen)"; ok=0; }
has 'P1 pid=3 val=C3' || { echo "FAIL  P3: process 3 did not run — the boot-built table must be untouched (rc=$RC, got: $seen)"; ok=0; }
has 'PSPAWN pid=1 -> child 4' || { echo "FAIL  P3: ring 3 did not receive a child pid. The line is printed BY THE PROCESS from the syscall's return value — without it, creation might be real but not LA-DRIVEN, which is the whole title of the brick (rc=$RC, got: $seen)"; ok=0; }
has 'P1 pid=4 val=D4' || { echo "FAIL  P3: the runtime-created process never ran with its OWN value. val=D4 (not A1) is the evidence that a NEW address space was built at runtime, not a second name for the parent's (rc=$RC, got: $seen)"; ok=0; }
has 'PSPAWN pid=4 -> child 5' || { echo "FAIL  P3: ★ the spawned process could not itself spawn. This is THE DISCRIMINATOR: a fourth process is exactly what 'P1_NPROC equ 4' also prints, and only a fifth created BY the fourth separates pspawn from a bigger boot table (rc=$RC, got: $seen)"; ok=0; }
has 'P1 pid=5 val=E5' || { echo "FAIL  P3: ★ the grandchild never ran. Creation must be a capability the created process HAS, which is exactly what P5 needs of init's children (rc=$RC, got: $seen)"; ok=0; }

# Ordering: a child must run AFTER the pspawn that created it. Presence alone would
# not prove creation preceded execution — the same argument as P2's assertion 3.
S4=$(printf '%s\n' "$CLEAN" | grep -n 'PSPAWN pid=1 -> child 4' | head -1 | cut -d: -f1)
R4=$(printf '%s\n' "$CLEAN" | grep -n 'P1 pid=4 val=D4'         | head -1 | cut -d: -f1)
S5=$(printf '%s\n' "$CLEAN" | grep -n 'PSPAWN pid=4 -> child 5' | head -1 | cut -d: -f1)
R5L=$(printf '%s\n' "$CLEAN" | grep -n 'P1 pid=5 val=E5'        | head -1 | cut -d: -f1)
if [ -n "$S4" ] && [ -n "$R4" ]; then
    [ "$R4" -gt "$S4" ] || { echo "FAIL  P3: process 4 ran BEFORE the pspawn that created it (line $R4 vs $S4) — then it was not created by that call"; ok=0; }
fi
if [ -n "$S5" ] && [ -n "$R5L" ]; then
    [ "$R5L" -gt "$S5" ] || { echo "FAIL  P3: process 5 ran BEFORE the pspawn that created it (line $R5L vs $S5)"; ok=0; }
fi

has 'P1 pcb pid=04 state=03 fault=ff' || { echo "FAIL  P3: the child is not RECORDED in the table as a clean exit. A syscall can return a pid and record nothing — P2's 'announcing is not recording', one station earlier. P4 (pwait) reads exactly this (rc=$RC, got: $seen)"; ok=0; }
has 'P1 pcb pid=05 state=03 fault=ff' || { echo "FAIL  P3: the grandchild is not RECORDED in the table (rc=$RC, got: $seen)"; ok=0; }
has 'P1 table drained' || { echo "FAIL  P3: the kernel did not outlive its now-larger process table (rc=$RC, got: $seen)"; ok=0; }
[ "$RC" -eq 33 ] || { echo "FAIL  P3: exit code != 33 (got $RC). 124 means it wedged; 35 means a fault halted it"; ok=0; }

[ "$ok" -eq 1 ] && echo "PASS  P3: LA-driven process creation — ring 3 called pspawn() and RECEIVED a pid ('PSPAWN pid=1 -> child 4'), the kernel built that child's PML4/PDPT/PD and copied the pristine image into its frame AT RUNTIME through the high alias (the low identity map P1's boot loop used is gone under a process CR3), the child ran in its OWN address space (val=D4, not the parent's A1) and is RECORDED in the table ('pcb pid=04 state=03 fault=ff'), and ★ THAT CHILD ITSELF SPAWNED CHILD 5 — the discriminator, because a fourth process is exactly what 'P1_NPROC equ 4' would also print while nothing pre-baked yields a fifth created BY the fourth. Five processes drained and the kernel exited 33. Falsifiable: './kernel/gate_p3.sh --r4' forbids a spawned process to spawn and child 5 vanishes; '--r3' announces a child without creating one; '--r2' collapses the child onto the parent's address space."
[ "$ok" -eq 1 ]
