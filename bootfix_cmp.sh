#!/bin/sh
# Compare each patched arm against nasm: sections masked at relocation fields,
# relocation tables, the equ sites, and the HIGH_BASE encodings.
B="$HOME/logos-b"
for ARM in NONE HH1 HH2; do
  D="$B/.bootfix_$ARM"; cd "$D" 2>/dev/null || { echo "$ARM: no dir"; continue; }
  echo "=== $ARM ==========================================="
  for f in elfobj_out.o nasm_ref.o; do
    [ -s "$f" ] || { echo "  FAIL: $f missing/empty — refusing to compare"; continue 2; }
  done
  progbits() { readelf -SW "$1" | sed -n 's/.*\] \(\.[a-zA-Z0-9_.]*\) *PROGBITS.*/\1/p' | sort; }
  progbits nasm_ref.o > n.secs; progbits elfobj_out.o > o.secs
  [ -s n.secs ] || { echo "  FAIL: nasm object has no PROGBITS"; continue; }
  cmp -s n.secs o.secs && echo "  PASS section set identical: $(tr '\n' ' ' < n.secs)" \
                       || echo "  FAIL section set differs (ours: $(tr '\n' ' ' < o.secs))"
  while read -r s; do
    objcopy -O binary --only-section="$s" nasm_ref.o   "n$s.bin" 2>/dev/null
    objcopy -O binary --only-section="$s" elfobj_out.o "o$s.bin" 2>/dev/null
    nb=$(stat -c%s "n$s.bin" 2>/dev/null || echo 0); ob=$(stat -c%s "o$s.bin" 2>/dev/null || echo 0)
    [ "$nb" -eq 0 ] && continue
    nr=$(python3 "$B/maskrel.py" nasm_ref.o   "$s" "n$s.bin" "nm$s.bin") || { echo "  FAIL $s: mask refused"; continue; }
    python3 "$B/maskrel.py" elfobj_out.o "$s" "o$s.bin" "om$s.bin" >/dev/null || { echo "  FAIL $s: mask refused"; continue; }
    if cmp -s "nm$s.bin" "om$s.bin"; then
      printf '  PASS %-11s %5s B identical outside %s reloc field(s)%s\n' "$s" "$nb" "$nr" \
        "$([ "$nb" -ne "$ob" ] && echo "  [SIZE ours=$ob]" )"
    else
      printf '  FAIL %-11s differs outside relocs: %s\n' "$s" "$(cmp "om$s.bin" "nm$s.bin" | head -1)"
    fi
  done < n.secs
  readelf -rW nasm_ref.o   | awk 'NF>3 && $1 ~ /^[0-9a-f]+$/ {print $1,$3,$5,$6,$7}' | sort > n.rel
  readelf -rW elfobj_out.o | awk 'NF>3 && $1 ~ /^[0-9a-f]+$/ {print $1,$3,$5,$6,$7}' | sort > o.rel
  if cmp -s n.rel o.rel; then echo "  PASS relocation tables identical ($(wc -l < n.rel) entries)"
  else echo "  FAIL relocation tables differ"; diff n.rel o.rel | head -4 | sed 's/^/        /'; fi
  oh=$(xxd -p "o.boot32.bin" 2>/dev/null | tr -d '\n'); nh=$(xxd -p "n.boot32.bin" 2>/dev/null | tr -d '\n')
  printf '  HIGH_BASE 48c7c000000080: nasm=%s ours=%s   (old defect form b800000080: ours=%s)\n' \
    "$(printf '%s' "$nh"|grep -o 48c7c000000080|wc -l)" \
    "$(printf '%s' "$oh"|grep -o 48c7c000000080|wc -l)" \
    "$(printf '%s' "$oh"|grep -o b800000080|wc -l)"
  case $ARM in
    HH1) SITES="hh_msg_len:41b904000000";;
    HH2) SITES="hh2_ok_len:41b917000000 hh2_bad_len:41b918000000";;
    *)   SITES="";;
  esac
  for st in $SITES; do
    sym=${st%%:*}; pat=${st##*:}
    printf '  equ %-12s %s: nasm=%s ours=%s\n' "$sym" "$pat" \
      "$(printf '%s' "$nh"|grep -o "$pat"|wc -l)" "$(printf '%s' "$oh"|grep -o "$pat"|wc -l)"
  done
done
