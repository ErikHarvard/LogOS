#!/bin/bash
# gate_audit2.sh — regression gates for the LogOS_bug_audit_2.md fixes on this
# branch. Each case FAILS on the unfixed tree and PASSES with its fix. Runs in a
# private temp dir (no fixed /tmp paths); needs gcc, and nasm only where noted.
# Not wired into build.sh (local tracks edit it) — one line to hook it in.
#   usage: ./gate_audit2.sh [case ...]     (no args = every case)
set -u
REPO=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d "${TMPDIR:-/tmp}/gate_audit2.XXXXXX")
trap 'rm -rf "$W"' EXIT
cd "$W"
gcc -O2 -o tiny_host "$REPO/tiny_host.c" || { echo "FAIL  gate: cannot build tiny_host"; exit 1; }
cp "$REPO"/*.la .
./tiny_host secd.la >/dev/null 2>&1 || { echo "FAIL  gate: cannot emit logos_secd"; exit 1; }
FAILS=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }
# vmc <prog.la> — compile a program for the SECD VM with codegen.la on the host
vmc() { cp "$1" logos_source.la && timeout 600 ./tiny_host codegen.la >/dev/null 2>&1; }

# ── #4 logosinit: a failed fork() is not a pid ────────────────────────────────
# fork is shadowed to return -EAGAIN ("-11"). Unfixed: SPAWN returns "-11" as the
# shell pid, nothing ever retries, and SIGTERM runs kill(-11, SIGTERM) — a
# process-GROUP kill. Fixed: init reports the failure, retries after BACKOFF,
# still answers SIGTERM, and signals no one.
case_logosinit_forkfail() {
    { echo 'glyph fork = la _. "-11"'; cat logosinit.la; } > t_forkfail.la
    vmc t_forkfail.la || { fail "logosinit fork-fail: codegen"; return; }
    sleep 10 | ./logos_secd > init.out 2>&1 &
    local p=$!; sleep 2.5; kill -TERM "$(pgrep -P $p -x logos_secd 2>/dev/null || echo $p)" 2>/dev/null
    local rc=0; wait $p || rc=$?
    if grep -q 'logosinit: fork failed (-11) — retrying' init.out \
       && grep -qxF 'LogOS received SIGTERM — terminating session.' init.out; then
        pass "logosinit: failed fork reported + retried, SIGTERM still honoured (no kill of a non-positive pid)"
    else
        fail "logosinit: failed fork not handled — got: $(tr '\n' '|' < init.out)"
    fi
}

# ── #39 logosinit: a failed/erroring signalfd is not a 128-byte siginfo ───────
# The VM's raw read maps every error to "", and ord("") = "0" is taken as the
# SIGCHLD arm, so a signalfd that failed (-errno) or a read that errors spins
# the supervision loop at 100% CPU forever. Two shadows: signalfd returns
# -EMFILE ("-24"); signalfd works but every read of it errors (""). Unfixed:
# still spinning after 2.5 s, only the boot line printed. Fixed: a loud halt,
# rc != 0, naming the cause.
logosinit_spin() {   # <label> <shadow glyph line> <expected stderr fragment>
    { echo "$2"; cat logosinit.la; } > t_spin.la
    vmc t_spin.la || { fail "logosinit $1: codegen"; return; }
    sleep 10 | ./logos_secd > spin.out 2>&1 &
    local p=$! t=0
    while [ $t -lt 25 ] && kill -0 $p 2>/dev/null; do sleep 0.1; t=$((t+1)); done
    if kill -0 $p 2>/dev/null; then
        kill -KILL "$(pgrep -P $p -x logos_secd 2>/dev/null || echo $p)" 2>/dev/null; wait $p 2>/dev/null
        fail "logosinit $1: still running after 2.5 s (spin) — got: $(tr '\n' '|' < spin.out)"; return
    fi
    local rc=0; wait $p || rc=$?
    if [ "$rc" != 0 ] && grep -qF "$3" spin.out; then pass "logosinit $1: halts loudly (rc $rc), no spin"
    else fail "logosinit $1: rc=$rc — got: $(tr '\n' '|' < spin.out)"; fi
}
case_logosinit_sigfd() {
    logosinit_spin "signalfd=-EMFILE" 'glyph signalfd = la m. "-24"' 'logosinit: signalfd failed (-24)'
    logosinit_spin "read(sigfd) errors" 'glyph read = la fd. la n. ""' 'logosinit: signalfd read failed'
}

# ── #73 strutil: an empty separator/pattern must not loop forever ─────────────
# STARTS_WITH("") is always TRUE and DROP("") is the identity, so SPLIT("") and
# REPLACE("") recursed on the same rest until a resource guard. Checked on both
# the implementation VALUES (the spec with its MAIN swapped) and the SOURCE the
# pipeline DEPLOYs (the generated module), each under a 60 s timeout.
# Unfixed: both time out (rc 124). Fixed: [abc] and abc, instantly.
case_strutil_empty() {
    local probe='glyph SEQ = la a. la b. b
glyph MAIN = print(concat(JOIN("|")(SPLIT("")("abc")))(concat("/")(REPLACE("")("X")("abc"))))'
    { grep -v '^glyph MAIN\|^    SEQ(print(concat("=== GENERATE\|^       (print(DEPLOY' strutil_spec.la; echo "$probe" | sed 1d; } > t_suval.la   # probe minus its SEQ: specpipe defines it
    local v rc=0; v=$(timeout 60 ./tiny_host t_suval.la 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$v" = "abc/abc" ]; then pass "strutil values: SPLIT(\"\")/REPLACE(\"\") return at once"
    else fail "strutil values: rc=$rc out=[$v] (want abc/abc)"; fi
    rm -f strutil_generated.la
    local su; su=$(timeout 300 ./tiny_host strutil_spec.la 2>/dev/null)
    if ! printf '%s\n' "$su" | grep -q "module VERIFIED" || [ ! -f strutil_generated.la ]; then
        fail "strutil: spec not VERIFIED / module not written"; return; fi
    { cat strutil_generated.la; echo "$probe"; } > t_sumod.la
    rc=0; v=$(timeout 60 ./tiny_host t_sumod.la 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$v" = "abc/abc" ]; then pass "strutil generated module: SPLIT(\"\")/REPLACE(\"\") return at once"
    else fail "strutil generated module: rc=$rc out=[$(printf '%s' "$v" | head -c 200)] (want abc/abc)"; fi
}

# ── #85 host: an import cycle halts loudly instead of SIGSEGV ─────────────────
# do_import → parse_program → do_import had no cycle check and no stack guard:
# a first-form self-import SIGSEGV'd (rc 139, no diagnostic); a glyph before it
# died 'too many glyphs'; a two-file cycle SIGSEGV'd. Fixed: 'import cycle: …',
# rc 1. Control: a diamond (A imports B and C, both import D) still runs.
case_import_cycle() {
    mkdir -p cyc && ( cd cyc
    printf 'import("selfA.la")\nglyph MAIN = print("x")\n' > selfA.la
    printf 'glyph Y = "y"\nimport("selfB.la")\nglyph MAIN = print("x")\n' > selfB.la
    printf 'import("cycB.la")\nglyph MAIN = print("x")\n' > cycA.la
    printf 'import("cycA.la")\nglyph BV = "b"\nexport BV\n' > cycB.la
    printf 'glyph DV = "d"\nexport DV\n' > D.la
    printf 'import("D.la")\nglyph BV = DV\nexport BV\n' > B.la
    printf 'import("D.la")\nglyph CV = DV\nexport CV\n' > C.la
    printf 'import("B.la")\nimport("C.la")\nglyph MAIN = print(concat(BV)(CV))\n' > A.la )
    local f want out rc
    for f in "selfA.la|import cycle: selfA.la -> selfA.la" "selfB.la|import cycle: selfB.la -> selfB.la" \
             "cycA.la|import cycle: cycA.la -> cycB.la -> cycA.la"; do
        want=${f#*|}; f=${f%%|*}; rc=0
        out=$(cd cyc && timeout 60 ../tiny_host "$f" 2>&1) || rc=$?
        if [ "$rc" = 1 ] && [ "$out" = "$want" ]; then pass "host import cycle $f: halts loudly, rc 1"
        else fail "host import cycle $f: rc=$rc out=[$(printf '%s' "$out" | head -c 200)] (want [$want], rc 1)"; fi
    done
    rc=0; out=$(cd cyc && timeout 60 ../tiny_host A.la 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = "dd" ]; then pass "host diamond import (control): still runs"
    else fail "host diamond import (control): rc=$rc out=[$out] (want dd)"; fi
}

# ── #74/#78/#79 theourgia COMPOSE clips to the destination ────────────────────
# Unclipped, ox<0 recursed forever in TAKE (resource-guard crash), a right
# overhang lengthened rows (skewed raster, rc 0), and oy<0 shifted the source
# instead of clipping it. DRAW_TEXT and the session's RENDER_SURFACE go through
# COMPOSE, so a long string or an off-screen window hit the same paths. dst is a
# 3x2 surface of pixel 1; src is 2x1 [2 3] or 1x2 [2;3]. Expected rows derived
# by hand: (-1,0) → 3 1 1 / 1 1 1 · (2,0) → 1 1 2 / 1 1 1 · column at (0,-1)
# → 3 1 1 / 1 1 1 · (5,5) and (-9,0) → unchanged. Control: the stock scene is
# byte-identical to HEAD's theourgia.la.
case_compose_clip() {
    # src surfaces are built from SOLID + an in-bounds COMPOSE, the module's own shape
    cat > t_clip.la <<'LAEOF'
import("theourgia.la")
import("theourgia_text.la")
glyph SEQ = la a. la b. b
glyph P   = la n. PX(n)(n)(n)
glyph D   = SOLID(3)(2)(P(1))
glyph SH  = COMPOSE(SOLID(2)(1)(P(2)))(SOLID(1)(1)(P(3)))(1)(0)
glyph SV  = COMPOSE(SOLID(1)(2)(P(2)))(SOLID(1)(1)(P(3)))(0)(1)
glyph MAIN = SEQ(write_file("c1.ppm")(PPM(COMPOSE(D)(SH)(sub(0)(1))(0))))(
             SEQ(write_file("c2.ppm")(PPM(COMPOSE(D)(SH)(2)(0))))(
             SEQ(write_file("c3.ppm")(PPM(COMPOSE(D)(SV)(0)(sub(0)(1)))))(
             SEQ(write_file("c4.ppm")(PPM(COMPOSE(D)(SH)(5)(5))))(
             SEQ(write_file("c5.ppm")(PPM(COMPOSE(D)(SH)(sub(0)(9))(0))))(
             SEQ(write_file("t1.ppm")(PPM(DRAW_TEXT(SOLID(24)(12)(P(0)))("HELLO")(0)(0)(P(255))(P(0)))))(
             SEQ(write_file("t2.ppm")(PPM(DRAW_TEXT(SOLID(24)(12)(P(0)))("HI")(sub(0)(3))(0)(P(255))(P(0)))))(
             print("clip-done"))))))))
LAEOF
    rm -f c?.ppm t?.ppm
    local rc=0 out; out=$(timeout 300 ./tiny_host t_clip.la 2>&1) || rc=$?
    if [ "$rc" != 0 ] || [ "$out" != "clip-done" ]; then
        fail "compose clip: program rc=$rc out=[$(printf '%s' "$out" | head -c 200)]"; return; fi
    local r; r=$(python3 - <<'PYEOF'
import os
def px(f):
    b=open(f,'rb').read(); hdr=b'P6\n3 2\n255\n'
    if not b.startswith(hdr): return 'badhdr:%r'%b[:16]
    b=b[len(hdr):]
    if len(b)!=18: return 'len%d'%len(b)
    return ' '.join(str(b[i]) for i in range(0,18,3))
want={'c1':'3 1 1 1 1 1','c2':'1 1 2 1 1 1','c3':'3 1 1 1 1 1','c4':'1 1 1 1 1 1','c5':'1 1 1 1 1 1'}
bad=[f'{k}=[{px(k+".ppm")}] want [{v}]' for k,v in want.items() if px(k+'.ppm')!=v]
for t in ('t1','t2'):
    n=os.path.getsize(t+'.ppm')
    if n!=len(b'P6\n24 12\n255\n')+24*12*3: bad.append(f'{t} is {n} bytes, want 877')
print('; '.join(bad) or 'OK')
PYEOF
)
    if [ "$r" = OK ]; then pass "theourgia COMPOSE clips on every edge; DRAW_TEXT wider than / left of the surface keeps its size"
    else fail "theourgia COMPOSE clip: $r"; fi
    # the native VM must produce the same seven rasters, byte for byte
    mkdir -p clip_host && mv c?.ppm t?.ppm clip_host/
    if ! vmc t_clip.la; then fail "compose clip (VM): codegen"
    else
        rc=0; out=$(timeout 300 ./logos_secd 2>&1) || rc=$?
        local f d=0; for f in clip_host/*.ppm; do cmp -s "$f" "${f#clip_host/}" || d=$((d+1)); done
        if [ "$rc" = 0 ] && [ "$out" = "clip-done" ] && [ "$d" = 0 ]; then pass "theourgia COMPOSE clip: native VM rasters byte-identical to the host's"
        else fail "compose clip (VM): rc=$rc out=[$(printf '%s' "$out" | head -c 120)] $d raster(s) differ"; fi
    fi
    # control: every in-bounds scene is byte-identical to HEAD's (unclipped)
    # COMPOSE — theourgia.la itself and the four modules that import it. Each
    # MAIN runs in a HEAD tree and in this tree; stdout and raster must match.
    local m o same=0 diff_list=""
    mkdir -p headtree && cp "$REPO"/*.la headtree/ && cp tiny_host headtree/
    for m in theourgia.la theourgia_fb.la theourgia_session.la theourgia_text.la theourgia_mux_session.la; do
        git -C "$REPO" show "HEAD:$m" > "headtree/$m"; done
    for m in theourgia.la:canvas.ppm theourgia_fb.la:framebuffer.bin theourgia_session.la:session.ppm \
             theourgia_text.la:text.ppm theourgia_mux_session.la:mux_session.ppm; do
        o=${m#*:}; m=${m%%:*}
        rm -f "$o" "headtree/$o"
        timeout 300 ./tiny_host "$m" > "ctl_new.out" 2>&1
        ( cd headtree && timeout 300 ./tiny_host "$m" > ctl_head.out 2>&1 )
        if [ -s "$o" ] && cmp -s "$o" "headtree/$o" && cmp -s ctl_new.out headtree/ctl_head.out; then same=$((same+1))
        else diff_list="$diff_list $m"; fi
    done
    if [ "$same" = 5 ]; then pass "theourgia (control): 5/5 in-bounds scenes byte-identical to HEAD (theourgia, fb, session, text, mux_session)"
    else fail "theourgia (control): differs from HEAD:$diff_list"; fi
}
# Each edge as its OWN program: in compose_clip the unclipped tree halts at the
# left edge (c1) before the right/top scenes run, so those two never showed a
# red of their own. Same dst/src as above; expected rows derived by hand:
# right (2,0) → 1 1 2 / 1 1 1 (the 3 falls off) · top (0,-1) → 3 1 1 / 1 1 1
# (the 2 falls off). Unclipped: right lengthens row 0, top shifts the source.
case_compose_edges() {
    local e want got rc out
    for e in "right:SH:2:0:1 1 2 1 1 1" "top:SV:0:sub(0)(1):3 1 1 1 1 1"; do
        IFS=: read -r name src ox oy want <<< "$e"
        cat > "t_edge_$name.la" <<LAEOF
import("theourgia.la")
glyph P   = la n. PX(n)(n)(n)
glyph D   = SOLID(3)(2)(P(1))
glyph SH  = COMPOSE(SOLID(2)(1)(P(2)))(SOLID(1)(1)(P(3)))(1)(0)
glyph SV  = COMPOSE(SOLID(1)(2)(P(2)))(SOLID(1)(1)(P(3)))(0)(1)
glyph MAIN = write_file("e_$name.ppm")(PPM(COMPOSE(D)($src)($ox)($oy)))
LAEOF
        rm -f "e_$name.ppm"; rc=0; out=$(timeout 300 ./tiny_host "t_edge_$name.la" 2>&1) || rc=$?
        got=$(python3 -c '
import sys
b=open(sys.argv[1],"rb").read(); h=b"P6\n3 2\n255\n"
if not b.startswith(h): print("badhdr:%r"%b[:16])
elif len(b)-len(h)!=18: print("len%d:%s"%(len(b)-len(h)," ".join(str(x) for x in b[len(h)::3])))
else: print(" ".join(str(x) for x in b[len(h)::3]))' "e_$name.ppm" 2>&1 | tail -1)
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then pass "theourgia COMPOSE clips the $name edge alone: [$got]"
        else fail "theourgia COMPOSE $name edge: rc=$rc got [$got] want [$want] out=[$(printf '%s' "$out" | head -c 120)]"; fi
    done
}

# ── #76 theourgia TO_FB: a surface wider than the pitch halts loudly ──────────
# FB_ROW pads with ZEROS(pitch - w*4); REPEAT stopped only at 0, so w*4 > pitch
# recursed forever (C-stack guard / heap exhausted, an unrelated diagnostic).
# Fixed: a loud TO_FB error naming both widths. Control: a 2x3 surface into a
# 2-row, 12-byte-pitch screen is 24 bytes (the tall surface clipped to 2 rows).
case_tofb_pitch() {
    sed '/^glyph MAIN =/,$d' theourgia_fb.la > t_fbw.la; cp t_fbw.la t_fbc.la
    echo 'glyph MAIN = print(str_len(TO_FB(SOLID(4)(2)(PX(1)(2)(3)))(2)(8)))' >> t_fbw.la
    echo 'glyph MAIN = print(str_len(TO_FB(SOLID(2)(3)(PX(1)(2)(3)))(2)(12)))' >> t_fbc.la
    local out rc=0; out=$(timeout 120 ./tiny_host t_fbw.la 2>&1) || rc=$?
    if [ "$rc" = 1 ] && grep -qF 'TO_FB: surface is 4 px wide = 16 bytes, more than the pitch of 8 bytes' <<< "$out"; then
        pass "theourgia TO_FB: surface wider than the pitch halts loudly, rc 1"
    else fail "theourgia TO_FB wide: rc=$rc out=[$(printf '%s' "$out" | head -c 200)]"; fi
    rc=0; out=$(timeout 120 ./tiny_host t_fbc.la 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = 24 ]; then pass "theourgia TO_FB (control): fitting surface, tall rows clipped — 24 bytes"
    else fail "theourgia TO_FB control: rc=$rc out=[$out] (want 24)"; fi
}

# ── #66 phonym: an unknown primitive halts loudly; an empty range is empty PCM ─
# PHON_PRIM fell back to a silent PAIR(0)(…) for any unknown name; RENDER then
# ran BUILD on (0,0), whose only base case is a length-1 range, so it recursed
# forever (C-stack guard / secd stack overflow — an unrelated diagnostic).
# Fixed: 'phonym: unknown primitive BOGUS', rc 1; BUILD/PCM of an empty range
# is "" (unfixed: recursed forever too — a second red path). Control inside the
# same run: BEING renders 6080 samples x 2 bytes (ENC16) = 12160 bytes.
# Host only — a VM compile of a phonym importer is ~6 min.
case_phonym_unknown() {
    printf 'import("phonym.la")\nglyph MAIN = print(str_len(RENDER(PHONYM(PRIM("BOGUS")))))\n' > t_pbog.la
    printf 'import("phonym.la")\nglyph MAIN = print(concat(str_len(RENDER(PHONYM(PRIM("BEING")))))(concat("/")(str_len(PCM(la i. 0)(0)))))\n' > t_pctl.la
    local out rc=0; out=$(timeout 120 ./tiny_host t_pbog.la 2>&1) || rc=$?
    if [ "$rc" = 1 ] && grep -qF 'phonym: unknown primitive BOGUS' <<< "$out"; then pass "phonym: unknown primitive halts loudly, rc 1"
    else fail "phonym unknown primitive: rc=$rc out=[$(printf '%s' "$out" | head -c 200)]"; fi
    rc=0; out=$(timeout 300 ./tiny_host t_pctl.la 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = "12160/0" ]; then pass "phonym: empty-range PCM = 0 bytes (was unbounded recursion); BEING still 12160 bytes (control)"
    else fail "phonym control: rc=$rc out=[$(printf '%s' "$out" | head -c 200)] (want 12160/0)"; fi
}

# ── #42 metadebug: PROD/SUM/VEC judge a wrong-shaped value instead of crashing ─
# PROD/SUM/VEC destructured the checked value (FST(p), v(l)(r), IS_NIL(xs))
# before asking what it is, so an int or string was applied as a function and
# TYPECHECK halted 'attempt to apply a non-function' instead of "type error".
# Fixed: a typeof guard on the value (and on each list cell for VEC) first.
# Each probe is its own program, so one crash cannot hide the next. Control:
# the well-typed values still check, and metadebug.la's own run is unchanged
# (ALL_SPECCED: T with the new negative spec cases). Host only: typeof (#83).
md_probe() {   # md_probe <MAIN expr> -> MDOUT MDRC
    sed '/^glyph MAIN =/,$d' metadebug.la > t_md.la; echo "glyph MAIN = $1" >> t_md.la
    MDRC=0; MDOUT=$(timeout 60 ./tiny_host t_md.la 2>&1) || MDRC=$?
}
case_typesys_shape() {
    local e want bad=0
    for e in 'PROD(IS_INT)(IS_STR))(42)' 'PROD(IS_INT)(IS_STR))("s")' 'SUM(IS_INT)(IS_STR))(42)' \
             'SUM(IS_INT)(IS_STR))("s")' 'VEC(2)(IS_INT))("x")' 'VEC(2)(IS_INT))(42)' 'VEC(2)(IS_INT))(CONS(1)(5))' \
             'PROD(IS_INT)(IS_STR))(PAIR(42)("hi"))' 'SUM(IS_INT)(IS_STR))(RIGHT("hi"))' 'VEC(3)(IS_INT))(V3)'; do
        case "$e" in *'"hi"))'|*'(V3)') want=well-typed;; *) want="type error";; esac
        md_probe "print(TYPECHECK($e)"
        if [ "$MDRC" = 0 ] && [ "$MDOUT" = "$want" ]; then :
        else fail "metadebug TYPECHECK($e: rc=$MDRC got [$MDOUT] want [$want]"; bad=$((bad+1)); fi
    done
    [ "$bad" = 0 ] && pass "metadebug PROD/SUM/VEC: 7 wrong-shaped values judged 'type error', 3 well-typed controls unchanged"
    local out rc=0; out=$(timeout 300 ./tiny_host metadebug.la 2>&1) || rc=$?
    local l miss=""; for l in 'ALL_SPECCED: T' 'T2_prod: T' 'T2_sum: T' 'T3_vec_ok: T' 'T3_vec_bad: F' 'T3_pi: T' 'T4_bad: type error' 'T5_int: T' 'T5_self: T'; do
        grep -qxF "$l" <<< "$out" || miss="$miss [$l]"; done
    if [ "$rc" = 0 ] && [ -z "$miss" ]; then
        pass "metadebug (control): own run rc 0, ALL_SPECCED: T, T2/T3/T4/T5 lines unchanged"
    else fail "metadebug own run: rc=$rc missing:$miss"; fi
}

# ── #43 metadebug: IS_TYPE decides "is A(w) a Church bool" without crashing ───
# IS_TYPE fed A(IS_INT) to BOOL_STR, i.e. applied it to two thunks and IF's "!"
# forcing token. A non-bool crashed there (la x. TRUE → str_eq on a closure;
# "T" → applied as a function) or was judged a type because "!" filled a third
# argument slot (la t. la f. la x. "T" → T). IS_TYPE(ID) = F only because "!"
# happens to be a string. Fixed: IS_BOOL asks typeof at each step of b("T")("F")
# and wants the string "T" or "F". Controls: IS_INT, IS_TYPE are types; ID is
# not; la A. A("s") is a type on its one witness (the documented one-sample
# design, unchanged). metadebug.la's own run unchanged. Host only: typeof (#83).
case_typesys_istype() {
    local e want bad=0
    for e in 'la A. la x. TRUE:F' 'la A. "T":F' 'la A. la t. la f. la x. "T":F' \
             'IS_INT:T' 'IS_TYPE:T' 'ID:F' 'la A. A("s"):T'; do
        want=${e##*:}; e=${e%:*}
        md_probe "print(BOOL_STR(IS_TYPE($e)))"
        if [ "$MDRC" = 0 ] && [ "$MDOUT" = "$want" ]; then :
        else fail "metadebug IS_TYPE($e): rc=$MDRC got [$MDOUT] want [$want]"; bad=$((bad+1)); fi
    done
    [ "$bad" = 0 ] && pass "metadebug IS_TYPE: 3 non-bool results judged F without crashing; 4 controls unchanged"
    local l miss="" out rc=0; out=$(timeout 300 ./tiny_host metadebug.la 2>&1) || rc=$?
    for l in 'ALL_SPECCED: T' 'T4_self: well-typed' 'T5_int: T' 'T5_self: T'; do grep -qxF "$l" <<< "$out" || miss="$miss [$l]"; done
    if [ "$rc" = 0 ] && [ -z "$miss" ]; then pass "metadebug (control): own run rc 0, ALL_SPECCED: T, T5 lines unchanged"
    else fail "metadebug own run: rc=$rc missing:$miss"; fi
}

# ── #17 VM: a write/send to a dead peer returns -EPIPE instead of killing the VM ──
# Unfixed: SIGPIPE's default action kills the VM (rc 141) before the builtin can
# return -32, so no program can recognise a dead peer. Fixed: -32, execution
# continues. Covers send (socket, MSG_NOSIGNAL) and write (pipe, SIG_IGN).
case_sigpipe() {
    cat > t_sigpipe.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph P = "gate_sigpipe.sock"
glyph MAIN =
  (la srv. SEQ(unlink(P))(SEQ(bind(srv)(P))(SEQ(listen(srv))(
  (la cli. SEQ(connect(cli)(P))(
  (la conn. SEQ(close(conn))(
    SEQ(print(concat("send=")(send(cli)("hello"))))(
    (la p. (la rfd. (la wfd. SEQ(close(rfd))(SEQ(print(concat("write=")(write(wfd)("x"))))(print("survived"))))(str_tail(str_tail(p))))(str_head(p)))(pipe("!"))))
  )(accept(srv)))
  )(socket("!"))))))(socket("!"))
LAEOF
    vmc t_sigpipe.la || { fail "sigpipe: codegen"; return; }
    local out rc=0; out=$(timeout 20 ./logos_secd 2>&1) || rc=$?
    if [ "$rc" = 0 ] && [ "$out" = "$(printf 'send=-32\nwrite=-32\nsurvived')" ]; then
        pass "VM: send/write to a dead peer return -32 (EPIPE) and the program continues"
    else
        fail "VM: dead-peer send/write — rc=$rc out=[$(echo "$out" | tr '\n' '|')] (want -32/-32/survived, rc 0)"
    fi
}

# ── #21 live loops: every "forever" loop's self-call is a TAIL call ──────────
# The VM's TCO fires only when APPLY is followed by RET. `SEQ(work)(self(...))`
# puts self(...) in ARGUMENT position (its APPLY is followed by SEQ's APPLY), so
# each iteration leaked a dump frame + its env; the loop halted `secd: heap
# exhausted` after ~800k iterations. The binder form `(la _. self(...))(work)`
# (logosinit's shape) runs forever. Checked on the SOURCE of each loop glyph
# (tailpos.py: a self-call is tail only through applied-lambda bodies and IF
# thunks), plus a VM control: the binder form reaches 1.2M iterations.
case_tail_loops() {
    local bad=0 fg
    for fg in theourgia_poll_live.la:MULTIPLEX theourgia_poll.la:MULTIPLEX \
              theourgia_mux_session.la:LIVE theourgia_mux_session_live.la:LIVE \
              theourgia_text_session_live.la:LIVE theourgia_text_live.la:HOLD \
              sigil_live.la:HOLD sigil_seal_live.la:CYCLE; do
        python3 "$REPO/tailpos.py" "${fg%%:*}" "${fg##*:}" >tp.out 2>&1 || { fail "tail loops: $(tr '\n' ' ' < tp.out)"; bad=1; }
    done
    cat > t_bind.la <<'LAEOF'
glyph Z   = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF  = la c. la t. la f. c(t)(f)("!")
glyph LOOP = Z(la self. la n. IF(int_eq(n)(1200000))(la _. print("reached"))(la _. (la _. self(add(n)(1)))(n)))
glyph MAIN = LOOP(0)
LAEOF
    vmc t_bind.la && [ "$(timeout 120 ./logos_secd 2>&1)" = reached ] || { fail "tail loops: binder-form control loop did not reach 1.2M on the VM"; bad=1; }
    [ $bad = 0 ] && pass "live loops: all eight forever-loops recurse in tail (binder) position; binder control reaches 1.2M iterations"
}

# ── #20 live input: a hung-up device halts loudly instead of busy-spinning ───
# poll reports a closed peer ready (POLLHUP) on every call and read() returns
# ""; decoded, "" is a zero event, so MULTIPLEX spun at 100% CPU forever. The
# pipe here carries one real 24-byte KEY_A event, then its writer closes.
case_pollhup() {
    sed '/^glyph MAIN =/,$d' theourgia_poll.la > t_hup.la
    cat >> t_hup.la <<'LAEOF'
glyph EV24 = concat("0123456789abcdef")(concat(chr("1"))(concat(chr("0"))(concat(chr("30"))(concat(chr("0"))(concat(chr("1"))(concat(chr("0"))(concat(chr("0"))(chr("0")))))))))
glyph MAIN = (la p. (la rfd. (la wfd. SEQ(write(wfd)(EV24))(SEQ(close(wfd))(MULTIPLEX(CONS(rfd)(NIL)))))(str_tail(str_tail(p))))(str_head(p)))(pipe("!"))
LAEOF
    vmc t_hup.la || { fail "pollhup: codegen"; return; }
    local out rc=0; out=$(timeout 20 ./logos_secd 2>&1) || rc=$?
    if [ "$rc" = 1 ] && [ "$(sed -n 1p <<< "$out")" = "fd 3: type=1 code=30 value=1" ] \
       && grep -q 'hung up or failed (read gave 0 bytes' <<< "$out" && [ "$(wc -l <<< "$out")" = 2 ]; then
        pass "live input: the real event decodes, then the hung-up fd halts loudly (no busy-spin)"
    else
        fail "live input POLLHUP: rc=$rc, $(wc -l <<< "$out") lines, first: $(head -2 <<< "$out" | tr '\n' '|')"
    fi
}

# ── native_codegen3 cases (#9 #11 #12): compile with the host, run natively ──
# The emitted binaries carry native_codegen3.la's HEAP_SIZE in p_memsz; on a box
# that cannot map it the exec itself fails (rc 139) — reported as SKIP, not PASS.
nc3() {   # nc3 <prog.la> -> sets NOUT NERR NRC (compile+run natively)
    cp "$1" native_input.la; rm -f native_codegen3_out
    timeout 900 ./tiny_host native_codegen3.la >/dev/null 2>nc3.err || { NRC=COMPILE; NERR=$(tail -c 200 nc3.err); return; }
    NOUT=$(timeout 30 ./native_codegen3_out 2>nc3.run); NRC=$?; NERR=$(cat nc3.run)
}
case_nc3_shadow() {      # #9: a user glyph shadows a builtin of the same name
    printf 'glyph concat = la a. la b. "SHADOW"\nglyph MAIN = print(concat("a")("b"))\n' > t_shadow.la
    nc3 t_shadow.la
    if [ "$NRC" = 0 ] && [ "$NOUT" = SHADOW ]; then pass "native_codegen3: a glyph named like a builtin shadows it (native SHADOW == host)"
    elif [ "$NRC" = 139 ] && [ -z "$NOUT" ]; then echo "SKIP  nc3_shadow: native binary cannot exec here (p_memsz > RAM+swap)"
    else fail "native_codegen3 shadow: native rc=$NRC out=[$NOUT] (host prints SHADOW)"; fi
}
case_nc3_error_int() {   # #11: error(<INT>) prints the decimal and exits 1, like the host
    printf 'glyph MAIN = error(5)\n' > t_err5.la; nc3 t_err5.la
    if [ "$NRC" = 1 ] && [ "$NERR" = 5 ]; then pass "native_codegen3: error(5) prints 5 to stderr, rc 1 (was SIGSEGV)"
    else fail "native_codegen3 error(5): rc=$NRC stderr=[$NERR] (want '5', rc 1)"; fi
}
case_nc3_readdir() {     # #12: read_file on a directory halts loudly instead of SIGSEGV
    printf 'glyph MAIN = print(str_len(read_file("/tmp")))\n' > t_rdir.la; nc3 t_rdir.la
    if [ "$NRC" = 1 ] && [ "$NERR" = "native: read_file: is a directory" ]; then pass "native_codegen3: read_file(dir) halts loudly, rc 1 (was SIGSEGV)"
    else fail "native_codegen3 read_file(dir): rc=$NRC stderr=[$NERR]"; fi
}

CASES="${*:-logosinit_forkfail logosinit_sigfd sigpipe tail_loops pollhup nc3_shadow nc3_error_int nc3_readdir strutil_empty import_cycle compose_clip compose_edges tofb_pitch phonym_unknown typesys_shape typesys_istype}"
for c in $CASES; do "case_$c"; done
[ "$FAILS" -eq 0 ] && { echo "gate_audit2: all passed"; exit 0; } || { echo "gate_audit2: $FAILS failed"; exit 1; }
