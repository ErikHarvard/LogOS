#!/usr/bin/env python3
"""contention_guard — is a timing-sensitive gate's result trustworthy right now?

WHY THIS EXISTS
---------------
`~/logos-agent`'s own honest-boundary note: CPU/RAM are NOT isolated between the
concurrent track sessions.  A gate with fixed `sleep`s and a wall-clock timeout
(D's HAL gates: fixed sleeps + a 90 s timeout) can go **falsely RED** under load
from another agent -- "a false RED an unattended agent then 'fixes'," i.e. an
agent burns a cycle debugging a non-bug, or worse, edits working code to chase a
timeout that was really the neighbour's build.

This is the TIMING analogue of heapscope's liveness rule (`logos-heapscope-instrument`):
a measurement taken under conditions that invalidate it must be FLAGGED, not
believed.  heapscope refuses to read a dead process as a plateau; this refuses
to read a load-induced timeout as a failure.

WHAT IT MEASURES (and why not loadavg)
--------------------------------------
loadavg is a 1/5/15-min average -- far too slow to catch the burst of a
neighbour's build during a 90 s gate.  The instantaneous signal a fixed-sleep
gate actually cares about is `procs_running` (field after "procs_running" in
/proc/stat): the number of tasks in the run queue THIS instant.  When
procs_running exceeds the core count, runnable tasks are waiting for a CPU, so a
fixed sleep no longer maps to the wall-clock time it assumed.  The ratio
peak(procs_running)/cores over the gate's run is the contention factor.

USAGE
    contention_guard.py --check [--max-ratio R]     # safe to run a timing gate now?
    contention_guard.py --watch [--max-ratio R] -- CMD...   # run CMD, judge its result
    contention_guard.py --selftest

EXIT STATUS
    0  gate result trustworthy (contention below R) / CMD succeeded uncontended
    1  --check: contention too high now  |  --watch: CMD's timing result is SUSPECT
    2  --watch: CMD failed AND ran uncontended -> a REAL failure, not load
    the wrapped CMD's own exit is always reported in the verdict line.
"""
import argparse
import os
import subprocess
import sys
import threading
import time


def procs_running():
    """Instantaneous run-queue depth from /proc/stat (not the slow loadavg)."""
    try:
        with open("/proc/stat") as fh:
            for line in fh:
                if line.startswith("procs_running"):
                    return int(line.split()[1])
    except OSError:
        pass
    return 0


def cores():
    return os.cpu_count() or 1


def sample_contention(seconds, interval=0.2):
    """Peak run-queue depth over a window, as a ratio of cores."""
    n = cores()
    peak = procs_running()
    t_end = time.time() + seconds
    while time.time() < t_end:
        peak = max(peak, procs_running())
        time.sleep(interval)
    return peak, n, peak / n


class Monitor(threading.Thread):
    """Sample run-queue depth continuously while a wrapped command runs."""
    def __init__(self, interval=0.2):
        super().__init__(daemon=True)
        self.interval = interval
        # NOT self._stop: threading.Thread has an internal _stop() method that
        # join() calls, and an Event here shadows it -> "Event is not callable".
        self._halt = threading.Event()
        self.peak = procs_running()

    def run(self):
        while not self._halt.is_set():
            self.peak = max(self.peak, procs_running())
            time.sleep(self.interval)

    def stop(self):
        self._halt.set()
        self.join(timeout=1.0)


def do_check(max_ratio):
    # a short instantaneous read -- "is it safe to START a timing gate now?"
    peak, n, ratio = sample_contention(seconds=1.0)
    safe = ratio <= max_ratio
    print(f"{'OK' if safe else 'BUSY'}  run-queue peak {peak} / {n} cores "
          f"= {ratio:.2f}x  (threshold {max_ratio:.2f}x) -- "
          f"{'timing gate results trustworthy' if safe else 'DEFER a timing gate: results would be suspect'}")
    return 0 if safe else 1


def do_watch(max_ratio, cmd):
    mon = Monitor()
    mon.start()
    t0 = time.time()
    try:
        rc = subprocess.call(cmd)
    except FileNotFoundError:
        mon.stop()
        print(f"contention_guard: cannot run {cmd[0]!r}", file=sys.stderr)
        return 2
    dt = time.time() - t0
    mon.stop()
    n = cores()
    ratio = mon.peak / n
    contended = ratio > max_ratio
    # The judgement matrix that makes this worth having:
    #   CMD ok               -> trustworthy pass (annotate contention for the record)
    #   CMD failed + calm     -> REAL failure (exit 2): believe it, it wasn't load
    #   CMD failed + contended-> SUSPECT (exit 1): re-run isolated before believing
    if rc == 0:
        print(f"PASS  cmd rc=0 in {dt:.1f}s; run-queue peak {mon.peak}/{n} "
              f"= {ratio:.2f}x -- result trustworthy")
        return 0
    if contended:
        print(f"SUSPECT  cmd rc={rc} in {dt:.1f}s UNDER CONTENTION "
              f"(run-queue peak {mon.peak}/{n} = {ratio:.2f}x > {max_ratio:.2f}x) "
              f"-- do NOT treat as a real failure; re-run isolated first")
        return 1
    print(f"REAL-FAIL  cmd rc={rc} in {dt:.1f}s while UNCONTENDED "
          f"(run-queue peak {mon.peak}/{n} = {ratio:.2f}x) -- believe this failure")
    return 2


def selftest():
    ok = True
    n = cores()

    # --watch, calm + success: a quick true command must read trustworthy PASS
    rc = do_watch(max_ratio=100.0, cmd=["true"])   # huge threshold = definitely calm
    if rc == 0:
        print("PASS selftest calm-pass: uncontended success reported trustworthy")
    else:
        print(f"FAIL selftest calm-pass: rc={rc}"); ok = False

    # --watch, calm + failure: a false command uncontended must read REAL-FAIL (2)
    rc = do_watch(max_ratio=100.0, cmd=["false"])
    if rc == 2:
        print("PASS selftest calm-fail: uncontended failure believed (exit 2)")
    else:
        print(f"FAIL selftest calm-fail: expected 2, got {rc}"); ok = False

    # --watch, contended + failure: a failing command with the threshold set to 0
    #   (so ANY run-queue occupant counts as contention) must read SUSPECT (1),
    #   never a believed failure.  This is the whole point of the tool.
    rc = do_watch(max_ratio=0.0, cmd=["false"])
    if rc == 1:
        print("PASS selftest contended-fail: failure-under-load flagged SUSPECT (exit 1)")
    else:
        print(f"FAIL selftest contended-fail: expected 1, got {rc}"); ok = False

    # under real load, --check must flip to BUSY.  Spawn (cores*2) busy threads.
    stop = threading.Event()
    def spin():
        while not stop.is_set():
            pass
    load = [threading.Thread(target=spin, daemon=True) for _ in range(n * 2)]
    for t in load:
        t.start()
    time.sleep(0.5)
    busy_rc = do_check(max_ratio=1.0)     # GIL caps python threads; may or may not trip
    stop.set()
    # Don't hard-assert the load trips it (GIL/scheduler dependent); report honestly.
    print(f"NOTE selftest load-check: --check returned "
          f"{'BUSY' if busy_rc else 'OK'} under {n*2} spinners "
          f"(informational -- python's GIL bounds real parallelism)")

    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--watch", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--max-ratio", type=float, default=1.0,
                    help="contention factor above which timing results are suspect "
                         "(peak run-queue / cores; default 1.0 = fully subscribed)")
    ap.add_argument("cmd", nargs=argparse.REMAINDER,
                    help="with --watch: -- then the command to run")
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if args.check:
        return do_check(args.max_ratio)
    if args.watch:
        cmd = args.cmd[1:] if args.cmd and args.cmd[0] == "--" else args.cmd
        if not cmd:
            ap.error("--watch needs a command: --watch -- CMD ...")
        return do_watch(args.max_ratio, cmd)
    ap.error("one of --check / --watch / --selftest is required")


if __name__ == "__main__":
    sys.exit(main())
