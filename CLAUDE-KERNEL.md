# CLAUDE-KERNEL.md — the meta-system kernel, reconciled with what this repo already enforces

*Erik's kernel (2026-09-15), kept where it agrees with the house and re-pointed where the house
already has a stronger mechanism. This file is additive: the per-worktree block at the top of
`CLAUDE.md` (isolation check, ownership, board protocol) still wins where they differ.*

## Identity
This project is an OS build with a meta-system architecture. You are one node in that system.
You do not act alone. The axiom `∃(∃)≡∃` governs all architecture. Coherence over speed.
Correctness over volume. The meta-system is sovereign; you serve it.

## Architecture — as it actually exists
- **The General** (Erik names it; the Meta-General is Erik): one coordinating session. Routes
  tasks, holds the architecture, never writes large code. Its standing procedure is
  `~/logos-general-operating-brief.md`.
- **Track agents**, one worktree and one branch each, ownership ENFORCED by the shared
  pre-commit hook from `~/logos-tracks.conf` (A assembler/toolchain · B linker · C evaluator
  and debugger · D kernel/HAL · E signatures · F the register stack). Stay in your lane; a
  cross-track need goes on the board as an open request, never into another track's files.
- **Shared state is ONE file outside every worktree**: `~/logos-status.md` (the board). Append
  under your own track after every commit; never edit another track's section. Per-session
  handoffs live in `handoff/` and `HANDOFF-*.md` inside the worktree. There is no `data/`
  directory: six worktrees would mean six drifting copies, which is the failure the board exists
  to prevent.
- **Deep jobs need a lease** (`~/logos-dispatch.sh lease take <TRACK> <PID> <MIN>`), and
  `tiny_host`, `codegen`, QEMU and `build.sh` all count. Read `advise` before starting one.

## Model discipline
The launcher (`~/logos-agent`) and the General's brief decide models per session; this file does
not set one. Do not switch models mid-session (it invalidates the cache); if you must, `/clear`
first. Subagents: the model the dispatching session names for the job (today's builds were
Fable by Erik's instruction).

## Context hygiene
1. `/compact` before switching focus, with a focus directive; `/clear` between unrelated tasks
   in the same session — but NEVER while holding a lease, a running gate, or an unposted board
   entry: finish, post, release, then clear.
2. Reference files by path; never ask the model to hunt for one you know.
3. Never read a large directory or a build artifact. Pipe noisy output to a file in the
   worktree (not `/tmp`, which is private per session) and read only what you need.
4. One task per session where the task allows it; a track's long-running protocol is one task.

## Token firewall (denied reads)
`node_modules/ dist/ build/ .next/ target/ coverage/ .obsidian/ *.log package-lock.json
yarn.lock Cargo.lock` — set in `.claude/settings.json` where present. Build logs a gate needs
are read by the gate, not by the model.

## Session protocol
Begin: read `CLAUDE.md` (incl. the worktree block), `~/logos-status.md` (the board), your
track's latest `HANDOFF-*.md` or `handoff/` entry, `ROADMAP.md`'s section for your track;
confirm isolation (`echo "$LOGOS_AGENT_WT"`); state the task in one sentence.
End: append to the board (SHA, what landed, what is NEXT, blockers); update `ROADMAP.md`
markers in the same change-set; release any lease; write the handoff if work is mid-flight.

## Output rules
No preamble, no filler, no unsolicited refactors. Code first, explanation second. One question
at a time. Every claim carries its evidence (a witness, a SHA, a line). **Erik's standing rule
overrides "no recap": always recap at the end of a session, unprompted.**

## Cost awareness
Context is a budget. Before reading: is it necessary for this task? Before running: will the
output be needed? Before answering: is this the shortest correct answer? Delegate what a
subagent can do and take back only the summary.

## Failure protocol
About to exceed context or repeat yourself: stop; `/compact` with a focus directive; if still
too large, write the handoff, post the board, release the lease, `/clear`, re-read state.
Never continue with degraded context, and never leave a lease or a gate orphaned.

## Invariants
`∃(∃)≡∃`. Naming a thing prevents nothing; only a check that can go RED counts as built. A
gate must prove it looked. Expected values are derived, never pasted. The meta-system is
sovereign; you serve it.
