#!/bin/sh
# The SEAM: does link.la still consume what asm.la now emits?
#
# ★ WHY THIS GATE EXISTS. The nine asm.la fixes changed the assembler's OUTPUT.
#   Defect 7 in particular made it emit R_X86_64_PC32 against SECTION symbols
#   with NEGATIVE addends -- a form it had never produced before. link.la is
#   what consumes those. Nothing checked that the two halves of the LA-only
#   toolchain still agree across the change; each was verified alone.
#
# ★★ AND THE OBVIOUS GATE IS THE WRONG ONE. Byte-comparing link.la's image
#   against ld's FAILS at .boot32 byte 11 -- because ld places .bss at
#   0x402034 and link.la at 0x402000, so every RIP-relative displacement
#   LEGITIMATELY differs. Two correct linkers, two valid layouts, different
#   bytes. Reporting that as a defect would accuse link.la of a bug it does not
#   have, from a check that looks rigorous precisely because it is strict.
#   The gate must be SEMANTIC: does P_next + disp equal the symbol's address?
set -u
cd "$(dirname "$0")" || exit 1
G=.seamgate; rm -rf "$G"; mkdir -p "$G"
# ★ THE PRODUCER HALF IS TRACK A'S. asmelfobj.la and elfobj.la are not in this
#   worktree, so a gate that only looked for them locally would SKIP FOREVER
#   here -- permanently vacuous, and a skip reads like a pass at a glance.
#   They are staged READ-ONLY from git instead: reading a committed blob is not
#   reaching into another track's files.
for f in tiny_host link.la link_script.la link_reloc.la link_layout.la; do
  [ -f "$f" ] && cp "$f" "$G/" 2>/dev/null
done
for f in asmelfobj.la elfobj.la; do
  git show "kernel-k1:$f" > "$G/$f" 2>/dev/null || { echo "FAIL  seam: cannot stage $f from kernel-k1"; exit 1; }
done
# ★ AND IT MUST SAY WHICH ASSEMBLER IT TESTED. The whole point is the PATCHED
#   one; silently falling back to the committed one would test the opposite of
#   what this gate claims.
if [ -n "${SEAM_ASM:-}" ] && [ -f "$SEAM_ASM" ]; then cp "$SEAM_ASM" "$G/asm.la"; WHICH="$SEAM_ASM"
elif [ -f .imm64/asm.la ]; then cp .imm64/asm.la "$G/asm.la"; WHICH=".imm64/asm.la (patched)"
else git show kernel-k1:asm.la > "$G/asm.la" 2>/dev/null; WHICH="kernel-k1:asm.la (COMMITTED — pre-fix unless A has landed)"; fi
echo "NOTE  seam: assembler under test = $WHICH"
cp seam_fixture.asm "$G/asm_in.asm"
cd "$G" || exit 1
./tiny_host asmelfobj.la >asm.log 2>&1
[ -s elfobj_out.o ] || { echo "FAIL  seam: asm.la produced no object: $(tail -1 asm.log)"; exit 1; }
ld elfobj_out.o -o ref.elf 2>ld.err || { echo "SKIP  seam: ld refused the object — no control"; exit 0; }
printf 'elfobj_out.o\n' > link_inputs.txt
timeout 900 ./tiny_host link_reloc.la >link.log 2>&1
[ -s link_out ] || { echo "FAIL  seam: link.la produced no image: $(tail -1 link.log)"; exit 1; }
python3 - <<'PY'
import subprocess, re, sys
def syms(p):
    d={}
    for ln in subprocess.check_output(['readelf','-sW',p]).decode().splitlines():
        f=ln.split()
        if len(f)>=8 and re.fullmatch(r'[0-9a-f]{16}',f[1]): d[f[7]]=int(f[1],16)
    return d
def secaddr(p,n):
    for ln in subprocess.check_output(['readelf','-SW',p]).decode().splitlines():
        if f' {n} ' in ln:
            return int(ln[ln.index(']')+1:].split()[2],16)
ok=True
for img in ('ref.elf','link_out'):
    S=syms(img); base=secaddr(img,'.boot32')
    if base is None: print(f"FAIL  seam: no .boot32 in {img}"); ok=False; continue
    t=subprocess.check_output(['objcopy','-O','binary','--only-section=.boot32',img,'/dev/stdout'])
    for off,ilen,name in ((3,7,'msg'),(10,14,'flag')):
        disp=int.from_bytes(t[off:off+4],'little',signed=True)
        got=base+ilen+disp; want=S.get(name)
        if want is None: print(f"FAIL  seam: symbol {name} absent from {img}"); ok=False
        elif got!=want:  print(f"FAIL  seam: {img} [rel {name}] resolves {got:#x}, symbol at {want:#x}"); ok=False
e=[subprocess.check_output(['readelf','-hW',p]).decode() for p in ('ref.elf','link_out')]
g=[re.search(r'Entry point address:\s+(\S+)',x).group(1) for x in e]
if g[0]!=g[1]: print(f"FAIL  seam: entry {g[1]} != ld's {g[0]}"); ok=False
print("PASS  seam: link.la resolves every RIP-relative reference asm.la emits to the "
      "correct symbol address, and agrees with ld on the entry point — verified "
      "SEMANTICALLY, since the two linkers choose different layouts and so "
      "legitimately differ byte-for-byte" if ok else "")
sys.exit(0 if ok else 1)
PY
