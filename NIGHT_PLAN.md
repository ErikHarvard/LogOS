# Night plan — 2026-08-22 → 23   (Track A / kernel-k1)

Last night's plan and its results are preserved in `NIGHT_PLAN_2026-08-22.md`.

## The state I am starting from
The build is GREEN with all 40 kernel gates (`PASS=214 FAIL=0`), the crypto
substrate is complete and RFC-verified on two engines, and `gate_crypto.sh` is
wired — **42 gate invocations**. **98 files are uncommitted** and this session
cannot commit or push; that is unchanged and correct.

## Task 1 — the full build, all 42 gates  (RUNNING, ~3 h)
Log `~/.build_night2.log`. Last full build was 2 h 56 m; the crypto gate adds
~6 min. This is the real verification of tonight's 98 files: the crypto gate was
proven standalone and inside a build stopped at line 379, but never alongside all
40 kernel gates. **If this is RED, everything below is cancelled and I stop.**

## Task 2 — Freeze-Day Audit II, at last  (static, runs DURING the build)
`audit_gates.py` has existed since 2026-08-18 and has never been run in anger.
It triages build.sh's ~600 assertions by DISCRIMINATING POWER — *which checks
cannot go red?* It is pure static analysis: it reads build.sh and spawns nothing,
so it cannot collide with the running build.

**Tonight is the right night for it.** In one session I found two more checks that
could not fail, both by accident while looking at something else:

  * `chacha20.la`'s BLOCK fed forward hardcoded constants equal to its own test
    vector's key — a block function ignoring its key would have passed.
  * my own forged-tag control passed the GENUINE tag, testing the accept path.

That is cases 5 and 6 in a codebase where the first four were also found by
accident. Accident is not a search. This is the search.

Output: a ranked worklist, then hand-review of the top suspects. Findings append
to `FREEZE_II_FINDINGS.md`. **A clean report is NOT evidence a gate can fail** —
the tool's own docstring says so, and I will not report it as though it were.

## Task 3 — mutation-test the standalone gates  (AFTER the build)
Audit II asks which checks cannot go red; Task 2 *guesses* statically. This
*proves* it: for each standalone gate script, perturb the expected value in a
copy and confirm the gate goes RED, then confirm the unperturbed copy goes GREEN.

Two traps already hit tonight, both encoded in the runner:
  * a gate copied outside the repo dies on `cd "$(dirname "$0")"` and fails for
    the WRONG REASON — a red that proves nothing. Copies live in `~/logos`.
  * the red must name the REAL output, not a missing binary.

Cheap gates first (`gate_sha256`, `gate_crypto`, root gates), then kernel gates
in ascending measured cost, bounded by wall-clock. **Anything skipped is named**
— silent truncation reads as full coverage.

## Task 4 — only if 1–3 finish clean: HMAC-DRBG
The other half of ROADMAP G1's remaining gap. `hmac.la` is verified, so a
NIST SP 800-90A HMAC_DRBG is reachable, with published known-answer vectors.
Same discipline as tonight: **model it in Python and match the vectors BEFORE
writing a line of LA.** That caught every poly1305 transcription error in
seconds instead of minutes-long interpreter runs.
This does NOT close G1 — entropy ON THE METAL is a kernel-level absence a DRBG
cannot fix, and I will not let a green DRBG read as though it did.

## HARD RULES  (unchanged — every one of these was learned the expensive way)
  * **NEVER push.** The pre-push hook blocks agents by design.
  * **NEVER commit** — no private `/tmp`; the guard refuses, correctly.
  * **Never edit `build.sh` or `kernel/*.sh` while a build runs** — `/bin/sh`
    reads scripts lazily by byte offset; editing one mid-run corrupts it.
  * **Never touch repo-root scratch while a build is live** (`logos_secd`,
    `logos_program.bin`, `logos_source.la`). Racing those killed a 2-hour run.
  * **Stop on the first red in EXISTING verified work.** A red in Task 4's new
    module is iteration, not a fire — but it is bounded, and it is reported.
  * `pgrep -f` self-matches. Use exact PIDs. This misread the process list twice
    more tonight, including once while checking whether the repo was idle.
  * Killing a parent does not kill its grandchildren: `logos_secd` reappeared
    30 s AFTER a cleanup reported zero leftovers. Re-check after a settle.

## Morning queue (needs Erik)
  * `~/logos-agent a` then `./commit_all.sh` — 98 files, more by morning
  * `git push --no-verify origin kernel-k1`
  * `~/logos-tools/setup_tracker.sh` + one DNS record
  * `ghost start` on the VPS — still 502
