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

### ★ RULED 2026-08-19: ACCEPTED AND DOCUMENTED — leave all six unbounded

**The ruling: these are NOT bugs and will NOT be bounded.** Recorded in the first
audit's "accepted divergence" category, which exists exactly for this.

**1. Unbounded is semantically correct here.** Waiting for a user is not a fault.
Bounding would introduce a **false failure mode** — an idle user reported as a
dead device — which is a worse defect than the one it fixes, and one that would
fire constantly rather than never.

**2. The tempting middle option is not buildable under our own criterion.** The
attractive fix is a long fuel that emits `kbd still waiting st=NN` and then
*keeps waiting*, distinguishing wedged from idle without changing behaviour. It
is rejected because **I cannot produce a wedged i8042 in QEMU**, so it could not
be red-path tested — and Phase 4 is explicit that a fix without a failing-first
test is not a fix. Building an untestable mitigation is precisely what HAL.3d
cost. *(Honest: "cannot wedge the i8042" is ASSUMED, not measured. If someone
finds a producible wedge, this option becomes buildable and testable and the
ruling should be revisited.)*

**3. The real detection mechanism is architectural, not a loop bound.** Telling
"no input yet" from "controller dead" requires something OUTSIDE the poll — a
timer or watchdog noticing that no input has arrived while the system believes a
device is live. That is scheduler territory (K5/K6), not a `Z` loop.

**4. Test exposure is already bounded externally.** The gates run QEMU under
`timeout`, so a wedge in CI surfaces as a gate timeout rather than an infinite
hang. The kernel hanging forever is only a problem for a *human at the machine*,
which is case 3.

**★ SUB-FINDING, and it is worth more than the ruling: `kbd.la` IS GATED BY
NOTHING.** Checked, not assumed — no `gate_*.sh` references `kbd.la` or
`kernel_kbd.elf`. The other five are covered (`polltest`, `comp_text`,
`comp_term`, `comp_edit` by `gate_hal_idle.sh` and their own HAL gates;
`comp_session` by `gate_comp_session.sh`). **An unbounded loop in a file nothing
gates is doubly invisible** — Q3 found it by reading, and no amount of running
the suite would have. That is a gap in coverage, not in bounds, and it belongs on
the freeze's findings list in its own right.

### Judgement — the original triage that led to the ruling above
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


---

# Q3 by-product: the UNGATED sweep (2026-08-19)

`kbd.la` being gated by nothing raised the obvious question — how many tracked
`.la` files does nothing exercise? Method: transitive closure from `build.sh` and
every `gate_*.sh`, through the build scripts they invoke, into the `.la` files
those build, then following `import("x.la")` between modules.

**158 tracked `.la` files · 141 reachable · 17 not.** Triaged, because 17 is not
the finding — most of it is explainable:

### False positives I caused myself (4)
`cursor_ctrl` · `cursor_faulted` · `pointer_ctrl` · `pointer_faulted` — these ARE
gated, by `gate_ps2_bounded.sh`, which names them as `kernel/${D}_ctrl.la` with
`$D` a **parameter**. `mouse_ctrl`/`mouse_faulted` did NOT show up, because
`gate_mouse_bounded.sh` names them literally.
**★ A PARAMETERISED GATE IS INVISIBLE TO A STATIC REACHABILITY SWEEP.** I wrote
that gate this session and it immediately defeated my own audit method. Any
future sweep of this kind must either resolve parameters or accept that
generic gates hide their targets — worth knowing before the number is trusted.

### Legitimately ungated (5)
`ata_faultprobe`/`ata_faultprobe2` — standalone diagnostic probes, deliberately
not production. `archive/adam.compiler.la`, `archive/compiler.la` — archived.
`sigil_live` · `sigil_seal_live` · `theourgia_mux_session_live` ·
`theourgia_text_session_live` — drive REAL hardware (DRM scanout); they cannot
run headless in CI. Not gaps, but they should be *labelled* as hardware-only
rather than left looking like oversights.

### ★ REAL GAP: `buildla.la`
**Zero references in `build.sh`. No gate.** This is the LA build driver — the
thing standing in for `build.sh` itself as the toolchain moves into Lingua
Adamica. Nothing verifies it.

### ★★ REAL DEFECT, and it is Q2's class found by Q3's method: `gate_hal_idle.sh`
It consumes four **prebuilt, untracked** ELFs (`kernel_polltest`,
`kernel_comp_{text,term,edit}`) and never builds them. Two consequences:

1. **It is VACUOUS ON A FRESH CHECKOUT.** `[ -f "$elf" ] || continue` skips any
   absent ELF, and if none are found it prints SKIP and `exit 0`. Clone the repo,
   or `git clean`, and this gate passes having tested *nothing*.
2. **Nothing detects staleness.** No gate rebuilds those ELFs, so an edit to
   `comp_text.la` tomorrow leaves the gate testing yesterday's binary, silently.

**★ AND THE HONEST PART: consequence 2 is NOT currently manifesting.** I checked
rather than assumed — sources last committed 2026-07-18, ELFs built 2026-07-18/19.
They match. Reporting "this gate tests month-old stale binaries" would have been
a *false* finding, and it was the shape I expected before measuring. The defect is
that nothing *enforces* the match, not that the match is currently broken.

### Not yet adjudicated (3)
`kernel/alloc_churn_rare.la` · `kernel/alloc_churn_str.la` ·
`kernel/paging_poke_smoke.la` — likely invoked by name from a gate in a form the
sweep did not resolve, same class as the parameterised false positives. Needs the
same by-hand check the others got before being called anything.

## What this means for the freeze
Q1 and Q2 both operate on **what the suite already runs**. This sweep bounds what
they can possibly reach: a defect in `buildla.la`, or in any file behind a
skip-to-green gate, is outside both of their reach by construction. **Coverage is
prior to both questions**, and should be settled before their results are read as
a completeness claim.
