#!/bin/sh
# gate_link_kernel.sh — THE KERNEL SEAM: is link.la a drop-in for
# `ld -n -T kernel/kernel.ld` in track D's real kernel build?
#
#     boot.o --+--> ld -n -T kernel.ld --> objcopy -> QEMU   (control)
#              +--> link.la --script     --> objcopy -> QEMU   (ours)
#
# ONE VARIABLE MOVES: the SAME object goes into both linkers, so anything this
# finds is the linker's. That is the same discipline gate_link_e2e step 4b uses,
# and it is why this gate can name its own culprit.
#
# ── WHY THIS GATE EXISTS ────────────────────────────────────────────────────
# On 07-23 link.la linked the real kernel object byte-identically to ld and that
# looked like complete success by every check we had. The build's VERY NEXT LINE
# — `objcopy -O elf32-i386` — refused the image ("has no sections"). Item 12
# fixed that. But the claim still stopped at "the container is acceptable", one
# step short of the only thing anybody actually wants to know: DOES IT BOOT.
# This gate carries the chain to that step. Reproduce the real consumer's next
# step, not your own criterion.
#
# ── COST, AND WHY THIS IS NOT IN build.sh ───────────────────────────────────
# The link takes ~36 MINUTES for a 39 KB object (32 KB of it the incbin'd
# .la_image) — the known DROP curve, not a wrong algorithm. This is an ON-DEMAND
# gate, like track A's gate_bootelf.sh. Do not wire it into build.sh.
#
# ── WHAT IT DEPENDS ON, AND WHY IT SKIPS RATHER THAN FAILS ──────────────────
# kernel/boot.o and kernel/kernel.ld are TRACK D's. This reads them and writes
# NOTHING into kernel/. If they are absent it SKIPs: B does not own that half.
# ★ HONEST LIMIT, stated because it is a real weakness: boot.o is an UNCOMMITTED
# build artifact in D's worktree, so this gate tests whatever kernel D last
# built. It records the sha256 it actually tested so a green can be traced to a
# specific object. A fully reproducible version would assemble boot.asm here,
# which needs A's compiler for the incbin payload — a much longer chain.
set -u
cd "$(dirname "$0")" || exit 1
K=.kseam
FORCE=${FORCE_RELINK:-0}
ok=1

for t in qemu-system-x86_64 ld objcopy readelf; do
    command -v $t >/dev/null 2>&1 || { echo "SKIP  link_kernel: $t absent"; exit 0; }
done

BOOTO=${LOGOS_D_BOOTO:-$HOME/logos-d/kernel/boot.o}
[ -s "$BOOTO" ] || { echo "SKIP  link_kernel: track D's boot.o absent ($BOOTO) — nothing to link"; exit 0; }
mkdir -p "$K" || exit 1
cp -p "$BOOTO" "$K/boot.o" || exit 1
git -C "$HOME/logos" show track-d:kernel/kernel.ld > "$K/kernel.ld" 2>/dev/null
[ -s "$K/kernel.ld" ] || { echo "SKIP  link_kernel: track D's kernel.ld is not on track-d"; exit 0; }
cp tiny_host link.la link_reloc.la link_script.la link_layout.la "$K/" || exit 1
echo "NOTE  link_kernel: boot.o sha256 $(sha256sum "$K/boot.o" | cut -c1-16)… ($(stat -c%s "$K/boot.o") bytes)"

# ── the control: ld, exactly as kernel/build_*.sh invokes it ────────────────
( cd "$K" && ld -n -T kernel.ld boot.o -o ctrl64.elf 2>/dev/null \
  && objcopy -O elf32-i386 ctrl64.elf ctrl32.elf 2>/dev/null ) || {
    echo "SKIP  link_kernel: ld/objcopy could not build the control from this boot.o"; exit 0; }

# ── ours: link.la. Reused only if DEMONSTRABLY fresh ────────────────────────
#   ★ A CACHED ARTIFACT IS A FALSE-GREEN WAITING TO HAPPEN, so freshness is
#   CHECKED, not assumed: link_out must be newer than the object AND than every
#   .la that produced it. Any doubt -> relink. FORCE_RELINK=1 always relinks.
#   ★ FRESHNESS IS BY CONTENT HASH, NOT mtime — my first cut used `-nt` and the
#   cache could NEVER hit: this gate copies boot.o and regenerates kernel.ld on
#   every run, so both are always newer than link_out by construction. An mtime
#   test is meaningless about inputs the checker itself rewrites. The hash of
#   every input is stored beside the artifact and compared.
inhash=$(cat "$K/boot.o" "$K/kernel.ld" link.la link_reloc.la link_script.la link_layout.la | sha256sum | cut -d" " -f1)
stale=0
[ -s "$K/link_out" ] || stale=1
[ -f "$K/link_out.inputs" ] || stale=1
[ "$stale" = 0 ] && [ "$(cat "$K/link_out.inputs" 2>/dev/null)" != "$inhash" ] && stale=1
if [ "$FORCE" = 1 ] || [ "$stale" = 1 ]; then
    echo "NOTE  link_kernel: linking with link.la — THIS TAKES ~36 MINUTES (DROP curve on a 39 KB object)"
    ( cd "$K" && printf -- '--script=kernel.ld\nboot.o\n' > link_inputs.txt \
      && timeout 7200 ./tiny_host link_reloc.la ) >"$K/link.log" 2>&1
    [ -s "$K/link_out" ] || { echo "FAIL  link_kernel: link.la produced no image: $(tail -1 "$K/link.log")"; exit 1; }
    printf '%s' "$inhash" > "$K/link_out.inputs"
else
    echo "NOTE  link_kernel: reusing link_out — the sha256 of boot.o + kernel.ld + every link*.la is unchanged since it was produced; FORCE_RELINK=1 to relink"
fi
cp "$K/link_out" "$K/ours64.elf"; chmod +x "$K/ours64.elf"

# ── 1. the container the build's next tool must accept ─────────────────────
if ( cd "$K" && objcopy -O elf32-i386 ours64.elf ours32.elf 2>objcopy.err ); then
    echo "PASS  link_kernel 1: objcopy -O elf32-i386 accepts the LA-linked image (the 07-23 blocker)"
else
    echo "FAIL  link_kernel 1: objcopy refused our image: $(cat "$K/objcopy.err")"; ok=0
fi

# ── 2. entry point ─────────────────────────────────────────────────────────
e1=$(readelf -h "$K/ctrl64.elf" | awk '/Entry point address/{print $NF}')
e2=$(readelf -h "$K/ours64.elf" | awk '/Entry point address/{print $NF}')
if [ -z "$e1" ] || [ -z "$e2" ]; then
    echo "FAIL  link_kernel 2: could not read an entry point (ld=[$e1] ours=[$e2]) — refusing to compare with a measurement that did not parse"; ok=0
elif [ "$e1" = "$e2" ]; then
    echo "PASS  link_kernel 2: entry point $e2 == ld's"
else
    echo "FAIL  link_kernel 2: entry $e2 != ld's $e1"; ok=0
fi

# ── 3. every loadable byte ─────────────────────────────────────────────────
#   ★ NOT `readelf | while read`: a piped while runs in a SUBSHELL and an ok=0
#   set inside it is LOST, printing GREEN over a failed segment. Caught in this
#   gate's own draft. Redirect from a file so the loop runs in this shell.
readelf -lW "$K/ctrl64.elf" | awk '/LOAD/{print $2, $5}' > "$K/segs.txt"
nseg=$(wc -l < "$K/segs.txt")
if [ "$nseg" -lt 1 ]; then
    echo "FAIL  link_kernel 3: ld's image has no LOAD segments — the byte comparison would be vacuous"; ok=0
fi
i=0
while read off fsz; do
    i=$((i+1))
    o2=$(readelf -lW "$K/ours64.elf" | awk -v n=$i '/LOAD/{c++} c==n{print $2; exit}')
    f2=$(readelf -lW "$K/ours64.elf" | awk -v n=$i '/LOAD/{c++} c==n{print $5; exit}')
    if [ -z "$o2" ]; then echo "FAIL  link_kernel 3: our image has no LOAD segment $i (ld has $nseg)"; ok=0; continue; fi
    dd if="$K/ctrl64.elf" bs=1 skip=$((off)) count=$((fsz)) of="$K/s${i}_ld.bin"   2>/dev/null
    dd if="$K/ours64.elf" bs=1 skip=$((o2))  count=$((f2))  of="$K/s${i}_ours.bin" 2>/dev/null
    if [ "$((fsz))" -ne "$((f2))" ]; then
        echo "FAIL  link_kernel 3: segment $i filesz $((f2)) != ld's $((fsz))"; ok=0
    elif cmp -s "$K/s${i}_ld.bin" "$K/s${i}_ours.bin"; then
        echo "PASS  link_kernel 3: segment $i — all $((fsz)) loadable bytes byte-identical to ld's"
    else
        echo "FAIL  link_kernel 3: segment $i loadable bytes differ from ld's"; ok=0
    fi
done < "$K/segs.txt"
#   ld's -n (nmagic) packs segment 2 at a file offset NOT congruent to its vaddr
#   mod page; ours is page-congruent. Both load to the same vaddr and both boot.
#   Deliberate, documented, and the reason this compares CONTENT not offsets.

# ── 4. the step every previous claim stopped short of ──────────────────────
kboot() { timeout 90 qemu-system-x86_64 -kernel "$1" -m 256 -serial stdio -display none \
          -device isa-debug-exit,iobase=0xf4,iosize=0x04 -no-reboot -no-shutdown 2>/dev/null; }
CO=$(kboot "$K/ctrl32.elf"); CRC=$?
OO=$(kboot "$K/ours32.elf"); ORC=$?
csum=$(printf '%s' "$CO" | tr -d '\0' | tr '\n' '|')
osum=$(printf '%s' "$OO" | tr -d '\0' | tr '\n' '|')
#   ★ The control must actually SAY something. A kernel that boots to silence
#   would make "same serial" true and meaningless — the check would pass on two
#   images that both did nothing.
if [ "$CRC" != 33 ] || [ -z "$csum" ]; then
    echo "SKIP  link_kernel 4: ld's own image did not boot cleanly here (rc=$CRC serial=[$csum]) — with no working control there is nothing to compare against"
elif [ "$CRC" != "$ORC" ]; then
    echo "FAIL  link_kernel 4: our image exited $ORC, ld's exited $CRC (serial=[$osum])"; ok=0
elif [ "$CO" != "$OO" ]; then
    echo "FAIL  link_kernel 4: serial differs — ours=[$osum] ld=[$csum]"; ok=0
else
    echo "PASS  link_kernel 4: ★★ THE LA-LINKED KERNEL BOOTS — serial [$osum] and clean exit $ORC, identical to ld's image"
fi

[ "$ok" = 1 ] && echo "link_kernel gate GREEN" || { echo "link_kernel gate RED"; exit 1; }
