#!/bin/bash
# ============================================================
# LogOS Development Workspace
# Four-track layout: left | middle-top, middle-bottom | right
#
# Tracks:
#   A (left)         — audit / debug / holistic oversight
#   B (middle-top)   — LA completion arc
#   C (middle-bottom)— drivers / HAL
#   D (right)        — OS layers (LogosInit, etc.)
#
# Usage:
#   ./logos-workspace.sh          — start fresh
#   ./logos-workspace.sh attach   — reattach to existing session
#
# Remote Control (iPhone monitoring) is ON by default: each track
# starts with --remote-control and a distinct name, so the Claude
# app's Code section lists them as logos-A/B/C/D rather than four
# identical hostname entries. To start without it:
#   LOGOS_NO_RC=1 ./logos-workspace.sh
# ============================================================

SESSION="logos"

# ── Reattach if session already exists ──────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
    if [[ "$1" == "attach" ]] || [[ "$1" == "" ]]; then
        echo "LogOS session exists — attaching..."
        tmux attach-session -t "$SESSION"
        exit 0
    fi
    echo "Killing existing session to start fresh..."
    tmux kill-session -t "$SESSION"
fi

# ── Build the four-pane layout ───────────────────────────────
# Start with one full-screen pane
tmux new-session -d -s "$SESSION" -n workspace

# Split into left (33%) and right (67%)
tmux split-window -h -l 67% -t "$SESSION:workspace.0"

# Split right pane into middle (50% of right ≈ 33%) and right (33%)
tmux split-window -h -l 50% -t "$SESSION:workspace.1"

# Split middle pane vertically into middle-top and middle-bottom
tmux split-window -v -t "$SESSION:workspace.1"

# ── Pane assignments after splits ───────────────────────────
# 0 = left         (Track A — audit/debug)
# 1 = middle-top   (Track B — LA completion)
# 2 = middle-bottom(Track C — drivers)
# 3 = right        (Track D — OS layers)

# ── Remote Control flags ─────────────────────────────────────
# `logos-agent` passes any extra args through to `claude`, so the
# supported --remote-control flag does this properly. Do NOT send
# "/remote-control" with send-keys: the pane is running Claude Code,
# not a shell, and keystrokes land in its input box.
if [[ -n "${LOGOS_NO_RC:-}" ]]; then
    RC_A=""; RC_B=""; RC_C=""; RC_D=""; RC_E=""
    echo "Remote Control disabled (LOGOS_NO_RC set)."
else
    RC_A="--remote-control logos-A"
    RC_B="--remote-control logos-B"
    RC_C="--remote-control logos-C"
    RC_D="--remote-control logos-D"
    RC_E="--remote-control logos-E"
    echo "Remote Control enabled — each pane prints its own QR code."
fi

# ── Launch each track ────────────────────────────────────────
echo "Launching Track A (audit/debug) in left pane..."
tmux send-keys -t "$SESSION:workspace.0" \
    'echo "=== TRACK A: Audit / Debug ===" && ~/logos-agent a '"$RC_A"'' Enter

sleep 1

echo "Launching Track B (LA completion) in middle-top pane..."
tmux send-keys -t "$SESSION:workspace.1" \
    'echo "=== TRACK B: LA Completion Arc ===" && ~/logos-agent b '"$RC_B"'' Enter

sleep 1

echo "Launching Track C (drivers/HAL) in middle-bottom pane..."
tmux send-keys -t "$SESSION:workspace.2" \
    'echo "=== TRACK C: Drivers / HAL ===" && ~/logos-agent c '"$RC_C"'' Enter

sleep 1

echo "Launching Track D (OS layers) in right pane..."
tmux send-keys -t "$SESSION:workspace.3" \
    'echo "=== TRACK D: OS Layers ===" && ~/logos-agent d '"$RC_D"'' Enter

# ── Track E — the signature layer ───────────────────────────
# E gets its own WINDOW, not a fifth pane: five panes in one window
# leaves each too narrow to read, and E's work is independent of the
# other four. Ctrl-b 1 to reach it, Ctrl-b 0 to come back.
echo "Launching Track E (signature layer) in window 1..."
tmux new-window -t "$SESSION" -n trackE
tmux send-keys -t "$SESSION:trackE" \
    'echo "=== TRACK E: Signature Layer ===" && ~/logos-agent e '"$RC_E"'' Enter
tmux select-window -t "$SESSION:workspace"

# ── Set pane titles ─────────────────────────────────────────
tmux select-pane -t "$SESSION:workspace.0" -T "A: Audit/Debug"
tmux select-pane -t "$SESSION:workspace.1" -T "B: LA Completion"
tmux select-pane -t "$SESSION:workspace.2" -T "C: Drivers/HAL"
tmux select-pane -t "$SESSION:workspace.3" -T "D: OS Layers"

# ── Focus on left pane (Track A) and attach ─────────────────
tmux select-pane -t "$SESSION:workspace.0"
tmux attach-session -t "$SESSION"
