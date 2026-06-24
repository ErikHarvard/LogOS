# Freeze-day audit — native x86-64 backend (find phase, 2026-06-21)

Source: multi-agent static find workflow (6 lenses) over `native_codegen3.la`,
`native_codegen3_rt.asm`, `build.sh`, `kernel.la` vs `tiny_host.c` (the b_τ≡f_τ
reference). 22 raw findings → deduped + triaged below. This file is the durable
record (the workflow output lived in /tmp).

**STATUS (2026-06-23) — FIND + VERIFY + FIX all COMPLETE.** Verify workflow
adjudicated each empirically (native ELF vs `./tiny_host`, record in
`FREEZE_DAY_VERIFY.md`): 9 confirmed divergences + 3 latent code-confirmed
(#9/#10/#11). **All 12 actionable items #1–#12 are now FIXED, each with a
`build.sh` regression test, committed + pushed on `native-backend-stage3b`** (per-fix
commits a527c79 #1 · 10e3607 #2 · 7f499ae #3 · 272fb8b #4 · 0a4885a #5 · c17cd45 #6 ·
9765162 #7 · f4f08de #8 · 3792cdc #9 · d7186ac #10/#11 · #12 landing). #13 is
**accepted/documented** (not a bug — matches the SECD VM's fixed copy name); `typeof`
in the native backend is a **documented honest limit**. See `ROADMAP.md` (Stage 3 →
Freeze-day audit) for the consolidated fix list + honest limits.

Cardinal invariant: a compiled program's native stdout/exit must be **byte-identical
to `./tiny_host prog.la`**. Each item below is a suspected divergence or bug.

## HIGH — real divergence / memory corruption (fix first)

1. **GC blob overflow → FREEBLOB aliases REGDUMP (memory corruption).** PRE-EXISTING
   since 3b. `classidx` (rt asm ~88) has a lower clamp (≥5) but **no upper clamp**;
   `FREEBLOB: times 22 dq 0` (~1164) covers classidx 5..21 (max ~2 MB body). Any blob
   >~2 MB — `read_file` of a big file OR `concat` of large strings — yields classidx
   ≥22, and `FREEBLOB[r8*8]` runs past the array into `REGDUMP` (next label). The GC
   sweep re-bucket writes the dead blob's free-link into REGDUMP[0], corrupting the
   saved registers the GC epilogue restores. Fix: enlarge FREEBLOB (e.g. to ~32 entries,
   classidx up to 31 covers the 1.5 GB heap) + clamp classidx. Repro: write a >2 MB file,
   `print(str_len(read_file("big.txt")))`, native vs host (host prints the size).

2. **Non-STR argument → SIGSEGV (vs host/VM loud "argument is not a string").** CG_UN/
   CG_BIN emit no tag check; every string routine does `mov rcx,[rax+8]` then derefs. A
   boxed INT arg (tag 4, payload = the int) is derefed as a descriptor → wild read. Host
   halts loudly (tiny_host checks `v->t != N_STR`); SECD VM added `secd: argument is not
   a string`. Native uniquely crashes. Note `chr(65)` desugars to `chr(str_to_int("65"))`
   → boxed INT → rt_chr crash. Fix: tag-check (tag==0 STR) at the top of each string
   routine → loud halt. Repro: `print(str_len(add(1)(2)))` host=loud halt, native=SIGSEGV.

3. **rt_chr no 0..255 range check.** Accumulates full decimal, stores low byte only
   (`mov [numbuf], al`) → silent mod 256. Host: `chr: value N out of byte range 0..255`,
   exit 1 (tiny_host ~735); SECD VM has `secd: chr out of range`. Fix: range-check, loud
   halt. Repro: `print(ord(chr("256")))` host=loud halt, native prints `0`.

4. **rt_str_to_int lenient.** Skips a leading '-', then `(byte-'0')` for every byte, no
   digit/empty/lone-'-' validation. Host is STRICT (tiny_host ~779). Compile-time literal
   fold uses the host's strict version, so only a **computed** runtime str_to_int of a
   malformed string diverges. Fix: validate; loud halt `native: not a decimal integer`.
   Repro: `print(int_to_str(str_to_int(str_tail("x12x"))))` host=halt, native=garbage.

5. **rt_div / rt_mod raw `idiv`, no guards.** div0/mod0 → SIGFPE (exit 136) vs host's
   clean `div: division by zero` exit 1; `mod(LONG_MIN)(-1)` → host returns **0** (defined),
   native SIGFPEs (true result divergence). Fix: guard div0/mod0 (loud halt exit 1),
   LONG_MIN/-1 (div: loud overflow halt; mod: return 0). Repro: `print(div(5)(sub(3)(3)))`.

## MED — real, latent

6. **Negative int literal aborts the compiler.** `str_to_int("-5")` folds to
   `MOV_RAX_IMM(-5)` → `LE8(-5)` → `LEBYTES` uses signed C `mod` so `B(mod(-5)(256))` =
   `chr("-5")` → host chr rejects negative → **compile fails** on a host-valid program.
   Fix: make `LEBYTES`'s byte extraction unsigned 0..255 (e.g. `mod(add(mod(n)(256))(256))(256)`).
   Repro: `print(int_to_str(str_to_int("-5")))` host prints `-5`, native compile aborts.

7. **Module mangle collision.** `MANGLE` = `__mod_<SANITIZE path>__name`; `SANITIZE`
   maps every non-ident char → `_`, so `sub/m.la`, `sub.m.la`, `sub_m.la` all → `sub_m_la`.
   Two imported modules with colliding sanitized paths + same-named PRIVATE glyph → both
   mangle identical → LOOKUP_GLYPH first-match resolves one module's export against the
   other's private. Host uses a unique monotonic counter (`__mod%lu_`). Fix: add a unique
   per-import index to the mangle. Latent (repo uses flat same-dir filenames).

8. **write_file (and typeof) not in the native backend.** Host has both (write_file is a
   normal non-VM builtin). Native IS_BUILTIN2 lacks write_file → a using program fails to
   compile (`unbound name: write_file`), where the host runs it. Fix: add rt_write_file
   (= write_exec without chmod 0755; open mode 0644) + wire it. typeof: defer/document.
   SAFETY: when adding write_file to IS_BUILTIN2, also add its RT_BIN case — else RT_BIN's
   fall-through silently dispatches it to rt_write_exec (chmod 0755).

## LOW — robustness / honest-limit (cheap fixes or document)

9. **`export la` not stopped by IS_KEYWORD.** `la` lexes as a plain "name"; IS_KEYWORD
   omits it, so PARSE_EXPORT_NAMES would collect `la`. Trivial fix: add "la" to IS_KEYWORD.
10. **copy_self no short-write loop.** Single `write` per 64 KB chunk, return ignored
    (write_exec's `.wr` DOES loop). Cheap fix: mirror the write_exec loop.
11. **copy_self `r15` scratch no HEAP_END bound.** 64 KB read into [r15, r15+65536) with
    no check; a near-full heap overruns the mapping. Latent (copy_self runs heap-near-empty).
12. **read_file no lseek-fail guard.** lseek=-1 (non-seekable) → alloc_blob(-1) misallocs
    + unbounded read. Cheap `js` guard like the open-fail path.
13. **copy_self fixed name `new_logos_native.bin` vs host's gen/pid name.** The RETURNED
    string diverges if a program prints it (kernel discards it via SEQ). **ACCEPTED** — this
    matches the SECD VM's own fixed-name `new_logos_secd.bin` behavior (documented). Document,
    do not "fix".

## Triage for the fix pass (morning)
Fix order: #1 (corruption) → #2 (SIGSEGV guards) → #3,#4,#5 (chr/str_to_int/div-mod) →
#6 (neg literal) → #7 (mangle) → #8 (write_file) → #9,#10,#12 (cheap lows). Each fix gets
a build.sh regression test (native==host on its repro). Re-derive RT addresses after any
asm change (dq-label recipe). Document #11, #13, typeof as honest limits.
