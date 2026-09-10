#!/bin/bash
# Every gate that touches link.la or link_reloc.la, run sequentially so it does
# not contend with track A's build. gate_link_reloc first: it is the one that
# directly exercises the relocation resolver I changed.
cd "$HOME/logos-b" || exit 1
pass=0; fail=0; skip=0; sick=0
# ★ gate_link_layout.sh was MISSING from this list until 2026-09-08 — including
# in the version committed that morning. It is the only build-reachable cover for
# link_layout.la, and it had never been run by build.sh either, so the module had
# no enforcement anywhere. Listed second: it is cheap (38 s) and fails fast.
# ★ gate_seam_asm_link.sh added 2026-09-08: it was invoked by NOTHING anywhere
# and its exclusion was undocumented (my gate_link*.sh sweep glob missed it —
# it does not match that prefix). It is not in build.sh for a STATED reason
# (see there): it fails rather than skips when track A's asm.la half regresses.
# On-demand here is where it belongs, alongside gate_link_kernel.sh.
# ★★ AND THE SAME GLOB COST ME THE SAME GATE AGAIN ON 2026-09-09. Asked to run
#   "the linker gate suite", I composed a list from `ls gate_link*.sh` and got
#   EIGHT — missing gate_seam_asm_link.sh for the identical prefix reason, in a
#   tree whose own comment says so two lines up. ⇒ THIS FILE IS THE LIST. Do not
#   rebuild it from a glob; add gates HERE and run THIS.
GATES="gate_link_reloc.sh gate_link_layout.sh gate_link_hiaddr.sh gate_link.sh
       gate_link_nsec.sh gate_link_script.sh gate_link_e2e.sh gate_seam_asm_link.sh
       gate_link_kernel.sh"

# ─── A14: never deep beside deep ──────────────────────────────────────────────
# These gates are timing-sensitive; run beside another track's build or kernel
# gate they go falsely RED, and a false RED costs more than a delayed run.
# ⚠ THREE WAYS THIS COUNT HAS BEEN WRONG IN ONE DAY, ALL YIELDING A PLAUSIBLE
#   SMALL INTEGER: (1) `pgrep -f` matched any SHELL whose command line merely
#   mentioned tiny_host, including the waiter armed while blocked — so waiting
#   caused blocking; (2) `pgrep -x qemu-system-x86_64` can NEVER match, because
#   the kernel truncates comm to 15 chars and the name is 18 — pgrep warns on
#   stderr and still exits 1, indistinguishable from "no match"; (3) an awk on
#   `pgrep -a -x bash` tested $2, which is always the literal string "bash",
#   since `pgrep -a` prints PID then CMDLINE ($3 is argv[1]). Measured 19:24
#   against a live 1h52m `bash ./build.sh`: $2 gave 0, $3 gave 1.
# ⇒ PRINT THE PIDS, NOT THE COUNT. A zero arm is invisible because zero is
#   exactly what an idle arm looks like.
deep_pids(){
  pgrep -x tiny_host 2>/dev/null
  pgrep -x tiny_host_base 2>/dev/null
  pgrep -x qemu-system-x86 2>/dev/null   # truncated comm — the only matchable form
  pgrep -x build.sh 2>/dev/null          # ./build.sh via shebang: comm=build.sh
  pgrep -a -x bash 2>/dev/null | awk '$3 ~ /build\.sh$/ {print $1}'   # bash ./build.sh
}
DP=$(deep_pids | sort -u); DN=$(printf '%s' "$DP" | grep -c . )
if [ "$DN" -gt 0 ] && [ "${LOGOS_OVERRIDE_A14:-0}" != 1 ]; then
  echo "REFUSED: $DN deep job(s) already running — A14, and these gates go falsely RED under load."
  while read -r p; do [ -n "$p" ] && printf '    pid %-8s %s\n' "$p" "$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-70)"; done <<< "$DP"
  echo "  wait for the front to clear, or re-run with LOGOS_OVERRIDE_A14=1 if you accept a RED may be contention."
  exit 2
fi
[ "$DN" -eq 0 ] && echo "# front clear (0 deep jobs) at $(date '+%H:%M')" \
                || echo "# ⚠ OVERRIDDEN: running beside $DN deep job(s) — a RED here may be contention"

for g in $GATES; do
  [ -x "$g" ] || { echo "SKIP  $g (not executable)"; skip=$((skip+1)); continue; }
  s=$(date +%s)
  out=$(timeout 3600 ./"$g" 2>&1)
  rc=$?
  p=$(printf '%s\n' "$out" | grep -c '^PASS'); f=$(printf '%s\n' "$out" | grep -c '^FAIL')
  k=$(printf '%s\n' "$out" | grep -c '^SKIP')
  printf '%-24s rc=%-3s PASS=%-3s FAIL=%-3s SKIP=%-3s %ss\n' "$g" "$rc" "$p" "$f" "$k" "$(( $(date +%s)-s ))"
  [ "$f" -gt 0 ] && printf '%s\n' "$out" | grep '^FAIL' | head -3 | sed 's/^/    /'
  [ "$k" -gt 0 ] && printf '%s\n' "$out" | grep '^SKIP' | head -3 | sed 's/^/    /'
  # ★ A ROW WITH NO VERDICT IS NOT A GREEN ROW, and a tally is exactly where that
  #   hides. Counting only PASS and FAIL makes a gate that printed NEITHER add
  #   0 to both and vanish. Three pathologies, each named rather than summed:
  if [ $((p+f+k)) -eq 0 ]; then
    echo "    ‼ NO VERDICT LINE AT ALL — silent death or a FAIL muted by set -e. Not a pass."; sick=$((sick+1))
  fi
  if [ "$rc" -eq 0 ] && [ "$f" -gt 0 ]; then
    echo "    ‼ exit 0 WITH a FAIL line — this gate CANNOT GO RED."; sick=$((sick+1))
  fi
  if [ "$rc" -ne 0 ] && [ "$f" -eq 0 ] && [ $((p+k)) -gt 0 ]; then
    echo "    ‼ nonzero exit with no FAIL line — aborted part-way; the PASSes above are partial."; sick=$((sick+1))
  fi
  [ "$rc" -eq 124 ] && { echo "    ‼ rc=124 — TIMED OUT at 3600 s, not a verdict."; sick=$((sick+1)); }
  pass=$((pass+p)); fail=$((fail+f)); skip=$((skip+k))
done
echo "----------------------------------------"
echo "LINKER REGRESSION: $pass PASS / $fail FAIL / $skip SKIP"
# ★ THE SKIPs ARE PART OF THE VERDICT. A suite that mostly skips is not a passing
#   suite — build.sh currently carries 49 assertions that report neither PASS nor
#   FAIL, which is precisely how a tally shows nothing wrong.
[ "$skip" -gt 0 ] && echo "  ⚠ $skip SKIP — a skipped assertion proved nothing; read the lines above before calling this green."
[ "$sick" -gt 0 ] && echo "  ‼ $sick INCONSISTENT ROW(S) — the suite's own reporting is suspect, not just its subject."
{ [ "$fail" -eq 0 ] && [ "$sick" -eq 0 ]; } || exit 1
