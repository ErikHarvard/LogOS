# LogOS — static analysis: shellcheck (every `.sh`) and cppcheck (`tiny_host.c`)

Read-only. Tree analysed: `kernel-k1` at `9df29b0` (the base of the fix branches). Tools: ShellCheck 0.9.0 (`shellcheck -f gcc *.sh kernel/*.sh`), Cppcheck 2.13.0 (`cppcheck --enable=all --inconclusive --std=c11 --suppress=missingIncludeSystem tiny_host.c`). Nothing in the repository was changed.

## Summary

| Tool | Files | Findings | Real | Style/noise | False positive |
|---|---|---|---|---|---|
| shellcheck | 68 scripts (root + `kernel/`) | 93 | 3 errors + 52 warnings, of which ~48 are one recurring class | 38 notes | 7 |
| cppcheck | `tiny_host.c` | 6 (+1 info) | 0 | 6 | 0 |

`tiny_host.c` is clean by cppcheck's standards: no error, warning, performance or portability finding; only six `constVariablePointer` style notes. The shell scripts have one systemic issue (`cd` without a failure check, 43 sites), three genuine parse errors in `kernel/gate_k3a.sh` and `kernel/gate_k4a.sh`, and a handful of real quoting/logic problems.

## shellcheck — by severity

### ERROR (3) — real

| Where | Code | Finding |
|---|---|---|
| `kernel/gate_k3a.sh:13:326` | SC1102 | `$((` is ambiguous: shells parse it as arithmetic, not command substitution. The gate's condition may not evaluate as intended (`(( … ))` vs `$( ( … ) )`). |
| `kernel/gate_k4a.sh:24:329` | SC1102 | same |
| `kernel/gate_k4a.sh:35:336` | SC1102 | same |

Each is paired with SC2211 ("a glob used as a command name") at the same position — the parser has already gone wrong by then. These three lines are ~330 characters long; the fix is `$( (` with a space, and splitting the line.

### WARNING (52)

| Code | Count | Finding | Verdict |
|---|---|---|---|
| SC2164 | 43 | `cd … ` without `|| exit`: if the `cd` fails the script keeps running in the wrong directory. `gate_crypto.sh:42`, `gate_sha256.sh:25`, `stage4_seed_capture.sh:2` (`cd ~/logos`), and 40 `kernel/gate_*.sh` files. | **Real, systemic.** Several of these gates then `rm -f` or write build products. Fix: `cd "$dir" || exit 1`, or `set -e` at the top (only `gate_rss.sh` and a few others have it). |
| SC2211 | 3 | glob as command name | consequence of the SC1102 errors above |
| SC2046 | 1 | `build.sh:3109:68` unquoted `$(…)` word-splits | **Real** if the substituted value can contain spaces; check the variable's producer. |
| SC2024 | 1 | `drm_bringup_term.sh:97` `sudo cmd > file`: the redirect runs as the user, not root. | **Real** if `file` is root-owned; otherwise harmless. Use `| sudo tee`. |
| SC2034 | 1 | `freeze_q1_diff.sh:161` variable `out` assigned, never used | **Real** (dead code or a typo for a used name). |

### NOTE (38)

| Code | Count | Finding | Verdict |
|---|---|---|---|
| SC2015 | 19 | `A && B || C` is not if-then-else (`C` also runs when `A` succeeds but `B` fails). `build.sh:2884, 3767, 3814, 5067-5072, 5417, 6699, 6750, 7157, 7248, 7320`; `gate_bootelf.sh:56,119,125`; `gate_ratchet.sh:29`. | **Mostly false positive in this codebase**: the idiom here is `check && echo PASS || { echo FAIL; ok=0; }` where `B` is an `echo` that cannot fail. Real only where `B` is a command that can fail (none found on inspection of the 19 sites, but each new use should be `if/else`). |
| SC2086 | 13 | unquoted variable expansions. `build.sh:5414/5416` (×6), `kernel/build_k7b.sh:62-80` (×7). | **Real but low risk**: the values are numeric or space-free today. Quote them. |
| SC2016 | 4 | `gate_claimindex.sh:35,39,40` — `$` inside single quotes | **False positive**: these are awk/sed programs where `$1` is intended literally. |
| SC2162 | 2 | `kernel/build_k7b.sh:42,43` `read` without `-r` | Real but low risk (backslashes in input are mangled). |
| SC2018/SC2019 | 2 | `gate_claimindex.sh:35` `tr a-z A-Z` — use `[:lower:]`/`[:upper:]` | Style; matters only for non-ASCII input. |
| SC2001 | 1 | `gate_claimindex.sh:50` `sed` could be `${var//…}` | Style. |

### Known/likely false positives (7 marked)

SC2016 ×4 (`gate_claimindex.sh`: literal `$` in awk/sed), SC2015 where `B` is `echo` (representative: `build.sh:5067-5072`, six identical assertion lines — counted as 3 of the 19 here for the summary; the rest need a one-line look each).

### What is *not* flagged, and why that is not a clean bill
shellcheck does not model `set -e` semantics inside `x=$(cmd); rc=$?` (the dead-check pattern found in the first audit at `build.sh` 918/1332/1364/1402/1456/2028 on `965e734`; those lines have moved on kernel-k1), nor fixed `/tmp` paths, nor missing `mktemp`. Those remain as previously reported.

## cppcheck — `tiny_host.c`

| Line | Severity | Id | Finding | Verdict |
|---|---|---|---|---|
| 115 | style | constVariablePointer | `Node *e` in `gc_known` could be `const Node *` | style only |
| 757, 803, 823, 841, 871 | style | constVariablePointer | `Node *v = eval(argexpr)` in five string builtins could be `const Node *` | style only; `v` is read-only in those bodies |
| — | information | checkersReport | 113/592 checkers active (the rest need `--library`/premium) | n/a |

No error, warning, performance, or portability finding. Cppcheck did **not** find the `mkstrn` use-after-free (fixed in `c8c77d0`) or the unchecked `malloc`/`strdup` (fixed in `0ff92a0`) — both are inter-procedural (GC-in-callee) or need null-return modelling, which cppcheck's default checkers do not do. Sanitizers and the LD_PRELOAD injection gate are the right tools for those classes; keep both.

## Recommended order
1. Fix the three SC1102 parse errors in `kernel/gate_k3a.sh` / `gate_k4a.sh` — a gate whose condition does not parse as intended is a non-falsifiable gate.
2. Add `|| exit 1` to all 43 `cd` sites (or `set -euo pipefail` headers — `build.sh` already has it; most `kernel/gate_*.sh` do not).
3. Quote the 13 SC2086 expansions; fix SC2046, SC2024, SC2034.
4. Adopt a `shellcheck` pass as a build gate (`shellcheck -S warning *.sh kernel/*.sh`), with SC2015/SC2016 disabled by comment at the sites that are intentional.
