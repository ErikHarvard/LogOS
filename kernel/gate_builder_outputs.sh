#!/usr/bin/env bash
# kernel/gate_builder_outputs.sh — ONE OUTPUT PATH, SEVERAL WRITERS, NOT ALL
# PROVABLY IDENTICAL: FAIL.
#
# ⚠ WHAT IT DOES NOT CATCH, first: the e5cefe7 class — ONE SOURCE FILENAME, TWO
# PROGRAMS, and the merge kept one. That is what actually produced da04585's
# misread (below). It is a different class and needs its own check; this is not it.
#
# ★ WHY (2026-09-10). A gate is only as good as its claim on its subject, and a
# path two builders write is claimed by whichever ran last. HAL.4f came within one
# rename of that: merge e5cefe7 (2026-09-05) put kernel-k1's comp_term.la over
# HAL.4f's typewriter OF THE SAME NAME, and build_hal4f.sh and build_comp_term.sh
# both wrote kernel/kernel_comp_term.elf. 90ef810 restored the typewriter as
# comp_term_hal4f.la AND gave it its own ELF. Had it restored the source without the
# rename, two DIFFERENT programs would have shared one ELF, and any run that did not
# rebuild immediately before booting — or built beside another — would have tested
# whichever ran last.
#   ⚠ What this does NOT explain, stated because the first draft of this header
#   claimed it did: the misread da04585 published ("a real HAL.4f regression") came
#   from the SOURCE collision, not the ELF one. At c7e3c53 both builders compiled the
#   same kernel/comp_term.la with the same -D HAL4, and gate_hal4f rebuilt first, so
#   the shared ELF held one program either way. ONE SOURCE FILENAME, TWO PROGRAMS is
#   a different class, and nothing here detects it.
#
# WHAT IT CHECKS. Every kernel/build_*.sh, comment-stripped, for the image paths it
# WRITES: `-o P` (ld, nasm), objcopy's last argument, `dd of=P`, `cp X P` — P a
# LITERAL path under kernel/ ending .elf/.bin/.img, quoted or not. A path written by
# more than one builder FAILS, unless every writer's recipe for it is SELF-CONTAINED
# and IDENTICAL: then the bytes are the same whichever ran last, and the path is
# printed as a NOTE, never passed in silence. Self-contained means only these forms:
#     dd if=/dev/zero of=P [k=v ...]
#     printf '%s' "$V" | dd of=P [k=v ...]     V assigned exactly once, to a '...' literal
# ld / objcopy / cp are NEVER self-contained: each reads a file (kernel/boot.o, a
# compiled image) whose provenance the line does not show. The c7e3c53 pair is
# exactly that — text-identical ld/objcopy recipes over boot.o — so identical TEXT
# is not identical BYTES there; the selftest pins that it FAILS.
# NOT flagged, by design: kernel/boot.o and kernel/entry.inc, intermediates every
# builder rewrites in sequence (excluded by extension; the selftest pins boot.o).
#
# ★ ANTI-VACUITY. A builder whose writes this cannot see FAILS unless it is on
# NO_VISIBLE_WRITE with a reason; an empty builder set FAILS; zero writes FAILS; and
# every run prints what it read — builders, writes, distinct paths, shared ones.
# ★ RED PATH, BUILT IN. selftest runs the SAME judge() the tree gets, on planted
# builders. Must FAIL: two writing one ELF; a dd from a file sharing a .img with a
# dd from /dev/zero; the c7e3c53 text-identical ld/objcopy pair; a SIG changed in
# one writer; a non-literal SIG in both; a SIG reassigned in both; a blind builder;
# the empty set; builders that are all on NO_VISIBLE_WRITE (zero writes — the one
# case only the zero-writes floor refuses). Must PASS: identical self-contained disk
# writers (with a NOTE carrying writer count + recipe hash); a READ, a comment and
# the shared boot.o beside distinct writes.
#
# WHAT IT MISSES — measured 2026-09-10, track-d at 90ef810 (predicates: board post):
#   - a VARIABLE or CONSTRUCTED target (`-o "$OUT"`, `cp x "$2"`). 1 site today,
#     build_dinit1.sh:43, held on NO_VISIBLE_WRITE. A builder with one visible and
#     one variable write is not blind, so the variable one is missed silently.
#   - any target outside a literal kernel/ path: 6 builders write /tmp/<name>_rt.bin
#     (6 distinct names today), and every builder writes native_input.la and, via
#     kernel/ncc3.sh, native_codegen3_out — shared intermediates, rewritten in
#     sequence by design, and invisible here.
#   - write forms it does not parse: `>` redirection, mv, install, tee, --output,
#     -oPATH, objcopy/cp not first on the line (after &&, if, timeout). 0 today.
#   - the comment strip is textual, so a `#` inside a string on a WRITE line cuts
#     the line before its target. 13 non-comment lines in 3 builders are cut today;
#     none is a write.
# WHAT IT COULD FALSELY MATCH:
#   - a write in dead code, or in a builder nothing runs, counts as real.
#     build_faultprobe.sh and build_faultprobe2.sh are called by nothing in
#     kernel/*.sh or build.sh, and are two of hal3disk.img's six writers.
#   - an echo/printf whose TEXT carries `-o kernel/X.elf` or `of=kernel/X.img` as
#     separate tokens. 0 today.
#   - writes under disjoint conditions (a flag, a mode) count as if both always ran.
set -uo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob

# builders that write no image this can see — each with its reason
NO_VISIBLE_WRITE="build_kernel_half.sh build_dinit1.sh"
#   build_kernel_half.sh — the kernel-only runner; it builds nothing itself.
#   build_dinit1.sh      — writes its probes by `cp native_codegen3_out "$2"`, a
#                          variable target; they are Linux-hosted .bin probes, not
#                          images a QEMU gate boots.

strip() { sed -e 's/[[:space:]]*#.*$//' "$1"; }

writelines() {  # writelines <builder> -> "PATH<TAB>normalised line", one per image write seen
    strip "$1" | awk '
        function img(p) { gsub(/"/, "", p); return (p ~ /^kernel\/[A-Za-z0-9_.-]+\.(elf|bin|img)$/) ? p : "" }
        function out(p) { if (p != "") { l = $0; gsub(/[[:space:]]+/, " ", l); sub(/^ /, "", l); sub(/ $/, "", l); print p "\t" l } }
        {
            for (i = 1; i <= NF; i++) {
                if ($i == "-o" && i < NF) out(img($(i+1)))
                if ($i ~ /^of=/) { p = $i; sub(/^of=/, "", p); out(img(p)) }
            }
            if (($1 == "objcopy" || $1 == "cp") && NF >= 3) out(img($NF))
        }'
}

writes() { writelines "$1" | cut -f1 | sort -u; }   # the image paths a builder writes

recipe() {  # recipe <builder> <path> -> its recipe for <path>, normalised and sorted;
            # a write line that is not self-contained comes back prefixed "!"
    { writelines "$1" | awk -F'\t' -v P="$2" '$1 == P { print $2 }'; echo "--ASSIGN--"; strip "$1"; } \
    | awk -v q="'" '
        /^--ASSIGN--$/ { ph = 2; next }
        ph != 2 { w[++nw] = $0; next }
        { l = $0; gsub(/[[:space:]]+/, " ", l); sub(/^ /, "", l); sub(/ $/, "", l); a[++na] = l }
        END {
            dz = "^dd if=/dev/zero of=[^ ]+( [a-z]+=[A-Za-z0-9]+)*$"
            pf = "^printf " q "%s" q " \"[$][A-Za-z_][A-Za-z0-9_]*\" [|] dd of=[^ ]+( [a-z]+=[A-Za-z0-9]+)*$"
            for (i = 1; i <= nw; i++) {
                L = w[i]
                if (L ~ dz) { print L; continue }
                if (L ~ pf) {
                    match(L, /"[$][A-Za-z_][A-Za-z0-9_]*"/); v = substr(L, RSTART + 2, RLENGTH - 3)
                    c = 0; d = ""
                    for (j = 1; j <= na; j++) if (a[j] ~ ("(^|[ ;])" v "[+]?=")) { c++; d = a[j] }
                    if (c == 1 && d ~ ("^" v "=" q "[^" q "]*" q "$")) { print L; print d; continue }
                }
                print "!" L
            }
        }' | sort -u
}

judge() {  # judge <builder>... -> the verdict on exactly these builders; rc 0 = clean
    local b base p w ws r first rf names h ok=1 blind="" n=0 shared=0 same=0 bad=0
    local -A W=()
    local -a wr
    if [ "$#" -eq 0 ]; then
        echo "FAIL  builder-outputs: the scan read ZERO builders, so it can vouch for nothing — an empty scan must not pass."
        return 1
    fi
    for b in "$@"; do
        base=$(basename "$b"); ws=$(writes "$b")
        if [ -z "$ws" ]; then
            case " $NO_VISIBLE_WRITE " in *" $base "*) ;; *) blind="$blind $base" ;; esac
            continue
        fi
        while IFS= read -r p; do W[$p]="${W[$p]:-} $b"; n=$((n + 1)); done <<< "$ws"
    done
    if [ -n "$blind" ]; then
        echo "FAIL  builder-outputs: this scanner sees NO image write in:$blind"
        echo "      so it cannot vouch that they write distinct images. Teach writes() their idiom, or add"
        echo "      them to NO_VISIBLE_WRITE with a reason — silence must not read as 'no duplicates'."
        ok=0
    fi
    for p in $(printf '%s\n' "${!W[@]}" | sort); do
        read -ra wr <<< "${W[$p]}"
        [ "${#wr[@]}" -gt 1 ] || continue
        shared=$((shared + 1)); rf=0
        first=$(recipe "${wr[0]}" "$p")
        for w in "${wr[@]}"; do
            r=$(recipe "$w" "$p")
            if grep -q '^!' <<< "$r" || [ "$r" != "$first" ]; then rf=1; fi
        done
        names=$(for w in "${wr[@]}"; do basename "$w"; done | sort | tr '\n' ' ')
        if [ "$rf" -eq 0 ]; then
            same=$((same + 1))
            h=$(printf '%s\n' "$first" | sha256sum); h=${h:0:12}
            echo "NOTE  builder-outputs: $p <- ${#wr[@]} builders, ONE self-contained recipe (sha256 $h, $(wc -l <<< "$first")-line recipe — the same bytes whichever runs last): $names"
        else
            bad=$((bad + 1)); ok=0
            echo "FAIL  builder-outputs: $p is written by ${#wr[@]} builders whose bytes could differ, so a run"
            echo "      that boots it without rebuilding first tests whichever ran last: $names"
        fi
    done
    [ "$n" -gt 0 ] || { echo "FAIL  builder-outputs: $# builders read and ZERO image writes seen — an empty scan must not pass."; ok=0; }
    echo "      scanned: $# builders, $n image writes, ${#W[@]} distinct paths; written by >1 builder: $shared ($same one self-contained recipe, $bad could differ)"
    [ "$ok" -eq 1 ]
}

selftest() {
    local T ok=1 out rc; T=$(mktemp -d)
    local DZ="dd if=/dev/zero of=kernel/k_w.img bs=1M count=1 status=none"
    local PF="printf '%s' \"\$SIG\" | dd of=kernel/k_w.img bs=1 seek=512 conv=notrunc status=none"
    printf '%s\n' 'ld -n -T kernel/kernel.ld kernel/boot.o -o kernel/kernel_x_64.elf' 'objcopy -O elf32-i386 kernel/kernel_x_64.elf kernel/kernel_x.elf' > "$T/build_a.sh"
    cp "$T/build_a.sh" "$T/build_b.sh"                                  # c7e3c53's shape: text-identical ld/objcopy
    printf '%s\n' 'objcopy -O elf32-i386 kernel/kernel_y_64.elf "kernel/kernel_y.elf"' > "$T/build_c.sh"
    printf '%s\n' 'qemu-system-x86_64 -kernel kernel/kernel_x.elf' '# -o kernel/kernel_x.elf' 'nasm -f elf64 kernel/boot.asm -o kernel/boot.o' 'ld -o kernel/kernel_d.elf kernel/boot.o' > "$T/build_d.sh"
    printf '%s\n' 'dd if=/dev/zero of=kernel/k_z.img bs=1M count=1' > "$T/build_e.sh"
    printf '%s\n' 'cp native_codegen3_out kernel/native_z.bin' 'dd if=kernel/b.bin of=kernel/k_z.img conv=notrunc' > "$T/build_f.sh"
    printf '%s\n' "SIG='LOGOS-T'" "$DZ" "$PF" > "$T/build_g.sh"; cp "$T/build_g.sh" "$T/build_h.sh"
    printf '%s\n' "SIG='LOGOS-OTHER'" "$DZ" "$PF" > "$T/build_i.sh"
    printf '%s\n' 'SIG="$(date +%s%N)"' "$DZ" "$PF" > "$T/build_j.sh"; cp "$T/build_j.sh" "$T/build_k.sh"
    printf '%s\n' "SIG='LOGOS-T'" "SIG+='x'" "$DZ" "$PF" > "$T/build_l.sh"; cp "$T/build_l.sh" "$T/build_l2.sh"
    printf '%s\n' 'cp native_codegen3_out "$2"' > "$T/build_m.sh"
    must_fail() { local why="$1"; shift; judge "$@" >/dev/null && { echo "FAIL  builder-outputs selftest: NOT refused — $why"; ok=0; }; }
    must_fail "two builders writing kernel/kernel_x.elf with text-identical ld/objcopy recipes (c7e3c53's shape)" "$T/build_a.sh" "$T/build_b.sh"
    must_fail "a dd from a FILE sharing kernel/k_z.img with a dd from /dev/zero" "$T/build_e.sh" "$T/build_f.sh"
    must_fail "a SIG changed in one of two disk writers" "$T/build_g.sh" "$T/build_i.sh"
    must_fail "a non-literal SIG, text-identical in both writers" "$T/build_j.sh" "$T/build_k.sh"
    must_fail "a SIG reassigned (+=), text-identical in both writers" "$T/build_l.sh" "$T/build_l2.sh"
    must_fail "a builder whose write this cannot see" "$T/build_a.sh" "$T/build_m.sh"
    must_fail "the EMPTY builder set"
    mkdir -p "$T/nv"; printf '%s\n' 'echo "a runner: it builds nothing itself"' > "$T/nv/build_kernel_half.sh"
    must_fail "builders that are ALL on NO_VISIBLE_WRITE, so ZERO image writes were seen" "$T/nv/build_kernel_half.sh"
    out=$(judge "$T/build_g.sh" "$T/build_h.sh"); rc=$?
    [ "$rc" -eq 0 ] || { echo "FAIL  builder-outputs selftest: identical self-contained disk writers were refused"; ok=0; }
    grep -qE '^NOTE .*kernel/k_w\.img <- 2 builders, ONE self-contained recipe \(sha256 [0-9a-f]{12}, 3-line recipe' <<< "$out" || { echo "FAIL  builder-outputs selftest: a shared-identical path passed WITHOUT its NOTE (writer count + recipe hash) — an exemption must show it looked"; ok=0; }
    judge "$T/build_a.sh" "$T/build_c.sh" "$T/build_d.sh" >/dev/null || { echo "FAIL  builder-outputs selftest: a READ, a comment or the shared boot.o was counted as a duplicate write"; ok=0; }
    [ "$(writes "$T/build_c.sh")" = "kernel/kernel_y.elf" ] || { echo "FAIL  builder-outputs selftest: a quoted objcopy target was not seen"; ok=0; }
    [ "$(writes "$T/build_f.sh" | tr '\n' ' ')" = "kernel/k_z.img kernel/native_z.bin " ] || { echo "FAIL  builder-outputs selftest: a cp or dd write was not seen"; ok=0; }
    rm -rf "$T"
    [ "$ok" -eq 1 ]
}

selftest || { echo "FAIL  builder-outputs: the scanner failed its own selftest, so its verdict on the tree would mean nothing."; exit 1; }
for x in $NO_VISIBLE_WRITE; do [ -f "kernel/$x" ] || echo "NOTE  builder-outputs: $x is on NO_VISIBLE_WRITE but no longer exists — drop it."; done
B=(kernel/build_*.sh)
judge "${B[@]}"; rc=$?
[ "$rc" -eq 0 ] && echo "PASS  builder-outputs: no image path is written by two builders whose bytes could differ (selftest: the c7e3c53 ld/objcopy pair, a changed, non-literal or reassigned SIG, a blind builder and an empty scan all refused; identical self-contained disk writers pass, and are printed)."
exit "$rc"
