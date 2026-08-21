#!/bin/bash
# Wait for the base cycle to reach step 4 (which proves logos_program.bin is
# fully written), then run BOTH arms concurrently in private mount namespaces.
B="$HOME/logos-b"
for i in $(seq 1 240); do
  grep -q '\[4/4\]' "$B/.bootelf.log" 2>/dev/null && break
  sleep 15
done
grep -q '\[4/4\]' "$B/.bootelf.log" || { echo "TIMEOUT: base cycle never reached step 4"; exit 1; }
echo "base reached [4/4] at $(date +%H:%M:%S) — logos_program.bin is complete; launching both arms"
ls -l "$B/.bootelf/logos_program.bin"

for ARM in HH1 HH2; do
  ( unshare -rm --propagation private bash -c \
      "mount -t tmpfs tmpfs /tmp; export LOGOS_AGENT_WT=b; $B/run_arm.sh $ARM" \
      > "$B/.arm_$ARM.log" 2>&1; echo "$ARM exit=$?" >> "$B/.arm_$ARM.log" ) &
done
wait
echo "=== both arms finished at $(date +%H:%M:%S) ==="
tail -3 "$B/.arm_HH1.log"; tail -3 "$B/.arm_HH2.log"
