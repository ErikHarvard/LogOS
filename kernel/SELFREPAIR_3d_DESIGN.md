# HAL.3d — a SELF-REPAIRING ATA read path (design)

> ## ★★ RESULT 2026-08-18: THE FAULT DOES NOT MANIFEST RELIABLY. HAL.3d IS HELD.
> The load-bearing unknown below resolved the wrong way, exactly as it did for
> HAL.5s. **Do not build on this fault; redesign it or drop the slice.**
>
> First gate run: main wedged (`ata wedged st=0 err=0`), repaired, read the
> sector — checks 1 and 2 green. **Check 3 went RED: the control, with identical
> fault injection, did not wedge at all.** Re-measured immediately afterwards on
> the already-built ELFs, 4 boots each:
>
> | kernel | wedged | result |
> |---|---|---|
> | `ata3d` (main) | **0 / 4** | `ata read ok (NO WEDGE)` every run |
> | `ata3d_ctrl` (control) | 0 / 4 | `ata read ok (NO WEDGE)` every run |
>
> The main driver is the SAME BINARY that wedged during the gate ten minutes
> earlier. So the wedge was a race, not the injection working — QEMU's IDE model
> does not honour a held SRST the way the ATA spec describes, and whether DRQ
> appears inside the fuel budget is timing, not state.
>
> **Therefore check 2's PASS proves nothing.** "Sensed, diagnosed, reset,
> retried, recovered" was observed once against a drive that comes ready on its
> own — the control demonstrates the read completes with NO repair at all. The
> repair mechanism is UNPROVEN, not proven.
>
> ★ THIS IS THE RED-PATH EARNING ITS ENTIRE COST. Without a no-repair control,
> run 1 would have read as a clean two-for-two green and shipped as "a
> self-repairing ATA driver in Lingua Adamica", on one unreproducible event. The
> gate refused, and the refusal is correct.
> ★ AND THE `NO WEDGE` STRING DID ITS JOB TOO: the failure NAMED ITSELF instead
> of hiding as a pass. That string existed only because HAL.5s had already been
> lost to an inert fault; the lesson was cheap the second time because someone
> wrote it down the first time.
>
> ## ★★ 2026-08-19 — THE REPLACEMENT FAULT WAS TESTED FIRST, AND IT ALSO FAILS
> ### (differently, and the difference is the useful part)
>
> Two probes, written before any repair code this time — the step this slice
> originally skipped.
>
> **Probe 1 — does it wedge?** Out-of-range LBA (0x0FFFFFFF against a 2048-sector
> image): **WEDGED 6/6**, identical every run, `st=0x41` (DRDY|ERR) `err=0x04`
> (ABRT). A real device error response, not a timing race. As a *fault* this is
> everything SRST was not.
>
> **Probe 2 — does it PERSIST?** Issue the bad LBA, then the real read of LBA 1
> with **no reset and no repair in between**: **4/4 the valid read SUCCEEDS.**
> ERR does not survive a new command — which is exactly what ATA specifies.
>
> ⇒ **There is nothing to repair.** The drive recovers by itself on the next
> command. A repair loop built here would go GREEN while measuring nothing: the
> retry succeeds whether or not anything was reset. That is the same false
> positive HAL.3d's first run produced, arrived at from the opposite direction —
> SRST gave no fault, this gives a fault that needs no repair.
>
> ## ★★★ THE CRITERION THIS YIELDS, for the whole self-repair programme
>
> A repair loop is only meaningful if **both** hold, and both are cheap to test
> before a line of repair code exists:
>
> 1. **The fault MANIFESTS** — N/N, not once. (HAL.3d's SRST failed here: 0/4 on
>    re-measure, the single wedge was a race.)
> 2. **The fault PERSISTS across a retry with no repair.** (The bad LBA fails
>    here: 4/4 self-clearing.)
>
> Only then does "sensed, diagnosed, prescribed, retried, recovered" describe the
> repair rather than the device recovering on its own.
>
> **This is why HAL.5q/5r are genuine and these are not:** TE-off and RE-off
> *stay off* until the driver re-enables them, so their controls get no reply and
> the repair is provably load-bearing. Both of ATA's candidate faults fail one
> condition each.
>
> **Status: HAL.3d remains HELD.** Not for want of a repair loop — the loop is
> written and structurally sound — but for want of a fault that needs one. The
> honest slice for an aborted command is what HAL.3c already does: bound the
> wait and REPORT it. Resuming needs a fault that survives a retry; a physically
> failing drive would, and QEMU does not model one.
>
> **Next, if resumed:** the fault must be one QEMU actually models. The design's
> own candidates stand — a bogus command byte and repairing from the resulting
> ERR state, or an out-of-range LBA. Both should be verified to wedge N/N times
> BEFORE any repair code is written against them, which is the step this slice
> skipped.


*Written 2026-08-18. Source written, **NOT compiled, NOT gated** — the worktree
is serialised behind gate_nic5r.sh and gate_hal3bc.sh. Everything below that
says "should" is a prediction, not a result.*

The disk twin of HAL.5q/5r. Those applied AATC's Sense→Diagnose→Prescribe→Retry
loop to the NIC organ; this applies it to the disk. HAL.3c only *bounded* the
wait and named the failure — it stops, it does not recover. 3d is the recovery.

## The repair, and why it is spec-grounded rather than invented

ATA defines a software reset: set SRST (bit 2) in the Device Control register
(0x3F6 = 1014 decimal), hold it, clear it, then wait for BSY to fall. That is
the drive's own documented way back to a known state. So the loop is:

    SENSE      read status (0x1F7=503) and the error register (0x1F1=497)
    DIAGNOSE   "ata wedged st=<status> err=<error>" on serial
    PRESCRIBE  software reset: outb(1014)(4), then outb(1014)(0)
    RETRY      wait BSY clear (bounded), re-issue READ SECTORS, wait DRQ (bounded)
    LEARN      "ata recovered" — or "ata dead" if the retry also times out

Bounded at every step. A repair that cannot succeed must fail loudly, not hang:
that is the whole point of HAL.5q's WAITTXB and HAL.3c's DRQFUEL.

## ★ THE LOAD-BEARING UNKNOWN — read this before trusting any green

**Does the injected fault actually manifest in QEMU?** The fault is
self-inflicted: assert SRST and leave it set, so the drive is held in reset and
the first read cannot complete. This mirrors HAL.5q's TE-off exactly.

But HAL.5q's own design flagged this as the hard part, and it was right to:
if QEMU ignores the register write, the drive never wedges, the repair branch is
**dead code**, and a green gate proves nothing at all. HAL.5s died on precisely
this — a real TABT fault turned out to be inert in QEMU (it raises TOK+TUN and
never TABT), so 5s is HELD.

**So the gate's FIRST assertion is load-bearing and must be checked before any
other result is believed:** the serial must show `ata wedged st=...`. If it
shows `ata read ok` instead, the fault did not manifest, and the correct
response is to redesign the fault — NOT to accept the green. Candidate
alternatives if SRST proves inert: issue a bogus command byte and repair from
the resulting ERR state, or point the LBA at a sector beyond the image.

## What this does not claim

A self-inflicted fault proves the MECHANISM, not universal fault-tolerance —
the same honest scope HAL.5q recorded. It does not prove the driver survives a
genuinely failing disk, only that it detects a wedge it caused, applies the
drive's documented reset, and gets back to a working read.

## Files

- `kernel/ata3d.la` — the self-repairing driver (written).
- `kernel/ata3d_ctrl.la` — red-path control, repair branch removed (TODO).
- `kernel/build_hal3d.sh`, `kernel/build_hal3d_ctrl.sh` (TODO).
- `kernel/gate_hal3d.sh` — fault-manifested / repair-worked / red-path (TODO).

## Open questions for Erik

1. **Naming.** 3d continues the HAL.3 disk series; the NIC self-repair work used
   a fresh 5q/5r. Either is defensible — 3d keeps it with the organ, a new
   series keeps it with the *capability*.
2. **Fault realism.** SRST is self-inflicted and recoverable, which is what makes
   it gateable. A genuinely failing drive is not reproducible in QEMU. Is the
   self-inflicted mechanism proof enough here, as it was for 5q?
3. **Scope.** Repair the READ path only (this file), or the WRITE path too? The
   write path is worse exposed — three waits, one of them after 512 bytes are
   already pushed — but a mid-write reset raises a question 3d does not answer:
   whether to re-push the sector or report the write lost.
