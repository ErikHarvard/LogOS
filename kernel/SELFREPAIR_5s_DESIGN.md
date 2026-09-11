# HAL.5s — self-repair against a REAL hardware fault (design groundwork)

*Written 2026-08-04 by a session that could NOT compile-verify (the `~/logos-d`
native_codegen3 paths were locked by an in-flight timing build). DESIGN ONLY —
no code here was compiled or gated. Execute the "buildable slice" below once the
compile paths are free; the FAULT-MANIFESTATION check is the load-bearing first
step, exactly as it was for 5q (TE-off) and 5r (RE-off).*

## Why this slice

5q and 5r proved the AATC Sense→Diagnose→Prescribe→Retry loop over the NIC's TX
and RX organs, but both use a **self-inflicted** fault (TE-off / RE-off) — honest
about proving the *mechanism*, not universal fault-tolerance. The 5q design doc
named the upgrade: *"a real TABT via an oversized/malformed TX"* and *"mis-set
CAPR to wedge the RX ring."* 5s takes the first: a **genuine hardware TX-abort**,
not a disabled enable bit. This is strictly more real — the device itself raises
the error condition, not our own setup omission.

## The fault: TABT (transmit abort), RTL8139

TSD0 (0x10) status bits (already read by 5q's `WAITTXB` for TOK=bit15):
- **TOK** bit15 — transmit OK (the happy path).
- **TUN** bit14 — transmit underrun.
- **OWN** bit13 — 0 while the DMA is in flight, 1 when the NIC is done with the
  descriptor.
- **TABT** bit30 — **transmit ABORTED** (excessive collisions, or an
  out-of-spec frame). This is the genuine fault 5s targets.

TCR (Transmit Config, 0x40): **CLRABT** = bit0 — writing 1 clears an abort and
retriggers the transmit of the current descriptor. This is the datasheet-specified
recovery path for TABT (contrast 5q, which just re-enabled TE).

**Self-inflicted-but-GENUINE injection (the honest first fault):** program TSD0
with an **oversized length** (bits[12:0] > the 1792-byte MAX_DMA, e.g. 0x1FFF) so
the NIC's own DMA/length logic aborts the transmit and sets TABT — the abort is
raised by the *device*, not by us withholding an enable. The reply frame itself
stays the correct size in TXBUF; only the descriptor length field is poisoned, so
the repair (CLRABT + reprogram TSD0 with the correct length) recovers the SAME
frame. (Alternative injections if oversize doesn't abort in QEMU: force excessive
collisions is not reproducible in the socket netdev, so oversize is the candidate.)

## ★★ PROBE RESULT (2026-08-04): TABT does NOT manifest — this fault is INERT

`nic5s_probe` (TE on, TSD0 poisoned to length 8191, report waittx + full TSD0)
gave: `nic waittx=1` and `nic tsd=0000bfff`. Decode of TSD0 = 0x0000BFFF:
TOK(bit15)=1, TUN(bit14, underrun)=1, OWN(bit13)=1, size=0x1FFF; **byte3=0x00 so
TABT(bit30)=0**. QEMU's RTL8139 does NOT abort an oversized transmit — it sets
TOK (so the driver sees SUCCESS via WAITTXB) plus TUN, and moves on. There is
therefore **no detectable, repairable TX fault here** — TOK-set means the repair
loop never fires. **Do NOT build 5s on TABT.** The self-inflicted enable-bit
faults (5q TE-off, 5r RE-off) work because QEMU honors the enable bits; the
deeper hardware error conditions (TABT, and likely the CAPR-wedge below) either
don't manifest or manifest as non-blocking flags. If 5s is pursued, the RX-side
overflow (RXOVW/FOVW by flooding the ring) is the next candidate to PROBE, but
expectations should be low that QEMU models it as a recoverable stall.

## ★ THE LOAD-BEARING UNKNOWN (test FIRST, cheaply, like TE-off was) — ANSWERED ABOVE (inert)

**Does QEMU's RTL8139 actually set TABT on an oversized TSD length?** Unknown —
QEMU's device model may clamp/ignore the length rather than abort. Test it BEFORE
building the full repair, the way `nic5r_probe` measured RX timing:
1. Build a probe = 5q-clean-TX but with TSD0 length poisoned to 0x1FFF.
2. Boot + ping. Read the serial: does `WAITTXB` time out (TOK never sets) AND does
   TSD0 bit30 (TABT) read as 1? Extract bit30 with `div(IL(base)(16))(...)` /
   `mod` (no bitwise ops), as 5q extracts bit15.
3. If TABT does NOT set (QEMU clamps the length and transmits fine, or times out
   with TABT=0), the fault is inert → fall back to the CAPR-wedge RX fault below,
   or hold 5s. Do NOT build the repair against a fault that doesn't manifest.

## First buildable slice — HAL.5s, a TABT-self-repairing ICMP responder

Extends the REFACTORED 5q (helper glyphs `HDRSWAP`/`SETCKSUM`/`XMIT`/`TXREPAIR`):
1. **Poison** TSD0 length in the first `XMIT` (MAIN injects, or a variant XMIT).
2. **Detect**: `WAITTXB` times out (TOK=0). SENSE TSD0, extract TABT (bit30).
3. **DIAGNOSE**: `nic tx abort tsd=XXXXXXXX` (print the full 32-bit TSD, since TABT
   is in the high half — 5q only printed the low 16 bits; widen the witness).
4. **PRESCRIBE**: write TCR CLRABT (bit0 := 1), then reprogram TSD0 with the
   CORRECT length and retry (bounded, `rep`-flag style as 5r's SCAN).
5. **LEARN**: `nic tx abort cleared` on success, loud `nic tx dead` if the bounded
   retry still aborts.

## Gate (mirror gate_nic5q.sh, ports 12489/12499 to avoid the 5q/5r range)

- check 1 (load-bearing): `nic tx abort` MUST appear (TABT genuinely set — the
  check that the check can fire; if absent, QEMU ignored the oversize, gate proves
  nothing).
- check 2: `nic tx abort cleared` + pinger echo; `nic tx dead` absent.
- check 3 (red-path): `nic5s_ctrl` (CLRABT/retry removed) → no reply, rc != 0.

## Alternative if TABT is inert: CAPR-wedge RX (the other flagged fault)

Data-preserving RX fault: the frame IS received (RE on, BUFE clears), but CAPR
(0x38) is mis-set so the NIC's overflow logic wedges the ring after the first
packet. Detect BUFE-stuck / CBR-CAPR desync, reset CAPR to 0xFFF0 (or CR RST +
re-SETUP), recover. HARDER to make genuinely manifest+recover than TABT — the
driver reads at its own tracked offset `o`, not a CAPR-derived one, so a CAPR
wedge mostly affects the NIC's accept/overflow state, not the read. Prototype the
manifestation before committing to it. TABT is the recommended first 5s.

## Non-goals (this slice)

Not a general TX error handler (TUN underrun, carrier-lost are separate); not
multi-fault; not the RX CAPR-wedge in the same kernel. One real fault, one
datasheet-specified repair, one gate that goes RED without it.
