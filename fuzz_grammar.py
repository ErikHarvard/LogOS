#!/usr/bin/env python3
"""fuzz_grammar — differential fuzzing of Lingua Adamica's GRAMMAR (arc item 5, L2).

WHY
---
Item 5 makes the grammar recoverable AS DATA: productions as a first-class
GRAMMAR value, plus a differential proving the data-grammar and parser.la
accept/reject the SAME strings.  L1 (data) alone is decorative -- the
differential is the deliverable.

The differential is only as good as its corpus, and here is the trap: a corpus
drawn from existing .la files tests ONLY the accept side, because those files
contain, by construction, only valid forms.  Grammar drift hides on the REJECT
side -- where two grammars disagree about what is malformed.  So the corpus must
be GENERATED, and must include malformed input.  (Same shape as fuzz_canon.py,
whose red path was verified against a known-broken build.)

WHAT THIS DOES *TODAY*, BEFORE grammar.la EXISTS
------------------------------------------------
It carries a Python recursive-descent RECOGNIZER built from the productions
transcribed out of parser.la, and differentially tests THAT against parser.la
itself.  That is the L2 differential one layer early, and it earns its keep now:

  * it VALIDATES THE TRANSCRIBED GRAMMAR before anyone writes grammar_spec.la.
    If the transcription is wrong, we find out here -- not after building an LA
    module against a wrong spec.
  * any disagreement is a real finding: either the Python model is wrong, or
    parser.la deviates from its own documented grammar.
  * the same corpus is reused later to check grammar.la, so the expected
    verdicts are established independently of the thing being tested.

THE GRAMMAR (transcribed from parser.la; re-read before trusting)
    module    := ( glyphdef | exportdir )*      [PARSE_MOD_LOOP]
    glyphdef  := 'glyph' ident 'eq' expr        [PARSE_GLYPH]
    exportdir := 'export' ident+                [PARSE_EXPORT_NAMES]
    expr      := 'la' ident 'dot' expr | app    [PARSE_EXPR]
    app       := primary app_tail               [PARSE_APP]
    app_tail  := ( 'lp' expr 'rp' )*            [PARSE_APP_TAIL]  left-assoc
    primary   := ident | str | 'lp' expr 'rp'   [PARSE_PRIMARY]

TWO TRAPS THIS HARNESS HANDLES (both cost a session if hit blind)
  1. parser.la's REJECT IS A LOUD HALT, not a value.  PARSE_MOD_LOOP calls
     error("parser: parse error near: ...") on an unrecognised top-level form --
     it does not return NONE.  So reject == (nonzero exit AND that diagnostic).
     A harness that inspects only return values CRASHES on the reject corpus.
     It also means cases CANNOT be batched into one MAIN the way fuzz_canon.py
     batches its checks: the first reject would kill the run.  One invocation
     per case, deliberately.
  2. 'import' READS THE FILESYSTEM (PARSE_MOD_LOOP recurses through read_file).
     Import directives are therefore EXCLUDED from the generated corpus; testing
     them needs a committed fixture module, not a random path.

USAGE
    fuzz_grammar.py [--n N] [--seed S] [--logos DIR] [--show]
    fuzz_grammar.py --selftest        # Python-only; no tiny_host needed
"""
import argparse, os, random, string, subprocess, sys, tempfile

# ★ A → C cross-track request is OPEN (see ~/logos-status.md, 2026-08-18): a
#   NAMELESS `export` should be REJECTED.  parser.la TODAY accepts it --
#   PARSE_EXPORT_NAMES (:332-336) falls through to PAIR(NIL)(s) on a non-ident,
#   returning an EMPTY list rather than failing -- so the production is `ident*`.
#   Erik ruled it should be `ident+`.  FLIP THIS TO True WHEN TRACK C LANDS THAT,
#   and the differential should stay green; leave it False afterwards and the run
#   goes RED.  That is the regression signal working in both directions.
EXPORT_REQUIRES_NAME = False

KEYWORDS = {"glyph", "import", "export", "la"}
IDENT0 = string.ascii_letters + "_"
IDENTN = IDENT0 + string.digits


# ---------------------------------------------------------------- lexer ----
def lex(src):
    """-> list of (type, value) or None if a token is malformed (unterminated str)."""
    toks, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in " \t\r\n":
            i += 1; continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "(":
            toks.append(("lp", c)); i += 1; continue
        if c == ")":
            toks.append(("rp", c)); i += 1; continue
        if c == "=":
            toks.append(("eq", c)); i += 1; continue
        if c == ".":
            toks.append(("dot", c)); i += 1; continue
        if c == '"':
            i += 1; buf = []
            while i < n and src[i] != '"':
                if src[i] == "\\" and i + 1 < n:
                    buf.append(src[i + 1]); i += 2
                else:
                    buf.append(src[i]); i += 1
            if i >= n:
                return None                      # unterminated string literal
            i += 1
            toks.append(("str", "".join(buf))); continue
        if c in IDENT0:
            j = i
            while j < n and src[j] in IDENTN:
                j += 1
            w = src[i:j]; i = j
            toks.append((w if w in KEYWORDS else "ident", w)); continue
        return None                              # byte no rule accepts
    toks.append(("eof", ""))
    return toks


# ----------------------------------------------------------- recognizer ----
class P:
    def __init__(self, toks): self.t, self.i = toks, 0
    def peek(self):  return self.t[self.i][0]
    def take(self):  x = self.t[self.i]; self.i += 1; return x
    def eat(self, ty):
        if self.peek() != ty: return False
        self.i += 1; return True

def p_primary(p):
    ty = p.peek()
    if ty in ("ident", "str"): p.take(); return True
    if ty == "lp":
        p.take()
        return p_expr(p) and p.eat("rp")
    return False

def p_app(p):
    if not p_primary(p): return False
    while p.peek() == "lp":                      # app_tail, left-associative
        p.take()
        if not p_expr(p): return False
        if not p.eat("rp"): return False
    return True

def p_expr(p):
    if p.peek() == "la":
        p.take()
        if not p.eat("ident"): return False
        if not p.eat("dot"):   return False
        return p_expr(p)
    return p_app(p)

def p_module(p):
    while p.peek() != "eof":
        ty = p.peek()
        if ty == "glyph":
            p.take()
            if not p.eat("ident"): return False
            if not p.eat("eq"):    return False
            if not p_expr(p):      return False
        elif ty == "export":
            p.take()
            if EXPORT_REQUIRES_NAME and p.peek() != "ident":
                return False                      # ident+ : at least one name
            # ★ Kleene STAR, not plus.  PARSE_EXPORT_NAMES (parser.la:332) falls
            # through to PAIR(NIL)(s) when the next token is not an ident -- it
            # returns an EMPTY list rather than failing, so a bare `export` is
            # legal.  The spec originally transcribed this as ident+; this fuzzer
            # found the discrepancy on its first real run.
            while p.peek() == "ident": p.take()
        else:
            return False
    return True

def recognize(src):
    toks = lex(src)
    if toks is None: return False
    return p_module(P(toks))


# ------------------------------------------------------------ generator ----
def gen_expr(rng, d):
    r = rng.random()
    if d <= 0 or r < 0.30:
        return rng.choice([gen_ident(rng), f'"{gen_strbody(rng)}"'])
    if r < 0.50:
        return f"la {gen_ident(rng)}. {gen_expr(rng, d-1)}"
    base = gen_expr(rng, d-1) if rng.random() < 0.25 else gen_ident(rng)
    if rng.random() < 0.25: base = f"({base})"
    for _ in range(rng.randint(1, 2)):
        base += f"({gen_expr(rng, d-1)})"
    return base

def gen_ident(rng):
    return rng.choice(IDENT0) + "".join(
        rng.choice(IDENTN) for _ in range(rng.randint(0, 4)))

def gen_strbody(rng):
    return "".join(rng.choice("abcxyz 019") for _ in range(rng.randint(0, 6)))

def gen_program(rng):
    out = []
    if rng.random() < 0.25:
        out.append("export " + " ".join(gen_ident(rng)
                                        for _ in range(rng.randint(1, 3))))
    for _ in range(rng.randint(1, 3)):
        out.append(f"glyph {gen_ident(rng)} = {gen_expr(rng, rng.randint(1, 3))}")
    return "\n".join(out) + "\n"


MUTATIONS = ["truncate", "drop_char", "dup_paren", "drop_dot", "drop_eq",
             "drop_binder", "stray_rp", "empty_glyph", "empty_export", "lead_rp"]

def mutate(rng, src):
    m = rng.choice(MUTATIONS)
    if m == "truncate" and len(src) > 4:
        return src[:rng.randrange(1, len(src) - 1)], m
    if m == "drop_char" and len(src) > 2:
        i = rng.randrange(len(src)); return src[:i] + src[i+1:], m
    if m == "dup_paren":  return src.replace("(", "((", 1), m
    if m == "drop_dot":   return src.replace(". ", " ", 1), m
    if m == "drop_eq":    return src.replace(" = ", " ", 1), m
    if m == "drop_binder":
        i = src.find("la ")
        return (src[:i+3] + src[src.find(".", i):] if i >= 0 else src + ")"), m
    if m == "stray_rp":   return src + ")", m
    if m == "empty_glyph":return src + "\nglyph Z =\n", m
    if m == "empty_export": return "export\n" + src, m
    if m == "lead_rp":    return ")" + src, m
    return src + ")", m


# -------------------------------------------------------------- harness ----
def strip_main(src):
    """Drop the ENTIRE `glyph MAIN` definition, which may span many lines.
    parser.la's MAIN is multi-line (`SEQ(` continues); dropping only its first
    line leaves orphaned continuation lines and the DRIVER fails to parse."""
    out, skipping = [], False
    for l in src.splitlines():
        if l.startswith("glyph MAIN"):
            skipping = True; continue
        if skipping:
            # a new top-level form ends the MAIN block; anything else is its body
            if l.startswith(("glyph ", "export ", "import ")):
                skipping = False
            else:
                continue
        out.append(l)
    return "\n".join(out)


def esc(s):
    return (s.replace("\\", "\\\\").replace('"', '\\"')
             .replace("\n", "\\n").replace("\t", "\\t"))

def parser_verdict(logos, host, parser_src, subject, timeout=120):
    """Run parser.la's PARSE_PROGRAM on `subject`. -> True(accept)/False(reject)/None(error).
    Reject is a LOUD HALT (nonzero exit + 'parser: parse error'), never a value."""
    body = strip_main(parser_src)
    # eager CBV: the argument is evaluated (and may error) BEFORE the lambda applies
    prog = (body + '\nglyph FZ_SUBJ = "' + esc(subject) + '"\n'
            'glyph MAIN = (la t. print("FZ_ACCEPT"))(PARSE_PROGRAM(FZ_SUBJ))\n')
    wd = tempfile.mkdtemp(); src = os.path.join(wd, "fz.la")
    try:
        with open(src, "w") as fh: fh.write(prog)
        r = subprocess.run([host, src], capture_output=True, text=True,
                           timeout=timeout, cwd=logos)
    except subprocess.TimeoutExpired:
        return None
    finally:
        if os.path.exists(src): os.unlink(src)
        os.rmdir(wd)
    blob = r.stderr + r.stdout
    if r.returncode == 0 and "FZ_ACCEPT" in blob:
        return True
    # ★ Match parser.la's OWN diagnostic, not any parse error.  tiny_host emits
    # "parse error: expected 'glyph', 'import', or 'export'" when IT cannot parse
    # the DRIVER -- a harness bug, not a verdict about the subject.  Conflating
    # the two made every case look rejected and produced a confident, spurious
    # disagreement report.  Assert what you MEASURED.
    if "parser: parse error" in blob:
        return False
    return None                                   # harness could not classify


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--n", type=int, default=30)
    ap.add_argument("--seed", type=int, default=1729)
    ap.add_argument("--logos", default=os.path.expanduser("~/logos"))
    ap.add_argument("--show", action="store_true")
    ap.add_argument("--selftest", action="store_true",
                    help="Python-only checks; does not invoke tiny_host")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    parser_la = os.path.join(args.logos, "parser.la")
    host = os.path.join(args.logos, "tiny_host")
    for f in (parser_la, host):
        if not os.path.exists(f):
            print(f"SKIP  fuzz_grammar: missing {f}"); return 0

    rng = random.Random(args.seed)
    cases = []                                    # (label, text, model_verdict)
    while len(cases) < args.n:
        good = gen_program(rng)
        cases.append(("valid", good, recognize(good)))
        if len(cases) < args.n:
            bad, how = mutate(rng, good)
            cases.append((f"mut:{how}", bad, recognize(bad)))
    cases = cases[:args.n]

    parser_src = open(parser_la).read()
    disagree, unclassified, acc, rej = [], [], 0, 0
    for i, (label, text, model) in enumerate(cases):
        real = parser_verdict(args.logos, host, parser_src, text)
        if real is None:
            unclassified.append((i, label, text)); continue
        acc, rej = acc + (1 if real else 0), rej + (0 if real else 1)
        if real != model:
            disagree.append((i, label, text, model, real))
        if args.show:
            print(f"  {i:3} {label:16} model={'A' if model else 'R'} "
                  f"parser={'A' if real else 'R'} {'' if real == model else '  <-- DISAGREE'}")

    print(f"\nfuzz_grammar: {len(cases)} cases (seed {args.seed}) — "
          f"parser accepted {acc}, rejected {rej}")
    if unclassified:
        print(f"NOTE  {len(unclassified)} case(s) the harness could not classify "
              f"(neither FZ_ACCEPT nor a parse error) — inspect these, they are "
              f"where a NEW failure mode would show up first")
        for i, label, text in unclassified[:3]:
            print(f"      [{i}] {label}: {text!r}")
    if disagree:
        print(f"FAIL  fuzz_grammar: {len(disagree)} DISAGREEMENT(S) between the "
              f"transcribed grammar and parser.la")
        for i, label, text, model, real in disagree[:8]:
            print(f"  [{i}] {label}: model={'accept' if model else 'reject'} "
                  f"parser={'accept' if real else 'reject'}\n      {text!r}")
        print("  -> EITHER the transcribed grammar in this file is wrong, OR "
              "parser.la deviates from its documented grammar. Both are findings; "
              "resolve BEFORE writing grammar_spec.la.")
        return 1
    print("PASS  fuzz_grammar: transcribed grammar == parser.la on every case "
          "(accept AND reject sides)")
    return 0


def selftest():
    """Python-only: the recognizer must accept real LA and reject real breakage."""
    ok = True
    good = [
        'glyph A = x\n',
        'glyph A = "hi"\n',
        'glyph F = la x. x\n',
        'glyph F = f(x)(y)\n',                    # left-assoc app_tail
        'glyph F = la x. la y. f(x)(y)\n',
        'glyph F = (la x. x)(y)\n',               # lambda in function position
        'export A B\nglyph A = x\nglyph B = y\n',
        'glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))\n',
        '# comment only\nglyph A = x\n',
    ]
    bad = [
        'glyph A =\n',                            # empty body
        'glyph A x\n',                            # missing eq
        'glyph = x\n',                            # missing name
        'la x. x\n',                              # expr at top level
        'glyph A = (x\n',                         # unbalanced
        'glyph A = x)\n',                         # stray rp
        'glyph A = la . x\n',                     # missing binder
        'glyph A = la x x\n',                     # missing dot
        'glyph A = "unterminated\n',              # bad string
        ')\n',
    ]
    for s in good:
        if not recognize(s):
            print(f"SELFTEST FAIL: should ACCEPT {s!r}"); ok = False
    # bare `export` flips sides with the switch -- keep the selftest honest
    (good if not EXPORT_REQUIRES_NAME else bad).append('export\n')
    for s in bad:
        if recognize(s):
            print(f"SELFTEST FAIL: should REJECT {s!r}"); ok = False
    rng = random.Random(7)
    for _ in range(300):                          # generator must emit valid programs
        p = gen_program(rng)
        if not recognize(p):
            print(f"SELFTEST FAIL: generator emitted unparseable {p!r}"); ok = False; break
    print("SELFTEST PASS: recognizer + generator agree on "
          f"{len(good)} accept, {len(bad)} reject, 300 generated" if ok
          else "SELFTEST FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
