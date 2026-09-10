#!/usr/bin/env python3
"""
mutate.py — THE MUTATION LEVER, EXTENDED PAST THE 2 GATES IT COULD REACH.

The standing lever perturbs an EXPECTED VALUE and requires the check to fail.
It reaches 2 of 46 gates, because 44 assert inline over emitted output rather
than against a named constant -- there is no constant to perturb.

This perturbs the IMPLEMENTATION instead. That works regardless of assertion
style, and it is the only instrument that reaches the fourth vacuity axis:

  1. can the check go red at all?                 audit_gates.py
  2. is the pinned literal load-bearing?          branch-condition sweep
  3. is the expected value independently grounded? provenance census (not static)
  4. is the COMPUTATION independent of the EXPECTATION?   <-- only mutation

Axis 4 is where chacha20's shipped defect lived: its MARK was structurally
identical to sha256's, so the branch condition was impeccable while BLOCK fed
forward constants equal to the test vector's own key. Nothing static sees that.

★ EVERY MUTANT NEEDS ITS OWN WITNESS THAT IT DIED OF THE INTENDED CAUSE.
This is not a refinement, it is the difference between a working harness and a
harness that lies. A mutant that dies with `parse error` or `unbound variable`
or `attempt to apply a non-function` is a RED FOR THE WRONG REASON: the gate
did not detect the semantic change, the program merely failed to run. Counting
it as CAUGHT concludes that the gate catches something it does not. So a crash
is reported as INVALID and demands a rewritten mutant, never as a pass.
(Learned from track-e, where a malformed wrap-to-0 mutant died with
`attempt to apply a non-function`; the CORRECT mutant then passed six of the
register's own checks and was caught only by a seventh arm that looked
redundant. Reasoning would have deleted the arm that worked.)

Verdicts:
  CAUGHT    the gate reported FAIL, and not from a crash -> the gate sees it
  SURVIVED  the gate stayed green -> A REAL FINDING: this change is invisible
  INVALID   the mutant crashed -> the mutation is malformed, rewrite it
"""
import re, os, subprocess, sys, shutil, time

REPO = os.path.dirname(os.path.abspath(__file__))
CRASH = ('parse error', 'unbound variable', 'attempt to apply a non-function',
         'eval error', 'no MAIN glyph', 'error:')

# (module, mutant-name, find, replace, why-this-mutation-is-semantic [, gate-command])
# ★ The optional 6th field is the command whose output carries the verdict.
# A module's gates sometimes live OUTSIDE it -- selfext2.la reports what it did
# and gate_selfext2.sh decides whether that was right -- so running the module
# alone would report green for a mutant its gate catches. The harness has to run
# the thing that judges, not the thing that is judged.
MUTANTS = [
 ('prop.la', 'negation-is-identity',
  'glyph PNOT = la p. CONT(p)(VOIDP)', 'glyph PNOT = la p. p',
  'a negation that does nothing; DNE-holds-operationally passes trivially on it'),
 ('prop.la', 'coherence-always-true',
  'glyph COHERES = la s. la p. NOT(IS_VOID(s))', 'glyph COHERES = la s. la p. TRUE',
  'accepts "Void flows"; collapses COHERES into OBTAINS, killing the boundary'),
 ('prop.la', 'polarity-never-flips',
  '(la a. la b. IF(IS_VOID(b))(la _. self(NOT(pol))(a))',
  '(la a. la b. IF(IS_VOID(b))(la _. self(pol)(a))',
  'negation stops inverting; the glut/gap worlds can no longer separate the laws'),
 ('prop.la', 'glyph-negation-cancels',
  'glyph PNOT = la p. CONT(p)(VOIDP)',
  'glyph PNOT = la p. p(la nm. CONT(p)(VOIDP))(la a. la b. CONT(p)(VOIDP))(la a. la b. CONT(p)(VOIDP))(la a. la b. CONT(p)(VOIDP))(la a. la b. IF(IS_VOID(b))(la _. a)(la _. CONT(p)(VOIDP)))(la a. CONT(p)(VOIDP))',
  'the magma acquires an inverse: a second negation CANCELS the first, so k(~~P) == k(P) while a single ~ '
  'stays real -- the one leak this row exists for. negation-is-identity above turns this row red too, '
  'but only by destroying single negation as well, and mutate.py never said WHICH row caught it; so ONLY '
  'the dne-fails-ontologically row is read here',
  ['sh','-c','./tiny_host prop.la | grep -oE "dne-fails-ontologically (OK|FAIL)"']),
 ('prop.la', 'truth-negation-not-involutive',
  '(la a. la b. IF(IS_VOID(b))(la _. self(NOT(pol))(a))',
  '(la a. la b. IF(IS_VOID(b))(la _. self(FALSE)(a))',
  'the truth register loses its involution. Before this mutant NOTHING could turn dne-holds-operationally '
  'red: negation-is-identity passes it trivially (noted above), polarity-never-flips passes it too, and no '
  'WORLD can -- TVAL flips polarity, so TVAL(~~X) = TVAL(X) in every world, gluts and gaps included. Over two '
  'polarities every non-involutive negation is constant and FALSE is the only constant that breaks DNE; the '
  'laws rows go red with it, which is inherent. ONLY the dne-holds-operationally row is read',
  ['sh','-c','./tiny_host prop.la | grep -oE "dne-holds-operationally (OK|FAIL)"']),
 # ── the Goedel-Gentzen bridge (prop.la GATE 7): one TARGETED mutant per claim. Each one's FULL
 #    row-set was pre-registered in prop_bridge_model.py before the LA existed (arms 5, 6, 7, 9, 10);
 #    each gate command reads ONLY its own row.
 ('prop.la', 'kripke-negation-successor-blind',
  "(la a. (la S. KR_FILTER(la w. KR_ALL(la v. NOT(KR_MEM(v)(S)))(KR_SC(fr)(w)))(KR_WS(fr)))(self(a)))",
  "(la a. (la S. KR_FILTER(la w. NOT(KR_MEM(w)(S)))(KR_WS(fr)))(self(a)))",
  'Kripke negation stops looking at the future: w forces ~a iff w alone fails a -- classical '
  'negation -- so ~~P and P get one forcing set and the intuitionistic register collapses into the '
  'classical one. It also turns lem/wlem/por red (model arm 5); ONLY dne-fails-intuitionistically, '
  'the Kripke witness of GATE 1, is read',
  ['sh','-c','./tiny_host prop.la | grep -oE "dne-fails-intuitionistically (OK|FAIL)"']),
 ('prop.la', 'determination-is-its-own-image',
  'glyph KR_DET  = la a. la b. la at. la ng. la an. la dt. dt(a)(b)',
  'glyph KR_DET  = la a. la b. KR_POR(a)(b)',
  'primitive disjunction becomes its Goedel-Gentzen image: the two referents E12 and the M6 ruling '
  'name apart collapse into one sign, and excluded middle turns intuitionistically valid. It also '
  'turns lem/wlem red (arm 6); ONLY por-is-the-image-not-or is read',
  ['sh','-c','./tiny_host prop.la | grep -oE "por-is-the-image-not-or (OK|FAIL)"']),
 ('prop.la', 'gg-leaves-atoms-bare',
  '(la s. KR_NEG(KR_NEG(KR_ATOM(s))))', '(la s. KR_ATOM(s))',
  'the translation stops double-negating atoms, so the image of DNE is DNE itself and fails on K2: '
  'the embedding stops embedding. GG(LEM) stays valid under it (Glivenko), so this row is the ONLY '
  'one it can turn red (arm 7) -- gg-embeds-classical is read',
  ['sh','-c','./tiny_host prop.la | grep -oE "gg-embeds-classical (OK|FAIL)"']),
 ('prop.la', 'v-frame-loses-a-future',
  'IF(int_eq(w)(0))(la _. KR_L3(0)(1)(2))', 'IF(int_eq(w)(0))(la _. KR_L2(0)(1))',
  "V3's root stops seeing its second future, so no frame in the family has two incomparable "
  'futures and weak excluded middle holds everywhere: a family certifying an intermediate logic as '
  'intuitionistic. Only this row goes red (arm 9); wlem-fails-only-at-V3 is read',
  ['sh','-c','./tiny_host prop.la | grep -oE "wlem-fails-only-at-V3 (OK|FAIL)"']),
 ('prop.la', 'valuation-not-persistent',
  '(KR_L3(KR_NIL)(KR_L1(1))(KR_L2(0)(1)))', '(KR_L3(KR_NIL)(KR_L1(0))(KR_L2(0)(1)))',
  "K2's valuation {1} becomes {0}: P true now and false later, which no Kripke model allows. It also "
  'makes WLEM fail on K2 (arm 10); ONLY valuations-persistent is read',
  ['sh','-c','./tiny_host prop.la | grep -oE "valuations-persistent (OK|FAIL)"']),
 ('opgrammar.la', 'scan-keys-on-raw-form',
  'glyph K_ = la d. KAN_N(T_(d))', 'glyph K_ = la d. KAN(T_(d))',
  'reverts the scan to the raw derivation string, which is blind to every + collision'),
 ('opgrammar.la', 'negation-back-on-plus',
  'glyph R_NEG    = la x.       CONT(x)(PRIM("6"))',
  'glyph R_NEG    = la x.       CON(PRIM("6"))(x)',
  'undoes the ruling; every negation becomes identical to co-presence-with-Void'),
 ('selfext1.la', 'differs-always-true',
  'glyph C_DIFFERS  = la parent. la child. NOT2(str_eq(parent)(child))',
  'glyph C_DIFFERS  = la parent. la child. TRUE',
  'a revision arm that cannot tell a copy from a change'),
 ('selfext1.la', 'intact-always-true',
  'glyph C_INTACT   = la child. la spec. str_eq(child)(GENERATE(spec))',
  'glyph C_INTACT   = la child. la spec. TRUE',
  'accepts a CORRUPT successor -- the byte check replaced by nothing'),
 ('selfext1.la', 'verified-always-true',
  'glyph C_VERIFIED = la spec. NOT2(HASSUB("FAIL")(META_DEBUG(spec)))',
  'glyph C_VERIFIED = la spec. TRUE',
  'adopts an extension whose own test fails'),
 ('selfext1.la', 'survives-always-true',
  'glyph C_SURVIVES = la child. AND(HASSUB("glyph TRIPLEN = la x. mul(x)(3)")(child))',
  'glyph C_SURVIVES = la child. AND(TRUE)',
  'accepts a successor that LOST a parent capability'),
 ('selfext1.la', 'reproduction-always-true',
  'glyph REPRO = la parent. la child. str_eq(parent)(child)',
  'glyph REPRO = la parent. la child. TRUE',
  'the two arms stop disagreeing, so the split is decoration'),
 ('selfext2.la', 'emits-child-regardless',
  'glyph EMIT_CHILD = IF(VERIFIED)',
  'glyph EMIT_CHILD = IF(TRUE)',
  'an UNVERIFIED extension reaches execution -- verification stops gating it',
  ['sh','gate_selfext2.sh']),
 ('selfext2.la', 'main-hardcodes-the-answer',
  'glyph MAINSRC = "\\nglyph MAIN = print(int_to_str(TRIPLEDEC(5)))\\n"',
  'glyph MAINSRC = "\\nglyph MAIN = print(\\"12\\")\\n"',
  'the MAIN stops exercising the extension; only the PARENT control can see this',
  ['sh','gate_selfext2.sh']),
 ('selfext2b.la', 'organ-execs-the-VM-loader',
  'glyph RUN_CHILD = (la pid.\n    IF_(str_eq(pid)("0"))\n      (la _. SEQ2(execve("./logos_app"))(exit("127")))',
  'glyph RUN_CHILD = (la pid.\n    IF_(str_eq(pid)("0"))\n      (la _. SEQ2(execve("./logos_secd"))(exit("127")))',
  'the organ execs the GENERIC VM LOADER, which re-executes the organ from '
  'logos_program.bin -- CLAUDE.md rule 2, 148,121 processes. The safety gate is '
  'STATIC, so this mutant costs no vessel rebuild; it is the cheapest test of the '
  'most expensive mistake available in this repo.',
  ['python3','gate_selfext2b_safety.py']),
 ('ratchet.py', 'alpha-normalisation-disabled',
  'out.append(rep if rep else t)', 'out.append(t)',
  'bound occurrences keep their names, so a pure rename looks like a new class. '
  'NOTE: caught by the normaliser SELF-TEST (10%% of baseline time), not by arm B '
  '-- and that is unavoidable rather than a gap, since any break in alpha() is by '
  'construction a break the self-test examines. The low time ratio is what makes '
  'that visible instead of leaving it read as an arm-B catch.',
  ['sh','gate_ratchet.sh']),
 ('ratchet.py', 'increase-not-strict',
  'if len(kc) <= len(kp):', 'if len(kc) < len(kp):',
  'an extension adding NO new class is accepted -- the ratchet stops ratcheting',
  ['sh','gate_ratchet.sh']),
 ('ratchet.py', 'collapse-check-removed',
  '    if lost:\n', '    if []:\n',
  'a coinage may destroy a previously kappa-distinct parent form unnoticed',
  ['sh','gate_ratchet.sh']),
 ('selfext4.la', 'overfit-mode-is-secretly-honest',
  'glyph TD_IMPL = IF(OVERFIT)(la _. OVERFIT_I)(la _. HONEST_I)\nglyph TD_SRC  = IF(OVERFIT)(la _. "la x. 12")(la _. "la x. TRIPLEN(DEC(x))")',
  'glyph TD_IMPL = IF(OVERFIT)(la _. HONEST_I)(la _. HONEST_I)\nglyph TD_SRC  = IF(OVERFIT)(la _. "la x. TRIPLEN(DEC(x))")(la _. "la x. TRIPLEN(DEC(x))")',
  'the overfit fixture stops overfitting, so arm B has nothing to catch. '
  '★ THE FIRST VERSION OF THIS MUTANT CHANGED ONLY TD_IMPL AND SURVIVED -- not '
  'because the gate was blind but because TD_IMPL is what META_DEBUG TESTS while '
  'TD_SRC is what gets DEPLOYED, so the emitted module was untouched. That is the '
  'test-one/deploy-another split gate_srcdrift.py exists for, inside this organ. '
  'A mutant aimed at the tested half proves nothing about the deployed half.',
  ['sh','gate_selfext4.sh']),
 ('gate_selfext4.sh', 'probes-are-the-own-test',
  'HELD_IN="10 100 34"\nHELD_OUT="27 297 99"',
  'HELD_IN="5 5 5"\nHELD_OUT="12 12 12"',
  'the held-out probes become the probe the synthesiser ALREADY SAW, so the '
  'overfit extension answers them correctly -- held-out in name only',
  ['sh','gate_selfext4.sh']),
 ('gate_selfext5.sh', 'vm-leg-silently-falls-back-to-host',
  '  timeout 300 ./logos_secd 2>&1\n}',
  '  timeout 300 ./tiny_host sx5_audit.la 2>&1\n}',
  'the "VM leg" runs the HOST, so the cross-engine audit compares an engine with '
  'itself -- absence of a second witness presented as a witness. Arm C exists for '
  'exactly this and must catch it.',
  ['sh','gate_selfext5.sh']),
 ('gate_selfext5.sh', 'vm-leg-reuses-a-stale-stream',
  '  rm -f logos_program.bin logos_source.la\n  cp sx5_audit.la logos_source.la\n  timeout 900 ./tiny_host codegen.la >/dev/null 2>&1 || { echo "<CODEGEN-FAILED>"; return 1; }',
  '  cp sx5_audit.la logos_source.la\n  true || { echo "<CODEGEN-FAILED>"; return 1; }',
  'the VM executes whatever was compiled LAST rather than the module under audit, '
  'so the second engine witnesses a different artifact than the first',
  ['sh','gate_selfext5.sh']),
 ('selfext6.la', 'budget-is-ignored',
  'glyph BUDGET = str_to_int(read_file(".sx6budget"))',
  'glyph BUDGET = 99',
  'the search runs the whole space whatever the caller asked for, so exhaustion '
  'never happens and a bounded search is unbounded in fact while reporting a bound',
  ['sh','gate_selfext6.sh']),
 ('selfext6.la', 'emits-a-module-on-exhaustion',
  '  (la _. print(J(REPORT)(" | BUDGET EXHAUSTED — goal not met; NO module emitted")))',
  '  (la _. SEQ2(write_file("sx6_organ.la")(GENERATE(SPEC)))(print(J(REPORT)(" | BUDGET EXHAUSTED — goal not met; NO module emitted"))))',
  'a best-effort artifact is written even though the want was NOT met -- a silent '
  'partial success, and a reader seeing an artifact assumes the search finished',
  ['sh','gate_selfext6.sh']),
]

def has_fail(out):
    """★ A GATE FAILS WHEN IT PRINTS A FAIL LINE, NOT WHEN ITS PROSE CONTAINS
    THE LETTERS. `'FAIL' in out` classified stage 5's PASS text as a failure
    because it says "Disagreement is a FAILURE, not a note" -- a substring
    match on explanatory prose. Third substring bug of the day (selfopt.la
    contains opt.la; sx2 artifact names; this).
    ★ AND THE OBVIOUS FIX WAS ALSO WRONG. Matching a FAIL line at LINE START
    suits the shell gates but misses the LA modules, which report inline as
    `| laws-separable FAIL` -- re-running every mutation set after the change
    turned 8 previously-CAUGHT mutants into SURVIVED, which is the only reason
    it was noticed. Whole-word \bFAIL\b catches both formats and still
    excludes FAILURE, because the following U is a word character."""
    return re.search(r'\bFAIL\b', out) is not None


def run(mod, budget, gate=None):
    t0=time.time()
    cmd = gate if gate else ['./tiny_host',mod]
    try:
        r=subprocess.run(cmd,cwd=REPO,capture_output=True,
                         text=True,timeout=budget)
        return (r.stdout or '')+(r.stderr or ''), time.time()-t0
    except subprocess.TimeoutExpired:
        return '<TIMEOUT>', time.time()-t0

def main():
    only = sys.argv[1] if len(sys.argv)>1 else None
    budget = int(os.environ.get('MUT_BUDGET','2400'))
    rows=[]
    # ★ A CLEAN BASELINE FIRST, FOR TWO REASONS.
    # (1) If the unmutated tree is not GREEN, every CAUGHT below is worthless --
    #     the gate was already failing and the mutation proved nothing. An
    #     instrument has to establish that it CAN report green before its reds
    #     mean anything.
    # (2) It gives each mutant's time a reference. A red that arrives in a
    #     small fraction of the green run's time is the shape of a mutant that
    #     died before reaching the check -- which is how a wrong-cause red hides
    #     when it is not a crash. Reported as a ratio rather than judged, since
    #     a legitimate early refusal is also fast.
    baseline = {}
    for m in MUTANTS:
        mod = m[0]; gate = m[5] if len(m)>5 else None
        if only and mod!=only: continue
        key = (mod, tuple(gate) if gate else None)
        if key in baseline: continue
        out, el = run(mod, budget, gate)
        crashed = any(c in out for c in CRASH) or out=='<TIMEOUT>' or not out.strip()
        baseline[key] = ((not has_fail(out)) and not crashed, el)
    for key,(green,el) in baseline.items():
        if not green:
            print('FAIL  mutate: the UNMUTATED tree is not green for %s (%.0fs). '
                  'Every CAUGHT verdict would be meaningless -- the gate was already '
                  'failing. Fix the tree before trusting the lever.' % (key[0], el))
            return 1
    for m in MUTANTS:
        mod,name,find,repl,why = m[:5]
        gate = m[5] if len(m)>5 else None
        if only and mod!=only: continue
        path=os.path.join(REPO,mod); src=open(path,encoding='utf-8').read()
        if src.count(find)!=1:
            rows.append((mod,name,'ANCHOR-MISSING',
                         f'the mutation site is not present exactly once ({src.count(find)}); '
                         'the harness is stale, not the gate')); continue
        bak=path+'.mutbak'; shutil.copy2(path,bak)
        try:
            open(path,'w',encoding='utf-8').write(src.replace(find,repl))
            out,el=run(mod,budget,gate)
            crashed=any(c in out for c in CRASH) or out=='<TIMEOUT>' or not out.strip()
            failed=has_fail(out)
            if crashed:
                v='INVALID'; note=f'died of the wrong cause after {el:.0f}s -- rewrite the mutant'
            elif failed:
                b = baseline.get((mod, tuple(gate) if gate else None), (True, 0.0))[1]
                ratio = (f', {el/b:.0%} of the {b:.1f}s green baseline' if b > 0.05 else '')
                v='CAUGHT'; note=f'gate reported FAIL in {el:.1f}s{ratio}'
            else:
                v='SURVIVED'; note=f'gate stayed GREEN in {el:.0f}s -- the change is INVISIBLE'
            rows.append((mod,name,v,note))
        finally:
            shutil.move(bak,path)
    print("=== MUTATION LEVER (implementation-perturbing) ===")
    for mod,name,v,note in rows:
        print(f"  [{v:15}] {mod:14} {name:26} {note}")
    c=sum(1 for r in rows if r[2]=='CAUGHT'); s=sum(1 for r in rows if r[2]=='SURVIVED')
    i=len(rows)-c-s
    print(f"\n  {len(rows)} mutants: {c} CAUGHT, {s} SURVIVED, {i} INVALID/stale")
    if s: print("  ★ SURVIVED is the finding: those gates cannot see those changes.")
    if i: print("  ⚠ INVALID mutants prove nothing either way and must be rewritten.")
    return 1 if s else 0

if __name__=='__main__': sys.exit(main())
