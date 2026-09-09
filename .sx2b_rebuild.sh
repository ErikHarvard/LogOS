#!/bin/sh
# ★ WORKTREE-RELATIVE, NOT ABSOLUTE. This read `cd /home/erikxanderharvard/logos`.
# Untracked that was merely wrong; TRACKED it would be a cross-tree gate: a fresh
# clone running this would build in ANOTHER worktree and leave itself without the
# vessel, silently. Same defect gate_rss.sh was held back for. The path default
# goes with the wiring.
cd "$(dirname "$0")" || exit 1
L=.sx2b_build.log
echo "--- sx2b_app REBUILD (diamond broken) ---" >> $L
cp selfext2b.la logos_source.la
S=$(date +%s)
./tiny_host codegen.la >>$L 2>&1 || { echo "codegen FAILED" >> $L; echo SX2B_REBUILD_FAILED >> $L; exit 1; }
echo "  codegen(selfext2b.la) $(( $(date +%s) - S ))s" >> $L
cp logos_program.bin logos_embed.bin
./tiny_host bundle.la >>$L 2>&1 || { echo "bundle FAILED" >> $L; echo SX2B_REBUILD_FAILED >> $L; exit 1; }
mv logos_app sx2b_app && chmod +x sx2b_app
echo "  -> sx2b_app $(stat -c%s sx2b_app) bytes" >> $L
rm -f logos_source.la logos_embed.bin
echo SX2B_REBUILD_COMPLETE >> $L
