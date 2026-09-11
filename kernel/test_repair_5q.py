#!/usr/bin/env python3
# Verify HAL.5q's repair CONTROL-FLOW — the part testable without QEMU. Models
# the TXSTEP logic exactly: bounded wait -> on timeout, diagnose + re-enable TE
# + retry -> recovered/dead. Proves the loop branches correctly for the three
# device behaviours it must handle. Does NOT (cannot) test whether QEMU's
# RTL8139 actually withholds TOK when TE is off — that is the isolated session's
# first checkpoint.

def txstep(te_after_repair, tok_when_te_on, tok_when_te_off, repair_present=True):
    """Return the sequence of serial witnesses TXSTEP would print.

    te_after_repair : whether the repair re-enables TE (5q yes; a broken repair no)
    tok_when_te_on  : does TOK set when TE is enabled (healthy hardware: True)
    tok_when_te_off : does TOK set when TE is disabled (the FAULT: should be False;
                      if QEMU ignores TE this is True and the fault won't manifest)
    repair_present  : 5q True; the red-path control False
    """
    out = []
    te = False   # MAIN injected TE-off before the first TX
    r1 = tok_when_te_off if not te else tok_when_te_on
    # first TXFIRE with TE currently off:
    r1 = tok_when_te_off
    if r1:
        out.append("nic tx ok")
    else:
        if not repair_present:
            out.append("nic tx wedged")          # control: diagnose, then STOP (no reply)
            return out, False                      # no reply reaches the wire
        out.append("nic tx wedged")               # SENSE + DIAGNOSE
        if te_after_repair:
            te = True                              # PRESCRIBE: re-enable TE
        r2 = tok_when_te_on if te else tok_when_te_off
        out.append("nic tx recovered" if r2 else "nic tx dead")
        if not r2:
            return out, False
    out.append("nic icmp reply sent")
    return out, True

CASES = [
    # name, args, expected witnesses, expected reply-reaches-wire
    ("5q, fault manifests (TE-off withholds TOK)",
     dict(te_after_repair=True, tok_when_te_on=True, tok_when_te_off=False, repair_present=True),
     ["nic tx wedged", "nic tx recovered", "nic icmp reply sent"], True),
    ("red-path control, fault manifests, NO repair",
     dict(te_after_repair=True, tok_when_te_on=True, tok_when_te_off=False, repair_present=False),
     ["nic tx wedged"], False),
    ("broken repair that forgets to re-enable TE",
     dict(te_after_repair=False, tok_when_te_on=True, tok_when_te_off=False, repair_present=True),
     ["nic tx wedged", "nic tx dead"], False),
    ("★ FAULT DOES NOT MANIFEST (QEMU ignores TE) — repair branch never fires",
     dict(te_after_repair=True, tok_when_te_on=True, tok_when_te_off=True, repair_present=True),
     ["nic tx ok", "nic icmp reply sent"], True),
]

allok = True
for name, args, exp_wit, exp_reply in CASES:
    wit, reply = txstep(**args)
    ok = (wit == exp_wit and reply == exp_reply)
    allok &= ok
    print(f"[{'OK ' if ok else 'BAD'}] {name}")
    print(f"        witnesses: {wit}   reply_on_wire={reply}")

print()
print("CONTROL-FLOW VERIFIED." if allok else "*** control-flow mismatch ***")
print()
print("Reads of these cases:")
print(" - 5q recovers and replies ONLY when the fault manifests AND repair re-enables TE.")
print(" - The red-path control (no repair) diagnoses then stops -> no reply -> gate RED.")
print("   This is what makes the 5q gate able to fail.")
print(" - ★ If the fault does NOT manifest (QEMU ignores TE), 5q prints 'nic tx ok'")
print("   and the repair branch is DEAD CODE — a check that cannot fire. The gate")
print("   would still go GREEN (reply sent) but would prove NOTHING about repair.")
print("   => The isolated session MUST confirm 'nic tx wedged' appears on the")
print("      serial. If it sees 'nic tx ok' instead, the fault didn't manifest and")
print("      must be redesigned BEFORE the green means anything.")
import sys; sys.exit(0 if allok else 1)
