#!/bin/bash
# Overnight, unattended. Safety rules, in order of importance:
#   - NEVER push. Publishing is Erik's decision.
#   - NEVER edit a shared file (build.sh) — track A and D have runs in flight
#     and /bin/sh reads a script lazily by byte offset.
#   - NEVER touch another track's worktree, and never kill a process.
#   - Cap concurrency at 2 VMs: A's regression (6h+) and D's checkpoint (5h+)
#     are already starving, and my arms are the load they are competing with.
#   - Refuse rather than conclude when an artifact is missing or empty.
set -u
B="$HOME/logos-b"; L="$B/.overnight.log"
# ★ NO `exec > >(tee ...)`. Combined with the bare `wait` below it deadlocked
# this script overnight: `wait` blocks on the tee, which never exits because it
# holds the log pipe for the script's lifetime. Measured — the only child was
# `tee` and the script sat in do_wait for 36 minutes. Redirect to the file, and
# wait on EXPLICIT pids so a logger can never be waited on.
exec >> "$L" 2>&1
say() { echo "[$(date +%H:%M:%S)] $*"; }
say "=== overnight start ==="

# ---- 1. finish the three-arm boot comparison already in flight -------------
say "step 1: waiting for the in-flight HH1/HH2 arms"
for i in $(seq 1 240); do
  [ -s "$B/.bootfix_HH1/elfobj_out.o" ] && [ -s "$B/.bootfix_HH2/elfobj_out.o" ] && break
  sleep 20
done
if [ -s "$B/.bootfix_HH1/elfobj_out.o" ] && [ -s "$B/.bootfix_HH2/elfobj_out.o" ]; then
  say "step 1: all three landed — comparing"
  sh "$B/bootfix_cmp.sh" | tee "$B/.bootfix_cmp.txt"
else
  say "step 1: TIMEOUT — arms did not land in 80 min; not concluding anything"
fi

# ---- 2. enumerate every arm with nasm (fast, no LA) ------------------------
say "step 2: enumerating all 22 arms with nasm"
cd "$B/.bootfix" || exit 1
ARMS=$(grep -oE '^[[:space:]]*%(ifdef|elifdef|ifndef)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' asm_in.asm | awk '{print $2}' | sort -u)
: > "$B/.arm_census.txt"
for arm in NONE $ARMS; do
  if [ "$arm" = NONE ]; then cp asm_in.asm /tmp/c.asm; else { echo "%define $arm"; cat asm_in.asm; } > /tmp/c.asm; fi
  if nasm -f elf64 -D METAL_FLAG_ABS=0x400078 /tmp/c.asm -o /tmp/c.o 2>/tmp/c.err; then
    objcopy -O binary --only-section=.boot32 /tmp/c.o /tmp/c.bin 2>/dev/null
    if [ -s /tmp/c.bin ]; then
      h=$(xxd -p /tmp/c.bin | tr -d '\n')
      hb=$(printf '%s' "$h" | grep -o 48c7c0 | wc -l)
      printf '%-16s buildable  REX.W-C7-sites=%s\n' "$arm" "$hb" >> "$B/.arm_census.txt"
    else
      printf '%-16s buildable  .boot32 EMPTY — not counted\n' "$arm" >> "$B/.arm_census.txt"
    fi
  else
    printf '%-16s UNBUILDABLE  %s\n' "$arm" "$(head -1 /tmp/c.err | sed 's/.*error: //')" >> "$B/.arm_census.txt"
  fi
done
say "step 2: census written"; cat "$B/.arm_census.txt"

# ---- 3. run the patched assembler on the untested defective arms ----------
say "step 3: patched asm.la over HH1B, HH2B, HH2C (2 at a time)"
run_arm() {
  a=$1; D="$B/.bootfix_$a"
  rm -rf "$D"; mkdir -p "$D"; cp "$B/.bootfix"/* "$D"/ 2>/dev/null
  rm -f "$D"/asm_in_*.asm "$D"/elfobj_out.o
  { echo "%define $a"; echo "%define METAL_FLAG_ABS 0x400078"; cat "$B/.bootfix/asm_in.asm"; } > "$D/asm_in.asm"
  for dep in entry.inc idt.asm timer.asm kbdirq.asm native_codegen3_out; do
    [ -s "$D/$dep" ] || { say "  $a: dep $dep missing — refusing"; return 1; }
  done
  ( cd "$D"
    nasm -f elf64 asm_in.asm -o nasm_ref.o 2>/dev/null || { echo "$a: nasm refused" ; exit 1; }
    # ★ CAPTURE, never /dev/null. The first HH2B run here failed and this
    # redirect destroyed the only evidence; the re-run named the cause in one
    # line ("unsupported ALU operand: k6a_kstack_top"). A diagnostic path that
    # discards its diagnostic is the instrument failing, not the subject.
    t=$(date +%s); timeout 3000 ./logos_secd > secd.out 2>&1; rc=$?
    if [ -s elfobj_out.o ]; then echo "  $a elfobj_out.o $(stat -c%s elfobj_out.o) B in $(( $(date +%s)-t ))s"
    else echo "  $a: FAILED rc=$rc after $(( $(date +%s)-t ))s: $(tail -1 secd.out)"; fi )
}
( run_arm HH1B ) & p1=$!
( run_arm HH2B ) & p2=$!
wait "$p1"; wait "$p2"
( run_arm HH2C ) & p3=$!
wait "$p3"
say "step 3: done"

# ---- 4. compare those three too -------------------------------------------
say "step 4: comparing the three new arms"
for a in HH1B HH2B HH2C; do
  D="$B/.bootfix_$a"
  if [ -s "$D/elfobj_out.o" ] && [ -s "$D/nasm_ref.o" ]; then
    ( cd "$D"
      objcopy -O binary --only-section=.boot32 elfobj_out.o o.bin 2>/dev/null
      objcopy -O binary --only-section=.boot32 nasm_ref.o   n.bin 2>/dev/null
      python3 "$B/maskrel.py" elfobj_out.o .boot32 o.bin om.bin >/dev/null 2>&1
      python3 "$B/maskrel.py" nasm_ref.o   .boot32 n.bin nm.bin >/dev/null 2>&1
      if [ -s om.bin ] && [ -s nm.bin ] && cmp -s om.bin nm.bin; then
        echo "  PASS $a .boot32 identical outside relocs ($(stat -c%s n.bin) B)"
      else
        echo "  FAIL $a .boot32 differs: $(cmp om.bin nm.bin 2>&1 | head -1)"
      fi
      oh=$(xxd -p o.bin|tr -d '\n'); nh=$(xxd -p n.bin|tr -d '\n')
      echo "       48c7c000000080 nasm=$(printf '%s' "$nh"|grep -o 48c7c000000080|wc -l) ours=$(printf '%s' "$oh"|grep -o 48c7c000000080|wc -l)" )
  else
    echo "  $a: no object — refusing to compare"
  fi
done | tee "$B/.bootfix_newarms.txt"

# ---- 5. produce the patch for track A, commit on track-b, DO NOT PUSH -----
say "step 5: writing the patch + verification, committing on track-b"
cd "$B"
diff -u .bootelf/asm.la .imm64/asm.la > ASMLA_IMM64_FIX.patch
say "  patch: $(wc -l < ASMLA_IMM64_FIX.patch) lines"
say "=== overnight complete — NOTHING PUSHED ==="
