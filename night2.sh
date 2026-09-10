#!/bin/bash
# Overnight, unattended. Every safety rule here was earned today.
#
#   - NEVER push. Publishing is Erik's decision.
#   - NEVER edit a shared file (build.sh, ROADMAP.md) — A is converting kernel
#     gates and /bin/sh reads a script lazily by byte offset.
#   - NEVER touch ~/logos (A's worktree) except to READ committed blobs.
#   - ONE heavy job at a time. A has compiles running; contention is how I
#     nearly convinced myself I had broken its build.
#   - CAPTURE every diagnostic. A /dev/null redirect destroyed the evidence of
#     the one failure that mattered last night.
#   - NO `exec > >(tee)` with a bare `wait` — that deadlocked overnight.sh.
#   - NO `pkill -f` on a pattern my own command line contains (exit 144).
#   - REFUSE, don't conclude, when an artifact is missing: `grep -c` on a
#     nonexistent file returns 0, which reads exactly like "no matches".
set -u
B="$HOME/logos-b"; L="$B/.night2.log"; : > "$L"
say(){ echo "[$(date +%H:%M:%S)] $*" >> "$L"; }
run(){ # run <label> <logfile> <cmd...>  — always captures, never discards
  local lbl=$1 lf=$2; shift 2
  local s=$(date +%s)
  "$@" > "$lf" 2>&1; local rc=$?
  # ★ COUNT BOTH SHAPES. run_link_regress.sh emits `gate_x.sh rc=0 PASS=9 FAIL=0`
  # and a `LINKER REGRESSION: 51 PASS / 0 FAIL` summary — NOT ^PASS lines. The
  # first version counted only ^PASS and reported "0 PASS / 0 FAIL" for a run
  # that was actually 51/0. Zero of BOTH is the tell: a run that produces
  # neither has not been measured, and reads as green to a hurried eye.
  local np=$(grep -c '^PASS' "$lf" 2>/dev/null); local nf=$(grep -c '^FAIL' "$lf" 2>/dev/null)
  local sum=$(grep -oE '[0-9]+ PASS / [0-9]+ FAIL' "$lf" 2>/dev/null | tail -1)
  [ "$np" -eq 0 ] && [ "$nf" -eq 0 ] && [ -n "$sum" ] && { np=${sum%% PASS*}; nf=$(echo "$sum" | grep -oE '/ [0-9]+' | tr -dc 0-9); }
  [ "$np" -eq 0 ] && [ "$nf" -eq 0 ] && say "     ^ ZERO OF BOTH — this run was not measured, do not read it as green"
  say "  $lbl rc=$rc $(( $(date +%s)-s ))s  $np PASS / $nf FAIL"
  [ "$rc" -ge 128 ] && say "     ^ rc>=128 means KILLED, not failed — do not read this as a defect"
  grep '^FAIL' "$lf" 2>/dev/null | head -3 | sed 's/^/     /' >> "$L"
  return $rc
}
say "=== night2 start ==="

# ---- 1. finish the linker sweep: the 6th gate that was killed for A ---------
say "step 1: gate_link_kernel (the outstanding 6th gate, ~36 min)"
run gate_link_kernel "$B/.n_kernel.log" "$B/gate_link_kernel.sh"

# ---- 2. the FULL linker sweep as one coherent run --------------------------
say "step 2: all six linker gates in one sweep"
run link_regress "$B/.n_link.log" "$B/run_link_regress.sh"

# ---- 3. reconfirm the assembler suites against the current asm.la ----------
say "step 3: asm flat (25) + object (7) regressions"
cp "$B/.imm64/asm.la" "$B/.regress/asm.la" 2>/dev/null
cp "$B/.imm64/asm.la" "$B/.elfreg/asm.la" 2>/dev/null
run asm_flat   "$B/.n_flat.log"   "$B/.regress/run.sh"
run asm_object "$B/.n_object.log" "$B/.elfreg/run.sh"

# ---- 4. the seam gate, re-run against everything as it now stands ----------
say "step 4: assembler<->linker seam"
run seam "$B/.n_seam.log" "$B/gate_seam_asm_link.sh"

# ---- 5. can types 26 and 42 be produced AT ALL? ----------------------------
#   ISGOTPC(26) and ISGOTX(42) are implemented and unexercised. nasm would not
#   emit either. If no toolchain on this box can produce one, they are in the
#   same category ALUENC turned out to occupy: possibly real, possibly dead,
#   currently unprovable — and that is worth recording as a fact rather than
#   left as an open question nobody re-asks.
say "step 5: try to produce relocation types 26 and 42"
{
  T=$(mktemp -d)
  printf 'int e;\nint f(void){return e;}\n' > "$T/c.c"
  for cc in gcc clang; do
    command -v $cc >/dev/null || { echo "$cc: absent"; continue; }
    $cc -c -fPIC -O2 "$T/c.c" -o "$T/$cc.o" 2>/dev/null \
      && echo "$cc -fPIC: $(readelf -rW "$T/$cc.o" | awk 'NF>3&&$1~/^[0-9a-f]+$/{print $3}' | sort -u | tr '\n' ' ')"
    $cc -c -mcmodel=large "$T/c.c" -o "$T/${cc}L.o" 2>/dev/null \
      && echo "$cc -mcmodel=large: $(readelf -rW "$T/${cc}L.o" | awk 'NF>3&&$1~/^[0-9a-f]+$/{print $3}' | sort -u | tr '\n' ' ')"
  done
  rm -rf "$T"
} > "$B/.n_types.log" 2>&1
say "  types probe: $(tr '\n' '|' < "$B/.n_types.log" | cut -c1-160)"

# ---- 6. claimed-vs-exercised audit across MY gates -------------------------
#   The audit that found GOTPCREL, generalised: for every gate I own, is there
#   evidence it has ever been SEEN TO FAIL? A gate never observed red is not
#   known to be a gate.
say "step 6: red-path audit of my own gates"
{
  for g in "$B"/gate_link*.sh "$B"/gate_seam_asm_link.sh; do
    [ -f "$g" ] || continue
    n=$(basename "$g")
    rp=$(grep -ciE 'red.?path|RED PATH|deliberately (broken|corrupt)|must fail|flip.*bit' "$g")
    fl=$(grep -c 'FAIL' "$g")
    printf '%-26s FAIL-arms=%-3s red-path-evidence=%s\n' "$n" "$fl" "$([ "$rp" -gt 0 ] && echo "yes ($rp)" || echo 'NONE DOCUMENTED')"
  done
} > "$B/.n_redpath.log" 2>&1
say "  red-path audit written ($(wc -l < "$B/.n_redpath.log") gates)"

say "=== night2 complete ==="
say "SUMMARY:"
for f in .n_kernel .n_link .n_flat .n_object .n_seam; do
  [ -f "$B/$f.log" ] && say "  $f: $(grep -c '^PASS' "$B/$f.log") PASS / $(grep -c '^FAIL' "$B/$f.log") FAIL"
done
