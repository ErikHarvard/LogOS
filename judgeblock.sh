#!/usr/bin/env bash
# judgeblock.sh — judge a SAVED module output through build.sh's own, VERBATIM case block.
#
#   sh judgeblock.sh <saved-output> <build.sh line | module.la>      → prints ok=0/1 + the FAIL lines
#   sh judgeblock.sh --selftest                                      → green, truncated, and planted-bad cases
#
# Why (meta-architecture B1, 2026-09-26): on 09-25 F39 was "confirmed" by ONE output token and the
# appendix's second arm was missed; it was caught only by extracting build.sh's case blocks and running
# the output through them. This tool is that step: no hand-picked token stands in for the gate.
#
# The block is: the line `VAR="$(… ./tiny_host m.la …)"` through the line before the next top-level
# `say`. The command substitution on that ONE line is replaced by `cat <saved-output>`; every other
# line is build.sh's own text. The block runs in bash with ok=1; the verdict is the block's own ok.
#
# REFUSES (rc 2, never a verdict) when: the line is not that assignment shape (function-call gates
# such as cxi/f3check are out of scope) · the block runs tiny_host AGAIN (it would need the host) ·
# the block calls a command that is not defined here (a build.sh helper) · a module name matches
# 0 or >1 blocks. Side files the block reads (e.g. la_lexicon_appendix.tex) are read from the cwd, and
# listed — a verdict that used a side file says which one, since another run may have rewritten it.
# the build file is read PER CALL (JB_BUILD), so the selftest fixture really is what gets judged

extract() {  # $1 = line number → the block on stdout
  awk -v n="$1" 'NR==n{on=1} on && NR>n && /^say /{exit} on{print}' "$BUILD"
}

judge() {  # $1 = saved output, $2 = line or module
  out=$1; where=$2; BUILD=${JB_BUILD:-build.sh}
  [ -f "$out" ] || { echo "REFUSE judgeblock: no saved output at $out"; return 2; }
  case "$where" in
    *.la) m=$(printf '%s' "$where" | sed 's/[.]/[.]/g')
          lines=$(command grep -nE "^[A-Z_0-9]+=\"\\\$\\((timeout [0-9]+ )?\\./tiny_host $m( |\\))" "$BUILD" | cut -d: -f1)
          c=$(printf '%s\n' "$lines" | command grep -c .)
          [ "$c" -eq 1 ] || { echo "REFUSE judgeblock: $where matches $c assignment blocks in $BUILD (lines: $(echo $lines)) — pass the line number"; return 2; }
          n=$lines ;;
    *[!0-9]*|'') echo "REFUSE judgeblock: '$where' is neither a line number nor a module.la"; return 2 ;;
    *) n=$where ;;
  esac
  head=$(sed -n "${n}p" "$BUILD")
  var=$(printf '%s\n' "$head" | sed -nE 's/^([A-Z_0-9]+)="\$\(.*\.\/tiny_host [^ )]+.*$/\1/p')
  [ -n "$var" ] || { echo "REFUSE judgeblock: $BUILD:$n is not a VAR=\"\$(… ./tiny_host m.la …)\" line: $head"; return 2; }
  blk=$(extract "$n")
  nl=$(printf '%s\n' "$blk" | wc -l)
  rest=$(printf '%s\n' "$blk" | tail -n +2)
  if printf '%s\n' "$rest" | command grep -v '^[[:space:]]*#' | command grep -q 'tiny_host'; then
    echo "REFUSE judgeblock: the block at $BUILD:$n runs tiny_host again below its first line — it needs the host, not a saved output"; return 2
  fi
  # The first line, with its command substitution (and any `|| rc=$?`-style tail kept) rewritten to cat.
  # Everything after the first `$(` up to its closing `)"` is replaced; nothing else on the line is touched.
  first=$(printf '%s\n' "$head" | sed -E "s/^${var}=\"\\\$\\(.*\\)\"/${var}=\"\$(cat \"\$JB_OUT\")\"/")
  [ "$first" != "$head" ] || { echo "REFUSE judgeblock: could not rewrite the substitution on $BUILD:$n"; return 2; }
  checks=$(printf '%s\n' "$rest" | command grep -cE 'ok=0')
  [ "$checks" -gt 0 ] || { echo "REFUSE judgeblock: the block at $BUILD:$n contains no ok=0 arm — nothing in it can fail"; return 2; }
  side=$(printf '%s\n' "$rest" | command grep -v '^[[:space:]]*#' | command grep -oE '[A-Za-z0-9_./-]+\.(tex|txt|out|json|md|la)' | sort -u |
         while read -r f; do [ -f "$f" ] && printf '%s ' "$f"; done)
  err=$(mktemp); res=$(mktemp)
  { printf 'ok=1\n%s\n' "$first"; printf '%s\n' "$rest"; printf '\necho "JB_OK=$ok"\n'; } |
    JB_OUT="$out" bash 2>"$err" >"$res"
  if command grep -q 'command not found' "$err"; then
    echo "REFUSE judgeblock: the block calls a command not defined outside build.sh:"; sed 's/^/  /' "$err"
    rm -f "$err" "$res"; return 2
  fi
  ok=$(sed -n 's/^JB_OK=//p' "$res" | tail -1)
  echo "block $BUILD:$n-$((n+nl-1)) ($nl lines, $checks fail arms, var $var) · output $out ($(wc -c <"$out") bytes)${side:+ · side files read: $side}"
  command grep '^FAIL' "$res"
  [ -s "$err" ] && { echo "stderr from the block:"; sed 's/^/  /' "$err"; }
  rm -f "$err" "$res"
  case "$ok" in 1) echo "ok=1"; return 0 ;; 0) echo "ok=0"; return 1 ;;
    *) echo "REFUSE judgeblock: the block ended without a verdict (ok='$ok')"; return 2 ;; esac
}

selftest() {  # every case must be decided the way stated, or the tool is not trusted
  d=$(mktemp -d); pass=0; fail=0
  t() { want=$1; shift; got=$(judge "$@" >/dev/null 2>&1; echo $?)
        if [ "$got" = "$want" ]; then pass=$((pass+1)); echo "  ok   rc=$got  $*"; else fail=$((fail+1)); echo "  BAD  rc=$got want $want  $*"; judge "$@" 2>&1 | sed "s/^/       /"; fi; }
  # A fixture build.sh with the real shapes: a timeout'd assignment, two arms, a side file, a PASS echo.
  cat > "$d/b.sh" <<'EOF'
say "one"
X="$(timeout 60 ./tiny_host m.la 2>&1 || true)"
case "$X" in *"alpha=1"*) : ;; *) echo "FAIL  m: alpha"; ok=0 ;; esac
case "$X" in *"beta=2"*) : ;; *) echo "FAIL  m: beta"; ok=0 ;; esac
echo "PASS  m (this line prints whatever ok is — the tool must not read it as a verdict)"
say "two"
Y="$(./tiny_host n.la 2>/dev/null)"
case "$Y" in *z*) : ;; *) echo "FAIL n"; ok=0 ;; esac
./tiny_host again.la >/dev/null 2>&1
say "three"
Z="$(./tiny_host h.la 2>/dev/null)"
nothelper "$Z"
case "$Z" in *z*) : ;; *) ok=0 ;; esac
say "four"
W="$(./tiny_host w.la)"
echo "no arm can fail"
say "five"
EOF
  printf 'alpha=1\nbeta=2\n' > "$d/green"; printf 'alpha=1\n' > "$d/trunc"; : > "$d/empty"
  echo "selftest (fixture):"
  JB_BUILD="$d/b.sh" t 0 "$d/green" 2           # both arms satisfied
  JB_BUILD="$d/b.sh" t 1 "$d/trunc" 2           # RED: the SECOND arm catches a truncation the first passes
  JB_BUILD="$d/b.sh" t 1 "$d/empty" m.la        # RED by module name
  JB_BUILD="$d/b.sh" t 2 "$d/green" 7           # refuse: block re-runs tiny_host
  JB_BUILD="$d/b.sh" t 2 "$d/green" 11          # refuse: undefined helper
  JB_BUILD="$d/b.sh" t 2 "$d/green" 14          # refuse: no fail arm
  JB_BUILD="$d/b.sh" t 2 "$d/green" 3           # refuse: not an assignment line
  JB_BUILD="$d/b.sh" t 2 "$d/nosuch" 2          # refuse: no output
  # The real build.sh on a real saved output (09-25, runner5): green, then truncated to its first line.
  if [ -f .freeze-out/r5/lexappendix.out ]; then
    echo "selftest (real build.sh, lexappendix.out from 09-25):"
    head -c 60 .freeze-out/r5/lexappendix.out > "$d/lt"   # one-line output: cut mid-line, before "rows==entries OK"
    t 0 .freeze-out/r5/lexappendix.out lexappendix.la
    t 1 "$d/lt" lexappendix.la
  else echo "  (real-output case SKIPPED: .freeze-out/r5/lexappendix.out absent)"; fi
  rm -rf "$d"; echo "selftest: $pass ok, $fail bad"; [ "$fail" -eq 0 ]
}

case "$1" in
  --selftest) selftest ;;
  ''|-h|--help) sed -n '2,5p' "$0"; exit 2 ;;
  *) judge "$1" "$2" ;;
esac
