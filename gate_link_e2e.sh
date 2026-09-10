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
a_ok=1
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

    # ── step 5: TWO comparisons, because one cannot attribute a difference ──
    #   ★ THIS BLOCK USED TO COMPARE link.la(ours.o) AGAINST ld(nasm.o) — a
    #   single cmp spanning BOTH tracks' halves, so any difference was reported
    #   as B's. It fired for real on 2026-08-18: A's asm.la (92a29ad) began
    #   encoding `mov r64, <equ expanding to a label difference>` as movabs
    #   where nasm uses the 5-byte form, and this gate went RED naming the
    #   LINKER. B's half was untouched and correct. The header three screens up
    #   promises exactly what the code then failed to do — "an unattended B
    #   session must not go red because another track's tool moved" — because
    #   the design only anticipated A's producer being ABSENT or REFUSING, not
    #   emitting a valid object with different bytes.
    #
    #   The fix is not to weaken the check into a SKIP (that would hide real
    #   relocation bugs). It is to split it so each comparison can only accuse
    #   the track that owns it, by holding one variable fixed at a time:
    #
    #     ld(ours.o)  vs ld(nasm.o)   same LINKER, different ASSEMBLER -> A's half
    #     link.la(ours.o) vs ld(ours.o)  same OBJECT, different LINKER -> B's half
    #
    #   The B comparison is also STRICTLY STRONGER than what it replaces: it
    #   feeds both linkers the identical object, so a difference is the linker's
    #   by construction rather than by argument.
    if command -v nasm >/dev/null 2>&1 && command -v ld >/dev/null 2>&1 \
       && command -v objcopy >/dev/null 2>&1; then
        # ld over OUR object — the shared reference both comparisons pivot on.
        ld -o "$G/ours_ld.elf" "$G/elfobj_out.o" 2>/dev/null \
          && objcopy -O binary --only-section=.text "$G/ours_ld.elf" "$G/ours_ld.text" 2>/dev/null
        # ld over NASM's object, from the same source.
        nasm -f elf64 "$G/e2e_src.asm" -o "$G/ref.o" 2>/dev/null \
          && ld -o "$G/ref.elf" "$G/ref.o" 2>/dev/null \
          && objcopy -O binary --only-section=.text "$G/ref.elf" "$G/ref.text" 2>/dev/null

        # ── 5a. A's half, INFORMATIONAL — never sets ok=0 ──────────────────
        if [ -s "$G/ours_ld.text" ] && [ -s "$G/ref.text" ]; then
            if cmp -s "$G/ours_ld.text" "$G/ref.text"; then
                echo "PASS  link_e2e step 4a: ld(A's object) == ld(nasm's object) — A's assembler agrees with the reference it replaced"
                a_ok=1
            else
                echo "NOTE  link_e2e step 4a: ld(A's object) != ld(nasm's object) — TRACK A's assembler diverges from nasm on this fixture."
                echo "NOTE    ours: $(xxd -p "$G/ours_ld.text" | tr -d '\n')"
                echo "NOTE    nasm: $(xxd -p "$G/ref.text" | tr -d '\n')"
                echo "NOTE    This is NOT a linker fault and does NOT fail this gate. Filed on ~/logos-status.md as a cross-track request."
                a_ok=0
            fi
        else
            echo "SKIP  link_e2e step 4a: could not build both ld references to compare the assemblers"
            a_ok=0
        fi

        # ── 5b. B's half — THE ASSERTION THIS GATE OWNS ────────────────────
        #   Same object into both linkers, so nothing about A can move it.
        if [ -s "$G/ours_ld.text" ] && [ -s "$G/link_text.bin" ]; then
            if cmp -s "$G/ours_ld.text" "$G/link_text.bin"; then
                echo "PASS  link_e2e step 4b: link.la's relocated .text == ld's, on the SAME object — the linker halves agree"
            else
                echo "FAIL  link_e2e step 4b: link.la's relocated .text differs from ld's ON THE SAME OBJECT — this one is ours"
                echo "FAIL    ld:       $(xxd -p "$G/ours_ld.text" | tr -d '\n')"
                echo "FAIL    link.la:  $(xxd -p "$G/link_text.bin" | tr -d '\n')"
                ok=0
            fi
        else
            echo "SKIP  link_e2e step 4b: no ld(ours) reference — cannot isolate the linker"
        fi

        #   Both halves agreeing is the original claim, and it is only sound to
        #   state it when 4a and 4b BOTH passed. Stated separately so it can
        #   never be inferred from a green that 4a did not earn.
        if [ "$a_ok" = 1 ] && [ "$ok" = 1 ]; then
            echo "PASS  link_e2e step 4: ★ the relocated .text is byte-identical to ld(nasm)'s — both halves agree with the reference they replaced"
        fi
    else
        echo "SKIP  link_e2e step 4: nasm/ld/objcopy absent — no reference to compare the bytes with"
    fi
fi

# ── step 6: THE CROSS-OBJECT LINK — the threshold this track was defined by ─
#   A linker is not an image writer. LINKER.md's standing rule: "do not let
#   link.la claim to be a linker until it resolves a symbol defined in one
#   object and referenced from another." Until 2026-08-18 that case could not
#   even be EXPRESSED in this chain, because `extern` is what makes a symbol
#   UNDEFINED and asm.la halted on it — so this gate carried a PROBE instead,
#   which fed `extern` to A's producer every run and reported which state the
#   world was in. A comment would have gone stale in silence; the probe flipped
#   the day A landed 484622c, and this step is what it was waiting to become.
#
#   The probe is KEPT as the guard: if A's assembler cannot do `extern`, the
#   multi-object case is not expressible and this step SKIPs (A's half absent
#   is never B's failure). If it can, the link below is B's to get right.
cat > "$G/x_a.asm" <<'ASM'
bits 64
global _start
extern greet
section .text
_start:
    call greet
    mov rax, 60
    mov rdi, 17
    syscall
ASM
cat > "$G/x_b.asm" <<'ASM'
bits 64
global greet
section .rodata
msg:    db "TWO OBJECTS, ONE IMAGE", 10
section .text
greet:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, 23
    syscall
    ret
ASM
#   ★ The length 23 is written as a LITERAL, not `$ - msg`. A's 92a29ad
#   mis-encodes `mov r64, <equ expanding to a label difference>` (filed on the
#   board), and a fixture that trips a KNOWN defect in the other track's tool
#   tests that defect instead of the thing under test.

xobj_ok=1
for n in a b; do
    ( cd "$G" && cp "x_$n.asm" asm_in.asm && rm -f elfobj_out.o \
      && timeout 600 ./tiny_host asmelfobj.la ) >"$G/x_$n.log" 2>&1
    if [ -s "$G/elfobj_out.o" ]; then cp "$G/elfobj_out.o" "$G/x_$n.o"; else
        echo "SKIP  link_e2e step 6: A's producer refused x_$n.asm ($(tail -1 "$G/x_$n.log")) — the multi-object case needs A's \`extern'"
        xobj_ok=0; break
    fi
done

if [ "$xobj_ok" = 1 ]; then
    #   The threshold, asserted on the OBJECT before any linking: object A must
    #   genuinely carry `greet` as UNDEFINED. Without this the step could pass
    #   on two self-contained objects that never needed a linker at all.
    if readelf -sW "$G/x_a.o" | awk '$7=="UND" && $8=="greet"{f=1} END{exit !f}'; then
        echo "PASS  link_e2e step 6a: x_a.o carries \`greet' as an UNDEFINED symbol — a real cross-object reference"
    else
        echo "FAIL  link_e2e step 6a: x_a.o has no UND \`greet' — the fixture does not test cross-object resolution"
        ok=0; xobj_ok=0
    fi
fi

if [ "$xobj_ok" = 1 ]; then
    ( cd "$G" && printf 'x_a.o\nx_b.o\n' > link_inputs.txt && rm -f link_out link_text.bin \
      && timeout 1200 ./tiny_host link_reloc.la ) >"$G/xlink.log" 2>&1
    if [ ! -s "$G/link_out" ]; then
        echo "FAIL  link_e2e step 6b: link.la produced no image from two objects: $(tail -1 "$G/xlink.log")"; ok=0
    else
        chmod +x "$G/link_out"
        if xout=$( "$G/link_out" ); then xrc=0; else xrc=$?; fi
        if [ "$xout" = "TWO OBJECTS, ONE IMAGE" ] && [ "$xrc" = 17 ]; then
            echo "PASS  link_e2e step 6b: ★★ TWO OBJECTS, ONE IMAGE — _start called a \`greet' defined in the OTHER object, and no nasm or ld touched this chain"
        else
            echo "FAIL  link_e2e step 6b: the cross-object image printed '$xout' rc=$xrc, wanted 'TWO OBJECTS, ONE IMAGE' rc=17"; ok=0
        fi

        #   ── 6c. the relocated bytes, against ld over THE SAME OBJECTS ────
        #   Same attribution discipline as 4b: one variable (the linker) moves.
        #   ★ HONEST SCOPE, MEASURED not assumed: link.la's .text matches ld's
        #   EXCEPT in inter-object ALIGNMENT FILL, where ld emits multi-byte
        #   NOPs (66 2e 0f 1f 84 ...) and we emit 0x90 runs. Same length, same
        #   layout, same instruction bytes. That is ld's encoding convention,
        #   not semantics, so it is asserted rather than matched: every byte we
        #   differ on must be a 0x90 WE wrote. A relocation error cannot hide
        #   there, because it would differ somewhere we did not write fill.
        if command -v ld >/dev/null 2>&1 && command -v objcopy >/dev/null 2>&1 \
           && ld -o "$G/x_ld.elf" "$G/x_a.o" "$G/x_b.o" 2>/dev/null \
           && objcopy -O binary --only-section=.text "$G/x_ld.elf" "$G/x_ld.text" 2>/dev/null \
           && [ -s "$G/x_ld.text" ] && [ -s "$G/link_text.bin" ]; then
            if [ "$(stat -c%s "$G/x_ld.text")" != "$(stat -c%s "$G/link_text.bin")" ]; then
                echo "FAIL  link_e2e step 6c: our .text is $(stat -c%s "$G/link_text.bin") B, ld's is $(stat -c%s "$G/x_ld.text") B — a LAYOUT difference, not a fill difference"; ok=0
            elif cmp -s "$G/x_ld.text" "$G/link_text.bin"; then
                echo "PASS  link_e2e step 6c: the cross-object relocated .text is byte-identical to ld's"
            else
                #   ★ "every differing byte is 0x90 on our side" is NOT enough
                #   on its own: a mis-relocation that happened to write 0x90
                #   over an instruction would satisfy it. So the FILL REGION's
                #   boundaries are derived from the reference AT GATE TIME —
                #   the gap starts at the end of x_a.o's .text and ends where
                #   ld placed `greet` — and every differing byte must be 0x90
                #   AND inside that gap.
                #   ★★ NO strtonum. mawk does not have it: this file's own
                #   history records an alignment assertion that used it, errored
                #   to stderr, emitted nothing, and let the gate print PASS —
                #   decorative for a whole run. I reintroduced it here and it
                #   was caught only by running the check. Hex is parsed with
                #   printf, and every derived number is asserted to have parsed
                #   before it is used to judge anything.
                shdr() { readelf -SW "$1" | sed 's/^ *\[[ 0-9]*\] *//' | awk -v w="$2" '$1==w{print $3" "$5; exit}'; }
                a_text=$(shdr "$G/x_a.o" .text | awk '{print $2}')
                l_base=$(shdr "$G/x_ld.elf" .text | awk '{print $1}')
                g_addr=$(nm "$G/x_ld.elf" 2>/dev/null | awk '$3=="greet"{print $1; exit}')
                gap_start=$(printf '%d' "0x${a_text:-zz}" 2>/dev/null)
                base_d=$(printf '%d' "0x${l_base:-zz}" 2>/dev/null)
                gaddr_d=$(printf '%d' "0x${g_addr:-zz}" 2>/dev/null)
                if [ -z "$gap_start" ] || [ -z "$base_d" ] || [ -z "$gaddr_d" ]; then
                    echo "FAIL  link_e2e step 6c: could not derive the fill region from ld (a_text=[$a_text] base=[$l_base] greet=[$g_addr]) — refusing to judge the bytes with a measurement that did not parse"
                    ok=0
                else
                    gap_end=$((gaddr_d - base_d))
                    ndiff=$(cmp -l "$G/x_ld.text" "$G/link_text.bin" 2>/dev/null | wc -l)
                    bad=$(cmp -l "$G/x_ld.text" "$G/link_text.bin" 2>/dev/null \
                          | awk -v s="$gap_start" -v e="$gap_end" \
                                '{off=$1-1} ($3!="220" || off<s || off>=e){n++} END{print n+0}')
                    echo "NOTE  link_e2e step 6c: ld's inter-object alignment fill is .text[$gap_start,$gap_end); $ndiff bytes differ"
                    if [ "$gap_end" -le "$gap_start" ]; then
                        echo "FAIL  link_e2e step 6c: derived an empty fill region [$gap_start,$gap_end) — the measurement is wrong, so the check below would be vacuous"
                        ok=0
                    elif [ "$bad" = 0 ]; then
                        echo "PASS  link_e2e step 6c: .text matches ld's except $ndiff bytes, every one a 0x90 we wrote INSIDE ld's fill region [$gap_start,$gap_end) — the call displacement and all instruction bytes agree"
                    else
                        echo "FAIL  link_e2e step 6c: $bad of $ndiff differing bytes are either not 0x90 or fall OUTSIDE ld's fill region — that is a relocation or layout fault"
                        ok=0
                    fi
                fi
            fi
        else
            echo "SKIP  link_e2e step 6c: no ld reference over the same objects — cannot compare the relocated bytes"
        fi
    fi
fi

[ "$ok" = 1 ] && echo "link_e2e gate GREEN" || { echo "link_e2e gate RED"; exit 1; }
