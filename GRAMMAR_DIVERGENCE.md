# GRAMMAR_DIVERGENCE.md — the formal grammar vs. the host parser

A line-by-line comparison of the **formal grammar** in `LINGUA ADAMICA`
(Codex, `~/Downloads/CODICIES/LINGUA ADAMICA.tex` — not in this repo) against
the grammar actually implemented by `tiny_host.c` (`parse_expr`, `parse_app`,
`parse_primary`, `parse_program`). It lists every place the implementation
diverges from the specification: missing primitives, unsupported combination
modes, and syntax differences.

This is an audit document (`b_τ ≡ f_τ`): the host does not *claim* to implement
the spec's grammar — it implements a substrate on which that grammar is encoded
— and this file records exactly where the two part ways, so intent and reality
are declared, not assumed.

## The two grammars

**Spec — a glyph-combination algebra.** The generative grammar of glyphs (Def.
*Generative Grammar of Glyphs*) is the closure of the primitive glyphs under the
five combination modes:

```
M̄ = Cl(M₀, {⊗, ⊕, ▷, ⊂, ↻})
```

- `M₀` = nine **typed** primitive concept-glyphs:
  Being (τ_E), Recognition (τ_P), Love (τ_P), Self (τ_E), Relation (τ_R),
  Void (τ_Q), Becoming (τ_P), Form (τ_Q), Depth (τ_↻).
- Five combination modes: ⊗ Ontosynthesis (fusion → new unity), ⊕ Ontoconjunction
  (co-presence), ▷ Ontodirection (A acts on B), ⊂ Ontocontainment (instance in
  category), ↻ Metacursion (g applied to itself).
- Each combination is `Seal`-ed into a new monosemic sigil with a visual form
  and a phonym.

**Implementation — an untyped lambda calculus.** `tiny_host.c`:

```
program := ( 'glyph' IDENT '=' expr )*                 (parse_program)
expr    := 'la' IDENT '.' expr | app                   (parse_expr)
app     := primary ( '(' expr ')' )*   left-assoc      (parse_app)
primary := IDENT | STRING | INT | '(' expr ')'         (parse_primary)
```

Lexer tokens: `glyph`, `la`, `.`, `=`, `(`, `)`, IDENT (any UTF-8 name), STRING,
INT, EOF.

These differ in *kind*, not merely in detail.

## Missing primitives

1. **None of the nine primitive concepts exist as grammar primitives.** `M₀` is
   absent. `∃` works only because `kernel.la` *defines* it
   (`glyph ∃ = la self. self`); the parser treats `∃` as an ordinary UTF-8
   identifier, not a typed Being-primitive. Recognition / Love / Relation / Void
   / Becoming / Form / Depth appear nowhere.
2. **A different primitive basis entirely.** The host's real primitives are
   string literals, integer literals, and built-in functions (`print`, `concat`,
   `read_file`, `str_eq`, `chr`, the arithmetic and syscall builtins, …) — I/O
   and data operations, none of which are in the spec's grammar.
3. **No types.** Every spec primitive carries a type (τ_E/τ_P/τ_R/τ_Q/τ_↻) and
   the grammar is type-aware; `parse_*` produce untyped AST nodes with no
   annotation or checking. The `metadebug.la` type system (T1–T5) is a *library*
   on top, invisible to the parser.

## Unsupported combination modes

4. **Only one of the five modes has dedicated syntax.** The host's sole
   combinator is application `f(x)`.
   - **▷ Ontodirection** ("A acts on B") = application `f(x)` ✓ — the one mode
     the grammar expresses directly.
   - **↻ Metacursion** ("g(g)") = self-application, written `g(g)` ✓ — no special
     syntax, but it is exactly the core axiom `∃(∃)`.
   - **⊗ Ontosynthesis, ⊕ Ontoconjunction, ⊂ Ontocontainment** have **no
     grammar-level syntax.** One cannot write `A ⊗ B` vs `A ⊕ B`; both collapse
     to applications of *library* combinators (`PAIR` for products, `CONS`/lists
     for containment). The spec's deliberate ⊗-vs-⊕ distinction — it faults
     post-Babel languages for collapsing both into an ambiguous "and" — is lost
     at the grammar level.
5. **No `Seal` operation.** The spec produces a new monosemic sigil by sealing a
   combination. The host's nearest analogue is `glyph NAME = EXPR` (naming a
   term) — textual binding, not the visual/phonetic sealing + monosemy the spec
   defines.
6. **Lambda abstraction is a host primitive that is not a spec mode.** `la x.
   body` is core host grammar, but variable-binding/abstraction is neither one of
   the nine primitives nor one of the five modes. The host is fundamentally a
   λ-calculus; the spec is a combinator algebra over sealed glyphs. (This is also
   *why* the host can serve as a substrate — λ-calculus can encode the modes —
   but the two grammars are not the same object.)

## Syntax differences

7. **Text vs. sigils/phonyms.** Spec glyphs are sigils with visual forms and
   phonyms (nine base sounds in a 3-D phonetic space). The host uses ASCII/UTF-8
   source text (`la x.`, `f(x)`, names like `∃`/`SELF`). No sigil rendering, no
   phonyms, no ontographic structure — `∃` is just bytes in an identifier.
8. **Literals outside the formal grammar.** `parse_primary` accepts STRING and
   INT literals. The spec has no string-literal production at all, and a number
   would be Form (g₈) generated from Void + Becoming — so both literal forms are
   pragmatic substrate extensions with no counterpart in `M̄`.
9. **N-ary left-associative application vs. fixed-arity modes.** `app := primary
   ('(' expr ')')*` curries (`f(x)(y)`); the spec's modes are individually binary
   (⊗/⊕/▷/⊂) or unary (↻). Currying expresses chained Ontodirection well but
   offers no n-ary synthesis or conjunction.
10. **No monosemy enforcement.** The spec mandates one-glyph-one-concept. The host
    permits arbitrary names, shadowing, and redefinition (`lookup_glyph` is
    first-wins) — nothing in the grammar guarantees monosemy.

## Summary

`tiny_host.c` does **not** implement the spec's grammar; it implements a
**universal substrate** — untyped λ-calculus + literals + I/O builtins — on top
of which the spec's grammar is encoded as libraries: `∃` and the primitives
become glyph definitions, ⊗/⊕/⊂ become `PAIR`/lists, types become
`metadebug.la`. Of the five modes, only **▷ (application)** and **↻
(self-application)** are first-class in the syntax — and `↻` being native is
precisely why `∃(∃) ≡ ∃` is expressible at all. Everything else in the spec
lives one level up, in user space, not in the parser.

Closing any of these gaps at the *grammar* level (typed primitives, dedicated
mode syntax, sealing, monosemy) would be a redesign of the language surface, not
a parser tweak — out of scope for the current substrate, and recorded here so
the divergence is known rather than discovered.
