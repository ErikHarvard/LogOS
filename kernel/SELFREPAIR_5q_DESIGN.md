# HAL.5q — a SELF-REPAIRING NIC driver (Tier-2b "self-repairing drivers", first instance)

*Design groundwork written 2026-07-23 by an UNISOLATED session that could not
commit (ISOLATION=block). Execute from an isolated `~/logos-agent d` session.
Design only — no code was compiled or gated for this.*

## Why this item, now

Of Tier-2b's five items (ROADMAP §"Tier 2b"), **self-repairing drivers** is the
only one whose gate is OPEN: it is gated on "the core drivers (disk · input · NIC
send/recv) running on the metal", and those are all done (HAL.2/2b, 3/3b, 5a–5p).
The other four are gated on substrate not yet built (a live self-monitoring
daemon, a process-aware memory manager, a package/update layer). It is also
directly continuous with tonight's work — a "wedged NIC ring / stuck TX" is the
exact subsystem 5i–5p hardened, so the RTL8139 ring/CAPR/TSD mechanics are
already understood.

## The pre-existing bug this rests on (fix it regardless of the autopoiesis framing)

`WAITTX` in every 5x kernel is **unbounded**:

    glyph WAITTX = Z(la self. la base. la off.
        IF(TOK-set)(la _. base)(la _. self(base)(off)))

It spins forever if the transmit-OK bit (TSD bit15) never sets — which is exactly
what a real TX fault does (TABT transmit-abort, TUN underrun, or TE never
enabled). `WAITRX` already carries a fuel bound (`n`); `WAITTX` does not. So today
a stuck TX **hangs the kernel silently**. Bounding it is a genuine robustness fix
and the precondition for detecting a TX fault at all.

## The concept: AATC's loop, reinstantiated over DEVICE state

`aatc.la` gives `SENSE → DIAGNOSE → TRANSFORM → REPAIR` (+ `GAIN`/`LEARN` for
centropy), but built over autological predicates (SELF_INCLUSION / SELF_APPLICATION
/ SELF_VALIDATION / CLOSURE of a *source* organ). The Tier-2b spec asks for the
same SHAPE over a *device* organ. Mapping:

| AATC (source organ)        | HAL.5q (device organ = the NIC)                       |
|----------------------------|-------------------------------------------------------|
| SENSE (read module facts)  | read the device fault registers (CR / ISR / TSD)      |
| DIAGNOSE (which cond fails) | classify the fault (TX wedged? RX ring stuck?)        |
| TRANSFORM/PRESCRIBE (fix)   | re-run SETUP (chip reset + reprogram ring + re-enable) |
| REPAIR (iterate to fixpoint)| re-init then RETRY the operation, bounded             |
| GAIN/LEARN (centropy)       | did the retry succeed? (a 0/1 recovery witness)       |

Do NOT literally import aatc.la into a kernel driver (it is a language-layer
module and drags the import-mangler; kernel drivers stay flat + import-free, per
the standing HAL discipline). Reproduce the loop's SHAPE in flat LA, as the HAL
kernels already reproduce Z/IF/SEQ locally.

## RTL8139 fault surface (exact registers — verify against the datasheet before use)

- **CR** (0x37 / 55): RST=bit4 (write 1 to software-reset, self-clears when done),
  TE=bit2 (transmit enable), RE=bit3 (receive enable), BUFE=bit0 (RX buffer empty).
- **ISR** (0x3E / 62): TOK=bit2, TER=bit3 (TX error), RER=bit1 (RX error),
  RXOVW=bit4 (RX overflow), FOVW=bit6 (RX FIFO overflow). Write-1-to-clear.
- **TSD0** (0x10 / 16): TOK=bit15 (transmit OK), OWN=bit13 (0 while DMA in flight),
  TUN=bit14 (underrun), TABT=bit30 (transmit abort), size in bits[12:0].
  ⇒ A TX that never completes leaves TOK=0; TABT/TUN name *why*. Extract bits with
  div/mod (no bitwise ops), exactly as WAITTX/WAITRX already do for bit15/bit0.

## First buildable slice — HAL.5q, a self-repairing ICMP responder (extends HAL.5m)

Take 5m (the frame-classifying ICMP responder) and make its TX fault-tolerant:

1. **Bound WAITTX** — add a fuel param like WAITRX, so a stuck TX returns a
   *timeout sentinel* instead of hanging.
2. **On TX-timeout: SENSE** — read TSD0 and ISR, extract TOK/TABT/TUN/TER.
3. **DIAGNOSE** — emit a decision witness, e.g. `nic tx wedged tsd=XXXX` — the
   fault classified, printed, like 5m's `nic skip et=0806`.
4. **PRESCRIBE + REPAIR** — re-run SETUP (CR RST, wait reset, reprogram RXBUF/TX,
   re-enable TE|RE), then RETRY the transmit ONCE, bounded again.
5. **LEARN witness** — `nic tx recovered` on success, or `nic tx dead` if the
   bounded retry also times out (loud, honest failure — a repair loop that can
   silently give up is worse than none).

## ★ THE HARD PROBLEM — making the gate able to FAIL (the night's whole lesson)

A self-repair loop with no fault to repair is a check that cannot fire. The gate
MUST exhibit a real, controllable device fault, and a non-repairing variant must
FAIL it. QEMU cannot easily inject an external NIC fault, so the honest first
approach is a **self-inflicted but GENUINE fault**:

- **Chosen:** SETUP's first pass deliberately leaves **TE (transmit enable) OFF**.
  The first transmit then genuinely never completes (TOK never sets — the fault is
  real, not simulated). WAITTX(bounded) times out → SENSE sees OWN still set / not
  sent → DIAGNOSE "TX not enabled" → PRESCRIBE re-SETUP with TE on → RETRY → the
  reply goes out and the external pinger verifies it.
- **Why this is honest and gateable:** the fault is real (TX truly does not
  happen), deterministic (self-inflicted → reproducible), and DISCRIMINATING — a
  control build that OMITS the repair path never transmits, so the pinger gets no
  reply and the gate goes RED. Red-path it against that control, as every 5x
  kernel was red-pathed against its predecessor.
- **Honest scope, stated up front:** a self-inflicted fault proves the
  detect→diagnose→repair→retry MECHANISM, NOT that the driver handles every
  real-world fault (a physically wedged ring, a hardware TABT). It is the seed, the
  same way 5b's single ARP was the seed of the send/recv stack. Alternative faults
  to add later: mis-set CAPR to wedge the RX ring (detect BUFE-stuck → reset), and
  a real TABT via an oversized/malformed TX.

## Gate design (two-witness + decision, per the established discipline)

- Boot 5q on the socket netdev, pinger sends an ICMP echo request (reuse
  `ping_harness.py ping`).
- Guest serial MUST show the DECISION, not just the outcome:
  `nic tx wedged ...` → `nic tx recovered` → `nic icmp reply sent`.
- Pinger MUST independently verify the echo (addresses swapped, checksum) — proves
  the *repaired* transmit actually put a correct frame on the wire.
- **Red-path:** a `nic5q_ctrl` build with the repair branch removed must FAIL
  (no reply). Build it, run it, confirm RED, before believing the green.
- Negative assert: `nic tx dead` must NOT appear on the success path.

## Open questions for Erik / the executor

1. **Naming.** "HAL.5q" keeps NIC-arc continuity but this is really the Tier-2b
   "self-repairing drivers" rung. Call it 5q, or start a new "SR" series?
2. **Fault realism.** Is a self-inflicted TE-off fault an acceptable first
   demonstration, or do you want to hold out for a genuinely external fault
   (harder to produce in QEMU)? The design is honest that self-inflicted proves
   the mechanism, not universal fault-tolerance.
3. **Scope of the first slice.** TX-repair only, or also the RX-ring-wedge fault
   in the same kernel? Recommend TX-only first (one fault, one repair, one gate),
   then RX as 5r.
4. **Should the WAITTX bound fix be landed separately first** as a plain
   robustness fix across the existing 5x kernels, independent of the autopoiesis
   framing? It is a real hang bug today.

## Non-goals (this slice)

Not a general fault handler; not the AATC centropy-ledger accounting (a scalar
`recovered` witness suffices to start); not RX-side repair; not multi-fault; not
importing aatc.la. Just: bound the TX wait, detect one real fault, repair from
spec, retry bounded, prove it with a gate that goes RED without the repair.
