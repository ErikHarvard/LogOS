# -*- coding: utf-8 -*-
"""§26 wants + §27 protoagent derivation (2026-09-26, F20). Both witnesses are AATC centropy readings; recomputed WITHOUT
the LA code from the sensing CLAUDE.md documents (aatc.la, "The Centropic loop's SENSE phase"):
  MODULE(name)(self-ranging)(spec-ok)(unmet-dep) → the four conditions (inclusion, application, validation, closure) =
  (self-ranging, T, spec-ok, dep == ""); CLAUDE.md's worked cases fix the mapping: amnesic FTTT, spec-failing TTFT,
  needy TTTF, healthy TTTT. CENTROPY = the count of conditions satisfied (0..4).
  T_CLOSE (wants' RESOLVE): internalise the lacked domain — closure becomes T, the lack reads "".
  REPAIR (protoagent): iterate 𝒯 to the fixed point — every repairable condition made T (CLAUDE.md: "driving any
  repairable structure to autological closure"); on an already-autological structure it is the identity.
  ORDER (swc.la, protoagent's guard): a composition is an ORDER-VIOLATION iff some descendant operator has a HIGHER rank
  than an ancestor; the agent refuses then.
§26 is gated under tag wn, §27 under pa; this file prints both (check.py matches by tag)."""
def sense(self_ranging, spec_ok, dep): return [self_ranging, True, spec_ok, dep == ""], dep
def centropy(s): return sum(s[0])
def t_close(s): c = list(s[0]); c[3] = True; return c, ""
def repair(s): return [True, True, True, True], ""
def violation(node, bound=99):
    if node[0] == "atom": return False
    r = node[1]
    return r > bound or violation(node[2], r) or violation(node[3], r)
B = lambda x: "T" if x else "F"

# §26 — organ-A lacks MEMORY
a = sense(True, True, "MEMORY"); r = t_close(a)
print("WANT wn WANTS resolve(organ-A): lack after=%s closed:%s centropy before=%d after=%d strictly rises:%s" % (
    r[1], B(r[1] == ""), centropy(a), centropy(r), B(centropy(r) > centropy(a))))

# §27 — PROTO_AGENT over a well-founded composition: OOP(2)(OOP(1)(x)(y))(z)
C_WF = ("op", 2, ("op", 1, ("atom",), ("atom",)), ("atom",))
def agent(s, c):
    if violation(c): return None
    return repair(s) if sum(s[0]) < 4 else s
inc, ok = sense(False, True, "MEMORY"), sense(True, True, "")
ri, ro = agent(inc, C_WF), agent(ok, C_WF)
print("WANT pa PROTO_AGENT incomplete+WF: repaired: centropy %d→%d gain>0:%s result autological:%s | complete+WF: repaired: centropy %d→%d gain=0:%s" % (
    centropy(inc), centropy(ri), B(centropy(ri) > centropy(inc)), B(all(ri[0])), centropy(ok), centropy(ro), B(centropy(ro) == centropy(ok))))
