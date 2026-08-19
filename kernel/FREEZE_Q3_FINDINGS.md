# Freeze-Day Audit II — Q3: which loops can never terminate?

*Track D, 2026-08-19. Q3 is a THIRD question added to the audit's original two
(engine divergence; which assertions cannot go RED). The plan's own **Bounds**
section predicted it: "a third class of defect may exist that neither reaches."*

## Why Q3 exists

Four kernel-killers were found on track D in one night, none reachable by Q1 or Q2:

| site | defect | symptom |
|---|---|---|
| `WAITTX` (5x arc) | unbounded | a stuck TX hangs the kernel forever |
| `WAITRX` (5x arc) | 20M fuel | stack overflow on a stuck RX |
| `ata.la` `WAITDRQ` | unbounded | `EXCEPTION 0d`, recursion into unmapped memory |
| `ata3b.la` `WAITDRQ`+`WAITBSY` | unbounded, 3 sites | `EXCEPTION 06`, same class |

**★ WHY NO GATE SAW THEM: every gate hands the driver a HEALTHY DEVICE.** HAL.3
and HAL.3b are both `[x] DONE + gated` and both gates were *right* — they never
presented the fault. A gate that cannot fail, and a gate that never presents the
failing input, are two ways of certifying nothing. Q2 finds the first. Q3 finds
the second.

## Method

Mechanical signature in LA: `Z(la self. la _.` carries no counter;
`Z(la self. la n.` does. Sweep `kernel/*.la`, then adjudicate each site by hand —
the count alone is misleading and reporting it as a bug list would be crying wolf.

## ★ THE ADJUDICATION CRITERION (the audit's real product)

> **Waiting for a USER is correctly unbounded. Waiting for a DEVICE'S MANDATORY
> RESPONSE is a bug.**

A keypress may never come and that is normal. A `0xFA` ACK to a command we just
issued, or bytes 1–2 of a packet whose byte 0 already arrived, are *owed* by the
device — if they never come, the device is broken and the kernel must say so
rather than stop existing.

## Findings — 15 files swept

### Not bugs — deliberate, documented (3)
`fb.la` · `fb4b.la` · `comp.la` — `SPIN = Z(la self. la _. self("!"))`, commented
*"hold the framebuffer up (no exit) so the gate can screendump it."* Leave alone.

### Confirmed bugs — unbounded wait on an owed response
- **`mouse.la`** — `WAITIN` ×2 (IBF handshake before a command write; hangs if the
  controller never clears IBF); `POLLM` draining the `0xFA` ACK (INIT:58);
  `POLLM` for packet bytes 1–2 (RDPKT:65–66).
- **`pointer.la`** — identical shape: `WAITIN` ×2 (47,48), ACK drain (49), packet
  bytes 1–2 (51).
- **`cursor.la`** — ACK drain (INIT:53) and packet bytes 1–2 (55). No `WAITIN`:
  it writes commands with no IBF handshake at all, which is a *separate* latent
  issue — a command can be dropped rather than hang.
- **`wheel.la`** — `DRAINALL`/`POLLM` family, same ACK-drain shape.

**Byte 0 of a packet is NOT in this list.** It legitimately waits for the user to
move the mouse. Only the continuation bytes are owed.

### Judgement — by design, with a real caveat
`kbd.la` (59) · `polltest.la` (20) · `comp_session.la` · `comp_text.la` ·
`comp_term.la` · `comp_edit.la` — all `POLL` waiting for a keypress. Unbounded is
**correct** here. The caveat, recorded rather than "fixed": a WEDGED controller is
indistinguishable from an idle one, so the kernel can never report the difference.
Bounding these would break the intended behaviour; the honest options are a very
long fuel with a diagnostic, or accept-and-document. **Erik's call, not mine.**

## Fixing them — and the fault must be testable

Phase 4's rule: *a fix without a failing-first test is not a fix.* The bound is
always right on its own, but the RED path has to exist.

**Good news: this class IS red-path testable in headless QEMU.** With no mouse
movement, no AUX byte ever arrives — so an ACK/continuation wait never completes.
The unbounded control hangs (`timeout` → rc 124) or faults; the bounded version
times out and names the stage. That is the HAL.3c pattern exactly, and unlike
HAL.3d's fault it needs nothing QEMU refuses to model.

**★ AND THE CRITERION FOR GOING FURTHER THAN A BOUND** (earned 2026-08-18/19): a
bounded wait + diagnosis is always right; a **repair loop** on top is only
meaningful if the fault (1) MANIFESTS N/N and (2) PERSISTS across a retry with no
repair. Both ATA candidates failed one condition each — held-SRST gave no fault
at all (0/4 on re-measure, its one wedge a race between two boots of the same
binary), and an out-of-range LBA gave a perfectly reliable fault that clears
itself on the next command (4/4). Hence HAL.3d is HELD. TE-off/RE-off pass both,
which is why HAL.5q/5r are genuine.

## Bounds of this sweep — stated at the start, not the end
- It finds **LA-level** `Z` loops in `kernel/*.la`. Unbounded waits in `boot.asm`
  or in the SECD runtime are NOT covered.
- The signature is syntactic. A loop bounded by a counter that is itself never
  decremented would read as bounded and pass.
- Adjudication is by reading. Nothing here is a measurement except the four
  already-fixed cases; the rest are *predicted* hangs, not observed ones.
