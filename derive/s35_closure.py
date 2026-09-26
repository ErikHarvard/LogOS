# -*- coding: utf-8 -*-
"""§35 closure derivation (2026-09-26, F20). Recomputes closure.la's two captured witnesses WITHOUT the LA code — and
without tiny_host, which is the point for this section: §35's green run exceeds 30 minutes on the host (F42), while this
reads the same file in milliseconds. From the module's stated definitions (closure.la header + CL_* comments):
  listed    the words of the suite's first line beginning "for m in ", up to ";", skipping "" and words starting "."
  checked   a listed module m is checked iff some suite line begins "host <m> "
  residue   SLACKS(suite) = the LAST listed module (list order) with no host line — "" when every listed module is hosted;
            the red path appends an injected slack "notgated.la" to the list and judges it the same way
  AATC      the suite as a STRUCT (name gate_registers.sh, in-scope = listed, self-application = its own name, lacks =
            residue), read by the four conditions CLAUDE.md documents for aatc.la: inclusion = name ∈ scope, application
            = X(X) defined, validation = X(X) ≡ X, closure = lacks == "" ; CENTROPY = conditions met ; T_CLOSE internalises
            the lacked domain (lacks := "")
The input is the live gate_registers.sh, as it is for the module; the independence is the logic, not the input.
★ Red paths run on this script: a copy of the suite with a listed module's host line removed → residue named, CLOSURE F."""
import os, re
ROOT = os.environ.get('LA_ROOT') or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lines = open(os.path.join(ROOT, 'gate_registers.sh'), encoding='utf-8').read().split('\n')
forl = next(l for l in lines if l.startswith('for m in '))
listed = [w for w in forl[len('for m in '):].split(';')[0].split(' ') if w and not w.startswith('.')]
def hosted(m): return any(l.startswith('host %s ' % m) for l in lines)
def residue(extra=""):
    lst = listed + ([extra] if extra else [])
    miss = [m for m in lst if not hosted(m)]
    return miss[-1] if miss else ""
def struct(lack): return {"name": "gate_registers.sh", "scope": set(listed), "selfapp": "gate_registers.sh", "lacks": lack}
def diag(s): return [s["name"] in s["scope"], s["selfapp"] != "", s["selfapp"] == s["name"], s["lacks"] == ""]
def cen(s): return sum(diag(s))
B = lambda x: "T" if x else "F"
suite, slacked = struct(residue()), struct(residue("notgated.la"))
resolved = dict(slacked, lacks="")
print('WANT cl examined:%s all-listed-are-checked:%s | residue=%s | SLACKS(suite)="":%s CLOSURE(suite):%s AATC diagnosis(incl/appl/valid/closure)=%s centropy=%d' % (
    B(len(listed) > 0), B(all(hosted(m) for m in listed)), suite["lacks"] or "(none)", B(suite["lacks"] == ""),
    B(suite["lacks"] == ""), "".join(B(x) for x in diag(suite)), cen(suite)))
print('WANT cl CLOSURE resolved by aatc\'s T_CLOSE: SLACKS="":%s CLOSURE:%s centropy rises %d→%d strictly:%s' % (
    B(resolved["lacks"] == ""), B(resolved["lacks"] == ""), cen(slacked), cen(resolved), B(cen(resolved) > cen(slacked))))
print("NOTE §35: suite lists %d modules, %d hosted; injected slack named: %s" % (len(listed), sum(hosted(m) for m in listed), slacked["lacks"]))
