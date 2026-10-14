# Machine-scoped `verified-*` tags

The LogOS Roadmap from 2026-09-27 (revision 10, Phase 1) says: mark every `verified-*` tag minted since the 16 GiB heap
change as *verified on Erik's machine*, not portable. This file is that mark; tags are immutable, so the record lives here.

The change: `HEAP_SIZE = 17179869184` (16 GiB) entered `native_codegen3.la` in `0268c3f` (2026-06-26, "Stage 4 COMPLETE:
native_codegen3 self-hosts") and has not moved since (`:537` at `30eac3e`). Every emitted ELF since then carries a 16 GiB
`PT_LOAD` memsz, which loads only on a machine that can map it (188 GB RAM here; a 16 GB CI runner cannot).

Tags minted AFTER `0268c3f`, and therefore **verified on Erik's machine only** (measured 2026-09-28 by LOIPON: `git tag -l
'verified-*'` gives 40, five after the commit):

| tag | date |
|---|---|
| `verified-2026-06-27-43c46e6` | 2026-06-27 |
| `verified-2026-07-03-57108d6` | 2026-07-03 |
| `verified-2026-07-08-9e28028` | 2026-07-08 |
| `verified-2026-08-20-9bf432a` | 2026-08-20 |
| `verified-2026-08-21-e9f76b4` | 2026-08-21 |

The 35 tags before `0268c3f` were minted under the earlier heap size and are not covered by this note; none of the 40 was
verified on a second machine. A tag becomes portable only when the full audit passes on a clean checkout on a machine that is
not this one (roadmap Phase 8, the milestone), after the heap becomes a parameter (Phase 3, Finding 0).
