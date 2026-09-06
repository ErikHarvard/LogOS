# workspace/ — the operator tooling the tracks run inside

Every file here lived only in `$HOME` until 2026-09-06, in no repository at
all. That included `logos-agent`, which is not a convenience script: it is the
**mechanical isolation** the multi-agent architecture depends on. The build has
~550 hardcoded `/tmp` paths, so two sessions sharing `/tmp` can have one gate
read another's artifact and judge it — a false green. `logos-agent` makes that
impossible rather than forbidden, by giving each session its own mount
namespace and tmpfs. Losing it loses the guarantee.

| File | What it is |
|---|---|
| `logos-agent` | launches a Claude session in a worktree with a private `/tmp` |
| `logos-workspace.sh` | the tmux workspace: four track panes plus a `trackE` window |
| `logos-directives.sh` | permanent per-track assignments; `a`\|`b`\|`c`\|`d`\|`e`\|`all` |
| `logos-wrapup.sh` | end-of-day report. **Reports unpushed work; does not push.** |
| `logos-gate` | serializes a timing-sensitive gate across tracks |
| `shims/timeout` | the gate lock's enforcement point — takes the lock BEFORE the countdown starts |
| `shims/qemu-system-x86_64` | detector for unserialized QEMU; never blocks, warns loudly |
| `tmux.conf` | mouse on, pane titles, status |

## These are COPIES. The live ones are in `$HOME`.

Nothing syncs them. An edit to `~/logos-agent` does not appear here, and a
change here does not take effect until it is copied back. That is a real
divergence hazard and it is stated rather than hidden — if these drift, the
committed copy is documentation of a machine that no longer exists.

## Two things that are load-bearing and easy to break

**The gate lock wraps the whole gate, outside the `timeout`.** All 36 QEMU
sites read `timeout 30 qemu-system-x86_64 ...`, and `timeout` starts the clock.
A lock taken *inside* would spend the gate's own budget waiting and manufacture
the false red it exists to prevent. That is why the enforcement point is a
`timeout` shim and not the QEMU shim.

**The lock file lives in `$HOME`, never `/tmp`.** Each agent has a private
tmpfs, so a lock in `/tmp` is invisible to every other track.
