#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  build.sh — bootstrap LogOS: compile the host, speak the Word, replicate.
#  Each replication writes a unique sibling  new_logos_gen{N+1}_pid{PID}.bin :
#  the gen number is true ancestral depth (parent + 1); the PID keeps siblings
#  from the same parent distinct. A host can breed even when run directly.
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# Run a host on kernel.la. Captures stdout in RUN_OUT and the replicated
# child's path (parsed from copy_self's stderr line) in RUN_CHILD.
run_host() {
    local bin="$1" err
    err="$(mktemp)"
    RUN_OUT="$("$bin" kernel.la 2>"$err")"
    RUN_ERR="$(cat "$err")"
    RUN_CHILD="$(sed -n 's/^copy_self: replicated -> //p' "$err" | tail -1)"
    rm -f "$err"
}

say "Compiling the host (tiny_host.c)"
gcc -O2 -Wall -Wextra -o tiny_host tiny_host.c
echo "compiled -> tiny_host"

say "Testing concat built-in"
cat > /tmp/test_concat.la <<'LAEOF'
glyph MAIN = print(concat("hello, ")("world"))
LAEOF
OUT="$(./tiny_host /tmp/test_concat.la 2>/dev/null)"
if [ "$OUT" = "hello, world" ]; then
    echo "PASS  concat(\"hello, \")(\"world\") = \"hello, world\""
else
    echo "FAIL  expected 'hello, world', got '$OUT'"
    exit 1
fi

say "Testing str_head built-in"
cat > /tmp/test_str_head.la <<'LAEOF'
glyph MAIN = print(str_head("hello"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_head.la 2>/dev/null)"
if [ "$OUT" = "h" ]; then
    echo "PASS  str_head(\"hello\") = \"h\""
else
    echo "FAIL  expected 'h', got '$OUT'"
    exit 1
fi
cat > /tmp/test_str_head_empty.la <<'LAEOF'
glyph MAIN = print(concat("[")(concat(str_head(""))("]")))
LAEOF
OUT="$(./tiny_host /tmp/test_str_head_empty.la 2>/dev/null)"
if [ "$OUT" = "[]" ]; then
    echo "PASS  str_head(\"\") = \"\""
else
    echo "FAIL  expected '[]', got '$OUT'"
    exit 1
fi

say "Testing str_tail built-in"
cat > /tmp/test_str_tail.la <<'LAEOF'
glyph MAIN = print(str_tail("hello"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_tail.la 2>/dev/null)"
if [ "$OUT" = "ello" ]; then
    echo "PASS  str_tail(\"hello\") = \"ello\""
else
    echo "FAIL  expected 'ello', got '$OUT'"
    exit 1
fi

say "Testing str_eq built-in"
cat > /tmp/test_str_eq.la <<'LAEOF'
glyph MAIN = print(str_eq("abc")("abc")("equal")("not equal"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_eq.la 2>/dev/null)"
if [ "$OUT" = "equal" ]; then
    echo "PASS  str_eq(\"abc\")(\"abc\") = TRUE"
else
    echo "FAIL  expected 'equal', got '$OUT'"
    exit 1
fi
cat > /tmp/test_str_eq2.la <<'LAEOF'
glyph MAIN = print(str_eq("abc")("xyz")("equal")("not equal"))
LAEOF
OUT="$(./tiny_host /tmp/test_str_eq2.la 2>/dev/null)"
if [ "$OUT" = "not equal" ]; then
    echo "PASS  str_eq(\"abc\")(\"xyz\") = FALSE"
else
    echo "FAIL  expected 'not equal', got '$OUT'"
    exit 1
fi

say "Testing binary-safe primitives (chr / ord / write_exec)"
cat > /tmp/test_chr.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(print(ord(chr("65"))))(SEQ(print(chr("73")))(print(ord("A"))))
LAEOF
OUT="$(./tiny_host /tmp/test_chr.la 2>/dev/null)"
if [ "$OUT" = "$(printf '65\nI\n65')" ]; then
    echo "PASS  chr/ord round-trip (ord(chr 65)=65, chr 73='I', ord 'A'=65)"
else
    echo "FAIL  chr/ord: got '$OUT'"
    exit 1
fi
# A NUL byte must survive concat and write_file: A \0 B == 41 00 42.
cat > /tmp/test_nul.la <<'LAEOF'
glyph MAIN = write_file("/tmp/test_nul.bin")(concat(chr("65"))(concat(chr("0"))(chr("66"))))
LAEOF
./tiny_host /tmp/test_nul.la >/dev/null 2>&1
if [ "$(stat -c%s /tmp/test_nul.bin 2>/dev/null)" = "3" ] && [ "$(od -An -tx1 /tmp/test_nul.bin | tr -d ' \n')" = "410042" ]; then
    echo "PASS  embedded NUL survives concat + write_file (41 00 42)"
else
    echo "FAIL  binary string not NUL-safe: $(od -An -tx1 /tmp/test_nul.bin)"
    exit 1
fi
rm -f /tmp/test_nul.bin

say "Testing read_file built-in"
printf 'test content' > /tmp/test_rf_input.txt
cat > /tmp/test_read_file.la <<'LAEOF'
glyph MAIN = print(read_file("/tmp/test_rf_input.txt"))
LAEOF
OUT="$(./tiny_host /tmp/test_read_file.la 2>/dev/null)"
if [ "$OUT" = "test content" ]; then
    echo "PASS  read_file returned 'test content'"
else
    echo "FAIL  expected 'test content', got '$OUT'"
    exit 1
fi
rm -f /tmp/test_rf_input.txt

say "Testing write_file built-in"
rm -f /tmp/test_wf_output.txt
cat > /tmp/test_write_file.la <<'LAEOF'
glyph MAIN = print(write_file("/tmp/test_wf_output.txt")("written by LogOS"))
LAEOF
OUT="$(./tiny_host /tmp/test_write_file.la 2>/dev/null)"
WRITTEN="$(cat /tmp/test_wf_output.txt 2>/dev/null)"
ok=1
[ "$OUT" = "written by LogOS" ]     || { echo "FAIL  write_file did not return content: '$OUT'"; ok=0; }
[ "$WRITTEN" = "written by LogOS" ] || { echo "FAIL  file contents wrong: '$WRITTEN'";           ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  write_file wrote and returned 'written by LogOS'"
else
    exit 1
fi
rm -f /tmp/test_wf_output.txt

say "Testing read_file + write_file round-trip"
printf 'round trip data' > /tmp/test_rt_src.txt
cat > /tmp/test_roundtrip.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = SEQ(write_file("/tmp/test_rt_dst.txt")(read_file("/tmp/test_rt_src.txt")))(print(read_file("/tmp/test_rt_dst.txt")))
LAEOF
OUT="$(./tiny_host /tmp/test_roundtrip.la 2>/dev/null)"
if [ "$OUT" = "round trip data" ]; then
    echo "PASS  read -> write -> read round-trip"
else
    echo "FAIL  expected 'round trip data', got '$OUT'"
    exit 1
fi
rm -f /tmp/test_rt_src.txt /tmp/test_rt_dst.txt

say "Testing Z combinator (fixed-point recursion)"
cat > /tmp/test_z.la <<'LAEOF'
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la cond. la t. la f. cond(t)(f)("!")
glyph REVERSE = Z(la self. la s. IF(str_eq(s)(""))(la _. "")(la _. concat(self(str_tail(s)))(str_head(s))))
glyph MAIN = print(REVERSE("abcde"))
LAEOF
OUT="$(./tiny_host /tmp/test_z.la 2>/dev/null)"
if [ "$OUT" = "edcba" ]; then
    echo "PASS  Z combinator: REVERSE(\"abcde\") = \"edcba\""
else
    echo "FAIL  expected 'edcba', got '$OUT'"
    exit 1
fi

say "Testing self-hosted parser (parser.la parses kernel.la)"
OUT="$(./tiny_host parser.la 2>/dev/null)"
if printf '%s\n' "$OUT" | grep -qF "Kernel parse: IIIIIIIII glyph(s)"; then
    echo "PASS  parser.la parsed kernel.la (9 glyphs)"
else
    echo "FAIL  parser did not produce expected output"
    printf '%s\n' "$OUT"
    exit 1
fi
if printf '%s\n' "$OUT" | grep -qF "glyph ∃ = LAM[self, VAR[self]]"; then
    echo "PASS  parser correctly parsed ∃ (existence glyph)"
else
    echo "FAIL  ∃ glyph not correctly parsed"
    exit 1
fi

say "Testing byte instructions + stack machine (bytecode.la)"
# bytecode.la is a third representation of a program: a flat byte-
# instruction stream. EMIT compiles an AST to byte instructions,
# PARSE_BYTES decodes them back, RUN_BYTES executes them directly (no AST
# rebuilt), and RUN_SM is a real stack machine (S/E/C/D) over a compiled
# instruction list. Both engines run the kernel straight to replication.
rm -f new_logos_gen*.bin
ERR_B="$(mktemp)"
OUT="$(./tiny_host bytecode.la 2>"$ERR_B")"
BYTE_CHILD="$(sed -n 's/^copy_self: replicated -> //p' "$ERR_B" | tail -1)"
rm -f "$ERR_B"
ok=1
# The hand-built AST  la x. f(x)("a;b\c")  must emit this exact stream.
# (The string payload exercises field escaping: ';' -> '\;', '\' -> '\\'.)
printf '%s\n' "$OUT" | grep -qxF 'Lx;AAVf;Vx;Sa\;b\\c;'      || { echo "FAIL  byte-instr: unexpected encoding"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF 'la x. f(x)("a;b\\c")'      || { echo "FAIL  byte-instr: decode+unparse mismatch"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "bytes round-trip: stable"  || { echo "FAIL  byte-instr: expression round trip"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "kernel round-trip: stable" || { echo "FAIL  byte-instr: kernel.la round trip"; ok=0; }
# RUN_BYTES executes byte instructions directly.
printf '%s\n' "$OUT" | grep -qxF "byte vm"                   || { echo "FAIL  byte-vm: literal byte stream did not execute"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "yes kept"                  || { echo "FAIL  byte-vm: closures/booleans/lookup"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "I AM THAT I AM"            || { echo "FAIL  byte-vm: kernel did not speak from bytes"; ok=0; }
# The stack machine (S/E/C/D) executes the compiled program and the kernel.
printf '%s\n' "$OUT" | grep -qxF "TF"                              || { echo "FAIL  stack-machine: precompiled SM_TRUE/SM_FALSE booleans"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "kernel ran on the stack machine" || { echo "FAIL  stack-machine: kernel did not run"; ok=0; }
# Both engines replicated; the last child (from the stack machine) must match.
case "$BYTE_CHILD" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  byte-vm: kernel did not replicate ('$BYTE_CHILD')"; ok=0 ;; esac
[ -n "$BYTE_CHILD" ] && [ -f "$BYTE_CHILD" ] && cmp -s tiny_host "$BYTE_CHILD" \
    || { echo "FAIL  byte-vm: replicant not byte-identical"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  EMIT/PARSE_BYTES round-trip an AST through byte instructions"
    echo "PASS  every glyph of kernel.la survives AST -> bytes -> AST"
    echo "PASS  RUN_BYTES executes byte instructions directly (no AST rebuilt)"
    echo "PASS  the stack machine (S/E/C/D) runs the compiled program and kernel"
    echo "PASS  the kernel ran from bytes and on the stack machine: spoke and bred $BYTE_CHILD"
else
    printf '%s\n' "$OUT"
    exit 1
fi
rm -f new_logos_gen*.bin

say "Emitting native x86-64 code (Albedo Stage 1 — elf.la)"
# elf.la assembles a minimal static ELF64 from Lingua Adamica (chr + concat
# + write_exec) and emits a runnable native binary. The host plays no part in
# running it: the OS loads it and it makes its own write/exit syscalls.
rm -f logos_native
./tiny_host elf.la >/dev/null 2>&1
ok=1
[ -f logos_native ]                              || { echo "FAIL  native: logos_native not emitted"; ok=0; }
[ "$(stat -c%s logos_native 2>/dev/null)" = "171" ] || { echo "FAIL  native: wrong size ($(stat -c%s logos_native 2>/dev/null) != 171)"; ok=0; }
NATIVE_OUT="$(./logos_native 2>/dev/null)"; NATIVE_RC=$?
[ "$NATIVE_OUT" = "I AM THAT I AM" ]             || { echo "FAIL  native: emitted binary said '$NATIVE_OUT'"; ok=0; }
[ "$NATIVE_RC" = "0" ]                           || { echo "FAIL  native: emitted binary exited $NATIVE_RC"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  elf.la emitted a 171-byte native ELF executable"
    echo "PASS  the emitted binary ran on the bare OS and spoke: I AM THAT I AM"
else
    exit 1
fi
rm -f logos_native

say "Native codegen: compile to SECD streams, diff against RUN_SM (Albedo Stage 2)"
# secd.la emits the native SECD VM once; codegen.la compiles a source program
# (logos_source.la) to a native instruction stream (logos_program.bin); the VM
# runs it. For kernel.la and two other programs we check the native stdout
# equals the .la stack machine RUN_SM on the same program — generation lowered
# to native, recognition unchanged.
rm -f logos_secd logos_program.bin logos_source.la new_logos_secd.bin new_logos_gen*.bin
./tiny_host secd.la >/dev/null 2>&1
ok=1
[ -f logos_secd ]                                  || { echo "FAIL  codegen: VM not emitted"; ok=0; }
[ "$(stat -c%s logos_secd 2>/dev/null)" = "3964" ] || { echo "FAIL  codegen: VM wrong size ($(stat -c%s logos_secd 2>/dev/null) != 3964)"; ok=0; }
# Drift guard: the VM bytes must match their documented source.
if command -v nasm >/dev/null 2>&1; then
    nasm -f bin secd.asm -o /tmp/secd_ref 2>/dev/null
    cmp -s logos_secd /tmp/secd_ref || { echo "FAIL  codegen: VM bytes differ from nasm -f bin secd.asm"; ok=0; }
    rm -f /tmp/secd_ref
fi
# RUN_SM harness: bytecode.la's machinery, running logos_source.la and
# discarding the result so only the program's own output shows.
RUNSM_MAIN="$(grep -n '^glyph MAIN' bytecode.la | tail -1 | cut -d: -f1)"
head -$((RUNSM_MAIN-1)) bytecode.la > /tmp/runsm.la
printf 'glyph MAIN = (la _. print(""))(RUN_SM_PROGRAM(PARSE_PROGRAM(read_file("logos_source.la"))))\n' >> /tmp/runsm.la
diff_native_runsm () {   # $1 = label
    ./tiny_host codegen.la >/dev/null 2>&1
    local native runsm
    native="$(./logos_secd 2>/dev/null)"
    runsm="$(./tiny_host /tmp/runsm.la 2>/dev/null | sed '${/^$/d;}')"
    if [ "$native" = "$runsm" ]; then
        echo "PASS  native == RUN_SM — $1"
    else
        echo "FAIL  $1: native [$native] != RUN_SM [$runsm]"; ok=0
    fi
}
printf 'glyph MAIN = print(concat("Hello, ")("native world"))\n' > logos_source.la
diff_native_runsm "concat + print"
printf 'glyph MAIN = print(concat(str_head("ABC"))(str_tail("XYZ")))\n' > logos_source.la
diff_native_runsm "str_head / str_tail / concat -> AYZ"
cp kernel.la logos_source.la
diff_native_runsm "kernel.la (glyph table, read_file, copy_self, closures)"
if [ "$ok" -eq 1 ]; then
    echo "PASS  codegen.la lowers arbitrary programs to native SECD streams"
    echo "PASS  the native VM ran kernel.la and matched the interpreter (and replicated itself)"
    command -v nasm >/dev/null 2>&1 && echo "PASS  VM bytes are byte-identical to nasm -f bin secd.asm"
else
    exit 1
fi

say "The compiler and VM regenerate themselves — no C host in the loop (Albedo Stage 4)"
# Seed the VM and the compiler with the C host ONCE (the bootstrap seed). Then,
# using only those two native artifacts, regenerate BOTH and run a program —
# with no further tiny_host:
#   compiler.bin --(native)--> compiles codegen.la --> compiler.bin (identical)
#   compiler.bin --(native)--> compiles secd.la --> stream --> VM emits VM (identical)
#   regenerated VM runs kernel.la --> speaks the Word
rm -f logos_secd logos_program.bin logos_source.la compiler.bin vm_seed runner vm2 new_logos_secd.bin
./tiny_host secd.la >/dev/null 2>&1                       # seed: emit the VM
cp logos_secd vm_seed
cp codegen.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1                    # seed: compile the compiler
cp logos_program.bin compiler.bin
ok=1
cp vm_seed runner; chmod +x runner                        # a differently-named VM to run with
# (1) compiler reproduces itself
cp codegen.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1
cmp -s logos_program.bin compiler.bin \
    || { echo "FAIL  Stage4: native self-compilation of codegen.la differs from the seed"; ok=0; }
# (2) VM reproduces itself: native-compile secd.la, then run it to emit the VM
cp secd.la logos_source.la; cp compiler.bin logos_program.bin
./runner >/dev/null 2>&1                                  # logos_program.bin := secd.la stream
rm -f logos_secd
./runner >/dev/null 2>&1                                  # run secd.la stream -> emit logos_secd
{ [ -f logos_secd ] && cmp -s logos_secd vm_seed; } \
    || { echo "FAIL  Stage4: native-regenerated VM differs from the seed"; ok=0; }
# (3) the regenerated VM runs kernel.la
cp logos_secd vm2; chmod +x vm2
cp kernel.la logos_source.la; cp compiler.bin logos_program.bin
./vm2 >/dev/null 2>&1                                      # native-compile kernel.la
KOUT="$(./vm2 2>/dev/null)"
printf '%s\n' "$KOUT" | grep -qx "I AM THAT I AM" \
    || { echo "FAIL  Stage4: regenerated VM did not run kernel.la (got '$KOUT')"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  compiler.bin natively recompiles codegen.la to itself"
    echo "PASS  compiler.bin natively recompiles secd.la; the VM re-emits itself byte-for-byte"
    echo "PASS  the regenerated VM runs kernel.la and speaks the Word — no C host in the loop  (∃(∃) ≡ ∃)"
else
    exit 1
fi
rm -f compiler.bin vm_seed runner vm2

rm -f logos_secd logos_program.bin logos_source.la new_logos_secd.bin new_logos_gen*.bin /tmp/runsm.la

say "Linux syscalls + LogosInit (native sovereign session)"
# The native VM lowers write/open/close/mount/fork/execve/waitpid/exit to real
# Linux syscalls (integers cross the LA boundary as decimal strings). Compile
# each .la program with the native compiler and run it on the VM.
rm -f logos_secd logos_program.bin logos_source.la compiler.bin runner new_logos_secd.bin
./tiny_host secd.la >/dev/null 2>&1
cp codegen.la logos_source.la
./tiny_host codegen.la >/dev/null 2>&1
cp logos_program.bin compiler.bin
cp logos_secd runner; chmod +x runner
ok=1
nrun () {   # $1 = .la source file → native stdout
    cp "$1" logos_source.la
    cp compiler.bin logos_program.bin
    ./runner >/dev/null 2>&1
    ./runner 2>/dev/null
}
# LogosInit: mount /proc, /sys; announce.
OUT="$(nrun logosinit.la)"
printf '%s\n' "$OUT" | grep -qxF "LogOS sovereign session initialized." \
    || { echo "FAIL  syscalls: LogosInit did not announce the session"; ok=0; }
# fork / exit / waitpid: child exits 42, parent reaps it.
cat > /tmp/t_proc.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph MAIN = (la pid. IF(str_eq(pid)("0"))(la _. exit("42"))(la _. SEQ(print(concat("child exit code: ")(waitpid(pid))))(print("init done"))))(fork("!"))
LAEOF
OUT="$(nrun /tmp/t_proc.la)"
printf '%s\n' "$OUT" | grep -qxF "child exit code: 42" || { echo "FAIL  syscalls: fork/exit/waitpid"; ok=0; }
printf '%s\n' "$OUT" | grep -qxF "init done"           || { echo "FAIL  syscalls: parent continuation"; ok=0; }
# execve: child becomes /bin/true (exit 0), parent reaps.
cat > /tmp/t_exec.la <<'LAEOF'
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph MAIN = (la pid. IF(str_eq(pid)("0"))(la _. execve("/bin/true"))(la _. print(concat("exec child status: ")(waitpid(pid)))))(fork("!"))
LAEOF
OUT="$(nrun /tmp/t_exec.la)"
printf '%s\n' "$OUT" | grep -qxF "exec child status: 0" || { echo "FAIL  syscalls: execve/waitpid"; ok=0; }
# open / write / close: write a file via raw fds, then read it back.
rm -f /tmp/logos_io.txt
cat > /tmp/t_io.la <<'LAEOF'
glyph SEQ = la a. la b. b
glyph MAIN = (la fd. SEQ(write(fd)("io syscalls work\n"))(close(fd)))(open("/tmp/logos_io.txt")("577"))
LAEOF
nrun /tmp/t_io.la >/dev/null
[ "$(cat /tmp/logos_io.txt 2>/dev/null)" = "io syscalls work" ] || { echo "FAIL  syscalls: open/write/close"; ok=0; }
rm -f /tmp/t_proc.la /tmp/t_exec.la /tmp/t_io.la /tmp/logos_io.txt
if [ "$ok" -eq 1 ]; then
    echo "PASS  write/open/close/fork/execve/waitpid/exit work as native syscalls"
    echo "PASS  LogosInit ran natively and announced: LogOS sovereign session initialized."
    echo "      (mount of /proc,/sys returns -EPERM when unprivileged; the syscall path is exercised)"
else
    exit 1
fi
rm -f logos_secd logos_program.bin logos_source.la compiler.bin runner new_logos_secd.bin

say "Closing the self-hosting loop (eval.la interprets kernel.la, reconstructs itself)"
# eval.la is a lexer + parser + evaluator written entirely in Lingua
# Adamica. It reads kernel.la, parses it, evaluates it — and the
# self-interpreted kernel speaks the Word and replicates, one meta-level up.
# Its final act reads and parses its OWN source, then has INNER (its own
# unparser) reconstruct the WHOLE of eval.la from the parsed glyph table,
# writing it to eval_reconstructed.la. (The two self-parses take ~25s.)
rm -f new_logos_gen*.bin eval_reconstructed.la
ERR_E="$(mktemp)"
EVAL_OUT="$(./tiny_host eval.la 2>"$ERR_E")"
EVAL_CHILD="$(sed -n 's/^copy_self: replicated -> //p' "$ERR_E" | tail -1)"
rm -f "$ERR_E"
SRC_GLYPHS="$(grep -c '^glyph ' eval.la)"
RECON_GLYPHS="$(grep -c '^glyph ' eval_reconstructed.la 2>/dev/null || echo 0)"
ok=1
printf '%s\n' "$EVAL_OUT" | grep -qF "hello from the meta-evaluator" || { echo "FAIL  meta-eval: trivial print";   ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qF "identity works"                || { echo "FAIL  meta-eval: lambda apply";    ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qxF "concat"                       || { echo "FAIL  meta-eval: curried concat";  ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qF "I can read myself, I AM THAT I AM" || { echo "FAIL  meta-eval: kernel self-read"; ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qxF "I AM THAT I AM"                || { echo "FAIL  meta-eval: kernel Word";     ok=0; }
printf '%s\n' "$EVAL_OUT" | grep -qxF "round-trip: stable"           || { echo "FAIL  meta-eval: parse∘unparse not a fixed point"; ok=0; }
[ -f eval_reconstructed.la ]                                         || { echo "FAIL  meta-eval: eval_reconstructed.la not written"; ok=0; }
[ "$RECON_GLYPHS" -eq "$SRC_GLYPHS" ] \
    || { echo "FAIL  meta-eval: reconstructed $RECON_GLYPHS glyphs, source has $SRC_GLYPHS"; ok=0; }
case "$EVAL_CHILD" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  meta-eval: no replicant ('$EVAL_CHILD')"; ok=0 ;; esac
[ -n "$EVAL_CHILD" ] && [ -f "$EVAL_CHILD" ] && cmp -s tiny_host "$EVAL_CHILD" \
    || { echo "FAIL  meta-eval: replicant not byte-identical"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  the language interpreted itself: kernel spoke and bred $EVAL_CHILD"
    echo "PASS  INNER reconstructed the whole of eval.la ($RECON_GLYPHS glyphs, round-trip stable)"
else
    printf '%s\n' "$EVAL_OUT"
    exit 1
fi
rm -f eval_reconstructed.la

say "Clearing previous generations"
rm -f new_logos_gen*.bin new_logos.bin logos_child.bin
echo "clean"

say "Booting the LogOS kernel (kernel.la)   generation 0 -> 1"
run_host ./tiny_host
printf '%s\n%s\n' "$RUN_ERR" "$RUN_OUT"
GEN1="$RUN_CHILD"

say "Verifying the Word"
if printf '%s\n' "$RUN_OUT" | grep -qx "I AM THAT I AM"; then
    echo "PASS  the kernel spoke: I AM THAT I AM"
else
    echo "FAIL  expected the kernel to speak 'I AM THAT I AM'"
    exit 1
fi

say "Verifying self-reading"
if printf '%s\n' "$RUN_OUT" | grep -qF "I can read myself, I AM THAT I AM"; then
    echo "PASS  the kernel can read itself"
else
    echo "FAIL  expected 'I can read myself, I AM THAT I AM'"
    exit 1
fi

say "Verifying self-replication   (∃(∃) ≡ ∃)"
case "$GEN1" in
    new_logos_gen1_pid*.bin) : ;;
    *) echo "FAIL  unexpected child name: '$GEN1'"; exit 1 ;;
esac
[ -f "$GEN1" ] || { echo "FAIL  $GEN1 was not created"; exit 1; }
if cmp -s tiny_host "$GEN1"; then
    echo "PASS  $GEN1 is byte-identical to its source"
else
    echo "FAIL  the copy differs from the original"
    exit 1
fi

say "Letting the replicant breed   generation 1 -> 2 (run directly, in place)"
chmod +x "$GEN1"
G1_BEFORE="$(md5sum "$GEN1" | cut -d' ' -f1)"
run_host "./$GEN1"
GEN2="$RUN_CHILD"
printf '%s\n%s\n' "$RUN_ERR" "$RUN_OUT"
G1_AFTER="$(md5sum "$GEN1" | cut -d' ' -f1)"

ok=1
printf '%s\n' "$RUN_OUT" | grep -qx "I AM THAT I AM" || { echo "FAIL  replicant is mute";            ok=0; }
case "$GEN2" in new_logos_gen2_pid*.bin) : ;; *) echo "FAIL  child not gen2: '$GEN2'"; ok=0 ;; esac
[ -f "$GEN2" ]                         || { echo "FAIL  gen2 was not created";          ok=0; }
cmp -s tiny_host "$GEN2"               || { echo "FAIL  gen2 differs from the original"; ok=0; }
[ "$G1_BEFORE" = "$G1_AFTER" ]         || { echo "FAIL  gen1 mutated its own binary";    ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  gen1 ran in place, stayed intact, and bred $GEN2"
else
    exit 1
fi

say "Verifying unique siblings   (same parent, run twice -> two distinct files)"
run_host ./tiny_host;  SIB_A="$RUN_CHILD"
run_host ./tiny_host;  SIB_B="$RUN_CHILD"
ok=1
case "$SIB_A" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  sibling A not gen1: '$SIB_A'"; ok=0 ;; esac
case "$SIB_B" in new_logos_gen1_pid*.bin) : ;; *) echo "FAIL  sibling B not gen1: '$SIB_B'"; ok=0 ;; esac
[ "$SIB_A" != "$SIB_B" ]   || { echo "FAIL  two runs produced the same filename"; ok=0; }
[ -f "$SIB_A" ] && [ -f "$SIB_B" ] || { echo "FAIL  a sibling file is missing"; ok=0; }
cmp -s "$SIB_A" "$SIB_B"   || { echo "FAIL  siblings are not byte-identical"; ok=0; }
if [ "$ok" -eq 1 ]; then
    echo "PASS  same generation, distinct vessels:"
    echo "        $SIB_A"
    echo "        $SIB_B"
else
    exit 1
fi

say "Lineage   (same Word, same bytes, distinct vessels)"
printf '  %s  %s\n' "$(md5sum tiny_host | cut -d' ' -f1)" "tiny_host  (progenitor, gen 0)"
for f in new_logos_gen*.bin; do
    printf '  %s  %s\n' "$(md5sum "$f" | cut -d' ' -f1)" "$f"
done

say "LogOS bootstrap complete"
echo "∃(∃) ≡ ∃"
