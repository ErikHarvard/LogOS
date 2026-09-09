#!/bin/sh
# ★ WORKTREE-RELATIVE, NOT ABSOLUTE. This read `cd /home/erikxanderharvard/logos`.
# Untracked that was merely wrong; TRACKED it would be a cross-tree gate: a fresh
# clone running this would build in ANOTHER worktree and leave itself without the
# vessel, silently. Same defect gate_rss.sh was held back for. The path default
# goes with the wiring.
cd "$(dirname "$0")" || exit 1
L=.sx2b_build.log; : > $L
step() { echo "--- $1 ---" >> $L; }
mkbundle() {   # $1 = source .la, $2 = output vessel name
  cp "$1" logos_source.la || return 1
  S=$(date +%s)
  ./tiny_host codegen.la >>$L 2>&1 || { echo "codegen FAILED on $1" >> $L; return 1; }
  echo "  codegen($1) $(( $(date +%s) - S ))s" >> $L
  cp logos_program.bin logos_embed.bin || return 1
  ./tiny_host bundle.la >>$L 2>&1 || { echo "bundle FAILED on $1" >> $L; return 1; }
  mv logos_app "$2" || return 1
  chmod +x "$2"
  echo "  -> $2 $(stat -c%s "$2") bytes" >> $L
}
step "emit the VM"
rm -f logos_secd logos_program.bin logos_source.la logos_embed.bin logos_app
./tiny_host secd.la >>$L 2>&1 && echo "  logos_secd $(stat -c%s logos_secd) bytes" >> $L
step "compiler.bin (self-contained codegen)"
mkbundle codegen.la compiler.bin || { echo "SX2B_BUILD_FAILED" >> $L; exit 1; }
step "bundler.bin (self-contained bundler)"
mkbundle bundle.la bundler.bin  || { echo "SX2B_BUILD_FAILED" >> $L; exit 1; }
step "sx2b_app (the organ vessel)"
mkbundle selfext2b.la sx2b_app  || { echo "SX2B_BUILD_FAILED" >> $L; exit 1; }
rm -f logos_source.la logos_embed.bin
echo "SX2B_BUILD_COMPLETE" >> $L
