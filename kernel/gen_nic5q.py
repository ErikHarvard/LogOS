#!/usr/bin/env python3
# gen_nic5q.py — HAL.5q, a SELF-REPAIRING ICMP responder (Tier-2b first instance).
# Derives from gen_nic5m.py: same classify + ring-advance machinery, plus a
# BOUNDED WAITTX and a Sense->Diagnose->Prescribe->Retry repair loop around TX.
#
# ★★ AUTHORED BY AN UNISOLATED SESSION THAT COULD NOT COMPILE OR GATE IT. The
# repair CONTROL-FLOW is verified in Python (test_repair.py); the repair
# STRUCTURE is design-complete and paren-balanced. But the one load-bearing
# unknown — does QEMU's RTL8139 actually withhold TOK when TE is off, so the
# injected fault MANIFESTS — is UNVERIFIED. The isolated session MUST confirm
# that first (see the VERIFY-FIRST block in build_nic5q.sh). If QEMU transmits
# despite TE off, the repair branch never fires and the fault must be redesigned
# (candidates: mis-set CAPR to wedge RX, or a zero TSAD pointer).
import os
import sys

def chain(op, items):
    if len(items) == 1: return items[0]
    return f"{op}({items[0]})({chain(op, items[1:])})"
def seq(items): return chain("SEQ", items)

FUEL = "200000"   # TX-wait fuel; large enough for a real ~us TX, bounded so a
                  # wedged TX returns a timeout sentinel instead of hanging.

# --- the reply body (5m's, unchanged) --------------------------------------
CKSUM = ("(la nc. " + seq([
    "poke(add(TXBUF)(add(u)(2)))(div(nc)(256))",
    "poke(add(TXBUF)(add(u)(3)))(mod(nc)(256))",
]) + ")(EAC(add(add(mul(TB(add(u)(2)))(256))(TB(add(u)(3))))(2048)))")

# TXFIRE: point TSAD0 at the buffer, write TSD0 length (starts DMA), return the
# BOUNDED wait result (1 = TOK set = sent, 0 = timed out = wedged).
TXFIRE = ("(la fl. SEQ(OL(base)(32)(TXBUF))"
          "(SEQ((la tl. OL(base)(16)(tl))(IF(lt(fl)(60))(la _. 60)(la _. fl)))"
          "(WAITTXB(base)(16)(" + FUEL + "))))")

# The repair loop, entered after the FIRST TXFIRE:
#   r1 = TXFIRE(framelen)
#   IF r1==1  -> "nic tx ok"                              (no fault; happy path)
#   ELSE      -> SENSE+DIAGNOSE: print "nic tx wedged tsd=XXXX" (the TSD state)
#               PRESCRIBE: re-enable TE  (OB(base)(55)(12) = TE|RE)
#               RETRY: r2 = TXFIRE(framelen)
#               IF r2==1 -> "nic tx recovered"  ELSE -> "nic tx dead" (loud fail)
DIAGWIT = ('concat("nic tx wedged tsd=")(concat(HEX2(div(IL(base)(16))(256)))'
           '(HEX2(mod(IL(base)(16))(256))))')
REPAIR = seq([
    f'print({DIAGWIT})',
    "OB(base)(55)(12)",                                   # PRESCRIBE: TE|RE on
    ("(la r2. IF(int_eq(r2)(1))(la _. print(\"nic tx recovered\"))"
     "(la _. print(\"nic tx dead\")))" + f"({TXFIRE.replace('(la fl.', '(la fl.')}(framelen))"),
])
TXSTEP = ("(la r1. IF(int_eq(r1)(1))(la _. print(\"nic tx ok\"))(la _. " + REPAIR + "))"
          + f"({TXFIRE}(framelen))")

RESPOND_ITEMS = [
    "COPYN(TXBUF)(add(ra)(4))(framelen)",
    "COPYN(TXBUF)(add(ra)(10))(6)",
    "COPYN(add(TXBUF)(6))(add(ra)(4))(6)",
    "COPYN(add(TXBUF)(26))(add(ra)(34))(4)",
    "COPYN(add(TXBUF)(30))(add(ra)(30))(4)",
    "poke(add(TXBUF)(u))(0)",
    CKSUM,
    TXSTEP,                       # <-- the self-repair TX, replacing 5m's OL/OL/WAITTX
    'print("nic icmp reply sent")',
    'print("nic done")',
]
RESPOND = ("glyph RESPOND = la base. la o. la framelen. la u. (la ra. "
           + seq(RESPOND_ITEMS) + ")(add(RXBUF)(o))")

FROMWIT = "glyph FROMWIT = la o. la u. " + chain("concat", [
    '"nic icmp req ihl="', "HEX2(IHL2(o))",
    '" type="', "HEX2(RB2(o)(add(u)(4)))",
    '" from="', "HEX2(RB2(o)(10))", "HEX2(RB2(o)(11))", "HEX2(RB2(o)(12))",
    "HEX2(RB2(o)(13))", "HEX2(RB2(o)(14))", "HEX2(RB2(o)(15))",
])
SKIPWIT = "glyph SKIPWIT = la o. " + chain("concat",
            ['"nic skip et="', "HEX2(RB2(o)(16))", "HEX2(RB2(o)(17))"])

MATCHED = ("(la u. " + seq([
    "print(FROMWIT(o)(u))",
    "RESPOND(base)(o)(sub(RXLEN2(o))(4))(u)",
]) + ")(L4OFF2(o))")
SKIPPED = seq([
    "print(SKIPWIT(o))",
    "(la n. " + seq(["OW(base)(56)(sub(n)(16))", "self(base)(n)(sub(fuel)(1))"]) + ")(NEXTOFF(o))",
])
SCAN = ("glyph SCAN = Z(la self. la base. la o. la fuel.\n"
        '    IF(int_eq(fuel)(0))(la _. print("nic no match"))(la _.\n'
        '      IF(int_eq(WAITRX(base)(20000000))(0))(la _. print("nic rx timeout"))(la _.\n'
        f'        IF(int_eq(MATCH(o))(1))(la _. {MATCHED})(la _. {SKIPPED}))))')

# ★ THE FAULT INJECTION: after a correct SETUP, deliberately DISABLE TE so the
# first TX genuinely cannot complete. Present in BOTH 5q and the red-path
# control; the repair branch is what distinguishes them.
#   OB(base)(55)(8) = CR := RE only (bit3), TE (bit2) CLEARED.
FAULT = "OB(base)(55)(8)"

BODY = seq([
    "SETUP(dev)(base)",
    FAULT,                                                 # inject: TE off
    seq(['print("nic setup ok (te-off fault injected)")', "SCAN(base)(0)(8)"]),
])
FOUND = f"((la base. {BODY})(sub(CFG(dev)(16))(mod(CFG(dev)(16))(4))))"
DEV = f'((la dev. IF(int_eq(dev)(32))(la _. print("nic not found"))(la _. {FOUND}))(FIND(0)))'
MAIN = "glyph MAIN = " + seq(['print("nic5q:")', DEV])

HEADER = '''# =====================================================================
#  LogOS HAL.5q — a SELF-REPAIRING ICMP echo responder (Tier-2b: the AATC
#  repair loop applied to a DEVICE organ), in Lingua Adamica.
#
#  Extends HAL.5m (classify + RX-ring advance) with a Sense->Diagnose->
#  Prescribe->Retry loop around TRANSMIT:
#    1. WAITTX is now BOUNDED (WAITTXB, fuel-limited like WAITRX) — a wedged TX
#       returns a timeout sentinel (0) instead of hanging the kernel forever.
#       This alone fixes a real latent bug: every 5x kernel's WAITTX spins
#       forever if TOK never sets.
#    2. On a TX timeout: SENSE the TSD0 register and print it (DIAGNOSE:
#       "nic tx wedged tsd=XXXX").
#    3. PRESCRIBE: re-enable TE (CR := TE|RE) — re-initialise the faulted part
#       of the device from spec.
#    4. RETRY the transmit, bounded. "nic tx recovered" on success, or the loud
#       "nic tx dead" if the retry also times out (a repair loop that gives up
#       silently is worse than none).
#
#  ★★ THE INJECTED FAULT IS UNVERIFIED IN QEMU. MAIN deliberately disables TE
#  (CR := 8, RE only) after SETUP so the first TX cannot complete. Whether
#  QEMU's RTL8139 actually withholds TOK with TE off is NOT confirmed (this was
#  authored by a session that could not run it). The isolated session MUST
#  verify the fault manifests before trusting a green — see build_nic5q.sh.
#  If QEMU transmits anyway, redesign the fault (mis-set CAPR / zero TSAD).
#
#  HONEST SCOPE: a self-inflicted fault proves the detect->diagnose->repair->
#  retry MECHANISM, not universal fault-tolerance. TX-only; RX-ring repair is a
#  later slice. The gate is red-pathed against nic5q_ctrl (repair branch removed
#  -> no reply), so it can fail.
# =====================================================================
'''

# 5m's prelude, with WAITTX replaced by the BOUNDED WAITTXB.
PRELUDE = '''
glyph Z    = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF   = la c. la t. la f. c(t)(f)("!")
glyph SEQ  = la a. la b. b

glyph HEXD = la d.
    IF(lt(d)(10))(la _. chr(int_to_str(add(48)(d))))
                 (la _. chr(int_to_str(add(87)(d))))
glyph HEX2 = la b. concat(HEXD(div(b)(16)))(HEXD(mod(b)(16)))

glyph ADDR = la dev. la off. add(add(2147483648)(mul(dev)(2048)))(off)
glyph CFG  = la dev. la off. SEQ(outl(3320)(ADDR(dev)(off)))(inl(3324))
glyph CFGW = la dev. la off. la val. SEQ(outl(3320)(ADDR(dev)(off)))(outl(3324)(val))

glyph FIND = Z(la self. la dev.
    IF(int_eq(dev)(32))(la _. 32)(la _.
      (la r.
        IF(int_eq(mod(r)(65536))(4332))(la _.
          IF(int_eq(div(r)(65536))(33081))(la _. dev)(la _. self(add(dev)(1))))
        (la _. self(add(dev)(1))))
      (CFG(dev)(0))))

glyph OB = la base. la off. la v. outb(add(base)(off))(v)
glyph OW = la base. la off. la v. outw(add(base)(off))(v)
glyph OL = la base. la off. la v. outl(add(base)(off))(v)
glyph IB = la base. la off. inb(add(base)(off))
glyph IL = la base. la off. inl(add(base)(off))

glyph RXBUF = 268435456
glyph TXBUF = 268447744

glyph COPYN = Z(la self. la dst. la src. la n.
    IF(int_eq(n)(0))(la _. 0)(la _.
      SEQ(poke(dst)(peek(src)))(self(add(dst)(1))(add(src)(1))(sub(n)(1)))))

glyph WAITRST = Z(la self. la base.
    IF(int_eq(mod(div(IB(base)(55))(16))(2))(1))(la _. self(base))(la _. base))
# ★ BOUNDED transmit wait: fuel n; returns 1 if TOK (TSD bit15) sets, 0 if fuel
# runs out (the wedged-TX sentinel). The fix for WAITTX's unbounded spin.
glyph WAITTXB = Z(la self. la base. la off. la n.
    IF(int_eq(n)(0))(la _. 0)(la _.
      IF(int_eq(mod(div(IL(base)(off))(32768))(2))(1))(la _. 1)(la _. self(base)(off)(sub(n)(1)))))
glyph WAITRX = Z(la self. la base. la n.
    IF(int_eq(n)(0))(la _. 0)(la _.
      IF(int_eq(mod(IB(base)(55))(2))(0))(la _. 1)(la _. self(base)(sub(n)(1)))))

glyph RXLEN2 = la o. add(RB2(o)(2))(mul(RB2(o)(3))(256))
glyph RB2 = la o. la off. peek(add(add(RXBUF)(o))(off))
glyph TB = la off. peek(add(TXBUF)(off))
glyph EAC = la s. IF(lt(s)(65536))(la _. s)(la _. sub(s)(65535))

glyph ALIGN4 = la x. mul(div(add(x)(3))(4))(4)
glyph NEXTOFF = la o. ALIGN4(add(o)(add(4)(RXLEN2(o))))
glyph IHL2   = la o. mod(RB2(o)(18))(16)
glyph L4OFF2 = la o. add(14)(mul(IHL2(o))(4))
glyph ISIP   = la o. IF(int_eq(RB2(o)(16))(8))(la _. IF(int_eq(RB2(o)(17))(0))(la _. 1)(la _. 0))(la _. 0)
glyph OKIHL  = la o. IF(lt(IHL2(o))(5))(la _. 0)(la _. 1)
glyph ISICMP = la o. IF(int_eq(RB2(o)(27))(1))(la _. 1)(la _. 0)
glyph MATCH  = la o. IF(int_eq(ISIP(o))(1))(la _. IF(int_eq(OKIHL(o))(1))(la _. ISICMP(o))(la _. 0))(la _. 0)

glyph SETUP = la dev. la base.
    SEQ(CFGW(dev)(4)(7))
    (SEQ(OB(base)(82)(0))
    (SEQ(OB(base)(55)(16))
    (SEQ(WAITRST(base))
    (SEQ(OL(base)(48)(RXBUF))
    (SEQ(OW(base)(60)(0))
    (SEQ(OW(base)(62)(65535))
    (SEQ(OL(base)(68)(59151))
    (SEQ(OW(base)(56)(65520))
    (OB(base)(55)(12))))))))))
'''

out = HEADER + PRELUDE + SKIPWIT + "\n" + FROMWIT + "\n" + RESPOND + "\n" + SCAN + "\n" + MAIN + "\n"

depth = 0; in_str = False
for i, ch in enumerate(out):
    if in_str:
        if ch == '"' and out[i-1] != '\\': in_str = False
        continue
    if ch == '"': in_str = True
    elif ch == '(': depth += 1
    elif ch == ')':
        depth -= 1
        if depth < 0: sys.exit(f"UNBALANCED: closed past zero at offset {i}")
if depth != 0: sys.exit(f"UNBALANCED: final depth {depth}")

# ★ Write NEXT TO THIS SCRIPT, never to an absolute worktree path. This line
# used to read "/home/<user>/logos-d/kernel/nic5q.la" as an ABSOLUTE path, meaning
# running the generator from ANY other worktree (logos, logos-b, logos-c) would
# reach across and overwrite track D's source. That is exactly the cross-session
# collision the worktree isolation exists to prevent, and the private /tmp does
# NOT protect $HOME paths — so the one guard that would have caught it does not
# apply here. Caught by a pre-publication scan for absolute paths, not by a gate.
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nic5q.la")
open(path, "w").write(out)
print(f"wrote {path} ({len(out)} bytes), paren depth balanced at 0")
