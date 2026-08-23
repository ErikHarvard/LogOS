#!/usr/bin/env python3
"""heapscope — resident pages per LA runtime region, sampled from a live PID.

WHY THIS FILE EXISTS
--------------------
This instrument produced the rt_gc root cause (peak RSS grows as sqrt(allocs),
because the GC trigger is frontier POSITION not allocation VOLUME).  It existed
only as shell history in the session that ran it.  When that session ends the
instrument is gone and the finding becomes something believed rather than
something checkable -- the same way the linker's .rela.data fixture was lost to
a tmpfs while the logs proving it survived.  So it is written down.

WHY smaps CANNOT DO THIS
------------------------
native_codegen3 reserves ONE giant RWX mapping and sublets it:

    [ image ][ worklist 64 MiB ][ heap 16 GiB ][ bitmap 256 MiB ]

Every region shares one VMA, so smaps reports a single number for all four and
cannot say which one grew.  /proc/PID/pagemap is per-PAGE: bit 63 is "present",
so counting set bits over a sub-range gives that region's resident pages, and
the regions become separately measurable without changing the program.

The bounds are derived from the mapping's END, working backwards by the known
region sizes -- not from a hardcoded base, which would silently follow the wrong
mapping the moment the image size changes.

THE LIVENESS RULE (learned the expensive way)
--------------------------------------------
Two opposite conclusions were once drawn from the same crashing process: the
"plateau" that looked like a collector reclaiming was a DEAD PROCESS.  A flat
line and a corpse are indistinguishable unless the harness asserts otherwise.
So every sample here checks the process is alive FIRST and raises if it is not.
A measurement that cannot tell "stopped growing" from "stopped existing" is not
a measurement.

WHAT IS VERIFIED, AND WHAT IS NOT
---------------------------------
The constants and the region ORDER below are read off native_codegen3.la, not
inferred from a run -- testing them only against a subject built to match my own
assumption would have been circular:

    WL_SIZE     = 67108864     (64 MiB)              native_codegen3.la:528
    HEAP_SIZE   = 17179869184  (16 GiB)              native_codegen3.la:531
    BITMAP_SIZE = 268435456    (= HEAP_SIZE/64)      native_codegen3.la:536

    :552  heap base hb = heap_addr + WL_SIZE      -> worklist precedes the heap
    :549  HEAP_END     = hb + HEAP_SIZE           -> heap precedes the bitmap
    rt_init: BITMAP_BASE = HEAP_END               -> bitmap sits at the heap's end
    :752  memsz = (heap_addr - VADDR) + HEAP_SIZE + WL_SIZE + BITMAP_SIZE
          -> all four regions live in ONE PT_LOAD, which is why smaps cannot
             separate them and why the bounds here are derived from its END.

VERIFIED: the arithmetic above; the documented exit statuses, checked from the
CLI; and five `--selftest` cases against a synthetic subject of the same arena
shape -- per-region attribution, a non-arena subject, an already-dead pid, a
recycled pid, and a subject that dies mid-run.

VERIFIED AGAINST THE REAL BINARY (statically): the ARENA_SIZE model checks out
against an actual `native_codegen3_out`'s ELF.  Its largest PT_LOAD reserves
17,515,425,840 bytes; ARENA_SIZE (worklist+heap+bitmap) is 17,515,413,504; the
12,336-byte remainder is the image/code region at the front -- so giant_mapping's
threshold accepts the real mapping and regions()'s end-carve lands the image
region exactly on the code.  This closes the circularity worry: the shape is
confirmed by the artifact, not only by a subject built to match my assumption.

VERIFIED LIVE against a running native_codegen3_out (a COUNT loop, built and run
in a scratch dir so nothing in the tree or /tmp was touched).  Sampled over 12s:

    t      image  worklist    heap   bitmap   (MiB resident)
    0.1      0.0       0.0  2324.0     36.3
   12.3      0.0       0.0  2376.0     37.1

heap climbs, worklist+image stay 0, and bitmap = heap/64 to three figures
(2376/64 = 37.1) -- a PASSIVE follower of the frontier, not a driver.  This is
the sqrt(allocs) frontier-drift mechanism observed directly, and it is the same
conclusion measurement forced onto the bitmap hypothesis.  Nothing about this
instrument is now unverified against the real artifact.

HARNESS NOTE (a trap worth stating): getting this reading took three tries, all
harness bugs, none in heapscope.  `$!` on `cmd &` caught a WRAPPER BASH, not the
binary -- so attach by matching /proc/PID/exe, never by the launcher's pid; and a
short-lived subject exits and its pid recycles before you sample.  heapscope was
correct throughout -- it returned NotAnArena / a recycle-refusal rather than a
bogus number, which is exactly its job.

FOUR DEFECTS WERE FOUND BY RE-READING THIS FILE AFTER CALLING IT DONE.  Recorded
because they share one shape -- each produced a plausible quiet wrong answer
rather than an error, which is precisely what this instrument exists to catch:

  1. `resident_pages` decremented its loop counter by the REQUESTED read size,
     not the received one.  A short read (legal on any file object; pagemap is a
     special file) under-counted 10x -- 171 resident pages reported where 1667
     were present -- so a growing heap would have drawn a near-flat line.
  2. `alive` trusted the pid alone, so a recycled pid reported a STRANGER as the
     subject and spliced two processes into one graph.  Now pinned by
     (pid, starttime).
  3. `giant_mapping` accepted any mapping >= HEAP_SIZE while `regions` carved
     worklist+heap+bitmap from it; an undersized mapping produced bounds outside
     itself, and pagemap reads outside a mapping return ZEROS rather than
     failing.  The threshold is now the whole arena.

  4. `main` built its header from `regions()` BEFORE checking the subject, so a
     dead pid escaped as a FileNotFoundError traceback with exit 1 -- colliding
     with the selftest-failure code -- instead of the exit 2 documented three
     lines above it.  The subject is now established first.

Two lessons, both earned here rather than reasoned:

  * The selftest passed before and after fix 1, because the synthetic subject
    never short-reads.  A green test is evidence about the path it exercises
    and about NOTHING else.
  * Defect 4 was in the EXIT-STATUS table of this very docstring, written one
    edit earlier and never run.  Documentation drifts from code at the moment
    it is written, not only over months -- and this block has now gone stale
    twice in one session.  If you change behaviour here, re-read this text
    before trusting it.

USAGE
    heapscope.py <pid> [--interval SEC] [--samples N]
    heapscope.py <pid> --once
    heapscope.py <pid> --peak --max-heap-mib N   # gate: PASS iff peak heap <= N
    heapscope.py --selftest        # five cases; no LogOS build needed

--peak turns the instrument into an ACCEPTANCE TEST: it samples heap until the
subject exits (a workload finishing is normal, not an error), then PASS/FAILs on
peak heap.  gate_rss.sh drives it.  Verified both ways: the current leaky binary
peaks ~1856 MiB (FAIL); a bounded-heap subject peaks ~20 MiB (PASS).  After the
allocation-volume fix lands, the real binary should cross from FAIL to PASS --
climb-vs-flat, made executable.

EXIT STATUS
    0  ran to completion        2  subject died or was recycled mid-run
    1  selftest failure         3  subject is not an LA runtime

THE SELFTEST IS PART OF THE TOOL ON PURPOSE.  It first lived in a session
scratchpad -- which is a tmpfs, which is how the linker's .rela.data fixture was
lost while the logs proving it survived.  A test that validates an instrument and
then evaporates leaves the instrument believed rather than checked, so it lives
here, next to what it tests, where it cannot drift out of step with it either.
"""

import argparse
import os
import sys
import time

PAGE = 4096
WORKLIST_SIZE = 64 * 1024 * 1024
HEAP_SIZE = 16 * 1024 * 1024 * 1024
BITMAP_SIZE = HEAP_SIZE // 64          # 1 bit per 8-byte granule

# bit 63 of each 8-byte pagemap entry is "present"; byte 7 is its high byte, so
# a byte-wise translate+count over every 8th byte is the whole population count.
_TBL = bytes(1 if (i & 0x80) else 0 for i in range(256))


ARENA_SIZE = WORKLIST_SIZE + HEAP_SIZE + BITMAP_SIZE


class Dead(RuntimeError):
    """The subject exited.  Never let this look like a plateau."""


class NotAnArena(RuntimeError):
    """The subject has no mapping shaped like the LA arena.

    Deliberately NOT `Dead`: "the subject vanished" and "this was never an LA
    runtime" are different facts, and reporting the second as the first would
    send a reader hunting a crash that never happened.
    """


def identity(pid):
    """(pid, starttime) -- the pair that actually names a process.

    ★ A PID ALONE DOES NOT IDENTIFY A SUBJECT.  If the subject exits mid-run and
    the kernel recycles its pid, a pid-only check reports the STRANGER as alive
    and the run silently changes subject -- this board's method finding 2, "an
    observation that cannot distinguish my thing from not-my-thing" (the
    `pgrep -f` self-match, `ps -C tiny_host` hitting another track).  starttime
    (field 22 of /proc/pid/stat, in boot-relative clock ticks) is monotonic and
    never repeats for a recycled pid, so the pair pins the subject.

    Returns None when there is no live, non-zombie process with that pid.
    """
    try:
        with open(f"/proc/{pid}/stat", "rb") as fh:
            raw = fh.read()
    except OSError:
        return None
    # comm (field 2) may contain spaces AND parens, so split after the LAST ')'.
    fields = raw.rsplit(b")", 1)[1].split()
    if not fields or fields[0] == b"Z":     # field 3 = state; a zombie is not running
        return None
    if len(fields) < 20:                    # field 22 = starttime -> index 19
        return None
    return (pid, fields[19])


def alive(pid, pinned=None):
    """True iff the ORIGINAL subject is still running (not merely its pid)."""
    ident = identity(pid)
    if ident is None:
        return False
    return pinned is None or ident == pinned


def giant_mapping(pid):
    """The one mapping large enough to be the LA arena, as (start, end)."""
    best = None
    try:
        fh = open(f"/proc/{pid}/maps")
    except OSError:
        # The subject vanished between the liveness check and this read.  That
        # is a DEATH, not a shape problem -- reporting it as "not an LA runtime"
        # would blame the subject for the wrong thing.
        raise Dead(f"pid {pid} is not running -- it exited before its mapping "
                   f"could be read")
    with fh:
        for line in fh:
            span, _, rest = line.partition(" ")
            lo, _, hi = span.partition("-")
            try:
                lo, hi = int(lo, 16), int(hi, 16)
            except ValueError:
                continue
            # ★ The threshold is the WHOLE arena, not just HEAP_SIZE.  A mapping
            # that clears HEAP_SIZE but is smaller than worklist+heap+bitmap
            # would make regions() carve bounds that fall OUTSIDE it -- and a
            # pagemap read outside a mapping returns zeros rather than failing,
            # so the tool would report plausible low residency instead of an
            # error.  Silently-wrong is the failure mode this instrument exists
            # to eliminate, so the shape is checked up front.
            if hi - lo >= ARENA_SIZE and (best is None or hi - lo > best[1] - best[0]):
                best = (lo, hi)
    if best is None:
        raise NotAnArena(
            f"pid {pid}: no mapping >= {ARENA_SIZE} bytes (worklist+heap+bitmap) "
            f"-- not an LA runtime, or its layout constants have changed")
    return best


def regions(pid):
    """Sub-ranges of the arena, derived from its END so they cannot drift."""
    lo, hi = giant_mapping(pid)
    bitmap_lo = hi - BITMAP_SIZE
    heap_lo = bitmap_lo - HEAP_SIZE
    worklist_lo = heap_lo - WORKLIST_SIZE
    return [
        ("image", lo, worklist_lo),
        ("worklist", worklist_lo, heap_lo),
        ("heap", heap_lo, bitmap_lo),
        ("bitmap", bitmap_lo, hi),
    ]


def resident_pages(fh, start, end):
    """Count present pages in [start, end) via pagemap bit 63."""
    npages = (end - start) // PAGE
    if npages <= 0:
        return 0
    fh.seek((start // PAGE) * 8)
    total = 0
    remaining = npages
    while remaining:
        chunk = min(remaining, 1 << 20)          # 8 MiB of entries per read
        want = chunk * 8
        # ★ READ EXACTLY.  A bare fh.read(want) may return SHORT -- legal for any
        # file object, and pagemap is a special file.  Decrementing `remaining`
        # by the REQUESTED count would (a) treat unread entries as absent, so a
        # growing heap reports flat, and (b) leave the offset mid-entry, after
        # which buf[7::8] slices the wrong byte and every later count is
        # garbage.  Under-reporting residency is exactly the plateau-vs-growth
        # confusion this tool exists to prevent, so the short read is handled
        # rather than assumed away.
        buf = bytearray()
        while len(buf) < want:
            part = fh.read(want - len(buf))
            if not part:
                break                            # genuine EOF / truncated range
            buf += part
        got = len(buf) // 8
        if got == 0:
            break
        # every 8th byte holds bit 63; translate to 0/1 and count -- a per-entry
        # Python loop over millions of pages distorts the timeline it measures.
        total += bytes(buf[7::8]).translate(_TBL).count(1)
        remaining -= got
        if got < chunk:
            break                                # short of the region's end
    return total


def sample(pid, pinned=None):
    """One reading.  `pinned` is the identity() captured when the run began; the
    subject is re-checked BEFORE and AFTER, so neither an exit nor a pid recycle
    can be plotted as data."""
    if not alive(pid, pinned):
        raise Dead(f"pid {pid} is not the running subject "
                   f"-- a dead (or recycled) process is NOT a plateau")
    regs = regions(pid)
    with open(f"/proc/{pid}/pagemap", "rb") as fh:
        out = [(name, resident_pages(fh, lo, hi)) for name, lo, hi in regs]
    if not alive(pid, pinned):
        raise Dead(f"pid {pid} exited or was recycled DURING the sample "
                   f"-- discard it, do not plot it")
    return out


def mib(pages):
    return pages * PAGE / (1024 * 1024)


SUBJECT = r'''
import mmap, os, sys, time
PAGE=4096; WL=64*1024*1024; HEAP=16*1024*1024*1024; BM=HEAP//64; IMG=4*1024*1024
m = mmap.mmap(-1, IMG+WL+HEAP+BM, prot=mmap.PROT_READ|mmap.PROT_WRITE)
heap_off = IMG+WL                      # touch ONLY inside the heap sub-range
print(os.getpid(), flush=True)
for step in range(1, 100000):
    for p in range(256):               # 1 MiB per step
        m[heap_off + (step*256+p)*PAGE] = 1
    time.sleep(0.05)
'''


def selftest():
    """Green: growth is attributed to `heap` alone.  Red: a dead subject is
    reported as dead, never as a plateau.  Uses a synthetic subject with the
    same arena shape, so no LogOS build is involved."""
    import subprocess
    import tempfile

    ok = True
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as fh:
        fh.write(SUBJECT)
        path = fh.name
    proc = subprocess.Popen([sys.executable, path], stdout=subprocess.PIPE, text=True)
    try:
        pid = int(proc.stdout.readline().strip())
        time.sleep(2.0)

        pinned = identity(pid)
        rows = [sample(pid, pinned) for _ in (0, 1)]
        time.sleep(1.0)
        rows.append(sample(pid, pinned))
        by = {n: [dict(r)[n] for r in rows] for n, _, _ in regions(pid)}

        if not (by["heap"][-1] > by["heap"][0]):
            print("FAIL selftest: heap did not grow"); ok = False
        for quiet in ("image", "worklist", "bitmap"):
            if any(by[quiet]):
                print(f"FAIL selftest: {quiet} resident ({by[quiet]}), expected 0")
                ok = False
        if ok:
            print(f"PASS selftest green: growth attributed to heap alone "
                  f"({mib(by['heap'][0]):.0f} -> {mib(by['heap'][-1]):.0f} MiB); "
                  f"image/worklist/bitmap flat at 0")

        # --- red 0: a live process with NO arena must be reported as such,
        #     never as a death.  Our own interpreter is the handy subject.
        try:
            sample(os.getpid())
            print("FAIL selftest arena: sampled a non-arena process"); ok = False
        except NotAnArena:
            print("PASS selftest arena: non-arena process reported as such, not as dead")
        except Dead:
            print("FAIL selftest arena: reported 'dead' for a LIVE non-arena process")
            ok = False

        # --- red 0b: an ALREADY-DEAD pid must raise Dead cleanly, not escape
        #     as an OSError traceback out of the mapping read.
        import subprocess as _sp
        _c = _sp.Popen([sys.executable, "-c", "pass"]); _c.wait()
        try:
            regions(_c.pid)
            print("FAIL selftest deadpid: read a mapping for a dead pid"); ok = False
        except Dead:
            print("PASS selftest deadpid: dead pid raises Dead, not a traceback")
        except OSError:
            print("FAIL selftest deadpid: OSError escaped instead of Dead"); ok = False

        # --- red 1: a RECYCLED pid (same pid, different starttime) must be
        #     refused even though the pid is very much alive.
        try:
            sample(pid, (pid, b"0"))
            print("FAIL selftest recycle: sampled an impostor identity"); ok = False
        except Dead:
            print("PASS selftest recycle: wrong starttime refused though pid is alive")

        # --- red 2: the liveness rule must fire, and must NOT look like a plateau
        proc.kill()
        proc.wait()
        try:
            sample(pid, pinned)
            print("FAIL selftest red: sampled a DEAD process without raising"); ok = False
        except Dead as exc:
            print(f"PASS selftest red: {exc}")
    finally:
        if proc.poll() is None:
            proc.kill()
        os.unlink(path)
    return 0 if ok else 1


def peak_mode(pid, interval, max_heap_mib):
    """Sample heap until the subject EXITS (a workload finishing is normal here,
    not an error), report peak heap, and gate on it.  This is what turns the
    instrument into an acceptance test: the leaky binary drives heap far past a
    small bound (RED); the allocation-volume fix keeps it near GC_INTERVAL
    (GREEN).  climb-vs-flat, made executable.

    A subject that exits before we ever get one arena sample is reported as a
    setup failure (exit 2), never as heap=0 -> spurious GREEN."""
    pinned = identity(pid)
    if pinned is None:
        print(f"heapscope: pid {pid} exited before any sample -- "
              f"cannot gate on a subject that never ran", file=sys.stderr)
        return 2
    peak = None
    try:
        while True:
            row = dict(sample(pid, pinned))
            h = mib(row["heap"])
            peak = h if peak is None else max(peak, h)
            time.sleep(interval)
    except Dead:
        pass                      # the workload finished -- expected end of run
    except NotAnArena as exc:
        print(f"heapscope: {exc}", file=sys.stderr)
        return 3
    if peak is None:
        print("heapscope: subject exited before a single heap sample -- "
              "not a real measurement (use a longer-running workload)",
              file=sys.stderr)
        return 2
    verdict = "PASS" if peak <= max_heap_mib else "FAIL"
    print(f"{verdict}  peak heap = {peak:.1f} MiB  (bound {max_heap_mib:.1f} MiB) "
          f"-- {'bounded' if verdict=='PASS' else 'UNBOUNDED: frontier drift present'}")
    return 0 if verdict == "PASS" else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--selftest", action="store_true",
                    help="verify the instrument itself (green + red); no pid needed")
    ap.add_argument("pid", type=int, nargs="?")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--samples", type=int, default=0, help="0 = until it exits")
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--peak", action="store_true",
                    help="sample heap until the subject exits; gate on peak heap")
    ap.add_argument("--max-heap-mib", type=float, default=64.0,
                    help="--peak bound: PASS if peak heap <= this (default 64)")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if args.pid is None:
        ap.error("a pid is required (or use --selftest)")
    if args.peak:
        return peak_mode(args.pid, args.interval, args.max_heap_mib)

    if args.once:
        args.samples = 1

    pinned = identity(args.pid)
    if pinned is None:
        print(f"heapscope: pid {args.pid} is not running -- nothing to sample",
              file=sys.stderr)
        return 2
    try:
        names = [n for n, _, _ in regions(args.pid)]
    except Dead as exc:
        print(f"heapscope: {exc}", file=sys.stderr)
        return 2
    except NotAnArena as exc:
        print(f"heapscope: {exc}", file=sys.stderr)
        return 3
    print(f"{'t':>7}  " + "  ".join(f"{n:>12}" for n in names) + "   (MiB resident)")

    t0 = time.time()
    n = 0
    try:
        while True:
            row = sample(args.pid, pinned)
            print(f"{time.time() - t0:7.1f}  "
                  + "  ".join(f"{mib(p):12.1f}" for _, p in row))
            n += 1
            if args.samples and n >= args.samples:
                break
            time.sleep(args.interval)
    except NotAnArena as exc:
        print(f"\nheapscope: {exc}", file=sys.stderr)
        return 3
    except Dead as exc:
        # LOUD, and on stderr with a non-zero exit -- the whole point is that
        # this can never be mistaken for the measurement levelling off.
        print(f"\nheapscope: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
