; link_test_kseam_entry.inc — the TRACKED stand-in for kernel/entry.inc, which kernel/build_k1.sh GENERATES from
; the compiled LA image's e_entry. Used only by gate_link_kernel.sh: it copies this to .kseam/entry.inc, generates
; 256 zero bytes as the incbin'd LA image beside it, and assembles kernel/boot.asm from this commit.
; LA_ENTRY's value lands in boot.o's bytes (push qword LA_ENTRY, mov rax, LA_ENTRY), but ONE object feeds both ld
; and link.la, so the linker comparison never depends on it. It points far past the 256-byte stub image (kernel.ld
; places the image at 0x400000, boot.asm:25-26), so no LA program runs: that is why the gate's step 4, the boot
; comparison, is a named SKIP on this stub.
; Tracked 2026-09-10. The gate used to read an IGNORED copy (.bootfix2_HH2B/entry.inc, this same line) and, in any
; fresh checkout, fell back to track D's worktree.
LA_ENTRY equ 0x410a9e
