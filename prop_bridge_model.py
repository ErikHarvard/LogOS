#!/usr/bin/env python3
"""
prop_bridge_model.py -- M6 part 2 DESIGN WITNESS (prop.la GATE 7): a reference model of the Goedel-Gentzen bridge over a
finite Kripke family, written BEFORE any LA, so the LA gate's rows are PRE-REGISTERED rather than
fitted to whatever it prints.  ENTELECHEIA (Track B), 2026-09-10.  Python only: no tiny_host.

THE CLAIM (Lingua Adamica White Paper, sub:proplayer, sha256 98beeff4ee456b15 :2390-2399): the glyph
level is INTUITIONISTIC (sealing is one-way), the truth level CLASSICAL (facts have no direction), and
the double-negation translation embeds the second into the first.

WHY OR MUST BE PRIMITIVE HERE, AND NAMED APART FROM POR (E12; Lieutenant, 14-MASTER-LIST M6 09-10).
prop.la builds only NOT, AND and POR = NOT(AND(NOT a)(NOT b)).  Over that fragment classical and
intuitionistic VALIDITY coincide (Glivenko), so no formula prop.la can build separates the registers:
POR(P, NOT P) is intuitionistically valid.  POR is the GG IMAGE of disjunction, not disjunction.
The registers separate only through (a) a PRIMITIVE OR (determination), and (b) DNE read as
EQUIVALENCE of forcing sets -- the Kripke witness of NOT NOT P =/= P -- since E12 gives no primitive ->.

FRAMES (finite posets, reflexive-transitive):  C1 one world (Boolean) · K2 0<=1 (the 2-chain) ·
V3 0<=1, 0<=2 (the V-frame, two incomparable futures).  Valuations: every UPWARD-CLOSED set of worlds
for the one atom P -- or, where a frame carries an EXPLICIT list (as the LA does, hand-written), that
list, so an LA mutant that edits a frame is modelled as exactly that edit.  WHY V3: every frame with
a top element validates weak excluded middle NOT P OR NOT NOT P, so K2 cannot be WLEM's red path --
only two incomparable futures break it.

Each ARM carries its verdict WRITTEN BEFORE ITS FIRST RUN (arms 1-8 on 11:59:07's first run; the two
LA-mutant arms 9-10 added 12:1x, before they ran).  A mismatch is a finding about the model or the
reasoning, to be diagnosed -- never resolved by editing the expectation.
exit 0 iff every arm matches its pre-registered pattern.
"""
import itertools, sys

C1 = ('C1', 1, [], None)
K2 = ('K2', 2, [(0, 1)], None)
V3 = ('V3', 3, [(0, 1), (0, 2)], None)


def closure(n, edges):
    le = {(w, w) for w in range(n)} | set(edges)
    while True:
        add = {(a, d) for (a, b) in le for (c, d) in le if b == c} - le
        if not add:
            return le
        le |= add


P = ('P',)
def NOT(a): return ('NOT', a)
def AND(a, b): return ('AND', a, b)
def OR(a, b): return ('OR', a, b)
def POR(a, b): return NOT(AND(NOT(a), NOT(b)))          # prop.la's POR: the GG image of OR
def EQUIV(a, b): return ('EQUIV', a, b)                 # same forcing set at every world


class Sem:
    def __init__(self, neg_local=False, or_demorgan=False, gg_bare_atoms=False, persistent=True):
        self.neg_local, self.or_demorgan = neg_local, or_demorgan
        self.gg_bare_atoms, self.persistent = gg_bare_atoms, persistent

    def forces(self, le, n, val, w, f):
        t = f[0]
        if t == 'P':
            return w in val
        if t == 'NOT':
            if self.neg_local:                              # MUTANT: classical, successor-blind negation
                return not self.forces(le, n, val, w, f[1])
            return all(not self.forces(le, n, val, v, f[1]) for v in range(n) if (w, v) in le)
        if t == 'AND':
            return self.forces(le, n, val, w, f[1]) and self.forces(le, n, val, w, f[2])
        if t == 'OR':
            if self.or_demorgan:                            # MUTANT: one referent for OR and POR
                return self.forces(le, n, val, w, POR(f[1], f[2]))
            return self.forces(le, n, val, w, f[1]) or self.forces(le, n, val, w, f[2])
        raise ValueError(f)

    def gg(self, f):
        t = f[0]
        if t == 'P':
            return P if self.gg_bare_atoms else NOT(NOT(P))   # MUTANT: atoms left bare
        if t == 'NOT':
            return NOT(self.gg(f[1]))
        if t == 'AND':
            return AND(self.gg(f[1]), self.gg(f[2]))
        if t == 'OR':
            return POR(self.gg(f[1]), self.gg(f[2]))          # (A v B)^N = NOT(NOT A^N AND NOT B^N)
        if t == 'EQUIV':
            return EQUIV(self.gg(f[1]), self.gg(f[2]))
        raise ValueError(f)

    def vals(self, frame, le):
        _, n, _, explicit = frame
        if explicit is not None:                            # the frame's own hand-written list
            return [frozenset(v) for v in explicit]
        every = [frozenset(w for w in range(n) if b[w]) for b in itertools.product((0, 1), repeat=n)]
        if not self.persistent:                             # MUTANT: persistence dropped
            return every
        return [s for s in every if all(v in s for (w, v) in le if w in s)]

    def fails(self, frame, law):
        """the first (world, valuation) where the law fails on this frame, or None if valid on it"""
        _, n, edges, _ = frame
        le = closure(n, edges)
        for val in self.vals(frame, le):
            for w in range(n):
                if law[0] == 'EQUIV':
                    if self.forces(le, n, val, w, law[1]) != self.forces(le, n, val, w, law[2]):
                        return (w, sorted(val))
                elif not self.forces(le, n, val, w, law):
                    return (w, sorted(val))
        return None

    def all_persistent(self, family):
        for fr in family:
            le = closure(fr[1], fr[2])
            if any(not all(v in s for (w, v) in le if w in s) for s in self.vals(fr, le)):
                return False
        return True


LEM, WLEM = OR(P, NOT(P)), OR(NOT(P), NOT(NOT(P)))
LNC, DNE = NOT(AND(P, NOT(P))), EQUIV(NOT(NOT(P)), P)
LAWS = [('LEM', LEM), ('WLEM', WLEM), ('LNC', LNC), ('DNE', DNE)]
ROWS = ['classical-frame', 'lem-fails-intuitionistically', 'dne-fails-intuitionistically',
        'wlem-fails-only-at-V3', 'lnc-holds-everywhere', 'gg-embeds-classical',
        'por-is-the-image-not-or', 'valuations-persistent']


def rows(sem, family):
    names = [f[0] for f in family]
    failing = {ln: [f[0] for f in family if sem.fails(f, law)] for ln, law in LAWS}
    r = {}
    r['classical-frame'] = 'C1' in names and all(sem.fails(C1, law) is None for _, law in LAWS)
    r['lem-fails-intuitionistically'] = bool(failing['LEM'])
    r['dne-fails-intuitionistically'] = bool(failing['DNE'])
    r['wlem-fails-only-at-V3'] = failing['WLEM'] == ['V3']
    r['lnc-holds-everywhere'] = not failing['LNC']
    # GG embeds the classical register: every law valid on the Boolean frame has an image valid on
    # EVERY frame of the family.  (All four are classically valid, so all four images must hold.)
    r['gg-embeds-classical'] = all(sem.fails(f, sem.gg(law)) is None
                                   for _, law in LAWS if sem.fails(C1, law) is None for f in family)
    r['por-is-the-image-not-or'] = (all(sem.fails(f, POR(P, NOT(P))) is None for f in family)
                                    and any(sem.fails(f, OR(P, NOT(P))) for f in family))
    r['valuations-persistent'] = sem.all_persistent(family)
    return r, failing


ALL = [C1, K2, V3]
V3_LOSES_A_FUTURE = ('V3', 3, [(0, 1)], [[], [1], [2], [1, 2], [0, 1, 2]])   # LA mutant: root sees 0,1 only
K2_NONPERSISTENT = ('K2', 2, [(0, 1)], [[], [0], [0, 1]])                     # LA mutant: {1} -> {0}
# (arm, semantics, family, the rows that MUST read FAIL) -- each WRITTEN BEFORE ITS FIRST RUN
ARMS = [
    ('TRUE semantics, family C1 K2 V3', Sem(), ALL, set()),
    ('family without V3',               Sem(), [C1, K2], {'wlem-fails-only-at-V3'}),
    ('family without C1',               Sem(), [K2, V3], {'classical-frame'}),
    ('family C1 only',                  Sem(), [C1],
        {'lem-fails-intuitionistically', 'dne-fails-intuitionistically', 'wlem-fails-only-at-V3',
         'por-is-the-image-not-or'}),
    ('negation successor-blind (classical)', Sem(neg_local=True), ALL,
        {'lem-fails-intuitionistically', 'dne-fails-intuitionistically', 'wlem-fails-only-at-V3',
         'por-is-the-image-not-or'}),
    ('OR defined as POR (one referent)', Sem(or_demorgan=True), ALL,
        {'lem-fails-intuitionistically', 'wlem-fails-only-at-V3', 'por-is-the-image-not-or'}),
    ('GG leaves atoms bare',             Sem(gg_bare_atoms=True), ALL, {'gg-embeds-classical'}),
    ('valuations not persistent',        Sem(persistent=False), ALL,
        {'wlem-fails-only-at-V3', 'valuations-persistent'}),
    # -- added 12:1x for the LA mutants, expectations written before this arm first ran --
    ('V3 loses a future (LA mutant)',    Sem(), [C1, K2, V3_LOSES_A_FUTURE], {'wlem-fails-only-at-V3'}),
    ('K2 valuation {1}->{0} (LA mutant)', Sem(), [C1, K2_NONPERSISTENT, V3],
        {'valuations-persistent', 'wlem-fails-only-at-V3'}),
]

ok = True
for arm, sem, family, must_fail in ARMS:
    r, failing = rows(sem, family)
    got_fail = {k for k in ROWS if not r[k]}
    match = got_fail == must_fail
    ok &= match
    print('%-40s %s' % (arm, 'as pre-registered' if match else '!! MISMATCH'))
    print('    FAIL rows: %s' % (', '.join(sorted(got_fail)) or 'none'))
    if not match:
        print('    expected : %s' % (', '.join(sorted(must_fail)) or 'none'))
    print('    laws failing per frame: %s' % ' · '.join('%s@%s' % (ln, '/'.join(fs) or '-') for ln, fs in failing.items()))

print('\nwitnesses on the TRUE semantics (world, valuation of P):')
s = Sem()
for fr in ALL:
    print('  %s: ' % fr[0] + ' · '.join('%s %s' % (ln, s.fails(fr, law) or 'valid') for ln, law in LAWS)
          + ' · GG(DNE) %s' % (s.fails(fr, s.gg(DNE)) or 'valid'))
print('\nprop_bridge_model: %s' % ('EVERY ARM AS PRE-REGISTERED' if ok else 'MISMATCH -- diagnose, do not edit the expectation'))
sys.exit(0 if ok else 1)
