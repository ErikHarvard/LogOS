#!/bin/bash
cd ~/logos
cp native_codegen3.la native_input.la
rm -f native_codegen3_out
echo "START $(date)" > stage4_seed_out.txt
/usr/bin/time -v ./tiny_host native_codegen3.la >> stage4_seed_out.txt 2>&1
rc=$?
echo "EXIT_CODE=$rc" >> stage4_seed_out.txt
echo "END $(date)" >> stage4_seed_out.txt
if [ -f native_codegen3_out ]; then echo "CC0_PRODUCED size=$(stat -c%s native_codegen3_out)" >> stage4_seed_out.txt; else echo "NO_CC0" >> stage4_seed_out.txt; fi
