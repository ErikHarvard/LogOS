#!/usr/bin/env bash
# gate_logosservices.sh — LogosServices (logosservices.la), LogosTime
# (logostime.la) and the GlyphLedger (logosledger.la), as real processes on
# the native VM.
#
# WHAT IT GUARDS. Every program is compiled on the VM and bundled (bundle.la)
# into its own executable; the manager runs them as child processes, and a
# client program (svcctl) talks to all three over logosipc channels. Checked
# against independent evidence, never against the module's own say-so: the
# kernel's view of the processes (/proc, pgrep), the gate's clocks (date,
# Python's CLOCK_MONOTONIC), Python's hashlib for every ledger link, and the
# manager's own timestamped log for the restart gaps.
#   errors   a dependency cycle and a missing dependency are refused loudly
#            (rc 1, the message) before anything starts; so is a channel
#            path that cannot be bound (a directory there), for the manager,
#            time and ledger alike, and time and ledger refuse a channel
#            another live server holds (which keeps its path)
#   signals  SIGTERM to the manager stops everything, rc 0, nothing left;
#            `stop logosservices` does the same through the channel
#   main     ten services (one is listed before the service it depends on):
#            status lists them all and the manager itself with its real pid;
#            dependency order; a second manager is refused the live channel;
#            stdout AND stderr reach logdir/<name>.log through the pipe; a
#            failed execv is logged and exits 127; on-failure / always / never;
#            the failing service is restarted with gaps 1,2,4,8,16 s and ends
#            failed after 5 restarts; a run of 10 s or more ends the row;
#            time answers now and mono; stop/start/restart; ledger append,
#            verify, tail and `broken <i>` after the gate edits the file (a
#            text field, a link field, a deleted last entry); the ledger
#            survives a restart; `restart logosservices` re-executes the
#            manager in place; shutdown ends every process with rc 0 and
#            removes the sockets.
# ISOLATION: a private temp dir (gate_wm_common.sh); the manager's channel is
# named after this shell's pid. The services' channels are the contract's
# fixed `time` and `ledger` (/tmp/logosipc-time, /tmp/logosipc-ledger), so two
# runs of this gate must not overlap. VM only; about 6 minutes, most of it
# the ledger's sha256 (CRYPT_REF: ~18 s per entry) and compiling it.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
R="$T/run"; mkdir -p "$R"
CHAN="svc$$"
cleanup() {
    pkill -KILL -f "$R/" 2>/dev/null
    [ -n "${SQ:-}" ] && kill "$SQ" 2>/dev/null
    rm -f "/tmp/logosipc-$CHAN" "/tmp/logosipc-${CHAN}b" "/tmp/logosipc-${CHAN}c"
    rmdir "/tmp/logosipc-${CHAN}d" /tmp/logosipc-time /tmp/logosipc-ledger 2>/dev/null
    rm -rf "$T"
}
trap cleanup EXIT
pass() { echo "PASS  services: $*"; }
fail() { echo "FAIL  services: $*"; ok=0; }
check() { if [ "$1" = 1 ]; then pass "$2"; else fail "$2"; [ -n "${3:-}" ] && echo "      $3"; fi; }

wm_setup logosservices.la logostime.la logosledger.la logosipc.la bundle.la \
         crypt_ref.la sha256.la hmac.la hkdf.la aead.la chacha20.la poly1305.la

# ── the gate's own programs ────────────────────────────────────────────────
cat > "$T/svcctl.la" <<'LAEOF'
# svcctl: reads ctl.req = "<channel>\n<type>\n<body>", sends one typed
# logosipc request, prints "<reply type> <reply body>" (noconn / noreply).
import("logosipc.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph CUT = Z(la self. la s. la k.
    str_eq(s)("")(la _. k("")(""))(la _.
      str_eq(str_head(s))("\n")(la _. k("")(str_tail(s)))
        (la _. self(str_tail(s))(la a. la b. k(concat(str_head(s))(a))(b)))("!"))("!"))
glyph RECVALL = Z(la self. la c. la acc.
    (la d. str_eq(d)("")(la _. acc)(la _. self(c)(concat(acc)(d)))("!"))(recv(c)("65536")))
glyph MAIN = CUT(read_file("ctl.req"))(la chan. la rest. CUT(rest)(la type. la body.
    (la s. (la r.
        str_eq(str_head(r))("-")
          (la _. (la _. exit("2"))(print(concat("noconn ")(r))))
          (la _. (la _. (la reply.
                    str_eq(reply)("")
                      (la _. (la _. exit("3"))(print("noreply")))
                      (la _. print(concat(MSG_TYPE(reply))(concat(" ")(MSG_BODY(reply)))))("!"))
                 (RECVALL(s)("")))
                 (send(s)(ENCODE(type)(body))))("!"))
      (connect(s)(concat("/tmp/logosipc-")(chan))))
    (socket("!"))))
LAEOF
cat > "$T/fail3.la" <<'LAEOF'
# a service that says when it started (monotonic), writes to stderr, waits 1 s, exits 3
glyph MAIN = (la _. (la _. (la _. exit("3"))(sleep("1")))
                    (write("2")("fail3: on stderr\n")))
             (print(concat("fail3: start ")(clock_gettime("1"))))
LAEOF
cat > "$T/ok0.la" <<'LAEOF'
# a service that ends cleanly after 1 s
glyph MAIN = (la _. (la _. exit("0"))(sleep("1")))(print(concat("ok0: start ")(clock_gettime("1"))))
LAEOF
cat > "$T/slow3.la" <<'LAEOF'
# a service that fails after a stable run of 11 s
glyph MAIN = (la _. (la _. exit("3"))(sleep("11")))(print(concat("slow3: start ")(clock_gettime("1"))))
LAEOF
cat > "$T/mgr.la" <<'LAEOF'
# the manager program: SVC_KIT with every builtin; the descriptor set is named
# by mgr.mode, the bundles' directory by mgr.dir, the channel by mgr.chan.
import("logosservices.la")
glyph NIL  = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph SVC  = la name. la path. la args. la deps. la restart. la k. k(name)(path)(args)(deps)(restart)
glyph B = la s. s(str_at)(ord)(str_to_int)(int_to_str)(concat)(str_eq)(str_len)
                 (add)(sub)(mul)(div)(mod)(lt)(int_eq)(bshl)
glyph X = la s. s(fork)(execv)(dup2)(pipe)(open)(close)(read)(write)(poll)(kill)
                 (waitpid)(clock_gettime)(getpid)(sigprocmask)(signalfd)(socket)
                 (bind)(listen)(connect)(unlink)(read_file)(stat)(mkdir)(exit)(error)
glyph P = la f. concat(read_file("mgr.dir"))(concat("/")(f))
glyph MAINSET =
  CONS(SVC("ledger")(P("logosledger"))("logosledger")(CONS("time")(CONS("logosservices")(NIL)))("on-failure"))(
  CONS(SVC("time")(P("logostime"))("logostime")(NIL)("always"))(
  CONS(SVC("fail")(P("fail3"))("fail3")(NIL)("on-failure"))(
  CONS(SVC("never")(P("fail3"))("fail3")(NIL)("never"))(
  CONS(SVC("once")(P("ok0"))("ok0")(NIL)("on-failure"))(
  CONS(SVC("flap")(P("ok0"))("ok0")(NIL)("always"))(
  CONS(SVC("ghost")("/nonexistent/ghost")("ghost")(NIL)("on-failure"))(
  CONS(SVC("argv")("/bin/sh")("sh -c echo$IFS[$0][$1];echo${IFS}to-stderr>&2 zero one")(NIL)("never"))(
  CONS(SVC("slow")(P("slow3"))("slow3")(NIL)("on-failure"))(
  NIL)))))))))
glyph TIMESET = CONS(SVC("time")(P("logostime"))("logostime")(NIL)("always"))(NIL)
glyph CYCLESET =
  CONS(SVC("a")(P("ok0"))("ok0")(CONS("b")(NIL))("never"))(
  CONS(SVC("b")(P("ok0"))("ok0")(CONS("c")(NIL))("never"))(
  CONS(SVC("c")(P("ok0"))("ok0")(CONS("a")(NIL))("never"))(
  CONS(SVC("d")(P("ok0"))("ok0")(NIL)("never"))(NIL))))
glyph MISSINGSET =
  CONS(SVC("a")(P("ok0"))("ok0")(NIL)("never"))(
  CONS(SVC("b")(P("ok0"))("ok0")(CONS("a")(CONS("nosuch")(NIL)))("never"))(NIL))
glyph MAIN = (la mode. la chan. SVC_KIT(B)(X)(la manager.
    str_eq(mode)("main")(la _. manager(MAINSET)(chan)("logs"))(la _.
    str_eq(mode)("term")(la _. manager(TIMESET)(chan)("logs2"))(la _.
    str_eq(mode)("cycle")(la _. manager(CYCLESET)(chan)("logs3"))(la _.
    str_eq(mode)("badchan")(la _. manager(TIMESET)(chan)("logs6"))(la _.
      manager(MISSINGSET)(chan)("logs4"))("!"))("!"))("!"))("!")))
  (read_file("mgr.mode"))(read_file("mgr.chan"))
LAEOF

# ── compile everything on the VM (in parallel), then bundle ────────────────
compile_one() {
    local d="$T/c_$1"; mkdir -p "$d"
    cp "$T"/*.la "$T/logos_secd" "$T/compiler.bin" "$d/"
    ( cd "$d" && cp compiler.bin logos_program.bin && cp "$1.la" logos_source.la \
        && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$d/err" && cp logos_program.bin "$T/$1.bin" )
}
PROGS="logosledger mgr logostime svcctl fail3 ok0 slow3 bundle"
t0=$(date +%s)
for p in $PROGS; do compile_one "$p" & done
wait
for p in $PROGS; do
    [ -s "$T/$p.bin" ] || { fail "compile $p on the VM: $(tail -c 300 "$T/c_$p/err" 2>/dev/null)"; exit 1; }
done
bundle_one() {   # stream name -> $R/name
    ( cd "$T/c_bundle" && cp "$T/$1.bin" logos_embed.bin && cp "$T/bundle.bin" logos_program.bin \
        && ./logos_secd >/dev/null 2>&1 && mv logos_app "$R/$2" )
}
for pair in mgr:logosservices logostime:logostime logosledger:logosledger svcctl:svcctl \
            fail3:fail3 ok0:ok0 slow3:slow3; do
    bundle_one "${pair%%:*}" "${pair##*:}" || { fail "bundle ${pair##*:}"; exit 1; }
done
echo "      (compiled and bundled in $(( $(date +%s) - t0 )) s)"
printf '%s' "$R" > "$R/mgr.dir"

# ── helpers ────────────────────────────────────────────────────────────────
# req DIR CHANNEL TYPE BODY -> ANS (the client's line), RRC (its rc)
req() {
    mkdir -p "$1"; printf '%s\n%s\n%s' "$2" "$3" "$4" > "$1/ctl.req"
    ANS=$(cd "$1" && timeout 200 "$R/svcctl" 2>&1); RRC=$?
}
C="$T/fg"
# start_mgr MODE CHANNEL -> MGRPID; stdout/stderr in $T/mgr_<mode>.{out,err}
start_mgr() {
    printf '%s' "$1" > "$R/mgr.mode"; printf '%s' "$2" > "$R/mgr.chan"
    ( cd "$R" && exec "$R/logosservices" ) > "$T/mgr_$1.out" 2> "$T/mgr_$1.err" &
    MGRPID=$!
}
# wait_up CHANNEL: until status answers (10 s)
wait_up() {
    for _ in $(seq 1 100); do req "$C" "$1" status ""; [ "$RRC" = 0 ] && return 0; sleep 0.1; done; return 1
}
# wait_exit PID SECONDS -> WRC (the exit status, or 124)
wait_exit() {
    local i; for i in $(seq 1 $(( $2 * 10 ))); do kill -0 "$1" 2>/dev/null || break; sleep 0.1; done
    if kill -0 "$1" 2>/dev/null; then WRC=124; else wait "$1"; WRC=$?; fi
}
left() { pgrep -af "$R/" | grep -v pgrep; }
# alone PROG -> ARC, AERR: a service run by itself (not under the manager), 10 s at most
alone() {
    mkdir -p "$T/alone"
    ( cd "$T/alone" && timeout 10 "$R/$1" ) > "$T/alone/out" 2> "$T/alone/err"; ARC=$?
    AERR=$(cat "$T/alone/err")
}
# squat PATH -> SQ: another live server listening at PATH (until killed)
squat() {
    python3 -c 'import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(4); time.sleep(60)' "$1" & SQ=$!
    for _ in $(seq 1 50); do [ -S "$1" ] && return 0; sleep 0.1; done; return 1
}
field() { echo "$ANS" | sed 's/^ok //' | awk -v n="$1" -v f="$2" '$1 == n { print $f }'; }

# ── errors before anything starts ──────────────────────────────────────────
for m in cycle missing; do
    printf '%s' "$m" > "$R/mgr.mode"; printf '%s' "${CHAN}c" > "$R/mgr.chan"
    ( cd "$R" && timeout 30 "$R/logosservices" ) > "$T/mgr_$m.out" 2> "$T/mgr_$m.err"; erc=$?
    if [ "$m" = cycle ]; then want="logosservices: dependency cycle among: a b c"; dir=logs3
    else want="logosservices: b: missing dependency nosuch"; dir=logs4; fi
    check "$([ "$erc" = 1 ] && [ "$(cat "$T/mgr_$m.err")" = "$want" ] && [ ! -e "$R/$dir" ] && [ -z "$(left)" ] && echo 1)" \
        "a $m is a loud error before anything starts (rc 1, \"$want\", no log dir, no process)" \
        "rc=$erc stderr=$(head -c 200 "$T/mgr_$m.err") dir=$(ls -d "$R/$dir" 2>/dev/null) left=$(left)"
done

# a channel whose path cannot be taken: a loud error, never a running manager
# or service that nobody can reach (bind fails on a directory: EADDRINUSE)
mkdir "/tmp/logosipc-${CHAN}d"
printf badchan > "$R/mgr.mode"; printf '%s' "${CHAN}d" > "$R/mgr.chan"
( cd "$R" && timeout 10 "$R/logosservices" ) > "$T/mgr_badchan.out" 2> "$T/mgr_badchan.err"; erc=$?
rmdir "/tmp/logosipc-${CHAN}d"
want="logosservices: cannot listen on the channel ${CHAN}d (bind -98)"
check "$([ "$erc" = 1 ] && [ "$(cat "$T/mgr_badchan.err")" = "$want" ] && [ -z "$(left)" ] \
         && ! grep -q " start " "$R/logs6/logosservices.log" && echo 1)" \
    "a channel path the manager cannot bind is a loud error before any service starts (rc 1, \"$want\")" \
    "rc=$erc stderr=$(head -c 200 "$T/mgr_badchan.err") left=$(left) log=$(tr '\n' '|' < "$R/logs6/logosservices.log")"
pkill -KILL -f "$R/" 2>/dev/null
for pc in logostime:time logosledger:ledger; do
    prog=${pc%%:*}; ch=${pc##*:}; p="/tmp/logosipc-$ch"
    mkdir "$p"; alone "$prog"; rmdir "$p"
    check "$([ "$ARC" = 1 ] && [ "$AERR" = "$prog: cannot listen on the channel $ch (bind -98)" ] && echo 1)" \
        "$ch: a channel path it cannot bind (a directory there) is a loud error (rc 1, the bind error)" "rc=$ARC stderr=$AERR"
    if squat "$p"; then
        alone "$prog"; [ -S "$p" ] && kept=1 || kept=0; kill "$SQ"; wait "$SQ" 2>/dev/null; SQ=; rm -f "$p"
        check "$([ "$ARC" = 1 ] && [ "$AERR" = "$prog: the channel $ch is already served" ] && [ "$kept" = 1 ] && echo 1)" \
            "$ch: a channel another live server holds is refused loudly (rc 1), and that server keeps its path" \
            "rc=$ARC stderr=$AERR path kept=$kept"
    else fail "$ch: the gate's own listener did not come up"; fi
done
pkill -KILL -f "$R/" 2>/dev/null

# ── SIGTERM, and `stop logosservices` ──────────────────────────────────────
start_mgr term "${CHAN}b"
if wait_up "${CHAN}b"; then
    tpid=$(field time 3)
    check "$([ "$(field time 2)" = running ] && kill -0 "$tpid" 2>/dev/null && echo 1)" "a one-service manager runs time" "$ANS"
    kill -TERM "$MGRPID"; wait_exit "$MGRPID" 10
    check "$([ "$WRC" = 0 ] && [ -z "$(left)" ] && [ ! -e "/tmp/logosipc-${CHAN}b" ] && [ ! -e /tmp/logosipc-time ] \
             && grep -q "signal: shutting down" "$R/logs2/logosservices.log" && grep -q "stopped time 0" "$R/logs2/logosservices.log" && echo 1)" \
        "SIGTERM: the manager stops its services and exits 0; no process, no socket left" \
        "rc=$WRC left=$(left) log=$(tail -3 "$R/logs2/logosservices.log" | tr '\n' '|')"
else fail "the one-service manager never answered: $(cat "$T/mgr_term.err")"; kill -KILL "$MGRPID" 2>/dev/null; fi
start_mgr term "${CHAN}b"
if wait_up "${CHAN}b"; then
    req "$C" "${CHAN}b" stop logosservices; a="$ANS"; wait_exit "$MGRPID" 10
    check "$([ "$a" = "ok shutdown" ] && [ "$WRC" = 0 ] && [ -z "$(left)" ] && [ ! -e "/tmp/logosipc-${CHAN}b" ] && echo 1)" \
        "self-application: \`stop logosservices\` is shutdown (reply, rc 0, nothing left)" "reply=$a rc=$WRC left=$(left)"
else fail "the one-service manager never answered (2): $(cat "$T/mgr_term.err")"; kill -KILL "$MGRPID" 2>/dev/null; fi

# ── the main run ───────────────────────────────────────────────────────────
rm -f "$R/glyphledger.txt" "$R/glyphledger.head"
start_mgr main "$CHAN"
TSTART=$(date +%s)
wait_up "$CHAN" || { fail "the manager never answered: $(cat "$T/mgr_main.err")"; exit 1; }
LOG="$R/logs/logosservices.log"
S1="$ANS"
names=$(echo "$S1" | sed 's/^ok //' | awk '{print $1}' | sort | tr '\n' ' ')
check "$([ "$names" = "argv fail flap ghost ledger logosservices never once slow time " ] && echo 1)" \
    "status lists every service, one line each" "$S1"
check "$([ "$(echo "$S1" | head -1)" = "ok logosservices running $MGRPID 0" ] && echo 1)" \
    "self-application: the manager lists itself as logosservices with its real pid ($MGRPID)" "$(echo "$S1" | head -1)"
TPID=$(field time 3); LPID=$(field ledger 3)
pp() { awk '{ s = $0; sub(/.*\) /, "", s); split(s, f, " "); print f[2] }' "/proc/$1/stat" 2>/dev/null; }
cmd() { tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null; }
check "$([ "$(field time 2)" = running ] && [ "$(field ledger 2)" = running ] && [ "$(pp "$TPID")" = "$MGRPID" ] \
         && [ "$(pp "$LPID")" = "$MGRPID" ] && [ "$(cmd "$TPID")" = "$R/logostime " ] && [ "$(cmd "$LPID")" = "$R/logosledger " ] && echo 1)" \
    "time and ledger are separate processes, children of the manager, running their own bundles" \
    "time=$TPID ppid=$(pp "$TPID") cmd=$(cmd "$TPID") ledger=$LPID ppid=$(pp "$LPID") cmd=$(cmd "$LPID")"
lt=$(grep -n " start time " "$LOG" | head -1 | cut -d: -f1); ll=$(grep -n " start ledger " "$LOG" | head -1 | cut -d: -f1)
check "$([ -n "$lt" ] && [ -n "$ll" ] && [ "$lt" -lt "$ll" ] && echo 1)" \
    "dependency order: time starts before ledger, which is listed first and depends on it (and on the manager itself)"
( cd "$R" && timeout 30 "$R/logosservices" ) > "$T/mgr_second.out" 2> "$T/mgr_second.err"; src=$?
req "$C" "$CHAN" status ""
check "$([ "$src" = 1 ] && grep -q "logosservices: the channel $CHAN is already served" "$T/mgr_second.err" \
         && [ "$(echo "$ANS" | head -1)" = "ok logosservices running $MGRPID 0" ] && echo 1)" \
    "a second manager is refused the live channel; the first keeps serving" "rc=$src $(cat "$T/mgr_second.err")"

# LogosTime (wait until it has bound its socket)
for _ in $(seq 1 50); do req "$C" time now ""; [ "$RRC" = 0 ] && break; sleep 0.1; done
nowd=$(date +%s); a="$ANS"
req "$C" time mono ""; b="$ANS"; pm=$(python3 -c 'import time; print(time.monotonic())')
python3 - "$a" "$nowd" "$b" "$pm" <<'PYEOF' && pass "time: now is the realtime clock (within 3 s of date), mono the monotonic one (within 2 s of Python's)" || fail "time: now='$a' (date $nowd) mono='$b' (python $pm)"
import sys
a, nowd, b, pm = sys.argv[1], int(sys.argv[2]), sys.argv[3], float(sys.argv[4])
t, s, ns = a.split(); assert t == "ok" and abs(int(s) - nowd) <= 3 and 0 <= int(ns) < 10**9
t, s, ns = b.split(); assert t == "ok" and abs(int(s) + int(ns) / 1e9 - pm) <= 2 and 0 <= int(ns) < 10**9
PYEOF
req "$C" time "what" ""
check "$([ "$ANS" = "err logostime: unknown request what" ] && echo 1)" "time: an unknown request is an err reply" "$ANS"

# ── the ledger, in the background (sha256 under CRYPT_REF is slow) ─────────
LC="$T/lc"; mkdir -p "$LC"
lreq() { req "$LC" ledger "$1" "$2"; printf '%s' "$ANS" > "$LC/r_$3"; }
ledger_job() {
    for _ in $(seq 1 50); do req "$LC" ledger tail 0; [ "$RRC" = 0 ] && break; sleep 0.1; done
    lreq append boot a1; lreq append alpha a2; lreq append "omega|pipe" a3
    cp "$R/glyphledger.txt" "$LC/orig.txt"; cp "$R/glyphledger.head" "$LC/orig.head"
    lreq verify "" v1
    lreq tail 2 t2
    python3 - "$LC/orig.txt" "$R/glyphledger.txt" text2 <<'PYEOF'
import sys
lines = open(sys.argv[1]).read().split("\n")
f = lines[1].split("|", 3); f[3] = "alphX"; lines[1] = "|".join(f)
open(sys.argv[2], "w").write("\n".join(lines))
PYEOF
    lreq verify "" v2
    python3 - "$LC/orig.txt" "$R/glyphledger.txt" <<'PYEOF'
import sys
lines = open(sys.argv[1]).read().split("\n")
f = lines[2].split("|", 3); f[2] = ("0" if f[2][0] != "0" else "1") + f[2][1:]; lines[2] = "|".join(f)
open(sys.argv[2], "w").write("\n".join(lines))
PYEOF
    lreq verify "" v3
    python3 - "$LC/orig.txt" "$R/glyphledger.txt" <<'PYEOF'
import sys
lines = open(sys.argv[1]).read().split("\n")
del lines[2]
open(sys.argv[2], "w").write("\n".join(lines))
PYEOF
    lreq verify "" v4
    cp "$LC/orig.txt" "$R/glyphledger.txt"
    lreq append "two
lines" an
    lreq tail many tk
    : > "$LC/done"
}
ledger_job > "$LC/job.log" 2>&1 &
LJ=$!

# stop / start / restart
req "$C" "$CHAN" stop time; a="$ANS"
req "$C" "$CHAN" status ""
check "$([ "$a" = "ok stopped time" ] && [ "$(field time 2) $(field time 3) $(field time 4)" = "stopped 0 0" ] && ! kill -0 "$TPID" 2>/dev/null && echo 1)" \
    "stop time: replied after the process is gone; status shows it stopped" "reply=$a status=$(echo "$ANS" | grep '^time')"
req "$C" time now ""
check "$([ "$RRC" = 2 ] && echo 1)" "a stopped time no longer answers (its socket is gone)" "$ANS"
req "$C" "$CHAN" start time; a="$ANS"; NTPID=$(echo "$a" | awk '{print $4}')
for _ in $(seq 1 50); do req "$C" time now ""; [ "$RRC" = 0 ] && break; sleep 0.1; done; b="$ANS"
req "$C" "$CHAN" status ""
check "$([ "$a" = "ok started time $NTPID" ] && [ "$NTPID" != "$TPID" ] && [ "$(field time 3)" = "$NTPID" ] && kill -0 "$NTPID" && [ "${b%% *}" = ok ] && echo 1)" \
    "start time: a new process, and time answers again" "start=$a now=$b"
req "$C" "$CHAN" start time; a1="$ANS"; req "$C" "$CHAN" stop nosuch; a2="$ANS"
req "$C" "$CHAN" bogus x; a3="$ANS"; req "$C" "$CHAN" start logosservices; a4="$ANS"
check "$([ "$a1" = "err time is already running" ] && [ "$a2" = "err no service nosuch" ] && [ "$a3" = "err unknown request bogus" ] \
         && [ "$a4" = "err logosservices is already running" ] && echo 1)" \
    "malformed control requests are err replies" "$a1 | $a2 | $a3 | $a4"
req "$C" "$CHAN" stop "x
1 exit fail 1 0"
check "$([ "${ANS%%
*}" = "err no service x" ] && ! grep -q "^1 exit fail" "$LOG" && grep -q " request stop ?$" "$LOG" && echo 1)" \
    "a request cannot write a line into the manager's log (a body with a newline is logged as ?)" "$ANS / $(tail -2 "$LOG" | tr '\n' '|')"

# ── the restart policies: wait until the failing service is given up ───────
for _ in $(seq 1 900); do
    req "$C" "$CHAN" status ""
    [ "$(field fail 2)" = failed ] && [ "$(field flap 2)" = failed ] && [ "$(field ghost 2)" = failed ] && break
    sleep 0.1
done
S2="$ANS"
st() { echo "$(field "$1" 2) $(field "$1" 3) $(field "$1" 4)"; }
check "$([ "$(st fail)" = "failed 0 5" ] && [ "$(st flap)" = "failed 0 5" ] && [ "$(st ghost)" = "failed 0 5" ] \
         && [ "$(st never)" = "failed 0 0" ] && [ "$(st once)" = "exited 0 0" ] && [ "$(st argv)" = "exited 0 0" ] && echo 1)" \
    "policies: fail/flap/ghost given up after 5 restarts; never not restarted; a clean on-failure exit stays exited" \
    "$(echo "$S2" | tr '\n' '|')"
python3 - "$LOG" "$R/logs" <<'PYEOF' || ok=0
import re, sys
log, logs = sys.argv[1], sys.argv[2]
ev = [l.split() for l in open(log).read().splitlines()]
bad = 0
def check(cond, what, detail=""):
    global bad
    print(("PASS" if cond else "FAIL") + "  services: " + what + ("" if cond else "\n      " + detail))
    if not cond: bad = 1
def events(name):
    starts = [int(e[0]) for e in ev if len(e) >= 5 and e[1] == "start" and e[2] == name]
    exits = [(int(e[0]), e[4]) for e in ev if len(e) >= 5 and e[1] == "exit" and e[2] == name]
    return starts, exits
for name, status in (("fail", "768"), ("flap", "0"), ("ghost", "32512")):
    starts, exits = events(name)
    gaps = [s - x[0] for s, x in zip(starts[1:], exits)]
    want = [1000, 2000, 4000, 8000, 16000]
    check(len(starts) == 6 and len(exits) == 6 and all(x[1] == status for x in exits)
          and all(w - 50 <= g <= w + 700 for g, w in zip(gaps, want)) and len(gaps) == 5,
          f"{name}: 6 runs, each exit status {status}, restart gaps doubling from 1 s (measured {gaps} ms)",
          f"starts={starts} exits={exits}")
    check(any(e[1:3] == ["failed", name] and e[3:] == ["after", "5", "restarts"] for e in ev),
          f"{name}: the manager logs that it gave up after 5 restarts")
s, x = events("never"); check(len(s) == 1 and x == [(x[0][0], "768")] and any(e[1:3] == ["failed", "never"] for e in ev),
                              "never: one run, status 768, failed, not restarted", f"{s} {x}")
s, x = events("once"); check(len(s) == 1 and len(x) == 1 and x[0][1] == "0" and any(e[1:3] == ["exited", "once"] for e in ev),
                             "on-failure with a clean exit: one run, exited", f"{s} {x}")
s, x = events("slow")
bk = [e[3] for e in ev if e[1:3] == ["backoff", "slow"]]
check(len(x) >= 2 and all(st == "768" for _, st in x) and bk and all(b == "1000" for b in bk),
      "a run of 10 s or more ends the row: the slow service's every backoff is 1 s", f"exits={x} backoffs={bk}")
fl = open(f"{logs}/fail.log").read().splitlines()
st = [int(l.split()[2]) * 1000 + int(l.split()[3]) // 10**6 for l in fl if l.startswith("fail3: start ")]
d = [b - a for a, b in zip(st, st[1:])]
check(len(st) == 6 and fl.count("fail3: on stderr") == 6 and all(b > a for a, b in zip(d, d[1:])),
      f"fail.log holds the service's stdout and stderr; its own start stamps show the growing gaps ({d} ms)", "\n".join(fl))
gl = open(f"{logs}/ghost.log").read().splitlines()
check(gl == ["logosservices: execv /nonexistent/ghost failed: -2"] * 6,
      "a failed execv is logged in the service's log and the child exits 127 (status 32512)", repr(gl))
check(open(f"{logs}/argv.log").read() == "[zero][one]\nto-stderr\n",
      "args reach the program as its argv (argv[0] first), stdout and stderr through the pipe",
      repr(open(f"{logs}/argv.log").read()))
check(open(f"{logs}/time.log").read().startswith("logostime: serving now and mono on the channel time\nlogostime: stopped\n"),
      "time.log holds LogosTime's own output, including its clean stop", repr(open(f"{logs}/time.log").read()[:200]))
sys.exit(bad)
PYEOF

# ── the ledger's results ──────────────────────────────────────────────────
wait "$LJ"
rv() { cat "$LC/r_$1" 2>/dev/null; }
check "$([ "$(rv a1)" = "ok 1" ] && [ "$(rv a2)" = "ok 2" ] && [ "$(rv a3)" = "ok 3" ] && [ "$(rv v1)" = "ok 3" ] && echo 1)" \
    "ledger: append answers ok 1, 2, 3; verify answers ok 3" "$(rv a1) | $(rv a2) | $(rv a3) | $(rv v1)"
cat > "$T/oracle.py" <<'PYEOF'
# oracle.py LEDGER HEAD TLO THI TEXT... : the ledger file against hashlib
import hashlib, re, sys
lines = open(sys.argv[1], "rb").read().decode().split("\n")
head = open(sys.argv[2]).read()
tlo, thi, texts = int(sys.argv[3]), int(sys.argv[4]), sys.argv[5:]
assert lines[-1] == "", "the file must end with a newline"
lines = lines[:-1]
assert len(lines) == len(texts), f"{len(lines)} entries, {len(texts)} expected"
prev = "0" * 64
for i, (l, t) in enumerate(zip(lines, texts), 1):
    m = re.fullmatch(r"(\d+)\|(\d+)\|([0-9a-f]{64})\|(.*)", l)
    assert m, f"entry {i} malformed: {l!r}"
    assert int(m.group(1)) == i and m.group(3) == prev and m.group(4) == t, f"entry {i}: {l!r}"
    assert tlo <= int(m.group(2)) <= thi, f"entry {i} time {m.group(2)} not in [{tlo}, {thi}]"
    prev = hashlib.sha256(l.encode()).hexdigest()
assert head == f"{len(lines)} {prev}", f"head {head!r}, want {len(lines)} {prev}"
PYEOF
python3 "$T/oracle.py" "$LC/orig.txt" "$LC/orig.head" "$((TSTART - 2))" "$(( $(date +%s) + 2 ))" boot alpha "omega|pipe" \
    && pass "ledger: every entry is i|seconds|sha256 of entry i-1 (64 zeros first)|text, by hashlib; the head anchors the last" \
    || fail "ledger: the file does not match the hashlib oracle"
want_t2="ok $(sed -n 2,3p "$LC/orig.txt")"
check "$([ "$(rv t2)" = "$want_t2" ] && echo 1)" "ledger: tail 2 is the last two entries" "$(rv t2)"
check "$([ "$(rv v2)" = "broken 2" ] && [ "$(rv v3)" = "broken 3" ] && [ "$(rv v4)" = "broken 3" ] && echo 1)" \
    "ledger: verify reports the edited entry — text of entry 2 -> broken 2, link of entry 3 -> broken 3, entry 3 deleted -> broken 3" \
    "$(rv v2) | $(rv v3) | $(rv v4)"
check "$([ "$(rv an)" = "err logosledger: an entry is one line" ] && [ "$(rv tk)" = "err logosledger: tail needs a count" ] && echo 1)" \
    "ledger: a two-line entry and a non-numeric tail are refused" "$(rv an) | $(rv tk)"

# the ledger survives a restart: the new process continues the chain
req "$C" "$CHAN" restart ledger; a="$ANS"; NLPID=$(echo "$a" | awk '{print $4}')
for _ in $(seq 1 50); do req "$C" ledger tail 1; [ "$RRC" = 0 ] && break; sleep 0.1; done
req "$C" ledger append "after restart"; b="$ANS"
check "$([ "$a" = "ok restarted ledger $NLPID" ] && [ "$NLPID" != "$LPID" ] && ! kill -0 "$LPID" 2>/dev/null && [ "$b" = "ok 4" ] \
         && python3 "$T/oracle.py" "$R/glyphledger.txt" "$R/glyphledger.head" "$((TSTART - 2))" "$(( $(date +%s) + 2 ))" \
                    boot alpha "omega|pipe" "after restart" && echo 1)" \
    "restart ledger: a new process continues the chain (ok 4, linked by hashlib)" "restart=$a append=$b"

# self-application: the manager restarts itself in place
req "$C" "$CHAN" status ""; TPID2=$(field time 3)
req "$C" "$CHAN" restart logosservices; a="$ANS"
sleep 0.5; wait_up "$CHAN"
check "$([ "$a" = "ok restarting logosservices" ] && [ "$(echo "$ANS" | head -1)" = "ok logosservices running $MGRPID 0" ] \
         && [ "$(field time 2)" = running ] && [ "$(field time 3)" != "$TPID2" ] && ! kill -0 "$TPID2" 2>/dev/null \
         && [ "$(cmd "$MGRPID")" = "$R/logosservices " ] && grep -q "re-exec $R/logosservices" "$LOG" \
         && [ "$(grep -c " up $MGRPID $CHAN" "$LOG")" = 2 ] && echo 1)" \
    "self-application: \`restart logosservices\` re-executes the manager (same pid, same name), which starts every service again" \
    "reply=$a status=$(echo "$ANS" | head -2 | tr '\n' '|') cmd=$(cmd "$MGRPID")"
RSS=$(awk '/VmRSS/ {print $2}' "/proc/$MGRPID/status" 2>/dev/null)

# shutdown
req "$C" "$CHAN" shutdown ""; a="$ANS"; wait_exit "$MGRPID" 20
sleep 0.2
check "$([ "$a" = "ok shutdown" ] && [ "$WRC" = 0 ] && [ -z "$(left)" ] && [ ! -e "/tmp/logosipc-$CHAN" ] \
         && [ ! -e /tmp/logosipc-time ] && [ ! -e /tmp/logosipc-ledger ] && [ "$(tail -1 "$LOG" | cut -d' ' -f2-)" = "exit 0" ] && echo 1)" \
    "shutdown: every service stopped, the manager exits 0, no process left under the gate's dir, the sockets removed" \
    "reply=$a rc=$WRC left=$(left) log=$(tail -2 "$LOG" | tr '\n' '|')"
echo "      (manager RSS before shutdown ${RSS:-?} kB; main run $(( $(date +%s) - TSTART )) s)"

[ "$ok" = 1 ] || exit 1
