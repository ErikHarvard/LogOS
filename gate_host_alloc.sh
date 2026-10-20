#!/usr/bin/env bash
# gate_host_alloc.sh — the C host must halt loudly ("host: out of memory", rc 1) when
# an allocation fails, never dereference a NULL from malloc/strdup (SIGSEGV).
#
# WHAT IT GUARDS. tiny_host.c had four unchecked malloc sites and ten unchecked
# strdup sites; with strdup failing the host died with rc 139 while parsing
# kernel.la. Every allocation now goes through xmalloc/xstrdup.
#
# HOW. Two LD_PRELOAD shims built in a private mktemp dir: one makes strdup
# always fail, the other makes malloc fail after N successful calls (N=5 and
# N=20 land on sites that used to be unchecked). A static check also asserts
# no bare malloc(/strdup( call remains outside the two x* wrappers.
#
# ISOLATION: mktemp dir, nothing tracked touched, no fixed /tmp path. Needs: gcc.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=1

# (1) static: no unchecked allocation call outside xmalloc/xstrdup themselves
# comments are stripped first (gcc -fpreprocessed keeps code, drops comments), so a
# comment that mentions malloc() does not count; line numbers are the stripped file's.
gcc -fpreprocessed -dD -E -P "$ROOT/tiny_host.c" > "$T/nocomment.c" 2>/dev/null || cp "$ROOT/tiny_host.c" "$T/nocomment.c"
bare=$(grep -nE '(^|[^a-z_])(malloc|strdup)\(' "$T/nocomment.c" | grep -vE 'static (void|char) \*x(malloc|strdup)|= (malloc|strdup)\((n|s)\);' || true)
if [ -z "$bare" ]; then
    echo "PASS  host alloc gate: every malloc/strdup goes through xmalloc/xstrdup"
else
    echo "FAIL  host alloc gate: unchecked allocation call(s):"; while IFS= read -r l; do echo "      $l"; done <<< "$bare"; ok=0
fi

# (2) dynamic: injected allocation failures must halt loudly, not crash
gcc -O2 -o "$T/tiny_host" "$ROOT/tiny_host.c"
cp "$ROOT/kernel.la" "$T/"
cat > "$T/failstrdup.c" <<'EOF'
#include <stddef.h>
#include <errno.h>
char *strdup(const char *s) { (void)s; errno = ENOMEM; return NULL; }
EOF
cat > "$T/failmalloc.c" <<'EOF'
#define _GNU_SOURCE
#include <stddef.h>
#include <stdlib.h>
#include <errno.h>
#include <dlfcn.h>
static long n = 0;
void *malloc(size_t sz) {
    static void *(*real)(size_t) = 0;
    if (!real) real = dlsym(RTLD_NEXT, "malloc");
    const char *lim = getenv("FAIL_AFTER");
    if (lim && ++n > atol(lim)) { errno = ENOMEM; return NULL; }
    return real(sz);
}
EOF
gcc -shared -fPIC -o "$T/failstrdup.so" "$T/failstrdup.c"
gcc -shared -fPIC -o "$T/failmalloc.so" "$T/failmalloc.c" -ldl
check() {   # $1 label, then the command (run in $T)
    label=$1; shift
    rc=0; err=$( cd "$T" && "$@" 2>&1 >/dev/null ) || rc=$?
    rm -f "$T"/new_logos_gen*
    if [ "$rc" = 1 ] && [ "$err" = "host: out of memory" ]; then
        echo "PASS  host alloc gate ($label): 'host: out of memory', rc 1"
    else
        echo "FAIL  host alloc gate ($label): rc=$rc stderr='$err' (want rc 1 + 'host: out of memory'; rc 139 = NULL dereference regression)"; ok=0
    fi
}
check "strdup always fails"      env LD_PRELOAD=./failstrdup.so ./tiny_host kernel.la
check "malloc fails after 5"     env FAIL_AFTER=5  LD_PRELOAD=./failmalloc.so ./tiny_host kernel.la
check "malloc fails after 20"    env FAIL_AFTER=20 LD_PRELOAD=./failmalloc.so ./tiny_host kernel.la

[ "$ok" = 1 ] || exit 1
