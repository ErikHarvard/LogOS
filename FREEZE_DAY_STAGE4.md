# Stage 4 Freeze-Day Audit — 2026-06-26

Multi-agent differential audit (native_codegen3 CC2 vs C host). **132 programs tested, 7 candidates, 7 confirmed bugs, 0 false-positives, 0 misattributed known-limits.**

Audited surface: parser Z-ties (P_EXPR/P_APP/APP_TAIL/P_PRIMARY/P_LAMBDA), PARSE_MOD_LOOP self-tie, HEAP_SIZE 1.5->16 GiB.

## Verdict

VERDICT: NOT safe to tag as verified. Stage 4 introduces at least one blocking regression and surfaces several real b_τ≢f_τ divergences. 7 confirmed bugs (0 reclassified as known limits, 0 non-reproductions). Two are caused/reopened directly by the Stage 4 16 GiB heap bump (#1 SIGSEGV, #7 GC stderr); the rest are pre-existing type-guard gaps newly exercised. Do not tag until at least the HIGH bug is fixed and `./build.sh` is re-greened with the dq-probe addr-rederive.

BLOCKING (must fix before tag):

1. [HIGH / heap — Stage-4 REGRESSION] FREEBLOB size-class array overflows into REGDUMP for blobs >2 GiB → SIGSEGV (rc=139) where host returns the correct length. Freeze-day #1 reopened because HEAP_SIZE=16 GiB now makes >2 GiB blobs both allocatable and sweepable. Sharp threshold: DBL(31) OK, DBL(32) crashes.
   Fix: grow FREEBLOB from `times 32 dq 0` to cover the 16 GiB heap (classidx ~34 → `times 40 dq 0`) and derive the GC-clear bound (asm line 725 `cmp rcx,32`) and classidx guard from a single log2(HEAP_SIZE) constant; bounds-guard the sweep re-bucket to loud-halt (exit 73) instead of writing past the array.

SHOULD FIX (medium — silent-wrong-output vs host loud-halt; restore b_τ≡f_τ):

2. [MEDIUM / parser — in a Stage-4 Z-tied glyph] P_LAMBDA accepts ANY token as a lambda binder (la/keyword/string/number); host rejects. Worst case emits a raw garbage pointer.
   Fix: in P_LAMBDA (~line 155) require T_TYPE(HD(rest))=="name" and reject reserved keywords ("la","glyph"), else error("expected lambda parameter").

3. [MEDIUM / codegen] Integer-arg builtins (int_to_str/add/sub/mul/div/mod/lt/int_eq) unbox string/closure args as ints and print a raw pointer; host halts loudly. (Same root-cause family covers the three separately-reported int_to_str/add/lt/int_eq cases.)
   Fix: emit an INT-tag check at each integer-consuming rt helper entry (rt_int_to_str line 459, rt_add, etc.) before unboxing; on mismatch write the host-matching message to fd 2 and exit 1, mirroring the existing .seekfail/.die loud-halt pattern.

4. [MEDIUM / codegen] print of a non-string/non-integer (closure) prints a raw heap pointer; host halts with "print: argument is not a string or integer" (note: host exits 0 here, not 1).
   Fix: in rt print, after the string branch, tag-check; if not boxed-int, emit the host message to stderr and halt instead of printing the pointer.

LOW (Stage-4-surfaced, cosmetic but a real stderr divergence):

5. [LOW / heap — Stage-4-surfaced] rt_gc writes its live-object count to stderr on every GC pass (e.g. "56\n" ×4); host emits nothing. Exposed because a native GC now actually fires against the 16 GiB heap.
   Fix: delete the debug stderr block (asm lines 774–799) so .walked falls through to register-restore, or gate behind a debug flag defaulting off.

Notes on credibility: every candidate was run in a private mktemp dir (no shared-file race), each confirmed against ./tiny_host with matching controls proving the builtins are in the supported subset (so none are unsupported-builtin/typeof/copy_self known limits), and the CC2 self-host compiler — not just the shipped artifact — reproduces #2. Net: the parser Z-tie change is correct in mechanics but exposed an unguarded binder; the 16 GiB heap change is the actual regression source (#1 blocking, #5 cosmetic). Recommend fix #1 first, re-run full ./build.sh to 0-FAIL, re-validate rt offsets via the dq-probe addr-rederive recipe, then batch #2–#5 before tagging.

## Confirmed bugs (full detail)

### [1] MEDIUM — parser — Native parser accepts any token as a lambda parameter (la/keywords/strings/numbers/'('); host rejects

**Program:**
```
glyph MAIN = print((la la. "ok")("Y"))
```

**Host:** C host rejects: no stdout, stderr "parse error: expected lambda parameter", exit 1. The host requires a proper identifier as a lambda binder and reserves the keyword 'la'.

**Native:** CC2 (native_codegen3_selfhost.bin) compiles cleanly ("emitted native_codegen3_out", exit 0); the resulting binary prints "ok" and exits 0. Interp-built compiler (./tiny_host native_codegen3.la) agrees, so it is the compiler, not just the shipped artifact.

**Evidence:** Isolated temp dir /tmp/frz.0giUWf. PROGRAM `glyph MAIN = print((la la. "ok")("Y"))`: NAT rc=0 out=[ok]; HOST rc=1 out=[] err=[parse error: expected lambda parameter]. Divergence confirmed and BROADER than reported — the native parser accepts ANY token as a lambda parameter while host rejects all: `la glyph.` -> NAT ok / HOST err; `la "s".` -> NAT ok / HOST err; `la 5.` -> NAT ok / HOST err. Worst case `glyph MAIN = print((la la. la)("Y"))`: NAT rc=0 prints a raw garbage pointer [71313016], HOST rc=1 parse error — i.e. native silently emits wrong output, not just a benign accept. Root cause in native_codegen3.la line 155-158: `glyph P_LAMBDA = la pexpr. la rest. (la param. ...)(... )(T_VAL(HD(rest)))` takes the parameter as T_VAL(HD(rest)) with NO check that T_TYPE(HD(rest))=="name", whereas P_PRIMARY (line 170-174) dispatches strictly on token type. This lives in P_LAMBDA, one of the Stage-4 Z-tied parser glyphs, so it is exposed in the rewired mutual-recursion parser. Not a known documented limit (no typeof/copy_self/unsupported-builtin/div0 involved). No shared-file race: ran in private mktemp dir, native_input.la/native_codegen3_out isolated.

**Fix:** In P_LAMBDA (native_codegen3.la ~line 155), validate the binder token before use: require T_TYPE(HD(rest))=="name" and reject reserved keywords (at least "la"; match the host's reserved set, e.g. "glyph"), else error("native_codegen3: expected lambda parameter"). Concretely, guard with IF(str_eq(T_TYPE(HD(rest)))("name")) AND a not-keyword check around the existing `(la param. ...)(T_VAL(HD(rest)))` body. This restores b_τ≡f_τ for malformed lambda binders.

### [2] MEDIUM — codegen — print of a non-string/non-integer (closure) prints a raw heap pointer natively; host halts loudly

**Program:**
```
glyph MAIN = print(la x. x)
```

**Host:** ./tiny_host type-checks print's argument: stdout EMPTY, stderr='print: argument is not a string or integer', exit code 0 (NOT 1 as the peer claimed). It refuses to print a closure.

**Native:** native_codegen3_out prints the closure's boxed value as a raw heap pointer: stdout='71312936' (stable across reruns/recompiles), stderr empty, exit code 0. No type-check on print's argument.

**Evidence:** Program: glyph MAIN = print(la x. x). Isolated dir /tmp/frz.eHFaKW. Native: nat_out='71312936' natrc=0 (deterministic over 3+ runs and a fresh recompile). Host: host_out=[] host_e='print: argument is not a string or integer' hostrc=0. Divergence is in stdout content (71312936 vs empty) and stderr (empty vs type error). print is a supported builtin (print(42)->42 on both engines), so this is not an unsupported-builtin limit. Documented limits explicitly say non-string/non-integer print args must halt identically on both engines, so this divergence qualifies as a bug rather than a known limit. NOTE: peer's claimed host exit 1 is wrong (host exits 0); and this is a residual of FREEZE_DAY #2 (print type-check gap for closures), orthogonal to the Stage 4 parser/import/heap changes (exposed-by, not introduced-by).

**Fix:** In native_codegen3_rt.asm print runtime, after the string-type branch fails, check the value's type tag; if it is not a boxed integer (closure/pair/other), emit 'print: argument is not a string or integer' to stderr and halt, matching the host. Currently any non-string is unconditionally treated and printed as an integer (the raw boxed pointer).

### [3] MEDIUM — codegen — Integer-arg builtins (int_to_str/add/lt/int_eq/...) return silent garbage on native instead of halting loudly like the host

**Program:**
```
glyph MAIN = print(int_to_str("x"))
```

**Host:** Host type-checks the argument and halts loudly: stdout empty, stderr "int_to_str: argument is not an integer", exit code 1. Same for the related cases: add("a")(1) -> stderr "add: first argument is not an integer" rc=1; lt("a")(1) -> "lt: first argument is not an integer" rc=1; int_eq("a")("a") -> "int_eq: first argument is not an integer" rc=1.

**Native:** CC2 (native_codegen3_selfhost.bin) compiles it fine ("emitted native_codegen3_out"), and the resulting native binary does NOT type-check: it unboxes the STR heap pointer as if it were an INT and prints the raw pointer value as a decimal, exit code 0. Observed: int_to_str("x") -> stdout "71312968" rc=0; add("a")(1) -> "71313001" rc=0; lt("a")(1) -> "71312920" rc=0; int_eq("a")("a") -> "71312936" rc=0.

**Evidence:** Fresh dir /tmp/frz.ha9cRK, harness as specified. P = `glyph MAIN = print(int_to_str("x"))`: natrc=0 nat_out="71312968" (no stderr); hostrc=1 host_out empty, host_e="int_to_str: argument is not an integer". Control `add(2)(3)` agrees on both engines (rc=0, out="5"), so the divergence is specifically the missing argument-type guard, not a broken builtin. int_to_str/add/lt/int_eq are all in the supported kernel subset (not unsupported builtins), so this is not the "unsupported builtin" known limit, not typeof, not copy_self, and not the div0/chr/str_to_int loud-halt-parity class (host halts loudly but native does NOT halt — the opposite of parity). Genuine b_τ≢f_τ.

**Fix:** In native_codegen3_rt.asm, add an INT-tag guard at the entry of the integer-consuming runtime helpers (rt_int_to_str, rt_add, rt_sub, rt_mul, rt_lt, rt_int_eq, and any other arithmetic/comparison builtins that unbox an INT). Before unboxing, check the value's tag is the boxed-INT tag; if not, write the matching host message (e.g. "int_to_str: argument is not an integer" / "add: first argument is not an integer") to stderr (fd 2) and exit(1) — mirroring the existing loud-halt patterns (.seekfail/.die) already in the runtime for the div0/seek cases. This restores b_τ≡f_τ for ill-typed programs. Note: this is a codegen/runtime type-check gap, orthogonal to the Stage 4 parser/import/heap changes; likely pre-existing and merely surfaced during the audit rather than introduced by Stage 4.

### [4] HIGH — heap — FREEBLOB size-class array overflows into REGDUMP for blobs >2 GiB -> SIGSEGV where host succeeds (freeze-day #1 reopened by the 16 GiB heap bump)

**Program:**
```
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph DBL = Z(la self. la n. la s.
    IF(int_eq(n)(0))(la _. s)(la _. self(sub(n)(1))(concat(s)(s))))
glyph MAIN = print(str_len(DBL(32)("a")))
```

**Host:** rc=0, stdout="4294967296" (correct length of the 2^32-byte string), stderr empty, RSS ~96 GB, ~65s wall. Uses system malloc on 188 GB RAM and completes.

**Native:** SIGSEGV, rc=139, reproduced 3/3 (core dumped each run). stdout empty; stderr="31". Never emits the loud 'native: heap exhausted' (exit 73). Sharp threshold: DBL(31) gives rc=0 stdout="2147483648" (works, matches host), DBL(32) SIGSEGVs.

**Evidence:** In isolated dir /tmp/frz.nCrM1x. native_input.la = the exact 5-glyph program (Z/IF/DBL/MAIN with DBL(32)). CC2 (native_codegen3_selfhost.bin) compiled it cleanly (rc=0, emitted native_codegen3_out). Running native_codegen3_out: 3/3 'Segmentation fault (core dumped)', natrc=139, nat_out empty, nat_e="31". Host (/usr/bin/time -v ./tiny_host native_input.la): hostrc=0, host_out="4294967296", Maximum RSS 96472924 KB (~96 GB), 1:05.50 wall. Threshold loop: DBL(31) natrc=0 nat_out="2147483648"; DBL(32) natrc=139. Root cause in /home/erikxanderharvard/logos/native_codegen3_rt.asm: FREEBLOB 'times 32 dq 0' (line 1405) covers classidx 0..31; REGDUMP (line 1411) is adjacent. classidx() (line 88) returns >=32 for a >=2 GiB blob; the GC sweep re-bucket 'mov [FREEBLOB + rcx*8], rsi' (line 755) and the GC-clear bound 'cmp rcx, 32' (line 725) write past the array into REGDUMP, corrupting rt_gc's saved registers -> crash on return. native_codegen3.la line 415 HEAP_SIZE=17179869184 (16 GiB, Stage 4 change #3) makes a >2 GiB blob both allocatable and sweepable, breaking the FREEBLOB-comment invariant (array sized for a 1.5 GiB heap where >1 GiB blobs could never be swept = freeze-day #1, now reopened). All builtins used are in the kernel subset; not a known limit, not a div0/chr/str_to_int parity case, not a shared-file race (fully isolated temp dir).

**Fix:** Re-size the blob size-class array to cover the actual 16 GiB heap and re-derive the GC-clear bound from it, not a hardcoded 32. A 16 GiB heap admits blobs up to classidx ~34, so grow FREEBLOB to e.g. `times 40 dq 0` (with headroom) and update the GC-clear loop bound at line 725 (`cmp rcx, 32`) to match the new count. Better/durable: tie the array length and clear-bound to a single named constant derived from log2(HEAP_SIZE) so future heap bumps cannot silently overflow it again, and add a bounds-guard in classidx / the sweep re-bucket that loud-halts (exit 73 'native: heap exhausted'-style) instead of writing past the array. This restores b_τ≡f_τ for the largest blobs the 16 GiB heap can hold.

### [5] LOW — heap — rt_gc writes its live-object count to stderr on every GC cycle; host produces no such output (stderr divergence on any GC-triggering program)

**Program:**
```
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph DBL = Z(la self. la n. la s.
    IF(int_eq(n)(0))(la _. s)(la _. self(sub(n)(1))(concat(s)(s))))
glyph LOOP = Z(la self. la k. la acc.
    IF(int_eq(k)(0))(la _. acc)(la _.
        self(sub(k)(1))(add(acc)(str_to_int(str_len(DBL(20)("a")))))))
glyph MAIN = print(int_to_str(LOOP(17000)(0)))
```

**Host:** rc=0, stdout="17825792000", stderr EMPTY (0 bytes). Elapsed ~90s, RSS ~381MB (interpreted host, no GC stderr output).

**Native:** rc=0, stdout="17825792000" (matches host), but stderr = "56\n56\n56\n56\n" (12 bytes, 4 lines — one decimal live-object count per GC pass). 4 native GC passes fired against the 16 GiB heap given ~17 GB cumulative blob churn.

**Evidence:** Isolated temp dir /tmp/frz.jIMt1E; fixed filenames (native_input.la / native_codegen3_out) used only locally, no concurrency. Native compile via native_codegen3_selfhost.bin (CC2): compile_rc=0, emitted native_codegen3_out (all builtins Z/IF/concat/sub/add/int_eq/str_to_int/str_len/int_to_str/print are in the supported subset — no unsupported-builtin error). Control LOOP(100) (no GC): native rc0 stdout=104857600, host rc0 stdout=104857600, BOTH stderr empty. Full LOOP(17000): native rc0 stdout=17825792000 stderr="56\n56\n56\n56\n"(12B); host rc0 stdout=17825792000 stderr=0B. Root cause: rt_gc at native_codegen3_rt.asm line 638 ends every pass (label .walked, line 771) with an UNCONDITIONAL stderr write — lines 774-799, comment "--- print live count + newline to stderr (fd 2) ---", formatting r13 (live count) and issuing write(2,...) at .pr (lines 794-799). No debug gating. C host GC emits nothing. Not a documented known limit (not typeof/copy_self/unsupported-builtin/div0/chr/str_to_int). Genuine b_tau != f_tau on the stderr channel, exposed by the Stage 4 16 GiB heap (a native GC must fire to trigger it).

**Fix:** In native_codegen3_rt.asm rt_gc, delete the debug stderr block at lines 774-799 (the "print live count + newline to stderr (fd 2)" formatting loop .lp/.pr and the write(2) syscall) so .walked (frontier check, lines 771-773) falls straight through to the register-restore at line 800. The numend scratch and .lp/.pr loop exist solely to format r13 for that leftover debug write; removing them makes the native GC silent, matching the host. (Alternatively gate it behind a build-time debug flag defaulting off.) Then re-run full ./build.sh to confirm 0-FAIL and re-validate via the dq-probe addr-rederive recipe since rt label offsets will shift.

### [6] MEDIUM — other — int_to_str on a non-integer (string) argument: native prints a garbage pointer; host halts loudly

**Program:**
```
glyph MAIN = print(int_to_str(str_len("hello")))
```

**Host:** rc=1, stderr "int_to_str: argument is not an integer", no stdout. Host int_to_str type-checks its argument; str_len returns a boxed STRING ("5"), which int_to_str rejects with a loud halt.

**Native:** rc=0, stdout "71313064", no stderr. Native rt_int_to_str (native_codegen3_rt.asm:459) does an unconditional `mov rax,[rax+8]` with no tag check, grabbing the string box's data pointer and formatting it as decimal — no loud halt.

**Evidence:** Fresh isolated dir /tmp/frz.YwHp1k. Program: glyph MAIN = print(int_to_str(str_len("hello"))). CC2 (native_codegen3_selfhost.bin) compiled native_input.la -> native_codegen3_out. native: rc=0 out="71313064" (deterministic across 3 runs). host (./tiny_host): rc=1 err="int_to_str: argument is not an integer". Controls: print(int_to_str(5)) -> "5" both engines; print(str_len("hello")) -> "5" both (so str_len is supported natively, not an unsupported-builtin limit). rt asm comment line 889 confirms str_len returns host-style strings; rt_int_to_str at line 459 lacks a tag check. This is the loud-halt-parity family (like div0/chr/str_to_int/non-string-args) where divergence is a bug. Not typeof/copy_self/unsupported-builtin known limits.

**Fix:** In native_codegen3_rt.asm, add an argument tag-check at the boxed rt_int_to_str entry (line 459) before `mov rax,[rax+8]`: verify the box is an INT (as other rt funcs do); on mismatch, loud-halt exit 1 with stderr "int_to_str: argument is not an integer" to match the host byte-for-byte. Keep rt_int_to_str_raw (line 463) unchanged for internal callers (rt_str_len/rt_ord) that pass a verified raw int.

### [7] MEDIUM — codegen — Native integer builtins (int_to_str/add/sub/mul/div/mod/int_eq/lt) accept string/closure args without type-checking → silent garbage output, while host halts loudly

**Program:**
```
glyph MAIN = print(int_to_str("hello"))
```

**Host:** rc=1, empty stdout, stderr: "int_to_str: argument is not an integer". Loud halt.

**Native:** CC2 (native_codegen3_selfhost.bin) compiles the program cleanly (exit 0); the emitted native_codegen3_out runs rc=0 and prints the garbage value 71312968 (a heap/STR pointer, unboxed as an int). Deterministic across 3 runs. No error, no halt.

**Evidence:** Isolated temp dir /tmp/frz.hTQLU1. Program: glyph MAIN = print(int_to_str("hello")). HARNESS result: native nat_out=71312968 natrc=0 (empty stderr); host host_out empty hostrc=1 host_e="int_to_str: argument is not an integer". Determinism check: 3 native runs all print 71312968. Control: int_to_str(42) -> native "42" rc=0 AND host "42" rc=0, proving int_to_str is a SUPPORTED native builtin (the divergence is a missing type guard, not an unsupported-builtin known-limit). Per the task's own rule, non-int args to int builtins must halt loudly+identically in both engines; native silently producing wrong output where host halts is therefore a genuine b_tau != f_tau bug, not a documented known limit (typeof/copy_self/unsupported-builtin/parity-on-bad-args). Caveat: this is a pre-existing native codegen type-guard gap (int builtin argument unboxing assumes a boxed-int tag), independent of the specific Stage 4 parser/import/heap edits, but it is a real divergence.

**Fix:** In native_codegen3 codegen for the integer builtins (int_to_str, add, sub, mul, div, mod, int_eq, lt), emit an argument tag-check before unboxing: verify each operand carries the boxed-int tag; on mismatch jump to a loud-halt runtime path that writes the host-matching message (e.g. "int_to_str: argument is not an integer") to stderr and exits 1. This mirrors the existing freeze-day rt error paths (#2 non-STR halt, #4 str_to_int strict, #5 div0 halt) so b_tau≡f_tau parity is restored for ill-typed args. The boxed-int tag/discriminator is already available at runtime (rt_box_int); reuse the same tag predicate the host uses in its runtime check.
