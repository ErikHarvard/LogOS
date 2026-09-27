#!/usr/bin/env bash
# gate_host_asan.sh — the C host's node constructors must copy their source
# bytes BEFORE calling new_node(), and the host must run clean under
# AddressSanitizer.
#
# WHAT IT GUARDS. new_node() may run the collector. mkstrn() used to call
# new_node() first and memcpy() its `bytes` argument afterwards; mkvar/mklam/
# mkpartial did the same with strdup(). When the bytes belong to a fresh
# intermediate value that nothing else references (str_head(str_tail(...)):
# the inner result is passed as `v->s + 1` in a tail call, so no root holds
# the node), the collector frees the buffer between the two lines and the copy
# reads freed memory. ASan caught this deterministically on commit 965e734
# (heap-use-after-free, mkstrn tiny_host.c:154, running primitives_spec.la);
# the plain build survived only because glibc's tcache handed the chunk back
# untouched. Whether the hazard is EXPOSED depends on register allocation, so:
#
#   (1) a STATIC check, deterministic: in each constructor that copies caller
#       bytes, the copy (strdup/memcpy) must precede new_node(). This catches
#       reintroduction of the pattern regardless of compiler luck.
#   (2) a DYNAMIC check, a safety net: build with -fsanitize=address and a
#       collector threshold lowered to 64 nodes (so a collection lands in
#       every allocation window), run three programs, require no ASan report.
#       ASan's fake stack must be OFF: it moves locals off the real stack,
#       which blinds the conservative scanner and produces false reports.
#
# ISOLATION. Private mktemp dir, its own copy of tiny_host.c (the threshold
# edit is applied to the copy only). Needs: gcc with libasan for (2); if
# unavailable, (2) is reported SKIP and the gate's verdict rests on (1).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=1

# ── (1) static ordering check ────────────────────────────────────────────────
# For each constructor, extract its one-line/multi-line body and check that
# the first copy call comes before the first new_node call.
check_order() {   # $1 = function name, $2 = copy call (strdup|memcpy)
    # the function's text: from its definition line to its `return n;`
    body=$(sed -n "/^static Node \*$1(/,/return n;/p" "$ROOT/tiny_host.c")
    pos_copy=$(printf '%s' "$body" | grep -bo "$2(" | head -1 | cut -d: -f1)
    pos_new=$(printf '%s' "$body" | grep -bo "new_node(" | head -1 | cut -d: -f1)
    if [ -z "$pos_copy" ] || [ -z "$pos_new" ]; then
        echo "FAIL  host asan gate: could not locate $2/new_node in $1 (source shape changed — update this gate)"; ok=0
    elif [ "$pos_copy" -lt "$pos_new" ]; then
        echo "PASS  host asan gate: $1 copies ($2) before new_node()"
    else
        echo "FAIL  host asan gate: $1 calls new_node() BEFORE $2 — the collector can free the source bytes between them (heap-use-after-free, the 965e734 bug)"; ok=0
    fi
}
check_order mkstrn    memcpy
check_order mkvar     strdup
check_order mklam     strdup
check_order mkpartial strdup

# ── (2) dynamic ASan run with a stressed collector ──────────────────────────
sed 's/^#define GC_MIN_THRESHOLD 250000/#define GC_MIN_THRESHOLD 64/' "$ROOT/tiny_host.c" > "$T/tiny_host.c"
grep -q "GC_MIN_THRESHOLD 64" "$T/tiny_host.c" || { echo "FAIL  host asan gate: GC_MIN_THRESHOLD line not found (update this gate)"; ok=0; }
if gcc -O2 -g -fsanitize=address -o "$T/th_asan" "$T/tiny_host.c" 2>"$T/cc.err"; then
    cat > "$T/gcloop.la" <<'EOF'
glyph TRUE  = la t. la f. t
glyph FALSE = la t. la f. f
glyph IF    = la c. la t. la f. c(t)(f)("!")
glyph Z     = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph LOOP  = Z(la self. la n. la acc. IF(int_eq(n)(0))(la _. acc)(la _. self(sub(n)(1))(str_head(str_tail(str_tail(concat(acc)("cd")))))))
glyph MAIN  = print(LOOP(20000)("ab"))
EOF
    cp "$ROOT/kernel.la" "$ROOT/primitives_spec.la" "$ROOT/specpipe.la" "$T/" 2>/dev/null || true
    export ASAN_OPTIONS=detect_leaks=0:detect_stack_use_after_return=0
    for p in gcloop kernel primitives_spec; do
        [ -f "$T/$p.la" ] || continue
        rc=0; ( cd "$T" && timeout 900 ./th_asan "$p.la" >/dev/null 2>asan.err ) || rc=$?
        if grep -q "ERROR: AddressSanitizer" "$T/asan.err"; then
            echo "FAIL  host asan gate: $p.la — $(grep -m1 'ERROR: AddressSanitizer' "$T/asan.err" | sed 's/^==[0-9]*==//') ($(grep -m1 -o 'in mk[a-z]* [^ ]*tiny_host.c:[0-9]*' "$T/asan.err" || echo 'see stack'))"; ok=0
        elif [ "$rc" != 0 ]; then
            echo "FAIL  host asan gate: $p.la exited $rc under ASan without a sanitizer report: $(head -c 200 "$T/asan.err")"; ok=0
        else
            echo "PASS  host asan gate: $p.la runs clean under ASan with a 64-node collector threshold"
        fi
    done
else
    echo "SKIP  host asan gate: gcc cannot build with -fsanitize=address here ($(head -1 "$T/cc.err")); only the static ordering check ran"
fi

[ "$ok" = 1 ] || exit 1
