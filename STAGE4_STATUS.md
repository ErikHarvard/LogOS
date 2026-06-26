# Stage 4 (full native self-hosting) — live status

**2026-06-25.** Working note, uncommitted. HEAD = `9f83a4d` (native-backend-stage3b).

## The wall (identified)
Seed = `tiny_host` compiling native_codegen3.la's OWN source → no CC0, exit 1.
Exact error (after ~6h CPU): `native_codegen3: cyclic glyph reference: APP_TAIL`.

Root cause: native_codegen3's `INLINE` pass produces "one closed lambda term over
builtins" (full inlining, `seen`-set guard) — so it can only represent
**Z-combinator recursion**, not **named recursion**. The parser is a 5-glyph
mutually-recursive SCC tied by NAMED cross-references:
`P_EXPR → P_APP → {APP_TAIL → P_EXPR, P_PRIMARY → P_EXPR}`, `P_LAMBDA → P_EXPR`.
`APP_TAIL` (direct self-ref) was just where the seen-check tripped first.
It was the SOLE out-of-subset construct (scan: only APP_TAIL had genuine
direct named recursion; B/MAIN were false positives).

## The fix (applied, path (a) — Erik approved)
Z-tie the parser SCC, the language's blessed recursion form (every other
recursive helper already uses Z). `P_EXPR = Z(la self. la toks. P_APP(self)(toks))`
is the single fixpoint; `pexpr` threaded as a param through P_APP/P_PRIMARY/
P_LAMBDA/APP_TAIL; APP_TAIL keeps an inner `Z(la self. ...)` for its own
recursion. All SCC back-edges are now bound-var `self`/`pexpr` (no named cycle)
→ INLINE yields a finite closed term. P_EXPR's external signature unchanged
(only external caller is line ~278), so non-SCC code is untouched.

Cheap validation PASSED (tiny_host, /tmp/c3check.sh): literal, lambda-app,
nested left-assoc app, paren+lambda+curry, Z+IF-thunk — all native==host.

## Wall 2 (cleared 2026-06-26)
Parser fix cleared APP_TAIL; ran 6.5h further → `cyclic glyph reference:
PARSE_MOD_LOOP`. Full Tarjan SCC analysis (not just direct self-ref) found the
LAST named-recursion cycle: `{PARSE_MODULE ↔ PARSE_MOD_LOOP}` (mutual, missed by
the direct-scan). PARSE_MOD_LOOP is already `Z(la self...)`; its import branch
(line ~285) called the NAMED `PARSE_MODULE(...)` to parse an imported file, but
`PARSE_MODULE = la toks. PARSE_MOD_LOOP(toks)` so `self` is identical. Fix:
swapped that one call `PARSE_MODULE(` → `self(`. Tarjan now reports ZERO
remaining named-recursion SCCs. Validated native==host on the import path
(greetapp→greetmod) + parser (/tmp/c3check2.sh).

## Now running
6h self-host seed relaunched (stage4_seed_capture.sh → stage4_seed_out.txt;
native_input.la := native_codegen3.la). Watch for `CC0_PRODUCED` vs `NO_CC0`.
NOTE: each wall has taken ~6-6.5h to hit because INLINE fully inlines (no
sharing) — if this run OOMs / runs much longer instead of erroring, the term may
be blowing up exponentially → that's a compiler-scaling problem (option (b)),
not another named cycle.

## If CC0 is produced
Fixed-point test: `cp native_codegen3_out compiler_native.bin`;
`rm native_codegen3_out; ./compiler_native.bin` → CC1;
success = `cmp CC0 CC1` byte-identical + CC1 compiles kernel.la, no tiny_host
in CC0→CC1. THEN full ./build.sh green before any commit (discipline).

## If a NEW wall (different error / still NO_CC0)
The seed may surface a further out-of-subset construct only reachable past the
SCC. Read the new error line, identify the construct, plan-first with Erik.
