# LogOS CLAUDE.md — DRAFT CLAIMS LEDGER

Reference tree: `scratchpad/k1` (branch `kernel-k1`, HEAD 9df29b0). `CLAUDE.md` there is byte-identical to `/home/user/LogOS/CLAUDE.md` (diff empty). Line numbers below are CLAUDE.md lines; `build.sh:N` are build.sh lines in k1; `say` = stage banner.


Status vocabulary: **BACKED** (a build.sh check or a source definition establishes it) · **EXISTS-UNCHECKED** (code exists, no build check) · **UNBACKED** (nothing in the tree establishes it; usually a manual/perf number) · **CONTRADICTED** (code/build says otherwise) · **STALE** (was true, no longer).

## Summary

| Total | BACKED | EXISTS-UNCHECKED | UNBACKED | CONTRADICTED | STALE |
|------:|------:|------:|------:|------:|------:|
| 312 | 230 | 30 | 21 | 12 | 19 |

## Actionable first: CONTRADICTED and STALE

| ID | Line | Claim | Status | Evidence |
|---|---|---|---|---|
| C1 | 699 | "the VM has no `unlink` builtin yet" (socket-layer honest limits) | CONTRADICTED | `secd.asm:2789 .bi_unlink` (syscall 87); `build.sh:6570 say "unlink: …"` PASS 6588; CLAUDE.md L842 itself says CHANNEL `unlink`s. |
| C2 | 1269 (also 65, 1265-1272) | NORMK: "`⊗`/`⊕` are symmetric, so their operands are sorted (`⊕(A,B) ≡ ⊕(B,A)`)" — ⊗ commutative | CONTRADICTED | `canon.la:93` NORMK: ⊕ → `SORT2`, ⊗ → `REWRITE_SYN` (canon.la:91, order-preserving, only ⊗(∃,∃)→∃). build.sh:5117 asserts ⊗ operand order CHANGES the sigil; monosemy gate build.sh:6259 asserts `order ⊗ … DISTINCT`; srcdrift comment build.sh:928-931 records the ⊗ non-commutativity correction (91fc923). |
| C3 | 65 | monosemy_test: "⊗/⊕ commutativity (incl. nested) … COLLAPSE to one glyph" | CONTRADICTED | monosemy_test.la labels `order ⊗ : ⊗(B,L) vs ⊗(L,B)` expected DISTINCT (build.sh:6259); only ⊕ commutativity collapses. |
| C4 | 1532 | `LAW_IDENTITY = la a. TRIBAR(a)(a)` — "holds without inspecting a" | CONTRADICTED | `metalogic.la:61 glyph LAW_IDENTITY = la g. AUTO_OK(g)`; build.sh:2559 "each law returns BOTH T and F (LAW_IDENTITY→AUTO_OK …) — no longer constant-TRUE tautologies". |
| C5 | 1534 | `LAW_NONCONTRADICTION = ¬(A≡B ∧ ¬(A≡B))` | CONTRADICTED | `metalogic.la:63 = la term. INHABITS(DECL_ARITY(term))(BODY_ARITY(term))`. |
| C6 | 1542 | `LAW_EXCLUDED_MIDDLE = (A≡B) ∨ ¬(A≡B)` | CONTRADICTED | `metalogic.la:65 = la term. WELLFORMED(term)`. |
| C7 | 62 | denote.la: "**`COMPOSE`** denotes each mode as a real operation" | CONTRADICTED (name) | No `glyph COMPOSE` in denote.la; the mode denotations are `D_SYN/D_CON/D_DIR/D_CONT/D_MC` + `MEANING` (denote.la glyph list). Behaviour itself BACKED (build.sh:5705-5737). |
| C8 | 944 | theourgia_drm.la "paints the whole screen blue and self-replicates the proof" | CONTRADICTED | theourgia_drm.la MAIN: `drm_mode` → `present(FRAME)` → print "theourgia: painted" → `sleep("4")`; no `copy_self`. |
| C9 | 946, 950 | drm_mode "halts loudly (`secd: drm error`, exit 1)" | CONTRADICTED (message text) | secd.asm:3909 `drm_pfx "secd: drm "` + step name; build.sh:4097 greps `secd: drm SETCRTC failed: -[0-9]+`. Exit 1 is BACKED. |
| C10 | 197 | self-hosted parsers add "four glyphs … `RENAME_FREE`" in every engine incl. codegen | CONTRADICTED (minor, codegen only) | codegen.la has PARSE_MODULE/MANGLE_MODULE/PRIVATE_NAMES/SANITIZE but `RENAME_ALL` (codegen.la:111), no RENAME_FREE. parser/eval/bytecode do have RENAME_FREE. |
| C11 | 59 | phonym table row: "⊗ smooth fusion" | CONTRADICTED by own §1408 | phonym.la:271 `SYNP` = superposition over max-length window (CLAUDE.md L1408-1416 says so). Table row wording stale. |
| C12 | 21 | logosinit "supervises forever with a `reap(-1)` loop" | CONTRADICTED by own §751-768 | logosinit.la:31-37,92,119: signalfd read loop + `reapnb` drain; `reap` is not the supervision primitive. |
| S1 | 492 | "The VM (`secd.asm`, 13775 bytes) is a fixed binary" | STALE | secd.la:5-11: "The byte count that stood here said 13775 and had been wrong through TWO growth events (14207, then 14639) … the build DERIVES it from `nasm -f bin secd.asm`" (build.sh:3741-3750). |
| S2 | 1668 | "`build.sh` succeeds only if … `new_logos.bin` is created and is byte-identical to `tiny_host`" | STALE | Child is `new_logos_gen1_pid*.bin` (tiny_host.c:579; build.sh:7208-7215 `case "$GEN1" in new_logos_gen1_pid*.bin`). `new_logos.bin` appears only in cleanup rm (7185). |
| S3 | 1253 | canon: "META_DEBUG-verified (29 glyphs)" | STALE | build.sh:1124-1129 verifies 48 names; canon.la has 49 glyphs. |
| S4 | 1550 | metalogic: "META_DEBUG-verified (25 glyphs)" | STALE | build.sh:2456-2463 verifies 40 names; metalogic.la has 51 glyphs. |
| S5 | 1554 | metalogic witness "`≡\|=≢\|INE\|ineY\|TFy\|du`" | STALE | build.sh:2504 `ML_EXPECT="FFF\|TTT\|TfY\|=≢\|TFy\|du"`. |
| S6 | 1492 | metaglyph: "wiring a minted operation back in as an executable combinator … is a further step" | STALE | metaglyph.la exports `MKOP APPLYOP`; build.sh:5909-5912 asserts `ν*·apply(A,B) = ⊗(▷(A,A),↻(B))`, "ν* is a NEW mode ? YES". |
| S7 | 60 | goertzel: "unifying the three divergent formant tables (psc/phonsem/phonym) are the phonosemantics follow-ups" | STALE | build.sh:5404 `say "Formant single-source guard"` PASS 5423 — done. |
| S8 | 1427, 59 | phonym `MAIN` "writes nine primitives + three generated phonyms" | STALE (incomplete) | phonym.la:455 prints "9 primitives + 3 GENERATED + 2 modes + the evaluator 𝓡"; build.sh:5330 size 344524 "(+ evaluator phonym 𝓡)". |
| S9 | 1438 | "speech-to-glyph *input* direction of the Bidirectional Speech Protocol … deferred" | STALE | sglyph.la (`RECOGNIZE`); build.sh:5012 PASS "speech->glyph recovers the derivation tree (9/9 primitives + mode + roundtrip)". |
| S10 | 1272, 65 | NORMK rewrite set = "one entry" / "(one entry)" | STALE | canon.la:89 REWRITE_MC: ↻(BEING)→SELF, ↻-idempotence (HAS_PREFIX), ↻(𝓡)→𝓡, ⊕(SELF,SELF) fixed; canon.la:91 REWRITE_SYN ⊗(∃,∃)→∃. |
| S11 | 471 | "Stage 2 — threaded SECD machine, **in progress**" | STALE | Stages 2/4/5 all green (build.sh:3736, 3825, 3870). |
| S12 | 482-487 | Stage 2 early description: "`PUSHV` looks a name up in `E` then falls back to the `print` builtin"; "runs a real lambda `print((la x. x)("I AM THAT I AM"))`" | STALE | Superseded by the glyph table + full builtin set (CLAUDE.md L495; secd.asm dispatch 1151-1288); the single-lambda demo is not tested anywhere. |
| S13 | 270-275 | eval.la builtin tables "cover … print, copy_self, read_file, write_file, concat, str_head, str_tail, str_eq, and the native integers" | STALE (incomplete) | eval.la:240-275 also has str_len, str_at, band/bor/bxor/bshl/bshr; the *absence* of chr/ord/write_exec/error is BACKED (build.sh:340). |
| S14 | 893-896 | "Still deferred, per the Codex: Γ-seal encryption, runtime schema validation, socket multiplexing" | STALE (partially) | An AEAD substrate exists (aead.la `ENCRYPT DECRYPT TAGOF`, chacha20/poly1305/hkdf; build.sh:529) though not wired into logosipc/logoscap (grep ENCRYPT = 0); `poll` multiplexing exists (build.sh:6626). |
| S15 | 42 | aatc: build "runs the GENERATED module stand-alone: the Archē passes, a self-exempting TOE HETEROLOGICAL (witness `FTTF`), cogito α=0" | STALE (detail) | Stand-alone witness is now `T\|TTTT\|131\|TTFT\|T\|4\|TTTT` (build.sh:2634-2636); TOE/cogito live in aatc_spec.la META_DEBUG tests (aatc_spec.la:118,125). |
| S16 | 27 | secd.asm "a bump heap" | STALE (wording) | Two-semispace copying GC (secd.asm:3598ff); CLAUDE.md L1720ff itself says so. |
| S17 | 494 | "The VM … carries a glyph table" then L495 "`PUSHV` resolves … then the builtins" | (fine) — listed only to note L482 vs L495 inconsistency | — |
| S18 | 1105 | font: "an earlier deeply-nested assoc-list font made codegen of any importer pathologically slow (>10 min)" | UNBACKED (historical perf) | No test. |
| S19 | 322 | "**87 glyphs** (was 85 … 72 … 67)" | BACKED-now | `grep -c '^glyph ' eval.la` = 87; build.sh:7139-7148 compares reconstructed count to source count (not to a literal 87) — number will drift silently with the file. |

## Full ledger

### Layout table (L11-68)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 1 | 13 | tiny_host.c is a minimal C interpreter for .la | BACKED | build.sh:211 `gcc -O2 -Wall -Wextra -o tiny_host tiny_host.c` |
| 2 | 14 | kernel.la defines MAIN | BACKED | kernel.la `glyph MAIN`; build.sh:2800 "parsed kernel.la (9 glyphs)" |
| 3 | 15 | stdlib.la exports MAP/FILTER/ALL/LIST_FIND, helpers private | BACKED | stdlib.la:14 `export MAP FILTER ALL LIST_FIND`; build.sh:459 |
| 4 | 16 | app.la imports stdlib, proves namespace isolation (host) | BACKED | build.sh:442-461 (SECRET stays app's; decoy IF) |
| 5 | 17 | greetapp/greetmod prove both isolation directions identically on all five engines | BACKED | build.sh:464-505 PASS "coherent across all 5 engines" |
| 6 | 18 | logosipc.la exports SEND/RECV/MSG_TYPE…, AF_UNIX CHANNEL/ACCEPT/CONNECT | BACKED | logosipc.la:39 export line, :64-71 |
| 7 | 19 | ipc_demo.la round-trips a typed message | BACKED | build.sh:718-730 |
| 8 | 20 | logoscap: Morris sealer/unsealer, BRAND mints sealer+unsealer, opaque box, imports logosipc, byte-identical host/VM | BACKED | logoscap.la:38,56-64; build.sh:735-763 |
| 9 | 21 | logosinit mounts /proc & /sys, fork+execve /bin/sh, respawn-throttled, TCO-bounded | BACKED (except reap(-1) wording, see C12) | logosinit.la:115-119,73,80; build.sh:6678-6820 |
| 10 | 22 | autopoiesis: bundled vessel, gen from medium, speaks, copy_self, fork+execve child, no external driver | BACKED | build.sh:3957-4001 |
| 11 | 23 | parser.la: self-hosted lexer+parser → Church ASTs | BACKED | build.sh:2797-2807 |
| 12 | 24 | eval.la evaluates kernel.la | BACKED | build.sh:7132-7174 |
| 13 | 25 | bytecode.la: EMIT/PARSE_BYTES/RUN_BYTES/RUN_SM | BACKED | glyphs exist; build.sh:2857-2905 |
| 14 | 26 | elf.la emits runnable native ELF speaking the Word | BACKED | build.sh:2912-2926 |
| 15 | 27 | secd.asm self-contained `nasm -f bin` ELF; loads logos_program.bin; secd.la emits VM | BACKED | build.sh:3738-3757, 3820 (nasm byte-identity when present) |
| 16 | 28 | codegen.la compiles arbitrary programs, native output matches RUN_SM | BACKED | build.sh:3758-3817 `diff_native_runsm` |
| 17 | 29 | bundle.la fuses VM+stream, patches p_filesz, runs standalone, bundled kernel self-replicates | BACKED | bundle.la:53-55; build.sh:3870-3922 |
| 18 | 30 | metadebug.la: spec table + DEBUG/META_DEBUG sharing one glyph table | BACKED | build.sh:796-869 |
| 19 | 31 | specpipe: SPEC/GENERATE/META_DEBUG/DEPLOY; type error rejects module and writes no file | BACKED | build.sh:875-917, 2757-2791 |
| 20 | 32 | strutil_spec: STARTS_WITH/ENDS_WITH/CONTAINS/SPLIT/JOIN/REPLACE verified module | BACKED | build.sh:950-978 |
| 21 | 33 | primitives.la regenerated by build.sh from spec; autology tests; DEPTH(DEPTH) via timeout | BACKED | build.sh:1041-1115 |
| 22 | 34 | typed_spec: IDT/KESTREL/COMPOSE/FLIP/PAIRT accepted; BADCONST rejected, no file | BACKED | build.sh:2757-2791 |
| 23 | 35 | swc.la regenerated; WF/ILL/UNKNOWN; operator-order chain; Pathology 3; byte-identical | BACKED | build.sh:2703-2751 |
| 24 | 36 | glyphdag: hash-consed DAG string; DAG/DECOMP/DCOLLAPSE; linear vs exponential; byte-identical | BACKED | glyphdag.la glyphs; build.sh:2659-2697 |
| 25 | 37 | canon: κ, IS, three laws over IS, KAPPA, MONO/REN/ETYM/COLLAPSE/DEPTH/AUTO_OK, REVAL, eight SR_* glyphs, byte-identical | BACKED (SR distinctness only partially: SR_AS≠SR_FROM) | canon.la:27-99; build.sh:1121-1322 (witness CANON_EXPECT) |
| 26 | 37 | "All eight distinct (monosemic)" | EXISTS-UNCHECKED | build.sh W9 checks only IS(SR_AS)(SR_FROM)=d |
| 27 | 37 | SR(SR) ≡ SR fixed points via REWRITE_MC | BACKED (partial: SR_TO, SR_BY tested) | canon.la:89; build.sh W9 `↻(DEPTH)/==` |
| 28 | 38 | psc.la: THETA_P idempotent, SYN_INV union, PRESERVES containment (Love/Recognition ⊆ Compassion, Depth not), SYN_DUR max | BACKED | psc.la:27-37; build.sh:1330-1374 |
| 29 | 38 | "FFT recovers 6/6 of each parent's vowel formants in Compassion" | UNBACKED | no FFT/Compassion measurement in build; goertzel measures Love /u/ only |
| 30 | 39 | topoembed: VINV, PRESERVES_V, MODE_REC (⊗≠⊕), byte-identical | BACKED | topoembed.la:35-39; build.sh:1380-1419 |
| 31 | 40 | onf.la/topoderive.la DSIGIL derived from ONF features; deterministic, canonical, injective; coexists with SIGIL | BACKED | build.sh:5132-5231 |
| 32 | 40 | "d_𝒪↔d_𝒫 proximity … score 0.863" | EXISTS-UNCHECKED | 0.863 appears in PASS text (build.sh:5320) / FAIL comment (1145); a threshold assertion was not located |
| 33 | 40 | φ / Flower-of-Life / π do NOT emerge | EXISTS-UNCHECKED | asserted in prose; no build check found |
| 34 | 41 | metalogic: TRIBAR vs YIELDS disagree on add(2,3) vs 5; ≡⟹= but =⇏≡ | BACKED | build.sh:2495-2504 W4 `=≢`, W6 `du` |
| 35 | 42 | aatc: 47 glyphs META_DEBUG + type-checked | BACKED | build.sh:2568-2591 (47 names) |
| 36 | 42 | AATC(AATC) ≡ TRUE | BACKED | build.sh:2647 PASS text; aatc_spec META_DEBUG |
| 37 | 42 | DIAGNOSE/TRANSFORM/T_APPLY..T_CLOSE/REPAIR = 𝒯⁴ | BACKED | aatc.la:55-57; build.sh W `DIAGNOSE(REPAIR(BROKEN))`=TTTT |
| 38 | 42 | ORGAN_DIAGNOSE: healthy autological, spec-failing TTFT, amnesic FTTT, needy TTTF | BACKED (TTFT in stand-alone; others via META_DEBUG) | build.sh:2634 `ORGAN_DIAGNOSE(M_FAIL)`=TTFT |
| 39 | 42 | LEARN_ALL total 4 across healthy/failing/sick | BACKED | build.sh:2634 `LEARN_ALL(...)`=4 |
| 40 | 42 | AUDIT_FILE("kernel.la")("MAIN") = TTTT on host and VM | BACKED | build.sh:2634-2645 |
| 41 | 43 | evdev.la regenerated, META_DEBUG-verified, OPEN_INPUT/READ_EVENT/CLOSE_INPUT, decoders, classifiers | BACKED | evdev.la:40 export; build.sh:984-1035 |
| 42 | 44 | theourgia.la surfaces/compose/PPM byte-identical | BACKED | build.sh:4006-4038 |
| 43 | 45 | theourgia_drm paints one colour; halts loudly under compositor | BACKED (see C8/C9 for wording) | build.sh:4083-4121 (only when a graphical session exists) |
| 44 | 46 | theourgia_fb imports Stage 1, TO_FB, byte-identical | BACKED | theourgia_fb.la:34; build.sh:4043-4078 |
| 45 | 47 | theourgia_input decodes 24-byte input_event incl. signed deltas; WATCH VM-only | BACKED / WATCH EXISTS-UNCHECKED | build.sh:4124-4150; theourgia_input.la WATCH |
| 46 | 48 | theourgia_session STEP/RENDER deterministic byte-identical | BACKED | build.sh:4155-4191 |
| 47 | 49 | theourgia_poll JOIN/SPLIT/DRAIN with SIMREAD; two ready fds decode | BACKED | build.sh:4196-4228 |
| 48 | 50 | theourgia_poll_live MULTIPLEX/OPEN_OR_DIE; not in build.sh | BACKED (exists; not in build as stated) | glyphs exist; no build stage |
| 49 | 51 | theourgia_mux_session DRAIN_STEP; fds "5 7" (4,4)→(5,5) | BACKED | build.sh:4233-4269 |
| 50 | 52 | theourgia_mux_session_live carries DRAIN_STEP/STEP/TO_FB/LIVE + OPEN_OR_DIE; not in build.sh | BACKED (exists) | glyphs present |
| 51 | 53 | font: A–Z 0–9 space; FONTDATA 296 bytes; imports nothing; exports GLYPH_ROW BIT FW FH | BACKED | theourgia_font.la:23,55 (296 tokens); no import line |
| 52 | 54 | DRAW_TEXT/TEXT_SURFACE; "HI" on 24×12 checked on both engines | BACKED | build.sh:4274-4312 |
| 53 | 55 | theourgia_text_live imports just the font; run via drm_bringup_text.sh | EXISTS-UNCHECKED | theourgia_text_live.la:27; script exists |
| 54 | 56 | text_session_live moves window 40px/keypress; verified reducer | EXISTS-UNCHECKED | file comments :13,:38; not in build |
| 55 | 57 | sigil: nine catalogue sigils, five blend modes, 32×32 predicate, integer primitives, MAIN renders nine + four derived, symmetry signatures, byte-identical | BACKED | sigil.la:100 SZ=32, :121-164 primitives, :402-403 derived; build.sh:5017-5127 |
| 56 | 58 | sigil_live imports sigil.la, REPEAT2, SCALE, drm_bringup_sigil.sh | EXISTS-UNCHECKED | sigil_live.la:26,61,74; script exists |
| 57 | 59 | phonym: nine phonyms with stated IPA; pure integer DSP; WAV byte-identical; PSC_STAR witness | BACKED | build.sh:5325-5368 |
| 58 | 60 | goertzel imports phonym's exported SR/SINEK/PSIN/VMIX/VSAMP | BACKED | phonym.la:114 export; goertzel.la:20 |
| 59 | 60 | Bhaskara sine <0.2% error | EXISTS-UNCHECKED | goertzel.la:40-44 comment |
| 60 | 60 | Love formants 300/870/2240 dominate controls 1350/3300/6700 by >500× (asserted ≥50×); sine self-detect | BACKED for ≥50×; ">500×" UNBACKED | goertzel.la:67-89; build.sh:5375 GZ_EXPECT |
| 61 | 61 | metaglyph: mode decompositions ⊗=▷(LOVE,RELATION) etc., 𝔑≡⊗, 𝔑(𝔑), ν*, κ(κ) | BACKED | metaglyph.la:65-71; build.sh:5902-5939 |
| 62 | 61 | sigil.la renders 5 mode sigils; phonym speaks ⊗ and ↻ | BACKED | build.sh:5034 (6 META incl. 𝓡), 5334-5335 |
| 63 | 62 | denote: MEANING homomorphism; ⊗(BEING,VOID)→pq; ↻(BEING)≡SELF→T; nested→rs | BACKED | build.sh:5707 DEN_EXPECT |
| 64 | 63 | pragmatics: 15 glyphs, 12 typed, witness string | BACKED | pragmatics_spec.la 15 entries/12 `::`; build.sh:5742-5826 |
| 65 | 64 | deixis: 15 glyphs, 11 typed, witness `me/you/rome/noon|…` | BACKED | deixis_spec.la 15/11; build.sh:5832-5896 |
| 66 | 65 | monosemy: no polysemy; ▷/⊂, assoc, idempotence stay distinct | BACKED (⊗-commutativity part CONTRADICTED, C3) | build.sh:6255-6308 |
| 67 | 66 | autoloop: STEP_OK verify-or-reject; three terminations asserted on 4-step mathutil goal | BACKED | build.sh:1425-1474 |
| 68 | 66 | "host==VM byte-identical … confirmed manually (codegen ~160s)" | UNBACKED | build runs host only |
| 69 | 67 | build.sh compiles host, runs kernel, verifies replication | BACKED | build.sh:211, 7187-7258 |
| 70 | 68 | new_logos_genN_pidP.bin byte-identical copy of host | BACKED | build.sh:7215, 7236 |

### Lingua Adamica syntax & built-ins (L70-131)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 71 | 80-85 | grammar: variables (UTF-8), `la x.`, left-assoc application, string escapes, parens, `#` comments | BACKED | tiny_host.c lex/parse_*; build.sh:2813-2843 fuzz_grammar |
| 72 | 89-91 | print coerces INT to decimal on every engine; other non-string halts | BACKED | tiny_host.c:746; build.sh:7061-7063 (VM `-42`) |
| 73 | 92-102 | copy_self → new_logos_gen{N+1}_pid{P}.bin, gen from own filename, stderr path, child≠parent (ETXTBSY) | BACKED | tiny_host.c:553-594; build.sh:7208-7251 |
| 74 | 103-104 | read_file | BACKED | build.sh:354-361 |
| 75 | 105-107 | write_file curried, returns content | BACKED | build.sh:368-379 |
| 76 | 108-110 | concat curried | BACKED | build.sh:215-221 |
| 77 | 111-114 | str_head/str_tail incl. empty | BACKED | build.sh:227-255 |
| 78 | 115-116 | str_eq → Church TRUE/FALSE | BACKED | build.sh:261-277 |
| 79 | 117-120 | chr(decimal string) 0..255; int literal rejected loudly on every engine | BACKED | build.sh:283-290, 7043 `chr(65)` guard; tiny_host.c:804-806 |
| 80 | 121 | ord | BACKED | build.sh:290 |
| 81 | 122-124 | str_len O(1), all engines | BACKED (O(1) by design: length-carrying) | build.sh:686-713; tiny_host.c `v->len` |
| 82 | 125-127 | write_exec 0755 | BACKED | build.sh:2912-2926 (logos_native runs) |
| 83 | 128-131 | strings binary-safe; NUL survives concat/write_file | BACKED | build.sh:342-347 |
| 84 | 87-127 | (omission) builtin list lacks str_at, band/bor/bxor/bshl/bshr/bnot, typeof, error which the host has | STALE (incomplete list) | tiny_host.c:500-534; build.sh:536,585 |
| 85 | 133-149 | Z combinator needed (CBV); IF thunking idiom | BACKED | build.sh:400-409 |

### Module system (L151-225)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 86 | 160-166 | import merges exports; privates alpha-renamed `__mod<N>_<name>` with subst | BACKED | tiny_host.c:951; build.sh:442-459 |
| 87 | 168-175 | three isolation properties (importer sees only exports; privates don't leak in; importer glyphs don't leak into module) | BACKED | build.sh:452-456 |
| 88 | 177-185 | stdlib exports four, app decoy IF/SECRET; build.sh checks both facts | BACKED | build.sh:452-456 |
| 89 | 187-193 | import/export on every engine (host + eval/bytecode/parser/codegen→VM); kernel.la stays import-free | BACKED | build.sh:464-505; kernel.la has no import/export |
| 90 | 195-208 | parse-time resolution; PARSE_MODULE/RENAME_FREE/MANGLE_MODULE/PRIVATE_NAMES; read_file builtin | BACKED (codegen names differ, C10) | parser.la/eval.la/bytecode.la glyphs |
| 91 | 206-213 | mangling `__mod_<sanitize p>__g` deterministic | BACKED (SANITIZE injective fix build.sh:3587-3601) | codegen.la SANITIZE; parser/eval/bytecode `__mod_` |
| 92 | 213-218 | greetapp identical line on all five engines; LogosIPC VM test imports logosipc.la for real | BACKED | build.sh:505, 6830-6864 |
| 93 | 220 | no import-cycle detection | BACKED (no cycle handling in any engine) | grep cycle/circular = none |
| 94 | 221-223 | diamond import merged twice harmlessly | EXISTS-UNCHECKED | no build test |
| 95 | 223-225 | import does not work under eval.la meta-evaluation (builtin table lacks error) | BACKED | eval.la builtin list lacks `error` |
| 96 | 181-185 | `export` of undefined glyph rejected on all 5 engines (mentioned at L322 "export-defined check") | BACKED | build.sh:646-681 |

### parser.la / eval.la (L227-330)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 97 | 232-241 | AST_VAR/LAM/APP/STR, SOME/NONE, CONS/NIL, PAIR | BACKED | parser.la glyphs |
| 98 | 245-249 | eval.la runs kernel: speaks and replicates byte-identically | BACKED | build.sh:7150-7160 |
| 99 | 251-259 | EVAL(ast)(env)(gl) closure-based | BACKED | eval.la EVAL/VAL_CLO |
| 100 | 260-264 | VAL_STR/VAL_CLO/VAL_BI/VAL_PA (+VAL_INT) | BACKED | eval.la glyphs |
| 101 | 265-275 | effects pass through via APPLY_BI/APPLY_BI2; lacks chr/ord/write_exec/error → `eval: unbound variable` | BACKED | eval.la:396; build.sh:340 (chr/ord absence asserted) |
| 102 | 276-278 | META_TRUE/META_FALSE | BACKED | eval.la glyphs |
| 103 | 279-280 | RUN_GLYPH / RUN | BACKED | eval.la |
| 104 | 284-290 | SHOW_SRC parenthesises lambda in function position; ESCAPE re-escapes | EXISTS-UNCHECKED (behaviour) / round-trip BACKED | build.sh:7147 "round-trip: stable" |
| 105 | 291-297 | SHOW_SRC runs at host level not under EVAL | EXISTS-UNCHECKED | design note |
| 106 | 301-316 | INNER = SHOW_PROGRAM; writes eval_reconstructed.la (git-ignored); normalised form; parse∘unparse fixed point | BACKED | eval.la:557-562; .gitignore:16; build.sh:7147-7149 |
| 107 | 318-321 | eval_reconstructed.la behaviourally identical (runs all five tests) | UNBACKED | build.sh does not run the reconstruction |
| 108 | 321-323 | glyph count reconstruction == source, 87 | BACKED (equality); literal 87 matches file today | build.sh:7139-7148 |
| 109 | 325 | "two self-parses take roughly 25 seconds" | UNBACKED | perf, no check |
| 110 | 327-330 | reconstruction reads eval.la rather than re-running MAIN | BACKED | eval.la:557 |

### bytecode.la (L331-451)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 111 | 336-340 | EMIT / PARSE_BYTES / DECODE | BACKED | build.sh:2900 |
| 112 | 342-357 | opcode table V/S/L/A, `;`-terminated escaped fields, example `Lx;AAVf;Vx;Sa\;b\\c;` | BACKED | build.sh:2865-2866 |
| 113 | 359-361 | every kernel glyph survives DECODE(EMIT) | BACKED | build.sh:2868 |
| 114 | 364-380 | RUN_BYTES executes bytes directly; SKIP_BYTES/SKIP_FIELD; BYTE_TRUE/FALSE | BACKED | glyphs exist; build.sh:2869-2871 |
| 115 | 382-386 | literal byte stream executes (`byte vm`); kernel from bytes speaks + byte-identical replicant | BACKED | build.sh:2869,2871,2875-2877 |
| 116 | 391-397 | COMPILE_EXPR/COMPILE_PROGRAM linear | BACKED (existence) | bytecode.la |
| 117 | 398-411 | SECD transition semantics | EXISTS-UNCHECKED (internals) / behaviour BACKED | build.sh:2873-2874 |
| 118 | 410-415 | only recursion is trampoline; gcc -O2 turns tail `return eval` into jump | UNBACKED | design claim, no check |
| 119 | 416-421 | eager-evaluation subtlety (handlers as lambdas) | EXISTS-UNCHECKED | — |
| 120 | 421-423 | `yes kept` from both engines; kernel on SM speaks + byte-identical replicant | BACKED | build.sh:2870-2877 |
| 121 | 436-450 | RUN_SM never calls COMPILE_* at run time; SM_TRUE_CODE/SM_FALSE_CODE literals; `TF` check | BACKED (`TF`) / discipline EXISTS-UNCHECKED | build.sh:2872 |

### Albedo (L452-625)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 122 | 458-462 | Stage 0: binary-safe strings, chr/ord/write_exec in C | BACKED | build.sh:283-347 |
| 123 | 463-470 | elf.la: BYTES helper; 64+56+36+15 layout; two raw syscalls; prints Word | BACKED | elf.la:13-40; build.sh:2917-2926 (171 bytes, output) |
| 124 | 468-469 | "byte-identical to an independently assembled reference" | UNBACKED | build checks size+output only; elf.la:14 comment only |
| 125 | 471-489 | secd.asm layout, S/E/C/D registers, tags STR/BI/CLO, opcodes | EXISTS-UNCHECKED (internals) | secd.asm |
| 126 | 492 | 13775 bytes | STALE (S1) | secd.la:5-11 |
| 127 | 493-503 | glyph table, all builtins lowered, str_eq Church closures compiled in (TRUE_BODY/FALSE_BODY), copy_self replicates, binary-safe descriptors | BACKED | secd.asm:3931-3932; build.sh:3817-3818 |
| 128 | 505-511 | codegen encoding VAR→02 n 00, STR→01, LAM→03 p 00 body 05, APP→f a 04; RET-terminated bodies skipped by paren-matching scan | BACKED | codegen.la:10-13; secd.asm:97-98 skipbody |
| 129 | 512-516 | native output diffed against RUN_SM for kernel.la + two programs; VM replicates itself | BACKED (replication asserted in bundle stage 3901, not here) | build.sh:3758-3818 |
| 130 | 517-550 | Stage 4: compiler.bin fixed point; VM re-emits itself; regenerated VM runs kernel | BACKED | build.sh:3825-3862 |
| 131 | 530-533, 544-550 | tiny_host seeds once; heap no longer a limit (GC); program need not ship as stream (Stage 5) | BACKED | build.sh:3825ff, 6889, 3870ff |
| 132 | 551-575 | Stage 5: progembed check, p_filesz at offset 96, p_memsz untouched, TAKE/DROP/LE with str_len, write_exec 0755 | BACKED | bundle.la:13,53-55; secd.asm:281-290,3953; build.sh:3870-3922 |
| 133 | 566-572 | bundled kernel.la and greetapp.la run standalone; Stage B bundle produced on the VM | BACKED | build.sh:3896-3922, 3925-3952 |
| 134 | 573-575 | embedded stream capped at progcap 5 MiB; lives twice in memory | BACKED (progcap) / "twice" EXISTS-UNCHECKED | secd.asm:3974 |
| 135 | 576-579 | drift guard: secd.la embeds nasm output; build checks byte-identity when nasm present | BACKED | build.sh:3752-3756, 3820 |
| 136 | 582-596 | native integers on all five engines; literal desugars to str_to_int; VM tag 4 INT, builtins 19-27 | BACKED (tag 4: secd.asm:3686) | build.sh:435,2905,3819,7176 |
| 137 | 597-608 | str_to_int strict on every engine; host `str_to_int: not a decimal integer`, VM `secd: not a decimal integer`; build checks reject/accept sets | BACKED | tiny_host.c:849-858; secd.asm:3829; build.sh:7065-7071 |
| 138 | 609-618 | codegen PARSE_PROGRAM halts loudly (`codegen: parse error near:`; error builtin id 30); build compiles malformed file on VM, checks non-zero | BACKED | codegen.la:162,172; build.sh:6960-6972 |
| 139 | 616-618 | bytecode.la/parser.la halt loudly via PARSE_MOD_LOOP `error` | EXISTS-UNCHECKED | glyph PARSE_MOD_LOOP in parser/bytecode/eval; no build test |

### LogosInit & syscalls (L626-777)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 140 | 628-635 | mount/fork/execve(argv=[path], env empty)/waitpid(status)/exit/write/read(64 MiB clamp)/open/close/pipe | BACKED | secd.asm:2370,2582,2500; build.sh:6365-6408 |
| 141 | 635-639 | unlink → 0 / -errno (-2 ENOENT) | BACKED | build.sh:6570-6588 |
| 142 | 639-646 | random(n) → min(n,256) via getrandom flags 0 | BACKED | secd.asm:2820-2837; build.sh:6593-6621 (300→256 clamp) |
| 143 | 645-649 | ints cross as decimal strings; pathbuf/fsbuf 4 KiB; path ≥4096 → `secd: path too long` | BACKED | secd.asm:2857,3099; build.sh:6944-6955 |
| 144 | 651-666 | Tier-0 fs: mkdir 83/rmdir 84/rename 82/chmod 90/lseek 8 SEEK_SET/stat 4 → "st_mode st_size" (offsets 24/48) | BACKED | secd.asm:2883-3047, 2983-2987; build.sh:6492-6565 |
| 145 | 668-680 | signals: sigprocmask(14), signalfd4(289), read 128-byte siginfo, kill(62), getpid(39); build round-trips SIGUSR1 | BACKED | secd.asm:3187,3204,3067,3210; build.sh:6565 |
| 146 | 682-699 | AF_UNIX socket/bind/connect/listen(backlog 16)/accept/send/recv(64 MiB); -errno returns; non-string halts; server binds before fork; build passes message + two failure paths | BACKED | secd.asm:2615-2772, 2639, 2668; build.sh:6435-6487 |
| 147 | 697-699 | limits: AF_UNIX only, pathname only, "no unlink builtin yet", no partial-send retry | AF_UNIX/pathname BACKED (no 'abstract' in secd.asm); unlink CONTRADICTED (C1); retry-loop absence EXISTS-UNCHECKED | — |
| 148 | 701-722 | poll(fds)(timeout) space-separated both ways; "" on timeout; -errno; cap 512 (`secd: too many poll fds`); non-string halts; build: idle timeout, two signalfds selective | BACKED | secd.asm:3215-3282; build.sh:6626-6673, 7096-7097 |
| 149 | 724-730 | reap = wait4(-1) returns pid, -ECHILD | BACKED | secd.asm:2413-2433; build.sh:6699 |
| 150 | 732-739 | reapnb WNOHANG: pid / "0" / -ECHILD | BACKED | secd.asm:2438-2451; build.sh:6726 |
| 151 | 741-742 | sleep(n) = nanosleep | BACKED | secd.asm:2469; build.sh:6802 |
| 152 | 744-762 | logosinit: mounts, blocks SIGTERM+SIGCHLD, signalfd before fork, child unblocks and exits 127 on failed exec, signalfd loop, reapnb drain, BACKOFF=1 throttle, SIGTERM clean exit 0 | BACKED | logosinit.la:73,80-81,92-98,115-119; build.sh:6760-6820 |
| 153 | 762-769 | build: reap 3 children; reapnb; PID-1 orphan reaping under unshare -rpf (2 reaps); announce/spawn/supervise/SIGTERM exit 0; tick.sh throttle in 4 s | BACKED (orphan test degrades to PASS-skipped if unshare unavailable, 6753) | build.sh:6678-6820 |
| 154 | 771-777 | tail-position self calls + VM TCO → bounded dump; 5M-iteration loop completes; non-tail recursion halts via guard | BACKED | secd.asm:1048; build.sh:6921-6941, 6893-6915 |

### Autopoiesis (L778-815)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 155 | 785-795 | reads gen from autopoiesis.gen; speaks; writes next gen; copy_self; fork+execve; parent waitpid; failed execve exits 127 | BACKED | autopoiesis.la:44-70 |
| 156 | 797-801 | no recursion combinator; loop is the process lineage | BACKED | autopoiesis.la (no Z) |
| 157 | 803-808 | VM copy_self always writes new_logos_secd.bin; ETXTBSY no-op re-copy; cap 3 | BACKED | secd.asm:3836; autopoiesis.la:44 CAP="3" |
| 158 | 809-815 | build: bundles, seeds medium 0, gens 0..3 speak, exactly 4, "lineage complete", exit 0, successor byte-identical | BACKED | build.sh:3957-4001 |

### LogosIPC & capabilities (L816-897)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 159 | 820-822 | exports list incl. ENCODE; helpers private | BACKED | logosipc.la:39 |
| 160 | 824 | message = TYPE NUL BODY | BACKED | logosipc.la:45-48 |
| 161 | 825-828 | SEND/RECV/MSG_TYPE/MSG_BODY/MSG_OK | BACKED | logosipc.la:68-71; build.sh:718-730 |
| 162 | 829-846 | transport swap touched only transport lines; CHANNEL=socket+bind+listen, ACCEPT, CONNECT; self-cleaning unlink; stale file test | BACKED (stale-file test 6830-6864) / "only transport lines changed" UNBACKED (history) | logosipc.la:64-71 |
| 163 | 846-847 | pathname sockets only | BACKED | secd.asm has no abstract-namespace path |
| 164 | 849-861 | build: host decode via ipc_demo; VM server/worker round trip with real import | BACKED | build.sh:718-730, 6830-6864 |
| 165 | 863-884 | logoscap SEAL/UNSEAL/BRAND, attenuation, composes with ENCODE; build checks authorized/foreign/forged on both engines | BACKED | logoscap.la:56-64; build.sh:735-763 |
| 166 | 884-891 | MINT("!") = BRAND(random("32")); VM-only demo proves distinct nonces | BACKED | logoscap.la:74; build.sh:766-791 |
| 167 | 891-897 | limits: gates access not ciphertext; revocation deferred; Γ-seal/schema/multiplexing deferred | STALE-partial (S14) | aead.la exists; poll exists |

### Theourgia (L898-1126)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 168 | 903-912 | Stage 1 SURFACE/COMPOSE/PPM; 32×24 desktop, red+green windows, header/size/pixels on both engines | BACKED | build.sh:4006-4038 (size 2317) |
| 169 | 914-935 | drm_mode ioctl sequence, returns "w h pitch"; present copies + DIRTYFB; non-string rejected | BACKED (DIRTYFB secd.asm:1946; present(5) guard build.sh:7053) / ioctl sequence EXISTS-UNCHECKED | secd.asm:1690-1946 |
| 170 | 936-939 | VM-only; drmbuf 64 KiB above program buffer | BACKED | secd.asm:3996 |
| 171 | 941-955 | needs DRM master; under compositor SETCRTC refused → loud halt; build asserts wired + fails cleanly only when graphical session present, skips otherwise | BACKED (text mismatch C9) | build.sh:4083-4121 |
| 172 | 944 | self-replicates the proof | CONTRADICTED (C8) | theourgia_drm.la |
| 173 | 956-965 | verified on real hardware 2026-06-12 via drm_bringup.sh; script refuses graphical session | UNBACKED (manual) / script guard BACKED | drm_bringup.sh:18-24 |
| 174 | 966-990 | Stage 3 TO_FB: BGRX, pitch pad, height pad; 26 rows × 160 pitch; pixel checks; engines diffed | BACKED | build.sh:4043-4078 (4160 bytes) |
| 175 | 991-1011 | Stage 4 decoder U16/U32/S32; KEY_A press + REL_X −3; WATCH VM-only manual | BACKED / WATCH EXISTS-UNCHECKED | build.sh:4124-4150 |
| 176 | 1012-1032 | Stage 5 STEP/APPLY_KEY/MOVE/RENDER; RIGHT,RIGHT,DOWN (4,4)→(6,5); pixels | BACKED | build.sh:4155-4191 |
| 177 | 1033-1063 | Stage 6 JOIN/SPLIT/DRAIN, SIMREAD; "7 5" drains fd 7 then fd 5; OPEN_OR_DIE | BACKED / live loop EXISTS-UNCHECKED | build.sh:4196-4228 (expects `join=5 7 9`, fd 7 then fd 5) |
| 178 | 1064-1091 | Stage 7 restates STEP/TO_FB locally (fb does not export TO_FB); DRAIN_STEP; "5 7" → (5,5) | BACKED | theourgia_fb.la has no export; build.sh:4233-4269 |
| 179 | 1092-1126 | Stage 8 font 8×8, bit 0 leftmost, A–Z 0–9 space, FONTDATA 296 flat, imports nothing; DRAW_TEXT "HI" 24×12 checks; text_live builds frame directly | BACKED / text_live EXISTS-UNCHECKED | theourgia_font.la:8,55; build.sh:4274-4312 |
| 180 | 1105 | ">10 min" old-font codegen slowness | UNBACKED | — |

### Primitives & typing (L1127-1191)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 181 | 1129-1137 | only Being had a definition before; primitives.la regenerated by build | BACKED (regeneration) | build.sh:1052-1058 |
| 182 | 1139-1146 | definitions RELATION/RECOGNITION/LOVE/SELF/VOID/BECOMING/FORM/DEPTH/DEPTH_Z | BACKED | primitives.la (verbatim match) |
| 183 | 1148-1156 | closed algebra; seven autologies pass META_DEBUG; BECOMING(BECOMING) higher-order; DEPTH(DEPTH) rc 124 both engines; `abcdefghi` | BACKED | build.sh:1054-1110 |
| 184 | 1158-1169 | DEPLOY type check: BARITY vs TARITY (paren-aware), TYPE ERROR rejects, no file | BACKED | specpipe.la:133-147,199,235; build.sh:2766-2769 |
| 185 | 1169-1174 | WF_TYPE grammar; MALFORMED TYPE rejects (DANGLE) | BACKED | specpipe.la:179,202; build.sh:2770-2771 |
| 186 | 1176-1180 | gradual: prose sigs `untyped (trusted)`; math/strutil/evdev untyped still deploy | BACKED | specpipe.la:204; strutil/evdev specs have 0 `::` and pass |
| 187 | 1180-1185 | primitives: 9 of 11 typed, SELF/DEPTH_Z trusted | BACKED | primitives_spec.la 9 `::`; build.sh:1064-1070 |
| 188 | 1185-1191 | typed_spec accepted; BADCONST rejected | BACKED | build.sh:2757-2791 |

### κ / canon (L1192-1294)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 189 | 1196-1203 | decomposition nodes PRIM/SYN/CON/DIR/CONT/MC Scott-encoded | BACKED | canon.la |
| 190 | 1205-1211 | CANON → prefix string e.g. `⊂(↻(DEPTH),⊗(BEING,FORM))`; order-preserving; renders by name | BACKED | build.sh:1300 W1 |
| 191 | 1213-1219 | IS = str_eq(κa)(κb); LAW_ID/LAW_NC/LAW_EM ≡ TRUE | BACKED | canon.la:29-35; build.sh W3 `INE=` |
| 192 | 1221-1226 | KAPPA=▷(RECOGNITION,FORM); κ(κ)=↻(▷(RECOGNITION,FORM)); KAPPA≡KAPPA | BACKED | canon.la:37; build.sh W2 |
| 193 | 1228-1236 | REVAL=▷(DEPTH,RECOGNITION); 𝓡≢κ; ↻(𝓡)→𝓡; NIS(↻𝓡)(𝓡) | BACKED | canon.la:39,89; build.sh:5913 (𝓡 distinct from κ and ⊂), W9 |
| 194 | 1238-1251 | MONO/REN/ETYM; REN≡CANON∘ETYM by construction; COLLAPSE deepens (DEPTH+1); AUTO_OK | BACKED | canon.la:63-77; build.sh W4-W6 (`d=2`, `Ah`) |
| 195 | 1253 | 29 glyphs | STALE (S3) | — |
| 196 | 1253-1257 | typed: logical core/laws/etymology typed; Scott modes, CANON, KAPPA, TDEPTH trusted | BACKED | build.sh:1259-1265 (20 typed / 29 trusted) |
| 197 | 1257-1258 | UTF-8 sigils round-trip codegen→SECD byte-identically | BACKED | build.sh:1303-1310 |
| 198 | 1264-1272 | NORMK commutative sort for ⊗ and ⊕ | CONTRADICTED for ⊗ (C2) | canon.la:91-93 |
| 199 | 1268-1272 | ↻(BEING)≡SELF rewrite; NIS | BACKED | canon.la:89,95; build.sh W7 `SELF` |
| 200 | 1272-1277 | honest bound: only declared equivalences collapse | BACKED (as design) | — |
| 201 | 1279-1291 | IS_ALPHA1 = str_eq(CANON)(NORMK); ⊕(A,B) α=1, ⊕(B,A) α<1, both → ⊕(A,B) | BACKED | canon.la:97-99; build.sh:1113-1116 (α binary guard), W8 `1<⊕(A,B)` |

### Sigil (L1295-1363)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 202 | 1304-1314 | SIGIL = r->c->bool over 32×32; integer primitives + MIRRORH/V/ROT180; byte-identical; 1-bit, colour dropped | BACKED | sigil.la:100,121-164; build.sh:5106 cmp |
| 203 | 1315-1329 | nine catalogue forms drawn as described | BACKED (via symmetry signatures) | build.sh:5028-5036 |
| 204 | 1330-1341 | derived concepts generated via five blend modes; Truth/Consciousness/Beauty/Being² | BACKED | sigil.la:402-403; build.sh:5022 (DERIVED Truth) |
| 205 | 1343-1355 | symmetry checks: Self/Recognition/Relation H+V; Void/Love/Form H-only; Becoming neither; Truth H | BACKED (Relation not in the check list — build tests Self, Recognition, Void, Love, Form, Becoming, Truth) | build.sh:5029-5036 |
| 206 | 1356-1363 | sigil_live details; not in build | EXISTS-UNCHECKED | sigil_live.la |

### Phonym (L1364-1440)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 207 | 1371-1389 | nine IPA phonyms; formant/f0/ADSR; VDYN energy trajectories | EXISTS-UNCHECKED (values) / synthesis BACKED | phonym.la:106; build.sh:5325-5368 |
| 208 | 1390-1403 | parabolic-sine oscillator, hash noise, O(n log n) builder, 44-byte header, byte-identical host==VM | BACKED (byte-identity, RIFF/WAVE) / complexity EXISTS-UNCHECKED | build.sh:5328-5348 |
| 209 | 1404-1424 | PSC*: PHONYM walks same nodes; operator phonology; ⊗ superposition over max window; 6/6 FFT recovery; PSC_STAR witness | BACKED except "6/6 FFT" UNBACKED | build.sh:5333-5335 (5 witnesses) |
| 210 | 1425-1435 | MAIN writes nine + three; build checks WAV + five witnesses + byte-identity; bringup_phonym.sh uses aplay | STALE (S8) / build BACKED / aplay BACKED (bringup_phonym.sh:42) | — |
| 211 | 1435-1440 | deferred: native ALSA builtin, spectral-interpolation blend, speech-to-glyph | ALSA absence BACKED; speech-to-glyph STALE (S9) | — |

### Metaglyph (L1441-1493)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 212 | 1448-1454 | prior state: modes had no glyph identity | UNBACKED (history) | — |
| 213 | 1455-1460 | decompositions + 𝔑≡⊗ | BACKED | metaglyph.la:65-71 |
| 214 | 1461-1485 | cascade: sigils (5 modes), phonyms (⊗,↻), 𝔑(𝔑), ν*, κ(κ), 𝓡=▷(DEPTH,RECOGNITION), 𝓡(𝓡)≡𝓡, distinct | BACKED | build.sh:5034, 5334-5335, 5905-5915 |
| 215 | 1487-1493 | pure str_eq/concat byte-identical; 4 of 5 decompositions are assignments | BACKED | build.sh:5926 cmp, 5938 NOTE |
| 216 | 1492 | ν* wiring is a further step | STALE (S6) | — |

### Metalogic (L1494-1562)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 217 | 1503-1509 | TRIBAR over GROUND(FORM); GROUND ∃(∃)→∃ | BACKED | metalogic.la:25,29 |
| 218 | 1511-1514 | YIELDS over VAL | BACKED | metalogic.la:27 |
| 219 | 1516-1525 | disagree on add(2,3) vs 5; ≡⟹=, =⇏≡ | BACKED | build.sh W4,W6 |
| 220 | 1527-1530 | three laws first-class, each autological, LAWS_AUTOLOGICAL | BACKED (LAWS_AUTOLOGICAL `Y` in W3) | build.sh:2494 |
| 221 | 1532 | LAW_IDENTITY def | CONTRADICTED (C4) | — |
| 222 | 1534-1541 | LAW_NC def; INHABITS = int_eq; DEPLOY rejects contradiction, no file | def CONTRADICTED (C5); INHABITS/DEPLOY BACKED | metalogic.la:59; build.sh:2529-2538 |
| 223 | 1542-1547 | LAW_EM def; VERDICT total; VERDICT_OR_DIE halts both engines | def CONTRADICTED (C6); VERDICT_OR_DIE BACKED | metalogic.la:73; build.sh:2513-2527 (checks "ill-formed term" diagnostic) |
| 224 | 1549-1553 | 25 glyphs; typed core; TERM witnesses trusted | STALE count (S4); typing split BACKED | build.sh:2464-2472 |
| 225 | 1554-1558 | witness string | STALE (S5) | build.sh:2504 |
| 226 | 1558-1562 | GROUND collapses one identity extensibly | BACKED | metalogic.la:25 |

### Glyph-DAG (L1563-1596)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 227 | 1565-1572 | flat DAG `def0;…;defk`, root last, dedup | BACKED | glyphdag.la DAG/ADDNODE |
| 228 | 1574-1583 | DAG/DECOMP/DCOLLAPSE; DAG(DECOMP(form))≡form; TSIZE | BACKED | build.sh:2697 |
| 229 | 1585-1592 | nodes 3 4 5 6 vs tree 3 7 15 31 | BACKED | build.sh:2697 "nodes 3..6 vs tree 3..31" |
| 230 | 1593-1596 | 47-glyph module, META_DEBUG, byte-identical | BACKED | build.sh:2696-2697 |

### SWC (L1597-1646)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 231 | 1599-1603 | prior: no static SWC | UNBACKED (history) | — |
| 232 | 1605-1614 | WF=0 / ILL=2 / UNKNOWN=1 classification; FIND_SA eager flag; SWC max | BACKED | swc.la:25-27; build.sh:2751 |
| 233 | 1619-1633 | operator-order ranks ∂=1…𝔄=5; ORD flags descendant rank > ancestor; 𝔄 inside δ = Pathology 3; well-ordered accepted; both engines | BACKED | swc.la:33-41; build.sh:2751 |
| 234 | 1635-1646 | conservative, UNKNOWN residue (Z); spec-first, byte-identical | BACKED | build.sh:2750-2751 |

### Evaluation (L1647-1659)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 235 | 1649-1654 | eager CBV, capture-avoiding subst with fresh `_gN` | BACKED | tiny_host.c:461,467 |
| 236 | 1654-1655 | glyph names resolve globally; builtins unless shadowed | BACKED | tiny_host.c:895-911 |
| 237 | 1657-1659 | SEQ ordering forces effects | BACKED | kernel.la; build.sh:7192-7202 |

### Build & run (L1660-1682)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 238 | 1664 | `./tiny_host` defaults to kernel.la | BACKED | tiny_host.c:1000 |
| 239 | 1668-1670 | success iff Word printed, `new_logos.bin` created byte-identical, gen-2 reproduces | STALE name (S2); rest BACKED | build.sh:7192-7236 |
| 240 | 1672-1682 | auto-checkpoint annotated tag `verified-<date>-<sha>`, clean tree only, skip if already tagged, NOTE on hiccup | BACKED | build.sh:7499-7518 (`git tag -a`) |

### Debugging principle (L1683-1705) — philosophy; one checkable item

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 241 | 1702-1704 | codices live in `codices/` | BACKED | directory exists |

### Extending / GC / guards (L1706-1819)

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 242 | 1708 | new builtins: is_builtin + apply_builtin | BACKED (also apply_builtin2) | tiny_host.c:500,624,741 |
| 243 | 1709-1711 | forms: lex, parse_*, Node, eval, subst | BACKED | tiny_host.c:50,195,288-312,467 |
| 244 | 1712-1719 | host conservative mark-sweep GC, setjmp register dump, GC_MIN_THRESHOLD, ABI-safe | BACKED (existence) | tiny_host.c:60-66,73,132,352-371 |
| 245 | 1714 | "~27 MB steady" | UNBACKED | no host-memory test |
| 246 | 1719 | "raising threshold 8× left wall-time unchanged" | UNBACKED | — |
| 247 | 1720-1729 | VM copying GC: two semispaces, margin 65 MiB (read_file 64 MiB), roots S/E/dump, 8-byte forwarding header, DATA copied inline | BACKED (constants) / algorithm EXISTS-UNCHECKED | secd.asm:3598-3620,3997,3605 |
| 248 | 1730-1735 | type-directed, gcwork 16 MiB; churn test ~1 GiB completes | BACKED | secd.asm:3960-3961; build.sh:6867-6889 |
| 249 | 1736-1739 | semispaces 768 MiB each | BACKED | secd.asm:3972 |
| 250 | 1739 | "compiling secd.la peaks at ~320 MiB" | UNBACKED | — |
| 251 | 1740-1748 | heap exhausted / stack overflow loud halts; stackmargin; build checks >1M-frame non-tail recursion | BACKED (3M-deep test) | secd.asm:3809,3811; build.sh:6893-6915 |
| 252 | 1749-1758 | TCO reuses frame; 5M tail loop completes; non-tail still guarded | BACKED | secd.asm:1048; build.sh:6921-6941 |
| 253 | 1760-1768 | `secd: unbound variable` (used to exit 0) | BACKED | secd.asm:3815; build.sh:7094 |
| 254 | 1769-1772 | `program too large` / `read error`; loader drains into progcap | BACKED (too large) / read error untested (stated) | build.sh:7100-7113 (6 MiB) |
| 255 | 1773-1775 | `malformed program` on rbx/skipbody overrun | BACKED | build.sh:7115-7125 |
| 256 | 1776-1777 | `chr out of range` matches host | BACKED | build.sh:7095; tiny_host.c:806 |
| 257 | 1778-1801 | `argument is not a string` on all string builtins + syscall builtins; print coerces INT | BACKED | build.sh:7005-7071 (25 guard cases) |
| 258 | 1802-1808 | C host stack guard 512 KB below RLIMIT_STACK | EXISTS-UNCHECKED | tiny_host.c:82-89,992-995; no build test |
| 259 | 1809-1819 | build regression-tests unbound / non-function / chr / poll fds / too large / malformed + stack/path/string/str_to_int/codegen | BACKED | build.sh:7079-7125 |
| 260 | 1816-1819 | exceptions: read error, heap exhausted not forced | BACKED (consistent) | — |

### Additional cross-cutting claims

| ID | Line | Claim | Status | Backing |
|---|---|---|---|---|
| 261 | 17,213 | "all five engines" = host, eval.la, RUN_BYTES, RUN_SM, native VM | BACKED | build.sh:505,713 |
| 262 | 20,35,36,37,38,39,41,44,46,47,48,49,51,53,54,57,59,60,61,62,63,64,65 | "byte-identical on host and VM" per module | BACKED (each has a host/VM cmp: build.sh:763,2697,2751,1310,1374,1419,2559,4038,4078,4150,4191,4228,4269,4312,5106,5348,5399,5926,5735,5826,5896,6306) | — |
| 263 | 33,35,36,37,38,41,42,43,63,64 | "regenerated by build.sh, never hand-written" for primitives/swc/glyphdag/canon/psc/metalogic/aatc/evdev/pragmatics/deixis | BACKED | each stage runs `./tiny_host <spec>.la` and asserts the .la written |
| 264 | 42 | aatc ρ graded 0..3; φ over Church lists Zc/FOLDR/FORALL | BACKED | aatc.la:63; build.sh:2650 (`131` = α1 ρ3 φ1) |
| 265 | 42 | DELTA 1 / ∞ | BACKED | aatc.la:41 |
| 266 | 42 | honest scope: SENSE_FILE structural facts only | BACKED | aatc.la:93-95 |
| 267 | 60 | goertzel byte-identical host/VM | BACKED | build.sh:5384 |
| 268 | 63 | 12 of 15 pragmatics typed | BACKED | pragmatics_spec.la 12 `::` |
| 269 | 64 | deixis CTX/PAIR/FST/SND trusted (11 typed) | BACKED | deixis_spec.la 11 `::` |
| 270 | 34,1186 | typed_spec 5 well-typed glyphs | BACKED | typed_spec.la 9 `::` (incl. BADCONST/DANGLE) |
| 271 | 40 | "coexists with sigil.la (does not replace SIGIL)" | BACKED | topoderive.la:24 imports sigil.la |
| 272 | 66 | autoloop imports specpipe.la | BACKED | autoloop.la:27 |
| 273 | 62 | denote imports metaglyph | BACKED | denote.la:22 |
| 274 | 20 | logoscap imports logosipc | BACKED | logoscap.la:38 |
| 275 | 58 | sigil_live imports sigil.la | BACKED | sigil_live.la:26 |
| 276 | 53,55 | text_live / font import only the font | BACKED | theourgia_text_live.la:27 |
| 277 | 46,48,51 | fb/session/mux import theourgia.la (+ input) | BACKED | import lines |
| 278 | 27,493 | VM `copy_self` replicates /proc/self/exe | BACKED | secd.asm:1497; build.sh:3901,3990 |
| 279 | 92-101 | `tiny_host` is generation 0; gen encodes depth; siblings distinct | BACKED | build.sh:7221-7251 |
| 280 | 7 (README-ish) | host applied to itself reproduces itself | BACKED | build.sh:7208-7215 |
| 281 | 30 | metadebug phases 1-4 (+ type system T1-T5 not mentioned in CLAUDE.md) | BACKED | build.sh:860-869 |
| 282 | 31 | DEPLOY writes, re-reads, verifies in one call; "on-disk == generated source" | BACKED | build.sh:886-887 |
| 283 | 31 | DEPLOY rejects a test-failing module (verify-or-reject) | BACKED (not stated in CLAUDE.md L31, which only mentions type errors) | build.sh:901-912 |
| 284 | 43 | "New modules are built this way — spec first, never hand-written" | UNBACKED (policy) | many later modules (sigil.la, phonym.la, denote.la, metaglyph.la…) are hand-written .la, not specs |
| 285 | 66 | mathutil.la SUMSQ body | BACKED | build.sh:1435 |
| 286 | 66 | budget exhaustion clean stop rc 0 "budget exhausted after 2" | BACKED | build.sh:1466-1469 |
| 287 | 66 | loud halt rc≠0 with "loud halt" message | BACKED | build.sh:1448-1452 |
| 288 | 57 | catalogue colour layer dropped | BACKED (1-bit predicate) | sigil.la |
| 289 | 59 | Compassion=Love⊗Recognition, Truth=↻Recognition, Recognition⊂Being witnesses | BACKED | build.sh:5332-5334 |
| 290 | 61 | 𝔑(𝔑,Being)=G_{⊗⊗Being} | BACKED | build.sh:5908 |
| 291 | 37 | SR_FROM naming note "resolved" | UNBACKED (editorial) | — |
| 292 | 36 | DCOLLAPSE re-interns; a=b unifies | BACKED (self-combine test) | build.sh:2697 |
| 293 | 41 | NC wired to type checker: INHABITS & DEPLOY reject | BACKED | build.sh:2529-2538 |
| 294 | 50 | poll_live OPEN_OR_DIE halts loudly on negative fd | EXISTS-UNCHECKED | theourgia_poll_live.la |
| 295 | 45 | drm builtins "VM-only; under the C host unbound" | BACKED | tiny_host.c is_builtin lacks drm_mode/present |
| 296 | 626-633 | process builtins VM-only | BACKED | tiny_host.c is_builtin list |
| 297 | 21,750 | child exits 127 on failed execve | BACKED | logosinit.la:73; autopoiesis.la:56 |
| 298 | 756 | BACKOFF default 1 s | BACKED | logosinit.la:80 |
| 299 | 768 | tick.sh "handful in 4 s" | BACKED (2..12) | build.sh:6812-6820 |
| 300 | 764 | unshare -rpf exactly 2 reaps | BACKED (or PASS-skipped) | build.sh:6741-6753 |
| 301 | 22,808 | "truly unbounded organism just raises the cap" | EXISTS-UNCHECKED | autopoiesis.la:44 |
| 302 | 553-560 | progembed aliases operand-stack base | BACKED | secd.asm:3953 `progembed equ ostack` |
| 303 | 560 | p_filesz patched with 8 LE bytes at 96 | BACKED | bundle.la:55 |
| 304 | 573 | progcap 5 MiB for file loader too | BACKED | secd.asm:292,3974 |
| 305 | 3820 vs 576 | nasm present → byte-identity check | BACKED | build.sh:3820 |
| 306 | 495-500 | builtins lowered: print/read_file/write_file/copy_self/concat/str_head/str_tail/chr/ord/str_eq | BACKED | secd.asm dispatch; build.sh:3796-3819 |
| 307 | 1004 | REL_X −3 signed decode | BACKED | build.sh:4127 |
| 308 | 1024 | window ends at (6,5) | BACKED | build.sh:4160 |
| 309 | 1079 | (5,5) after one cycle | BACKED | build.sh:4238 |
| 310 | 1113 | 'H' row0 verticals, row3 crossbar, 'I' advance | BACKED | build.sh:4278-4284 |
| 311 | 910 | 32×24 PPM header + size + overlaid pixels | BACKED | build.sh:4010-4014 |
| 312 | 982 | fb 26 rows × 160 pitch, bg `128 0 0 0`, pads zero | BACKED | build.sh:4047-4053 |

## Notes for the editor

- The two highest-value corrections are C1 (unlink) and C2/C3/S10 (⊗ commutativity and the rewrite-set size), because they misdescribe *current* semantics that build.sh actively asserts the opposite of.
- The three law definitions in the metalogic section (C4-C6) and the metalogic/canon glyph counts and witness (S3-S5) describe a pre-refactor module.
- Several "verified manually"/perf numbers (25 s, 160 s, 27 MB, 320 MiB, 8×, 500×, 6/6 FFT, 2026-06-12 hardware run) have no check in the tree and should either be labelled as anecdotal or dropped.
- `13775 bytes` (S1) is called out as wrong by secd.la's own header; drop the literal.
