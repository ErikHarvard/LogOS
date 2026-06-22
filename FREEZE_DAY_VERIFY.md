# Freeze-day audit — VERIFY phase (2026-06-21)

Empirical reproduction of the 13 [FREEZE_DAY_FINDINGS](FREEZE_DAY_FINDINGS.md),
each in an isolated git worktree at commit `d04fd7e` (Stage 3e), native ELF
(`native_codegen3_out`) vs the host reference (`./tiny_host prog.la`). Method:
build `tiny_host`, write the repro, compile via `./tiny_host native_codegen3.la`,
run native and host, compare stdout + exit code (the cardinal `b_τ ≡ f_τ`
invariant). Run via the `freeze-day-verify` multi-agent workflow (10/13 by agents
in batches; #9/#11/#12 finished by hand after a transient API rate-limit).

**Verdict: 9 real divergences CONFIRMED (#1–#8, #12), 3 code-confirmed latent gaps
(#9, #10, #11), 1 accepted-by-design (#13). Zero NOT_REPRODUCED — every finding
was real.**

## CONFIRMED — fix (in this order)

| # | Sev | Bug | Host | Native | Fix |
|---|-----|-----|------|--------|-----|
| 1 | HIGH | GC FREEBLOB[22]→REGDUMP overflow (memory corruption) | `5242880` rc0 | corrupt `3079` → **SIGSEGV rc139** | enlarge FREEBLOB (~32) **and** upper-clamp `classidx` |
| 2 | HIGH | non-STR arg deref'd as descriptor | loud halt rc1 | **SIGSEGV rc139** | tag-check (STR=0) at top of rt_str_len/ord/chr/str_to_int → loud halt |
| 3 | HIGH | `chr` no 0..255 range check | loud halt rc1 | silent `0` rc0 | range-check in rt_chr → loud halt |
| 4 | HIGH | `str_to_int` lenient (folds every byte) | loud halt rc1 | garbage `192` rc0 | digit-validate in rt_str_to_int → loud halt |
| 5 | HIGH | `div`/`mod` raw idiv, no div0 guard | loud halt rc1 | **SIGFPE rc136** | guard div0 (+ LONG_MIN/-1) before idiv → loud halt |
| 6 | MED | negative int literal aborts the **compiler** | prints `-5` rc0 | **compile abort** (`chr: value -5…`) | mask each byte unsigned 0..255 in LEBYTES before chr |
| 7 | MED | module mangle collision (sanitized-path aliasing) | `ONETWO` (order-invariant) | `ONEONE`/`TWOTWO` (**order-dependent** mis-resolve) | per-import monotonic counter (or hash full path) in MANGLE |
| 8 | MED | `write_file` (+ `typeof`) missing from native backend | runs, writes file | **compile abort** (`unbound name: write_file`) | add rt_write_file (open 0644, **its own RT_BIN case** — not the write_exec fallthrough) + wire IS_BUILTIN2; typeof: defer/document |
| 12 | LOW | `read_file` no lseek-fail guard | aborts rc134¹ | wrong len `-29` (=−ESPIPE) rc0 | `js` guard on the lseek result like the open-fail path |

¹ The host *also* mishandles a non-seekable file (buffer-overflow abort) — a
separate pre-existing **host** bug, out of scope for the native-backend freeze;
noted for later.

**Wider symptom under #1:** a 1 MB-blob churn loop (classidx 20, *in* range) also
diverged (corrupt output → `native: heap exhausted` rc73 vs host `1048576` rc0),
so the GC's handling of large dead `read_file` blobs looks broken beyond the
classidx-22 REGDUMP overflow. The classidx≥22 → FREEBLOB-into-REGDUMP path is the
confirmed corruption mechanism for >4 MB reads; investigate the 1 MB case while
fixing #1.

## Code-confirmed, latent (cheap fixes — no behavioral divergence observed)

- **#9 `export la`** — `IS_KEYWORD` (native_codegen3.la:189) covers only
  `glyph`/`import`/`export`, not `la`, so `PARSE_EXPORT_NAMES` would collect `la`.
  Fix: add `"la"` to IS_KEYWORD. (No shipped program writes `export la`.)
- **#10 copy_self no short-write loop** — rt_copy_self does a single `write` per
  64 KiB chunk, return ignored (rt_write_exec's `.wr` loops; rt_read_file's `.rd`
  loops). Happy path correct + child byte-identical. Fix: mirror the `.wr` loop.
- **#11 copy_self `r15` scratch no HEAP_END bound** — reads 64 KiB into
  `[r15, r15+65536)` with no `cmp r15, HEAP_END`. Latent (runs heap-near-empty).
  Fix: bound-check, or use a dedicated scratch region.

## Accepted by design — document, do not fix

- **#13 copy_self fixed name** — native returns `new_logos_native.bin` vs host's
  `new_logos_genN_pidP.bin`. Real stdout divergence **only if a program prints
  copy_self's return** (kernel.la discards it via SEQ); the bred child is
  byte-identical and exit codes match. Mirrors the SECD VM's documented fixed
  `new_logos_secd.bin`. Document.

## Fix-pass plan
`#1 → #2 → #3 → #4 → #5 → #6 → #7 → #8 → #9/#10/#11 (cheap lows)`. Each fix gets a
`build.sh` regression test (native==host on its repro). Re-derive RT addresses
after any asm change (dq-label recipe). Document #11(latent)/#13/typeof as honest
limits. Re-run full `./build.sh` (expect 133/0 + the new regression tests) before
committing the freeze-day fixes.
