# reports/ — read-only audit deliverables (2026-09-28)

Written against branch `kernel-k1` at `9df29b0` by the cloud audit session; nothing here
changes code. Each file says which tree and commit it describes.

- `LogOS_static_analysis.md` — shellcheck (68 scripts, 93 findings, graded) and cppcheck (`tiny_host.c`).
- `LogOS_builtin_contract_table.md` — draft contract table: every builtin × six engines, with a DISAGREEMENTS section.
- `LogOS_claims_ledger.md` — draft ledger of 312 checkable claims in CLAUDE.md, each BACKED / EXISTS-UNCHECKED / UNBACKED / CONTRADICTED / STALE.
- `build.yml.draft` — a GitHub Actions workflow draft. Kept OUT of `.github/workflows/` on purpose: its header lists what must change before it can pass (the 16 GiB emitted-heap memsz, run time, stated dependencies, the auto-tag side effect).

The earlier audit documents (`LogOS_bug_audit.md`, `LogOS_bug_audit_2.md`, `LogOS_root_causes.md`, `LogOS_dynamic_checks.md`) were delivered as files in the session and are not in this tree.
