#!/usr/bin/env bash
# gate_shellcheck.sh — shellcheck as a ratchet: no NEW finding in any script.
#
# WHAT IT GUARDS. `shellcheck *.sh kernel/*.sh` reports 93 findings on
# kernel-k1 @ 9df29b0 (3 errors: SC1102 in kernel/gate_k3a.sh and gate_k4a.sh,
# 52 warnings, 43 of them SC2164 `cd` without `|| exit`; 38 notes). Those are
# recorded in shellcheck.baseline. This gate fails only on a finding that is
# not in the baseline, so existing debt does not block a build while every new
# script, and every edit to an old one, is held to shellcheck's standard.
#
# HOW. Each finding is keyed <file>|<SCcode>|<source line, whitespace-collapsed>
# (not the line number, so an edit elsewhere in a file does not shift keys). The
# current findings are compared to the baseline as multisets: a key occurring
# more often than baselined is NEW. Baselined findings that no longer occur are
# reported as fixed (informational; delete their lines to tighten the ratchet).
#
# Needs: shellcheck (0.9.0 produced the baseline; another version may report a
# different set) and python3. Without shellcheck the gate SKIPs loudly. Read-only.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
if ! command -v shellcheck >/dev/null; then
    echo "SKIP  shellcheck gate: shellcheck not installed"; exit 0
fi
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
shellcheck -f gcc ./*.sh kernel/*.sh > "$T/now.txt" 2>/dev/null || true
python3 - "$T/now.txt" shellcheck.baseline <<'EOF'
import sys, re, collections
now_txt, base = sys.argv[1], sys.argv[2]
def key(f, line, code):
    src = open(f, encoding='utf-8', errors='replace').read().split('\n')[line-1]
    return f"{f}|{code}|{' '.join(src.split())}"
now = collections.Counter(); where = {}
for ln in open(now_txt):
    m = re.match(r'^(?:\./)?(.*?):(\d+):\d+: (\w+): (.*)\[(SC\d+)\]\s*$', ln)
    if not m: continue
    k = key(m.group(1), int(m.group(2)), m.group(5))
    now[k] += 1; where.setdefault(k, f"{m.group(1)}:{m.group(2)}: {m.group(3)}: {m.group(4).strip()} [{m.group(5)}]")
baseline = collections.Counter(l.rstrip('\n') for l in open(base) if l.strip() and not l.startswith('#'))
new = now - baseline
fixed = baseline - now
if fixed:
    print(f"NOTE  shellcheck gate: {sum(fixed.values())} baselined finding(s) no longer occur (delete from shellcheck.baseline to tighten)")
if new:
    print(f"FAIL  shellcheck gate: {sum(new.values())} NEW finding(s) not in shellcheck.baseline:")
    for k in sorted(new): print("      " + where[k])
    sys.exit(1)
print(f"PASS  shellcheck gate: {sum(now.values())} finding(s), none new (baseline {sum(baseline.values())})")
EOF
