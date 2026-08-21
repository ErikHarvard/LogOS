#!/bin/sh
# Final LA-side encoding evidence, all three arms.
B="$HOME/logos-b"
# NONE arm's run IS the base cycle; graft its object into the control dir.
if [ -s "$B/.bootelf/elfobj_out.o" ]; then
  cp "$B/.bootelf/elfobj_out.o" "$B/.bootelf_NONE/elfobj_out.o"
fi
for ARM in NONE HH1 HH2; do
  "$B/compare_arm.sh" "$ARM" || echo "  ($ARM comparison exited non-zero)"
done
