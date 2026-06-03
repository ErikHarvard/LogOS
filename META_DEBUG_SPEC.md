# META_DEBUG_SPEC.md — Implementation Guide for Self-Verifying LogOS
#
# This document specifies the meta-debugging and meta-updating architecture
# for LogOS. It is written for Claude Code to implement incrementally as
# Lingua Adamica matures. Each phase has prerequisites, implementation
# steps, and verification criteria.
#
# Core principle: Debug(Debug) = Debug. Update(Update) = Update.
# The debugging and updating tools are themselves glyphs, subject to the
# same verification as any other glyph. No special machinery — just
# self-application of the existing test infrastructure.

## Implementation notes (LogOS-specific adaptations)

The pseudocode below is illustrative. Three adaptations are required by the
language as it actually exists, and are applied in `metadebug.la`:

1. **Eager-evaluation thunking.** Lingua Adamica is call-by-value, so a bare
   `cond(then)(else)` evaluates *both* branches and recursion never
   terminates. Use the codebase idiom `IF(cond)(la _. then)(la _. else)` —
   `IF` forces only the selected thunk.
2. **Church numerals for `LENGTH`.** `ZERO`/`SUCC` are added; `NUM_BARS`
   renders a numeral as `|`-bars so a count is observable in tests.
3. **Single file.** There is no module system yet, and `DEBUG` must see all
   glyphs in one glyph table, so the whole system lives in `metadebug.la`.

## Current State (read tiny_host.c, eval.la, build.sh to verify)

The system currently has:
- Built-ins: print, copy_self, read_file, write_file, concat, str_head, str_tail, str_eq
- Self-hosting compiler: codegen.la compiles itself (byte-exact fixed point)
- Self-interpreting evaluator: eval.la evaluates eval.la
- Source reconstruction: eval.la reconstructs itself from AST (72 glyphs, round-trip stable)
- Test suite: build.sh with 39 tests (the SECD VM segfault is fixed)
- Church-encoded data: TRUE/FALSE, PAIR/FST/SND, CONS/NIL lists, Z combinator

The system does NOT yet have:
- A spec/test pairing mechanism for individual glyphs
- Runtime glyph replacement
- Rollback capability
- A standard library (MAP, FILTER, ALL, ANY, LIST_FIND)
- Types or a module system

## Architecture Overview

Five layers, each building on the previous:

```
Layer 0: SPEC    — each glyph paired with a test predicate
Layer 1: DEBUG   — run specs across all glyphs, report PASS/FAIL
Layer 2: META_DEBUG = DEBUG(["DEBUG", "VERIFY", "IS_AUTOLOGICAL"])
Layer 3: UPDATE  — replace a glyph, verify target + self, rollback on failure
Layer 4: META_UPDATE = UPDATE("UPDATE")(new_definition)
Layer 5: INTEGRITY_CHECK — the invariant that no operation may violate
```

The key insight: META_DEBUG is not a separate system. It is DEBUG applied
to the list of debugging glyphs. The "meta" level collapses into the
object level by self-application. Same for META_UPDATE.

## Phase 1: Standard Library Primitives (implement first)

Before building the test framework, Lingua Adamica needs list operations.
These should be implemented as .la glyphs using the existing Z combinator
and Church-encoded lists.

### Glyphs to implement:

```
glyph MAP = Z(la self. la f. la lst.
    IS_NIL(lst)
        (NIL)
        (CONS(f(HEAD(lst)))(self(f)(TAIL(lst)))))

glyph FILTER = Z(la self. la pred. la lst.
    IS_NIL(lst)
        (NIL)
        (pred(HEAD(lst))
            (CONS(HEAD(lst))(self(pred)(TAIL(lst))))
            (self(pred)(TAIL(lst)))))

glyph ALL = Z(la self. la pred. la lst.
    IS_NIL(lst)
        (TRUE)
        (pred(HEAD(lst))
            (self(pred)(TAIL(lst)))
            (FALSE)))

glyph ANY = Z(la self. la pred. la lst.
    IS_NIL(lst)
        (FALSE)
        (pred(HEAD(lst))
            (TRUE)
            (self(pred)(TAIL(lst)))))

glyph LIST_FIND = Z(la self. la key. la lst.
    IS_NIL(lst)
        (NIL)
        (str_eq(FST(HEAD(lst)))(key)
            (SND(HEAD(lst)))
            (self(key)(TAIL(lst)))))

glyph LENGTH = Z(la self. la lst.
    IS_NIL(lst)
        (ZERO)
        (SUCC(self(TAIL(lst)))))
```

### Verification:
- MAP(double)(list_of_3) returns list_of_6
- FILTER(is_positive)(mixed_list) returns only positives
- ALL(is_true)(list_of_true) returns TRUE
- LIST_FIND("x")(assoc_list) returns the value paired with "x"

Add these tests to build.sh.

## Phase 2: Glyph Spec Table (implement second)

Each glyph gets a paired test specification. The spec table is itself
a glyph — a list of (name, test_function) pairs.

### Implementation:

```
# A test case is a PAIR(input, expected_output)
# A spec is a list of test cases

glyph SPEC_TABLE = CONS
    (PAIR("ID")(CONS(PAIR("hello")("hello"))(NIL)))
    (CONS
        (PAIR("TRUE")(CONS(PAIR(PAIR("a")("b"))("a"))(NIL)))
        (CONS
            (PAIR("FALSE")(CONS(PAIR(PAIR("a")("b"))("b"))(NIL)))
            (NIL)))

glyph GET_SPEC = la name. LIST_FIND(name)(SPEC_TABLE)
```

As each glyph is added or modified, its spec entry in SPEC_TABLE must
be updated. The spec IS the documentation. There is no separate doc.

### Verification:
- GET_SPEC("ID") returns the test cases for ID
- Every glyph in the system has an entry in SPEC_TABLE
- build.sh checks: number of SPEC_TABLE entries = number of glyphs

## Phase 3: DEBUG and VERIFY (implement third)

### Implementation:

```
# VERIFY: run one glyph against one test case
# Returns "PASS" or "FAIL: expected X got Y"

glyph VERIFY_ONE = la name. la glyph_fn. la test_case.
    (la input. la expected.
        (la actual.
            str_eq(actual)(expected)
                ("PASS")
                (concat("FAIL: expected ")(concat(expected)(concat(" got ")(actual))))
        )(glyph_fn(input))
    )(FST(test_case))(SND(test_case))

# VERIFY_ALL: run one glyph against all its test cases
# Returns a list of (test_case, result) pairs

glyph VERIFY_ALL = la name. la glyph_fn. la specs.
    MAP(la tc. PAIR(tc)(VERIFY_ONE(name)(glyph_fn)(tc)))(specs)

# IS_AUTOLOGICAL: does a glyph pass ALL its specs?

glyph IS_AUTOLOGICAL = la name. la glyph_fn.
    ALL(la result. str_eq(SND(result))("PASS"))
        (VERIFY_ALL(name)(glyph_fn)(GET_SPEC(name)))

# DEBUG: verify a list of (name, glyph_fn) pairs
# Returns a list of (name, "PASS"/"FAIL", details)

glyph DEBUG = la glyph_list.
    MAP(la entry.
        (la name. la glyph_fn.
            (la autological.
                TRIPLE(name)
                    (autological("PASS")("FAIL"))
                    (autological
                        ("autological")
                        (concat("heterological: ")(name)))
            )(IS_AUTOLOGICAL(name)(glyph_fn))
        )(FST(entry))(SND(entry))
    )(glyph_list)
```

### Verification:
- DEBUG on a known-good glyph returns PASS
- DEBUG on a deliberately broken glyph returns FAIL
- Add a "test_debug" case to build.sh that creates a bad glyph
  and confirms DEBUG catches it

## Phase 4: META_DEBUG (implement fourth)

This is the collapse. No new code — just application.

```
# META_DEBUG: the debugger debugging itself
# DEBUG applied to the list of debugging glyphs

glyph META_DEBUG = DEBUG(
    CONS(PAIR("VERIFY_ONE")(VERIFY_ONE))
    (CONS(PAIR("VERIFY_ALL")(VERIFY_ALL))
    (CONS(PAIR("IS_AUTOLOGICAL")(IS_AUTOLOGICAL))
    (CONS(PAIR("DEBUG")(DEBUG))
    (NIL)))))
```

### Verification:
- META_DEBUG returns all PASS
- If you deliberately break VERIFY_ONE *so that it no longer always returns
  "PASS"* (e.g. make it always return "WRONG", or break a verified *candidate*
  passed to DEBUG), META_DEBUG catches it. **But see the blind spot below: a
  VERIFY_ONE broken to always return "PASS" is NOT caught.**
- Add "test_meta_debug" to build.sh

### The always-affirm blind spot (a real limit of self-verification)

META_DEBUG is `DEBUG` applied to the debugging glyphs, and `DEBUG` decides
PASS/FAIL via `IS_AUTOLOGICAL`, which runs each glyph's spec through
**`VERIFY_ONE` itself**. So `VERIFY_ONE` is both the thing under test and the
instrument doing the testing. If `VERIFY_ONE` is corrupted to **always return
`"PASS"` regardless of input**, then:

- every spec check it runs returns `"PASS"`, so `IS_AUTOLOGICAL` returns TRUE
  for *every* glyph — including the broken `VERIFY_ONE`;
- `DEBUG` therefore reports the broken `VERIFY_ONE` as autological;
- **`META_DEBUG` stays all-PASS — the corruption is not caught**, and the whole
  framework goes blind (`DEBUG_BAD` and `META_CATCH` flip to PASS too).

This is verified empirically: editing `glyph VERIFY_ONE` to `la name. la fn.
la tc. "PASS"` leaves `META_DEBUG: T`. A verifier broken to always affirm is a
fixed point that certifies itself — the autological criterion (`∃(∃) ≡ ∃`)
cannot ground a verifier that lies in its own favor, because it grades its own
lie with the same lie. (This is the self-reference analogue of "a consistency
proof of T from within T proves nothing if T is inconsistent.")

The mitigation is an **independent, external check** the framework cannot
rewrite: `build.sh` asserts that specific known-FAIL probes actually emit FAIL
strings (`DEBUG_BAD`, `META_CATCH`). Those catch a broken *candidate*, but note
they too are blinded by an always-`"PASS"` `VERIFY_ONE` — so the *ground* check
must ultimately live outside Lingua Adamica (the shell asserting on exact output
bytes). Self-verification narrows the space of undetected faults; it cannot
close it against a verifier that affirms everything, itself included.

## Phase 5: UPDATE and META_UPDATE (implement when runtime glyph replacement exists)

This phase requires a capability that does not yet exist: replacing a
glyph definition at runtime and rolling back if verification fails.

### Prerequisites:
- A mutable glyph table (currently glyphs are fixed after parse)
- A snapshot/restore mechanism for the glyph table
- write_file working for .la source (to persist changes)

### Implementation (design only — implement when prerequisites exist):

```
glyph UPDATE = la name. la new_def.
    (la snapshot.
        (la _. # glyph replaced
            (la target_ok.
                target_ok
                    ((la self_ok.
                        self_ok
                            (COMMIT(name)(new_def))
                            (RESTORE(snapshot)(concat("UPDATE became heterological")))
                    )(IS_AUTOLOGICAL("UPDATE")(UPDATE)))
                    (RESTORE(snapshot)(concat(name)(" became heterological")))
            )(IS_AUTOLOGICAL(name)(LOOKUP(name)))
        )(REPLACE_GLYPH(name)(new_def))
    )(SNAPSHOT_GLYPHS)

glyph META_UPDATE = la new_update_def.
    UPDATE("UPDATE")(new_update_def)
```

### Verification:
- UPDATE a glyph with a valid definition: accepted, spec passes
- UPDATE a glyph with a broken definition: rejected, rolled back
- META_UPDATE with a valid new UPDATE: accepted
- META_UPDATE with a broken new UPDATE: rejected, old UPDATE intact

## Phase 6: INTEGRITY_CHECK (implement last)

```
glyph INTEGRITY_CHECK =
    (la meta_ok. (la debug_ok. (la update_ok.
        AND(meta_ok)(AND(debug_ok)(update_ok))
    )(IS_AUTOLOGICAL("UPDATE")(UPDATE))
    )(IS_AUTOLOGICAL("DEBUG")(DEBUG))
    )(ALL(la r. str_eq(SND(r))("PASS"))(META_DEBUG))
```

Run INTEGRITY_CHECK after every commit. If it returns FALSE,
the system is in a heterological state and must be repaired
before any further changes.

Add to build.sh as the final test: "INTEGRITY_CHECK = TRUE"

## Honest Scope

What this architecture handles:
- Regressions (a change that breaks a previously passing spec)
- Spec violations (behavior ≠ declaration for any specified test case)
- Self-consistency (the debugging/updating tools are verified by themselves)
- Rollback on failure (no update can break the integrity invariant)

What this architecture does NOT handle:
- Wrong specs (if the spec itself is incorrect, tests pass but behavior
  is still wrong — requires human judgment to fix the spec)
- Novel attack vectors (a security exploit that no spec anticipated)
- Hardware changes (new devices, new drivers, external dependencies)
- Performance regressions (specs check correctness, not speed)
- Emergent behavior from component interaction (each glyph passes its
  own spec, but the composition might still misbehave)
- Self-affirming corruption of the verifier itself (a `VERIFY_ONE` broken to
  always return "PASS" certifies its own brokenness — see "The always-affirm
  blind spot" under Phase 4; the ground check must live outside the framework)

The system maintains itself WITHIN the space of formally specified
behavior. Outside that space, the sovereign extends the specs.

## Integration with build.sh

Each phase adds tests to build.sh:

Phase 1: "MAP/FILTER/ALL/LIST_FIND work correctly"
Phase 2: "SPEC_TABLE has entries for all glyphs"
Phase 3: "DEBUG catches known-good and known-bad glyphs"
Phase 4: "META_DEBUG returns all PASS"
Phase 5: "UPDATE accepts valid changes, rejects invalid ones"
Phase 6: "INTEGRITY_CHECK = TRUE" (final test, always last)

## For Claude Code

Implement these phases in order. Each phase depends on the previous.
Do not skip ahead. After each phase, run build.sh and confirm all
existing tests still pass before proceeding.

The spec table (Phase 2) should be updated every time a new glyph is
added to ANY .la file. This is a standing rule, not a one-time task.

When implementing Phase 5 (UPDATE), you will need to modify tiny_host.c
to support runtime glyph replacement. This is the only phase that
requires changes to the C host. Document the change and note that it
will be eliminated when the system is fully self-hosting.
