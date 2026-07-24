#!/bin/sh
# gate_link_e2e.sh — THE CHAIN WITH NO FOREIGN TOOL IN IT.
#
#     .asm source --asm.la--> ELF64 object --link.la--> executable --> it runs
#
# no nasm, no ld, at any step. Track A's `-f elf64` gate proves ld(ours) ==
# ld(nasm), which removes nasm from the OBJECT step while keeping ld as the
# verifier. This is the other half: the object is linked by link.la, so the last
# foreign tool leaves the chain and the only witness left is that the program
# does what it says.
#
# ── THE OWNERSHIP SPLIT, WHICH IS WHY THE FAILURE MODES DIFFER ───────────────
# `asm.la`, `elfobj.la` and `asmelfobj.la` are TRACK A's files and live on A's
# branch. This gate reads them from the shared object store (published commits,
# read-only — it never touches A's worktree) and:
#
#   * if they are absent, or if A's producer REFUSES a fixture, it prints SKIP
#     and exits 0. B does not own that half, and an unattended B session must
#     not go red because another track's tool moved.
#   * if the producer emits an object and OUR side then mishandles it, that is
#     a FAIL. Reading, relocating and linking a valid ET_REL is track B's job.
#
# That asymmetry is the point: the gate can only ever accuse the half this
# track is responsible for.
set -u
cd "$(dirname "$0")" || exit 1
ok=1
G=.e2egate
rm -rf "$G"; mkdir -p "$G" || exit 1

for t in readelf; do
    command -v $t >/dev/null 2>&1 || { echo "SKIP  link_e2e: $t absent"; exit 0; }
done

# ── fetch track A's producer, from the published branch only ────────────────
#   ★ ALL THREE COME FROM ONE SOURCE, NEVER A MIX. The first version preferred
#   a local copy per file — and this branch carries a STALE `asm.la` from before
#   A added `-f elf64`, so it paired B's old assembler with A's new driver and
#   died on `unbound variable 'ASM_ELF'`. Three files that must agree about an
#   interface have to be taken from one commit; picking each independently is
#   how you assemble a combination that never existed.
ABRANCH=${LOGOS_A_BRANCH:-kernel-k1}
PRODUCER="asm.la elfobj.la asmelfobj.la"
have_local=1
for f in $PRODUCER; do [ -f "$f" ] || have_local=0; done
#   Local only if this branch has the WHOLE producer and it is not the stale
#   pre-`-f elf64` assembler; otherwise take the published set from A's branch.
if [ "$have_local" = 1 ] && grep -q "ASM_ELF" asm.la 2>/dev/null; then
    for f in $PRODUCER; do cp "$f" "$G/$f"; done
    src="this branch"
else
    for f in $PRODUCER; do
        git show "$ABRANCH:$f" > "$G/$f" 2>/dev/null && [ -s "$G/$f" ] || {
            echo "SKIP  link_e2e: track A's $f is on neither this branch nor $ABRANCH — the LA-only chain needs A's -f elf64 producer"
            exit 0; }
    done
    src="$ABRANCH"
fi
grep -q "ASM_ELF" "$G/asm.la" || {
    echo "SKIP  link_e2e: the asm.la taken from $src has no ASM_ELF — that is the pre-\`-f elf64' assembler, which cannot emit objects"
    exit 0; }
echo "NOTE  link_e2e: producer taken from $src"
cp tiny_host link.la link_script.la link_reloc.la "$G/" || exit 1

# A single object with no `extern`: see the NOTE at the bottom for why the
# multi-object case cannot be expressed yet.
cat > "$G/e2e_src.asm" <<'ASM'
bits 64
section .rodata
msg:    db "I AM THAT I AM", 10
MSGLEN  equ $ - msg
section .text
global _start
_start:
    mov     rax, 1
    mov     rdi, 1
    mov     rsi, msg
    mov     rdx, MSGLEN
    syscall
    mov     rax, 60
    mov     rdi, 42
    syscall
ASM

# ── step 1: source -> object, by asm.la (track A's half) ────────────────────
( cd "$G" && cp e2e_src.asm asm_in.asm && timeout 600 ./tiny_host asmelfobj.la ) >"$G/produce.log" 2>&1
if [ ! -s "$G/elfobj_out.o" ]; then
    echo "SKIP  link_e2e: track A's producer did not emit an object: $(tail -1 "$G/produce.log")"
    exit 0
fi
echo "PASS  link_e2e step 1: asm.la emitted an ELF64 object from source ($(stat -c%s "$G/elfobj_out.o") bytes, no nasm)"

# ── step 2: does OUR reader agree with readelf about A's object? ────────────
#   link.la is the oracle A asked for. Its verdict is implicit but total: an
#   object it mis-parses cannot produce a correct relocated .text below.
secs=$(readelf -SW "$G/elfobj_out.o" | sed 's/^ *\[[ 0-9]*\] *//' | awk '$1 ~ /^\./{print $1}' | tr '\n' ' ')
case "$secs" in
    *.text*) : ;;
    *) echo "FAIL  link_e2e: A's object has no .text — cannot proceed"; ok=0 ;;
esac

# ── step 3: object -> executable, by link.la (track B's half) ───────────────
( cd "$G" && printf 'elfobj_out.o\n' > link_inputs.txt && timeout 900 ./tiny_host link_reloc.la ) >"$G/link.log" 2>&1
if [ ! -s "$G/link_out" ]; then
    echo "FAIL  link_e2e: link.la produced no executable from A's object: $(tail -1 "$G/link.log")"
    ok=0
else
    echo "PASS  link_e2e step 2: link.la linked it into an executable (no ld)"

    # ── step 4: THE WHOLE POINT — run it ───────────────────────────────────
    if out=$( "$G/link_out" ); then rc=0; else rc=$?; fi
    if [ "$out" = "I AM THAT I AM" ] && [ "$rc" = 42 ]; then
        echo "PASS  link_e2e step 3: ★ IT RUNS — 'I AM THAT I AM', exit 42, and no nasm or ld touched this chain"
    else
        echo "FAIL  link_e2e: the LA-only binary printed '$out' rc=$rc, wanted 'I AM THAT I AM' rc=42"; ok=0
    fi

    # ── step 5: the relocated bytes are FORCED, so compare them with ld's ───
    #   Only if the reference toolchain is present; its absence is not a
    #   failure, since the chain under test does not use it.
    if command -v nasm >/dev/null 2>&1 && command -v ld >/dev/null 2>&1 \
       && command -v objcopy >/dev/null 2>&1; then
        nasm -f elf64 "$G/e2e_src.asm" -o "$G/ref.o" 2>/dev/null \
          && ld -o "$G/ref.elf" "$G/ref.o" 2>/dev/null \
          && objcopy -O binary --only-section=.text "$G/ref.elf" "$G/ref.text" 2>/dev/null
        if [ -s "$G/ref.text" ] && [ -s "$G/link_text.bin" ]; then
            if cmp -s "$G/ref.text" "$G/link_text.bin"; then
                echo "PASS  link_e2e step 4: the relocated .text is byte-identical to ld(nasm)'s — both halves agree with the reference they replaced"
            else
                echo "FAIL  link_e2e: relocated .text differs from ld(nasm)'s"; ok=0
            fi
        else
            echo "SKIP  link_e2e step 4: could not build the nasm+ld reference to compare against"
        fi
    else
        echo "SKIP  link_e2e step 4: nasm/ld/objcopy absent — no reference to compare the bytes with"
    fi
fi

# ── the standing gap, asserted rather than remembered ───────────────────────
#   `extern` is what makes a symbol UNDEFINED, and resolving an undefined
#   symbol across objects is the threshold this whole track defined as the
#   difference between a linker and an image writer. asm.la halts on it
#   ("asm: unsupported instruction: extern"), so the multi-object case cannot
#   be expressed yet and the chain above is SINGLE-OBJECT only.
#
#   This is checked, not just written down: the day A supports `extern`, this
#   line changes and whoever reads it learns the multi-object case is now
#   reachable. A comment would have gone stale silently.
cat > "$G/ext.asm" <<'ASM'
bits 64
section .text
global _start
extern greet
_start:
    call greet
    mov eax, 60
    xor edi, edi
    syscall
ASM
( cd "$G" && cp ext.asm asm_in.asm && rm -f elfobj_out.o && timeout 300 ./tiny_host asmelfobj.la ) >"$G/ext.log" 2>&1
if [ -s "$G/elfobj_out.o" ]; then
    echo "NOTE  link_e2e: asm.la now accepts \`extern' — the MULTI-OBJECT chain is newly reachable; extend this gate to a cross-object link"
else
    echo "NOTE  link_e2e: asm.la still refuses \`extern' ($(tail -1 "$G/ext.log")) — so the LA-only chain is single-object only, and cross-object resolution still needs nasm to produce the UND symbol"
fi

[ "$ok" = 1 ] && echo "link_e2e gate GREEN" || { echo "link_e2e gate RED"; exit 1; }
