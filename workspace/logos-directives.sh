#!/bin/bash
# ============================================================
# LogOS Track Directives
# Permanent assignments for each track.
# Edit the ROADMAP sections as priorities shift.
# Run: ./logos-directives.sh [a|b|c|d|all]
# ============================================================

SESSION="logos"

# ============================================================
# TRACK A — AUDIT, DEBUG, FREEZE (permanent role)
# This track NEVER builds new features.
# It watches what the other three build and verifies it.
# ============================================================
TRACK_A="Track A — Audit and Verification (permanent role). You do NOT build new features. Your job is to watch, verify, and protect the project's integrity.

Daily tasks in order: (1) Check the overnight build — report completion and verdict as two separate facts, any FAIL line verbatim. (2) Run the clean-checkout probe: git clone the repo to /tmp/test_clone and confirm it builds. (3) Check ~/logos-status.md for what Tracks B, C, D reported. (4) Run gate_cleanco.sh and report. (5) If any track has uncommitted work that has been sitting for more than one session, flag it.

Freeze discipline: if any track proposes committing something, verify the gate can go RED before approving. A gate that cannot fail is not a gate. Check the isolation — LOGOS_AGENT_WT must be set before any commit is trusted.

Auto-commit rule: you MAY commit your own audit artifacts (status updates, findings documents) when they are complete. You do NOT commit other tracks' code. You flag it for the human.

Standard: witnessed not asserted. Every claim carries the control that verified it."

# ============================================================
# TRACK B — LINGUA ADAMICA COMPLETION ARC
# Goal: close all 38 unbuilt items in LA_COMPLETION.md
# ============================================================
TRACK_B="Track B — Lingua Adamica Completion Arc. Goal: complete LA against its full philosophical specification.

DERIVE the priority order FROM LA_COMPLETION.md each session, in tier order, and state the counts you read. This directive deliberately does NOT hardcode the list any more: it used to name five items and was already stale — a hardcoded order is how work silently gets deferred while the file says otherwise. The file is the list; this is only the standing rule for reading it. IN SCOPE, NOT DEFERRED (Erik, 2026-09-06): all open items are in scope. Nothing in the language arc waits on the OS work. The tiers are a dependency order, not a deferral. Note eight items added 2026-09-06 that no list previously carried: three debts the white paper names as owed (meta-referent sigil, ontomorphology census, self-invocation) and five rows from the paper's own ledger at v18 lines 4490-4535 (constant-time execution, Identity Adequacy's three collisions, lexical-depth use-gating, meta-autontopoiesis, Meta-Ontosemantic Closure). The ledger rows are the paper's OWN unmet criteria, so they rank with the tier they sit in rather than behind everything else.

Auto-commit rule: commit when (a) the gate passes AND (b) the gate has been shown able to go RED on a constructed violation. Both conditions required. State which red path was run in the commit message.

Do not start the next item until the current one is gated green with a verified red path. Read LA_COMPLETION.md item counts from the file before each session — not from memory."

# ============================================================
# TRACK C — DRIVERS AND HAL
# Goal: build the OS outward from the kernel
# ============================================================
TRACK_C="Track C — Drivers and Hardware Abstraction. Goal: extend LogOS from a booting kernel to a system that can talk to real hardware.

Priority order: (1) NIC send/receive — HAL.5b only did a single ARP; build a real send/receive stack with a gate that verifies actual packet exchange. (2) AletheiaFS (filesystem) — disk driver exists (ATA); the next layer is a filesystem so data persists across boots. Without this, nothing saves. (3) After filesystem: deepen the text terminal (backspace, scrolling, HAL.4g — currently red pending the GC fix; check if the GC fix has landed before touching this). (4) Network stack (TCP/IP) — after AletheiaFS.

Auto-commit rule: same as Track B. Gate must pass AND gate must be shown to go RED. Boot-test every artifact before gating. Report completion and verdict as two separate facts.

If the GC fix (kernel dies in 5-6 seconds) has not landed, that is your first item — nothing on the metal is reliable without it."

# ============================================================
# TRACK D — OS LAYERS
# Goal: build the layers above the kernel
# ============================================================
TRACK_D="Track D — OS Layers above the kernel. Goal: turn LogOS from a kernel into an environment.

Priority order: (1) LogosInit — the sovereign init daemon replacing systemd. Spec is in kernel/LOGOSINIT_SCOPE.md; four open questions need the human's ruling before code is written (whether minimal means tasks or fault-isolated processes, whether Codex Autopoieticus is available, and two others listed in Part 6 of the scope doc). Read the scope before building. (2) LogosIPC at full depth — typed IPC between isolated processes exists; the full encrypted capability-gated version replacing D-Bus does not. (3) Theourgia compositor at full depth — started, terminal on metal; full sovereign UI layer not built. (4) LogosPkg — sovereign package system.

Auto-commit rule: spec and scope documents may be committed freely. Code commits require a gate that can go red. Spec first, gate design second, build third — never in a different order.

Do not start item 2 until item 1 is committed and Track A has verified the clean-checkout passes."

# ============================================================
# TRACK E — THE SIGNATURE LAYER (added 2026-09-06)
# Runs in tmux window `trackE`, NOT a workspace pane.
# ============================================================
TRACK_E="Track E — the signature layer. Goal: a real public-key signature scheme in LA, on track-e.

START BY READING THE DIVERGENCE, because the lists disagree with the repo. track-e already carries wotsp.la, wotsp_prod.la, xmss.la, xmss_signer.la and five xmssidx modules, with 12 gate references in build.sh. kernel-k1 carries NONE of them — 7 commits diverged — and LA_COMPLETION.md, which lives on kernel-k1, still says 'A signature scheme. No public-key primitive exists.' That sentence is true from kernel-k1 and false in the repo. Your first task is to establish which parts are genuinely built and gated versus named, and report it. Do not assume either document.

Then, in order: (1) State the honest parameter position. The known bound is toy parameters and a stateful scheme — say plainly which parameters are production and which are demonstration, and what a stateful signer means for key reuse, because a signature scheme that silently reuses an index is worse than none. (2) Wire whatever is ungated: a gate must exist that can go RED on a forged signature, not merely PASS on a valid one. Verification that accepts everything is the failure mode here. (3) Entropy: the ledger row reads 'Privacy layer [B] writable; no entropy source, no signatures' — no RDRAND/RDSEED builtin exists on the metal. Signatures without an entropy source are a bound, not a completion; state it. (4) When the layer is genuinely gated, prepare it to merge into kernel-k1 so the rest of the project can see it — invisible work is the defect class this project spent 2026-09-06 pulling out four times.

Auto-commit rule: same as the other tracks. Gate passes AND gate shown able to go RED on a constructed violation. State which red path was run. Do NOT push."

# ============================================================
# SEND TO SPECIFIC TRACK OR ALL
# ============================================================
send_to_target() {
    local target="$1" text="$2" label="$3" line
    line="$(printf '%s' "$text" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
    [[ -z "$line" ]] && { echo "  $label: empty — skipped"; return; }
    tmux send-keys -t "$target" -l -- "$line"
    sleep 0.3
    tmux send-keys -t "$target" Enter
    echo "  $label: sent (${#line} chars)"
}

send_to_pane() {
    local pane="$1"
    local text="$2"
    local label="$3"
    line="$(printf '%s' "$text" | tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
    [[ -z "$line" ]] && { echo "  $label: empty — skipped"; return; }
    tmux send-keys -t "$SESSION:workspace.$pane" -l -- "$line"
    sleep 0.3
    tmux send-keys -t "$SESSION:workspace.$pane" Enter
    echo "  $label: sent (${#line} chars)"
}

TARGET="${1:-all}"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "ERROR: logos session not running. Start it first: ~/logos-workspace.sh"
    exit 1
fi

case "$TARGET" in
    a|A) send_to_pane 0 "$TRACK_A" "Track A" ;;
    b|B) send_to_pane 1 "$TRACK_B" "Track B" ;;
    c|C) send_to_pane 2 "$TRACK_C" "Track C" ;;
    d|D) send_to_pane 3 "$TRACK_D" "Track D" ;;
    e|E) send_to_target "$SESSION:trackE" "$TRACK_E" "Track E" ;;
    all)
        echo "Sending directives to all tracks..."
        send_to_pane 0 "$TRACK_A" "Track A"
        send_to_pane 1 "$TRACK_B" "Track B"
        send_to_pane 2 "$TRACK_C" "Track C"
        send_to_pane 3 "$TRACK_D" "Track D"
        tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx trackE \
            && send_to_target "$SESSION:trackE" "$TRACK_E" "Track E" \
            || echo "  Track E: window 'trackE' not open — skipped (launch: ~/logos-agent e)"
        ;;
    *)
        echo "Usage: $0 [a|b|c|d|e|all]"
        exit 1
        ;;
esac

echo "Done."
