# gate_wm_common.sh — sourced (not run) by the gate_wm_*.sh scripts.
#
# The window-manager gates all need the same toolchain: the C host, the SECD VM
# (logos_secd) and the compiled compiler stream (compiler.bin). This file builds
# it once per gate into a private temporary directory, $T, and gives the gates
# three helpers. Nothing here touches a tracked file.
#
#   wm_setup FILE...       copy the named repository files into $T
#   wm_vm PROG.la OUT      compile PROG.la on the VM, run it, stdout to OUT;
#                          sets vrc (run rc; 90 = did not compile, see $T/vce)
#   wm_host PROG.la OUT    run PROG.la on the C host, stdout to OUT; sets hrc
#
# The VM compiles a program with codegen.la running AS compiler.bin on the VM
# itself, so import("...") paths resolve inside $T: copy every module a program
# imports into $T with wm_setup.
#
# DEVELOPMENT SHORTCUT. Building the toolchain costs about 35 s. If
# LOGOS_WM_TOOLS names a directory holding tiny_host, logos_secd and
# compiler.bin built from this checkout, they are copied instead of rebuilt.
# The gates never set it themselves, so a plain run always builds from source.
#
# Timeouts: WM_VM_TIMEOUT (default 600 s) bounds each VM compile and each VM
# run; WM_HOST_TIMEOUT (default 600 s) bounds each host run.

WM_ROOT=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
: "${WM_VM_TIMEOUT:=600}"
: "${WM_HOST_TIMEOUT:=600}"

if [ -n "${LOGOS_WM_TOOLS:-}" ] && [ -x "$LOGOS_WM_TOOLS/tiny_host" ] \
   && [ -x "$LOGOS_WM_TOOLS/logos_secd" ] && [ -f "$LOGOS_WM_TOOLS/compiler.bin" ]; then
    cp "$LOGOS_WM_TOOLS/tiny_host" "$LOGOS_WM_TOOLS/logos_secd" \
       "$LOGOS_WM_TOOLS/compiler.bin" "$T/"
else
    gcc -O2 -o "$T/tiny_host" "$WM_ROOT/tiny_host.c" || { echo "FAIL  wm gates: tiny_host did not build"; exit 1; }
    cp "$WM_ROOT/secd.la" "$WM_ROOT/codegen.la" "$T/"
    ( cd "$T" && ./tiny_host secd.la >/dev/null 2>&1 && cp codegen.la logos_source.la \
        && ./tiny_host codegen.la >/dev/null 2>&1 && cp logos_program.bin compiler.bin ) \
        || { echo "FAIL  wm gates: the VM toolchain did not build"; exit 1; }
fi

wm_setup() {
    for f in "$@"; do cp "$WM_ROOT/$f" "$T/" || { echo "FAIL  wm gates: missing $f"; exit 1; }; done
}

wm_vm() {
    cp "$T/$1" "$T/logos_source.la"
    cp "$T/compiler.bin" "$T/logos_program.bin"
    vrc=0
    ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) || vrc=$?
    if [ "$vrc" != 0 ]; then vrc=90; : > "$2"; return 0; fi
    ( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >"$2" 2>"$T/vre" ) || vrc=$?
    return 0
}

wm_host() {
    hrc=0
    ( cd "$T" && timeout "$WM_HOST_TIMEOUT" ./tiny_host "$1" >"$2" 2>"$T/hre" ) || hrc=$?
    return 0
}
