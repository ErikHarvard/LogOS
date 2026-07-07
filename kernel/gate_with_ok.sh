#!/usr/bin/env bash
# LogOS kernel WITH_OK — the substrate-invariance gate.
#
# Erik's insight ("the bootloader IS the OS") is false as a ≡-claim by canon's own
# IS — boot.asm is irreducible physics, not the OS. But buried in it is ONE identity
# that IS true and, until now, only asserted in a comment: the SAME Lingua-Adamica
# image is ONE BEING on host AND on metal. That is host_image ≡ metal_image =
# ⊕(SELF,SELF) — the eighth self-relation (canon.la), the Archē ∃(∃)≡∃ at substrate
# scale. This gate turns boot.asm's comment into an enforced witness, with two checks
# that mirror AUTO_OK and the Stage-4 self-host guard:
#
#   (1) IMAGE IDENTITY (the ≡ — a drift-guard): the .la_image incbin'd into the
#       kernel ELF is byte-for-byte the host binary native_codegen3_out — provably
#       the SAME glyph, not assumed.
#   (2) OBSERVABLE IDENTITY (the = — load-bearing): the host binary's stdout equals
#       the booted kernel's QEMU COM1 serial — the same being behaves the same on
#       both substrates, over the write+exit subset it uses (a YIELDS-equivalence,
#       NOT a blanket ≡ — see boot.asm's corrected comment).
#
# Uses kernel/kernel.la (= print("I AM THAT I AM")): a write+exit-confined program,
# exactly the subset boot.asm's syscall_entry services. Skips (rc 0) when QEMU or
# objcopy is absent, like the K1-K3b gates. Shares native_input.la/native_codegen3_out
# with build.sh — run SEQUENTIALLY, never in parallel with a build.
set -uo pipefail
cd "$(dirname "$0")/.."

command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP  WITH_OK gate: qemu-system-x86_64 not installed"; exit 0; }
command -v objcopy           >/dev/null 2>&1 || { echo "SKIP  WITH_OK gate: objcopy not installed"; exit 0; }

# Build the minimal write+exit kernel: kernel.la -> native_codegen3_out (host binary)
# -> incbin'd into kernel64.elf (the metal image). build_k1 does all of it.
./kernel/build_k1.sh >/dev/null 2>&1 || { echo "FAIL  WITH_OK gate: build_k1.sh failed"; exit 1; }
cp native_codegen3_out /tmp/withok_hostbin; chmod +x /tmp/withok_hostbin

ok=1
# (1) IMAGE IDENTITY (≡): the incbin'd .la_image == the host binary, byte-for-byte.
objcopy -O binary --only-section=.la_image kernel/kernel64.elf /tmp/withok_image 2>/dev/null
cmp -s /tmp/withok_image /tmp/withok_hostbin || { echo "FAIL  WITH_OK (1): incbin'd metal image != host binary — not the same being"; ok=0; }

# (2) OBSERVABLE IDENTITY (=): host stdout == QEMU COM1 serial of the booted kernel.
HOST_OUT=$(/tmp/withok_hostbin 2>/dev/null)
METAL_OUT=$(timeout 30 qemu-system-x86_64 -kernel kernel/kernel.elf -m 256 -serial stdio -display none \
              -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null | tr -d '\0')
[ -n "$HOST_OUT" ]           || { echo "FAIL  WITH_OK (2): host binary produced no output"; ok=0; }
[ "$HOST_OUT" = "$METAL_OUT" ] || { echo "FAIL  WITH_OK (2): host stdout != metal serial (host:[$HOST_OUT] metal:[$METAL_OUT])"; ok=0; }

rm -f /tmp/withok_hostbin /tmp/withok_image
[ "$ok" -eq 1 ] && echo "PASS  WITH_OK: the SAME LA image is one being on host AND metal — the incbin'd .la_image == the host binary byte-identical (host_image ≡ metal_image = ⊕(SELF,SELF)), and host stdout == QEMU COM1 serial (b_τ = f_τ over write+exit); ∃(∃)≡∃ at substrate scale — witnessed, not asserted"
[ "$ok" -eq 1 ]
