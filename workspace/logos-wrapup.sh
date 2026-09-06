#!/bin/bash
# ============================================================
# LogOS End-of-Day Wrap-Up
# Run this when you're done for the day.
# It reports status across all five worktrees and closes.
# It does NOT push — publishing stays a human decision.
#
# Usage: ~/logos-wrapup.sh
# ============================================================

SESSION="logos"
DATE=$(date +%Y-%m-%d)

echo "=== LogOS End-of-Day Wrap-Up — $DATE ==="
echo ""

# ── Step 1: Check what each track has ───────────────────────
echo "--- Current state across all worktrees ---"
for dir in logos logos-b logos-c logos-d logos-e; do
    if [[ -d "$HOME/$dir" ]]; then
        cd "$HOME/$dir" || continue
        branch=$(git branch --show-current 2>/dev/null)
        uncommitted=$(git status --short 2>/dev/null | grep -v "^?" | wc -l | tr -d ' ')
        unpushed=$(git log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
        untracked=$(git status --short 2>/dev/null | grep "^?" | wc -l | tr -d ' ')
        printf "  %-12s branch=%-10s uncommitted=%-3s unpushed=%-3s untracked=%s\n" \
            "$dir" "$branch" "$uncommitted" "$unpushed" "$untracked"
    fi
done
echo ""

# ── Step 2: Ask Claude Code sessions to wrap up ─────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "--- Sending wrap-up directive to all tracks ---"
    WRAPUP="End of session. Wrap up your current task at the next clean stopping point. Do NOT start anything new. Report: (1) what you completed today, (2) what is committed, (3) what is uncommitted and why, (4) what the next session should start with. Then go idle."
    line="$(printf '%s' "$WRAPUP" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
    for pane in 0 1 2 3; do
        tmux send-keys -t "$SESSION:workspace.$pane" -l -- "$line"
        sleep 0.2
        tmux send-keys -t "$SESSION:workspace.$pane" Enter
        echo "  Pane $pane: wrap-up sent"
    done
    echo ""
    # A fixed wait cannot know when a track is done — Track C has run a
    # single turn for 17+ minutes. Nothing below depends on them finishing
    # (Step 3 only reports), so this is a courtesy pause, not a gate.
    echo "Pausing 60s so the tracks can acknowledge (this gates nothing)..."
    sleep 60
fi

# ── Step 3: REPORT what is unpushed — do NOT push ───────────
# The original script ran `git push` across all five worktrees. Two
# reasons that is wrong here. First, .git/hooks/pre-push blocks every
# push by design ("Publishing is a human decision, and an agent must
# not make it"), so the loop could only ever print five failures — and
# a script that reliably fails teaches you to reach for
# `git push --no-verify`, which is the exact bypass the hook exists to
# prevent. Second, the worktrees share one object store; concurrent
# pushes across them are explicitly outside what logos-agent isolates.
echo "--- Unpushed work (NOT pushed — publishing is yours) ---"
total=0
for dir in logos logos-b logos-c logos-d logos-e; do
    if [[ -d "$HOME/$dir" ]]; then
        cd "$HOME/$dir" || continue
        branch=$(git branch --show-current 2>/dev/null)
        if ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
            echo "  $dir ($branch): NO UPSTREAM — cannot measure unpushed"
            continue
        fi
        unpushed=$(git log '@{u}..HEAD' --oneline 2>/dev/null | wc -l | tr -d ' ')
        total=$((total + unpushed))
        if [[ "$unpushed" -gt 0 ]]; then
            echo "  $dir ($branch): $unpushed commit(s)"
            git log '@{u}..HEAD' --format='      %h %s' | cut -c1-78
        else
            echo "  $dir ($branch): nothing unpushed"
        fi
    fi
done
echo ""
if [[ "$total" -gt 0 ]]; then
    echo "  $total commit(s) are ready to publish. To do it, as the human:"
    echo "      cd ~/<worktree> && git push --no-verify"
    echo "  Review them first — nothing here has been pushed."
fi
echo ""

# ── Step 4: Write end-of-day status entry ───────────────────
STATUS_FILE="$HOME/logos-status.md"
if [[ -f "$STATUS_FILE" ]]; then
    echo "--- Appending end-of-day entry to status board ---"
    {
        echo ""
        echo "## End of Day — $DATE ($(date +%H:%M))"
        for dir in logos logos-b logos-c logos-d logos-e; do
            [[ -d "$HOME/$dir" ]] || continue
            ( cd "$HOME/$dir" || exit
              b=$(git branch --show-current 2>/dev/null)
              u=$(git status --short 2>/dev/null | grep -vc '^?')
              p=$(git log '@{u}..HEAD' --oneline 2>/dev/null | wc -l | tr -d ' ')
              echo "- $dir ($b): HEAD $(git rev-parse --short HEAD), $u uncommitted, $p unpushed" )
        done
    } >> "$STATUS_FILE"
    echo "  Status board updated ✓"
fi
echo ""

# ── Step 5: Confirm and close ───────────────────────────────
echo "--- Everything above is done. ---"
echo ""
echo "To close the workspace, run:"
echo "  tmux kill-session -t logos"
echo ""
echo "Or press Ctrl+B then : then type 'kill-session' in tmux."
echo ""
read -p "Kill the tmux session now? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    tmux kill-session -t "$SESSION" 2>/dev/null
    echo "Workspace closed. Good night."
else
    echo "Workspace left running. Close your laptop safely."
    echo "Sessions will be waiting when you return: tmux attach -t logos"
fi
