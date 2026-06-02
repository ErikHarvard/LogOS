# TYPE_SYSTEM_SPEC.md — Dependent Types as Specifications for LogOS
#
# Design document. Written for Claude Code to implement incrementally,
# AFTER review. No code is added by this document; it specifies the
# architecture, maps every construct to the Lingua Adamica primitives,
# and states the autological admission rule.
#
# Core principle: a TYPE IS A SPECIFICATION. To type-check a value is to
# verify b_τ ≡ f_τ for it. The type system is not new machinery bolted on
# — it is metadebug.la's spec table, read as a type discipline.

## The Thesis: Type ≡ Spec ≡ b_τ ≡ f_τ

A type is a declaration of what a value must be. A spec (metadebug.la) is
a declaration of what a glyph must do. They are the same act:

| Type theory            | LogOS today (metadebug.la)        | Codex criterion          |
| ---------------------- | --------------------------------- | ------------------------ |
| value `x : A`          | glyph passes spec `A`             | `T(C) ≡ R(C)` (test v)   |
| type-checking          | `IS_AUTOLOGICAL(name)(glyph)`     | the Law of Admission     |
| the checker is typed   | `META_DEBUG` (checker checks self)| `C(C) = C` (test iv)     |

So **the type-checker already exists**: it is `IS_AUTOLOGICAL`. What this
document adds is (a) types as first-class predicates, (b) the five type
constructors as the five modes of combination, and (c) *dependent* types,
made concrete and checkable by the native integers just added.

## Mapping to the Nine Primitives and Five Modes

A **type is Form** (`g₈`, `τ_Q` — "pattern; structure; constraint"): it
constrains which values are well-formed. The nine primitives already
carry types (`τ_E, τ_P, τ_R, τ_Q, τ_↻`), so a type system is *endogenous*
to Lingua Adamica, not imported.

**Inhabitation** (`value : type`) is **Ontocontainment (`⊂`)** — instance
within category. The spec's theorem `g_C ⊂ g_E` (every concept is a region
of Being) is the top type: every well-formed value `⊂ τ_E`.

The five type constructors are the five modes of combination:

| Constructor      | Mode                   | Meaning                                   |
| ---------------- | ---------------------- | ----------------------------------------- |
| Product `A ⊗ B`  | Ontosynthesis (`⊗`)    | a value of A *and* B, fused (our `PAIR`)  |
| Sum `A ⊕ B`      | Ontoconjunction (`⊕`)  | a value of A *or* B (a tagged union)      |
| Function `A ▷ B` | Ontodirection (`▷`)    | maps A to B; A acting toward B (the arrow)|
| Refinement `A⊂P` | Ontocontainment (`⊂`)  | `{x : A \| P(x)}` — A constrained by P    |
| Recursive `↻A`   | Metacursion (`↻`)      | a type defined by self-reference (`Depth` g₉, `τ_↻`) |

**Type-checking self-applies (`↻`):** the checker has a type and must
inhabit it. `META_DEBUG` already demonstrates this — the type-of-types is
a type.

## A type is a predicate (refinement is the base case)

The most primitive type is a **predicate** — a glyph returning a Church
boolean:

```
# A type is a glyph  A : value -> Church bool.  x : A  iff  A(x) = TRUE.
glyph IS_INT  = la x. ...   # true iff x is a native integer
glyph HAS_TYPE = la A. la x. A(x)          # the inhabitation judgement
```

A metadebug **spec** is a *sampled* type: its test cases are points of the
predicate. A full type is the predicate itself. The spec table is thus a
table of (partial) types; `IS_AUTOLOGICAL` checks membership at the sample
points.

## Dependent types via native integers

A **dependent type** is a type indexed by a value. The native integers
just added make the index concrete and checkable. Canonical examples:

```
# Fin n — the integers 0 ≤ x < n. A type depending on the value n.
glyph FIN = la n. la x. AND(NOT(lt(x)(0)))(lt(x)(n))

# Vec n A — a list of exactly n elements, each of type A. Length depends
# on the value n (checked with native LENGTH', the integer-valued length).
glyph VEC = la n. la A. la xs.
    AND(int_eq(LEN(xs))(n))(ALL(A)(xs))
```

The **dependent function type (Π)** generalises `A ▷ B`: the result type
depends on the *argument value*. The probe-based test cases in metadebug.la
are already value-dependent (the expected output is computed from the
input), so they are proto-Π-types; integer indices make the dependency
explicit:

```
# Π(n : Int). Vec n Int -> Vec (add n 1) Int   (e.g. "append one element")
# The codomain type (Vec (add n 1) Int) mentions the argument value n.
```

This is where "types are specifications" becomes load-bearing: the type
of a function IS its full behavioural spec, and a dependent type lets the
spec quantify over the very values it constrains.

## Layered Implementation (each phase: a mode, a primitive, a self-test)

Implement only after review; each phase mirrors META_DEBUG_SPEC's
discipline (add to build.sh, confirm prior tests pass, never skip ahead).

**Phase T1 — Types as predicates (Refinement, `⊂`).**
`HAS_TYPE(A)(x) = A(x)`; base types `IS_INT`, `IS_STR`-via-affordance,
`IS_BOOL`. Verify: `HAS_TYPE(IS_INT)(42) = TRUE`, `HAS_TYPE(IS_INT)("x") =
FALSE`. *Autological:* `IS_INT` is itself a glyph with a spec; it must pass.

**Phase T2 — The five type constructors (the five modes).**
`PROD/SUM/ARROW/REFINE/REC` as above. Verify each constructor builds a
predicate that accepts/rejects correctly. *Autological:* each constructor,
applied to itself where meaningful, yields a type (`REC` is the `↻` case).

**Phase T3 — Dependent types (native integers).**
`FIN`, `VEC`, and one Π-type example. Verify `HAS_TYPE(FIN(5))(3)=TRUE`,
`HAS_TYPE(FIN(5))(7)=FALSE`, `HAS_TYPE(VEC(3)(IS_STR))(["a","b","c"])=TRUE`.
*Autological:* the index arithmetic is the already-autological integer ops.

**Phase T4 — TYPECHECK = autological check.**
`TYPECHECK(A)(x)` returns `"well-typed"` or a typed error, reusing
`VERIFY_ONE`'s shape. Fold types into `SPEC_TABLE`: a glyph's type is its
spec. *Autological:* `TYPECHECK` has a type and type-checks itself.

**Phase T5 — The type-of-types (`↻`, the meta-collapse).**
`IS_TYPE(A)` — A is a type iff it is a total predicate. `IS_TYPE(IS_TYPE)`
must hold (restricted to the well-founded fragment — see Honest Scope).
This is the `C(C)=C` closure for the type system, the analogue of
`META_DEBUG`.

## Integration with build.sh

| Phase | build.sh assertion |
| ----- | ------------------ |
| T1 | "HAS_TYPE accepts inhabitants, rejects non-inhabitants" |
| T2 | "PROD/SUM/ARROW/REFINE/REC build correct types" |
| T3 | "FIN/VEC dependent types check against integer indices" |
| T4 | "TYPECHECK agrees with IS_AUTOLOGICAL on the spec table" |
| T5 | "IS_TYPE(IS_TYPE) = TRUE (type-of-types closure)" |

## Honest Scope

What this design buys:
- A type discipline with **zero new criterion**: type-checking IS the
  autological check already implemented.
- Dependent types grounded in the native integers, not a separate kernel.
- Every constructor justified by a mode of combination.

What it does NOT solve (named, not hidden):
- **No `Type : Type`.** Full impredicative type-of-types is inconsistent
  (Girard's paradox). LogOS restricts to the **well-founded fragment** the
  Lingua Adamica codex already invokes for the Gödel case; `IS_TYPE` is
  total only on that fragment.
- **No inference.** Checking is bidirectional/explicit: a value is checked
  against a given type. There is no Hindley–Milner reconstruction.
- **Decidability/termination.** The language is Turing-complete (via `Z`),
  so an arbitrary predicate-type may not terminate. Admit only **total**
  predicates as types; structural/integer-bounded predicates are total by
  construction.
- **Sampled vs. universal.** A spec checks sample points; a type asserts a
  universal. The gap is the same one META_DEBUG_SPEC names: a wrong/weak
  type passes while the value misbehaves off-sample. Strengthening a type
  = adding cases until the predicate is total.

## The Autological Admission Rule (why only some features get in)

A type-system feature is admitted iff it survives self-application:
1. It can be given a type (spec).
2. It passes that type under `DEBUG`/`TYPECHECK`.
3. The checker, extended with it, still checks itself (`META_DEBUG`/T5
   stays `TRUE`).

This is exactly how native integers were admitted (they are specced in
metadebug.la and `ALL_SPECCED`/`META_DEBUG` remain `TRUE`). Any construct
that cannot be specced, or that breaks the checker's self-check, is
heterological and rejected — `b_τ ≢ f_τ` is not a bug to fix later but a
non-admission now.

## For Claude Code

Implement T1→T5 in order, after the user approves this design. Each phase
adds a build.sh assertion and must leave all prior assertions green. The
type of every new glyph is its spec-table entry (the standing rule from
META_DEBUG_SPEC applies). Types live in metadebug.la (one glyph table) until
a module system exists.
