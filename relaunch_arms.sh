#!/bin/bash
B="$HOME/logos-b"
for ARM in HH1 HH2; do
  ( unshare -rm --propagation private bash -c \
      "mount -t tmpfs tmpfs /tmp; export LOGOS_AGENT_WT=b; $B/run_arm.sh $ARM" \
      > "$B/.arm_$ARM.log" 2>&1; echo "$ARM exit=$?" >> "$B/.arm_$ARM.log" ) &
done
wait
echo "=== both arms finished $(date +%H:%M:%S) ==="
for ARM in HH1 HH2; do echo "--- $ARM ---"; cat "$B/.arm_$ARM.log"; done
