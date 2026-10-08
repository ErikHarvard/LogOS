#!/usr/bin/env bash
# gate_wm_shell.sh — the shell of the Stage 10 terminals (logosh.la): parsing,
# paths, builtins, PATH search and real programs, checked against known
# answers.
#
# WHAT IT GUARDS. The WM hands every line typed into a terminal to logosh's
# run, starts programs through it, and reaps them with finish. A slip in the
# word splitter or the path resolver sends the wrong arguments or the wrong
# directory to every command; a slip in the spawn sequence leaks the WM's file
# descriptors, loses stderr, lets a program read the WM's stdin, or leaves a
# job that hangup cannot stop.
#
#   1. SHELL_PURE_KIT on the VM and on the C host: parse and normpath against
#      hand-derived answers (quotes, backslashes, tabs, repeated spaces, empty
#      words, a trailing backslash, an unterminated quote; ., .., //, .. above
#      /, relative and absolute paths, a relative cwd), and on the VM also on
#      seeded random inputs against an independent Python model of the same
#      rules. The hand-derived answers are also checked against the model, so
#      the model cannot drift from what is written here.
#   2. SHELL_KIT on the VM: a driver runs a scripted session through run. For
#      a job it reads the pipe until EOF (read returns ""), closes it, and
#      calls finish, the way the WM does. The transcript (prompt + line, the
#      output, "? N" for a non-zero status) must equal the expected text below:
#      echo, pwd, cd (into a directory made in $T, a missing one, a file, too
#      many arguments, no argument), cat (files, a missing file, no trailing
#      newline, a directory, a FIFO — refused, not read, so the WM cannot
#      freeze — a file over the 1 MiB limit), mkdir/rmdir/rm/mv round trips,
#      pid = the WM's own pid, word, help (non-empty and mentions cd), clear
#      and exit actions, a program found on PATH, paths with / (relative and
#      absolute), a missing command, a non-executable file, a directory, exit
#      statuses ([exit 1], [exit 3], nothing for 0), stderr captured (the text
#      of ls's error comes from running the same command from bash), the cwd
#      reaching the child (/bin/pwd), stdin being /dev/null (/bin/cat with no
#      arguments ends at once although the driver's own stdin is a FIFO that
#      never ends), only fds 0-2 open in the child (the driver holds extra
#      fds), the execv-limit refusals (an argument with a space, an empty
#      argument, a directory name with a space, = in a program path),
#      an empty line and a line of spaces (no command, the last status kept:
#      "? 1" again after /bin/false), interrupt and hangup of /bin/sleep 30
#      ([signal 2], [signal 15]) even though the driver BLOCKS SIGINT and
#      SIGTERM in itself, as a WM with a signalfd would, hangup of a job that
#      has stopped itself (stopme.sh: the SIGTERM stays pending until hangup's
#      SIGCONT, then its trap exits 7), and finish returning promptly after
#      each.
#      Then what a WM with several windows does: a job kept running (slow.sh,
#      which sleeps 2 s holding its pipe) while a second job starts and
#      finishes, then the first is read and finished; a kept /bin/sleep 30
#      hung up after another job ran; output larger than a pipe's buffer
#      (seq 1 20000, byte count from bash); the signal guards (pid "0", "",
#      a non-number, the WM's own pid: "-3 -3 -3 -1", never a kill; and
#      "4294967296", "8589934592", "18446744073709551616", which the kernel
#      would read as pid 0, the WM's process group: "-3") and finish of a pid
#      that is not a child, is 0, or is "4294967295" / "4294967296" (pid -1 /
#      0 to the kernel: wait4 would reap ANY child) — each returns "" at once,
#      and a job kept running across them (/bin/false) is still there for
#      @fg to report [exit 1]; and the inputs that would otherwise halt the
#      whole VM (a path of 5000 bytes to cd, cat, mkdir, mv and as a program;
#      an execv line over 2048 bytes or over 200 words), each refused with a
#      message.
#   2b. In a pid namespace (unshare; SKIP if there is none), where kill(-1)
#      reaches only the namespace: interrupt and hangup of "4294967295" and
#      "18446744073709551615" (pid -1 to the kernel) are refused, and the kept
#      /bin/sleep 30 they would have killed is still there to hang up. Then a
#      pid namespace that still sees the outer /proc (no --mount-proc): there
#      /proc/<job pid> is some other process, so finish must fall back to
#      waitpid (/bin/echo hi, /bin/false -> [exit 1]) instead of polling it.
#   3. The filesystem afterwards: what the session made and removed in $T.
#   4. Measured VM timings (INFO, not pass/fail).
#
# The host cannot run SHELL_KIT (fork, execv and the rest are VM builtins), so
# the session runs on the VM only. The driver is started by a small Python
# wrapper that resets SIGINT/SIGTERM to their defaults (a gate started in the
# background would otherwise pass them on IGNORED, and an ignored signal
# survives execve, so the interrupt test would hang), gives it the FIFO as
# stdin, and kills its process group on a timeout so no job outlives a failure.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); touches no
# tracked file. Measured: 281 s on a 4-CPU machine at load 13 (other jobs
# running), 100 s of it without the toolchain build (LOGOS_WM_TOOLS). Most of
# the rest is the host's part of check 1 (about a second an operation there)
# and the VM compiles; the session itself takes ~10 s, mostly its deliberate
# sleeps.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
pass() { echo "PASS  shell: $*"; }
fail() { echo "FAIL  shell: $*"; ok=0; }

wm_setup logosh.la

# ── 1. the pure kit ─────────────────────────────────────────────────────────
python3 - "$T" <<'PYEOF'
import random, sys
T = sys.argv[1]
TAB = '\t'
# (line, the words as <w><w>...), derived by hand from the rules in logosh.la
HAND_P = [
    ('echo hello',            '<echo><hello>'),
    ('  a   b  ',             '<a><b>'),
    ('a' + TAB + 'b',         '<a><b>'),
    (' ' + TAB + ' a ' + TAB + TAB + ' b' + TAB, '<a><b>'),
    ('',                      ''),
    ('   ',                   ''),
    (TAB + TAB,               ''),
    ('""',                    '<>'),
    ('x ""',                  '<x><>'),
    ('"" ""',                 '<><>'),
    ('"a b" c',               '<a b><c>'),
    ('a"b c"d',               '<ab cd>'),
    ('a""b',                  '<ab>'),
    ('"tab' + TAB + 'here"',  '<tab' + TAB + 'here>'),
    ('a\\ b',                 '<a b>'),
    ('\\ ',                   '< >'),
    ('\\"x\\"',               '<"x">'),
    ('a\\\\b',                '<a\\b>'),
    ('ab\\',                  '<ab\\>'),
    ('\\',                    '<\\>'),
    ('"a\\"b"',               '<a"b>'),
    ('"\\\\"',                '<\\>'),
    ('"unterminated x',       '<unterminated x>'),
    ("'single quoted'",       "<'single><quoted'>"),
    ('a\\tb',                 '<atb>'),
    ('echo "a  b"  c\\ d "" e', '<echo><a  b><c d><><e>'),
]
# (cwd, path, normpath), derived by hand
HAND_N = [
    ('/home/user', 'docs',          '/home/user/docs'),
    ('/home/user', '.',             '/home/user'),
    ('/home/user', '..',            '/home'),
    ('/home/user', '../..',         '/'),
    ('/home/user', '../../../..',   '/'),
    ('/',          '..',            '/'),
    ('/',          '.',             '/'),
    ('/home/user', '/etc//passwd',  '/etc/passwd'),
    ('/home/user', 'a//b/./c/',     '/home/user/a/b/c'),
    ('/home/user', '',              '/home/user'),
    ('/',          '',              '/'),
    ('/a/b',       '/',             '/'),
    ('/a/b',       '//',            '/'),
    ('/a/b',       './../c/../d',   '/a/d'),
    ('/a//b/./c/..', 'x',           '/a/b/x'),
    ('/a',         '.../b',         '/a/.../b'),
    ('/a',         '..b/.c',        '/a/..b/.c'),
    ('',           'x',             '/x'),
    ('/a',         '/../../x',      '/x'),
    ('/a/b/c',     '../../..',      '/'),
    ('a/b',        'c',             '/a/b/c'),
    ('/a/b',       '../b/./../b',   '/a/b'),
    ('///',        '///x///y//',    '/x/y'),
]

def mparse(s):                      # the Python model of parse
    words, cur, has, q, i = [], [], False, False, 0
    while i < len(s):
        c = s[i]
        if c == '\\':
            cur.append(s[i + 1] if i + 1 < len(s) else '\\'); has = True
            i += 2; continue
        if c == '"':
            q = not q; has = True; i += 1; continue
        if not q and c in ' \t':
            if has:
                words.append(''.join(cur)); cur = []; has = False
            i += 1; continue
        cur.append(c); has = True; i += 1
    if has:
        words.append(''.join(cur))
    return words

def mnorm(cwd, path):               # the Python model of normpath
    def res(st, s):
        for h in [x for x in s.split('/') if x]:
            if h == '.':
                continue
            st = st[:-1] if h == '..' else st + [h]
        return st
    st = res([] if path.startswith('/') else res([], cwd), path)
    return '/' + '/'.join(st)

render = lambda ws: ''.join('<' + w + '>' for w in ws)
bad = [s for s, e in HAND_P if render(mparse(s)) != e] + \
      [c + ' ' + p for c, p, e in HAND_N if mnorm(c, p) != e]
open(T + '/pure.model', 'w').write('MODEL-DISAGREES %r\n' % bad if bad else 'ok\n')
rng = random.Random(20261008)
RP = [''.join(rng.choice('ab \t"\\') for _ in range(rng.randint(0, 12))) for _ in range(30)]
seg = lambda: '/'.join(rng.choice(['a', 'bb', '.', '..', '...', '']) for _ in range(rng.randint(0, 5)))
RN = [(rng.choice(['', '/']) + seg(), rng.choice(['', '/']) + seg()) for _ in range(30)]

esc = lambda s: s.replace('\\', '\\\\').replace('"', '\\"').replace('\t', '\\t').replace('\n', '\\n')
exprs, exp = [], []
for s, e in HAND_P:
    exprs.append('SHOWW(parse("%s"))' % esc(s)); exp.append(e)
for c, p, e in HAND_N:
    exprs.append('norm("%s")("%s")' % (esc(c), esc(p))); exp.append(e)
for s in RP:
    exprs.append('SHOWW(parse("%s"))' % esc(s)); exp.append(render(mparse(s)))
for c, p in RN:
    exprs.append('norm("%s")("%s")' % (esc(c), esc(p))); exp.append(mnorm(c, p))
def write(name, xs, es):
    body = 'print("end")'
    for x in reversed(xs):
        body = 'SEQ(print(%s))(%s)' % (x, body)
    open(T + '/' + name + '.la', 'w').write(
        'import("logosh.la")\n'
        'glyph SEQ = la a. la b. b\n'
        'glyph SHOWW = la l. l(la _. "")(la h. la t. concat("<")(concat(h)(concat(">")(SHOWW(t)))))\n'
        'glyph MAIN = SHELL_PURE_KIT(concat)(str_at)(str_len)(str_eq)(str_to_int)(add)(sub)(div)(lt)(int_eq)\n'
        '  (la parse. la norm.\n' + body + ')\n')
    open(T + '/' + name + '.expect', 'w').write('\n'.join(es + ['end']) + '\n')
nh = len(HAND_P) + len(HAND_N)
write('pure', exprs, exp)                    # every case, on the VM
write('pure_hand', exprs[:nh], exp[:nh])     # the hand-derived ones, on the host
open(T + '/pure.count', 'w').write('%d %d %d %d\n' % (len(HAND_P), len(HAND_N), len(RP), len(RN)))
PYEOF
counts=$(cat "$T/pure.count")
if [ "$(cat "$T/pure.model" 2>/dev/null)" = ok ]; then
    pass "the Python model agrees with all hand-derived answers"
else
    fail "the Python model and the hand-derived answers disagree: $(cat "$T/pure.model" 2>/dev/null)"
fi

wm_vm pure.la "$T/pure.vm"
if [ "$vrc" = 0 ] && cmp -s "$T/pure.vm" "$T/pure.expect"; then
    pass "pure kit (VM): parse + normpath match (hand, hand, random, random = $counts)"
else
    fail "pure kit (VM): rc=$vrc; first difference: $(diff "$T/pure.vm" "$T/pure.expect" | head -3 | tr '\n' ' ')"
fi
# The host's substitution takes about a second an operation here, so it runs
# the hand-derived cases (every rule) and leaves the random ones to the VM.
wm_host pure_hand.la "$T/pure.host"
if [ "$hrc" = 0 ] && cmp -s "$T/pure.host" "$T/pure_hand.expect"; then
    pass "pure kit (host): the C host gives the same answers on the hand-derived cases"
else
    fail "pure kit (host): rc=$hrc; first difference: $(diff "$T/pure.host" "$T/pure_hand.expect" | head -3 | tr '\n' ' ')"
fi

# ── 2. a scripted session on the VM ─────────────────────────────────────────
W="$T/w"
mkdir -p "$W/sub3" "$W/sp ace"
printf 'line one\nline two\n' > "$W/f.txt"
printf 'no newline' > "$W/noeol.txt"
: > "$W/empty.txt"
head -c 1048577 /dev/zero > "$W/big.bin"
mkfifo "$W/fifo"
printf '#!/bin/sh\necho script ran\n' > "$W/script.sh"; chmod 755 "$W/script.sh"
printf '#!/bin/sh\nexit 3\n' > "$W/exit3.sh"; chmod 755 "$W/exit3.sh"
printf '#!/bin/sh\necho no\n' > "$W/noexec.sh"; chmod 644 "$W/noexec.sh"
printf '#!/bin/sh\necho eq\n' > "$W/a=b.sh"; chmod 755 "$W/a=b.sh"
printf '#!/bin/sh\necho a\nsleep 2\necho b\n' > "$W/slow.sh"; chmod 755 "$W/slow.sh"
# A job that stops itself: hangup's SIGTERM stays pending until its SIGCONT.
printf '#!/bin/sh\ntrap "echo got TERM; exit 7" TERM\nkill -STOP $$\necho continued\nsleep 30\n' \
    > "$W/stopme.sh"; chmod 755 "$W/stopme.sh"

# The oracle for the one message logosh does not write itself: run the same
# command from bash, the way logosh starts it (empty environment, env -C).
ls_err=$(env -i /usr/bin/env -C "$W" /bin/ls /nonexistent_logosh </dev/null 2>&1); ls_st=$?
# ... and the byte count of seq's output, which is larger than a pipe's buffer.
seq_n=$(env -i /usr/bin/env -C "$W" seq 1 20000 </dev/null | wc -c)
# Inputs past the limits: an execv line over 2048 bytes, one of 250 words, and
# a 5000-byte path (the VM would halt the whole WM on a path of 4096 or more).
LONGX=$(printf 'x%.0s' $(seq 2100))
MANYA=$(printf 'a %.0s' $(seq 249))a
LONGY=$(printf 'y%.0s' $(seq 5000))
export W ls_err ls_st seq_n LONGX MANYA LONGY

sed -e "s|@W@|$W|g" -e "s|@LONGX@|$LONGX|g" -e "s|@MANYA@|$MANYA|g" -e "s|@LONGY@|$LONGY|g" \
    -e 's|^@SPACES@$|   |' \
    > "$T/script.txt" <<'EOF'
cd @W@
pwd
echo hello   world
echo "a  b" c\ d "" e
echo
word
pid
help
mkdir sub
mkdir sub
mkdir
cd sub
pwd
cd ..
cd sub/../sub/.
cd ../
cd nosuch
cd f.txt
cd a b
cd
pwd
cd ..
cd @W@
cat f.txt
cat noeol.txt
cat empty.txt
cat f.txt nofile.txt noeol.txt
cat sub
cat fifo
cat big.bin
cat
mv f.txt g.txt
cat g.txt
cat f.txt
mv g.txt sub
cat sub/g.txt
mv sub/g.txt ./f.txt
mv nosuch x
mv onlyone
mv a b c
rm f.txt
rm f.txt
rm sub
rmdir sub
rmdir sub
mkdir d1 d2 keep
rmdir d1 nosuch d2
clear
/bin/echo hello
nosuchcmd
ls -d .
/bin/false

@SPACES@
/bin/true
./script.sh
@W@/script.sh
sub3/../script.sh
./exit3.sh
./nosuch
./noexec.sh
./sub3
./a=b.sh
/bin/echo "a b"
/bin/echo ""
/bin/ls /nonexistent_logosh
cd sub3
/bin/pwd
cd ..
/bin/cat
/bin/ls /proc/self/fd
cd "sp ace"
/bin/true
pwd
cd ..
@int /bin/sleep 30
@hup /bin/sleep 30
@hup ./stopme.sh
@bg ./slow.sh
/bin/echo B
@fg
@bg /bin/sleep 30
/bin/echo still
@fghup
@count seq 1 20000
@bg /bin/false
@sigcheck
@fg
/bin/echo @LONGX@
/bin/echo @MANYA@
cd @LONGY@
cat @LONGY@
mkdir @LONGY@
./@LONGY@
@LONGY@
mv @LONGY@ x
exit
EOF

cat > "$T/session.expect" <<'EOF'
logos:/$ cd @W@
logos:@W@$ pwd
@W@
logos:@W@$ echo hello   world
hello world
logos:@W@$ echo "a  b" c\ d "" e
a  b c d  e
logos:@W@$ echo

logos:@W@$ word
I AM THAT I AM
logos:@W@$ pid
@PID@
logos:@W@$ help
@HELP@
logos:@W@$ mkdir sub
logos:@W@$ mkdir sub
logosh: mkdir: sub: file exists
? 1
logos:@W@$ mkdir
logosh: mkdir: missing operand
? 1
logos:@W@$ cd sub
logos:@W@/sub$ pwd
@W@/sub
logos:@W@/sub$ cd ..
logos:@W@$ cd sub/../sub/.
logos:@W@/sub$ cd ../
logos:@W@$ cd nosuch
logosh: cd: nosuch: no such file or directory
? 1
logos:@W@$ cd f.txt
logosh: cd: f.txt: not a directory
? 1
logos:@W@$ cd a b
logosh: cd: too many arguments
? 1
logos:@W@$ cd
logos:/$ pwd
/
logos:/$ cd ..
logos:/$ cd @W@
logos:@W@$ cat f.txt
line one
line two
logos:@W@$ cat noeol.txt
no newline
logos:@W@$ cat empty.txt
logos:@W@$ cat f.txt nofile.txt noeol.txt
line one
line two
logosh: cat: nofile.txt: no such file or directory
no newline
? 1
logos:@W@$ cat sub
logosh: cat: sub: is a directory
? 1
logos:@W@$ cat fifo
logosh: cat: fifo: not a regular file
? 1
logos:@W@$ cat big.bin
logosh: cat: big.bin: too large for the builtin cat (use /bin/cat)
? 1
logos:@W@$ cat
logosh: cat: missing operand
? 1
logos:@W@$ mv f.txt g.txt
logos:@W@$ cat g.txt
line one
line two
logos:@W@$ cat f.txt
logosh: cat: f.txt: no such file or directory
? 1
logos:@W@$ mv g.txt sub
logos:@W@$ cat sub/g.txt
line one
line two
logos:@W@$ mv sub/g.txt ./f.txt
logos:@W@$ mv nosuch x
logosh: mv: nosuch: no such file or directory
? 1
logos:@W@$ mv onlyone
logosh: mv: usage: mv SOURCE DEST
? 1
logos:@W@$ mv a b c
logosh: mv: usage: mv SOURCE DEST
? 1
logos:@W@$ rm f.txt
logos:@W@$ rm f.txt
logosh: rm: f.txt: no such file or directory
? 1
logos:@W@$ rm sub
logosh: rm: sub: is a directory
? 1
logos:@W@$ rmdir sub
logos:@W@$ rmdir sub
logosh: rmdir: sub: no such file or directory
? 1
logos:@W@$ mkdir d1 d2 keep
logos:@W@$ rmdir d1 nosuch d2
logosh: rmdir: nosuch: no such file or directory
? 1
logos:@W@$ clear
<clear>
logos:@W@$ /bin/echo hello
hello
logos:@W@$ nosuchcmd
logosh: nosuchcmd: command not found
? 127
logos:@W@$ ls -d .
.
logos:@W@$ /bin/false
[exit 1]
? 1
logos:@W@$@SP@
? 1
logos:@W@$@SP@@SP@@SP@@SP@
? 1
logos:@W@$ /bin/true
logos:@W@$ ./script.sh
script ran
logos:@W@$ @W@/script.sh
script ran
logos:@W@$ sub3/../script.sh
script ran
logos:@W@$ ./exit3.sh
[exit 3]
? 3
logos:@W@$ ./nosuch
logosh: ./nosuch: no such file or directory
? 127
logos:@W@$ ./noexec.sh
logosh: ./noexec.sh: permission denied
? 126
logos:@W@$ ./sub3
logosh: ./sub3: is a directory
? 126
logos:@W@$ ./a=b.sh
logosh: ./a=b.sh: a program path cannot contain = (env limit)
? 1
logos:@W@$ /bin/echo "a b"
logosh: /bin/echo: an argument cannot be empty or contain a space (execv limit)
? 1
logos:@W@$ /bin/echo ""
logosh: /bin/echo: an argument cannot be empty or contain a space (execv limit)
? 1
logos:@W@$ /bin/ls /nonexistent_logosh
@LS_ERR@
[exit @LS_ST@]
? @LS_ST@
logos:@W@$ cd sub3
logos:@W@/sub3$ /bin/pwd
@W@/sub3
logos:@W@/sub3$ cd ..
logos:@W@$ /bin/cat
logos:@W@$ /bin/ls /proc/self/fd
0
1
2
3
logos:@W@$ cd "sp ace"
logos:@W@/sp ace$ /bin/true
logosh: /bin/true: cannot start a program in a directory whose name has a space (execv limit)
? 1
logos:@W@/sp ace$ pwd
@W@/sp ace
logos:@W@/sp ace$ cd ..
logos:@W@$ /bin/sleep 30
[signal 2]
? 130
logos:@W@$ /bin/sleep 30
[signal 15]
? 143
logos:@W@$ ./stopme.sh
got TERM
[exit 7]
? 7
logos:@W@$ ./slow.sh
<bg>
logos:@W@$ /bin/echo B
B
<fg ./slow.sh>
a
b
logos:@W@$ /bin/sleep 30
<bg>
logos:@W@$ /bin/echo still
still
<fg /bin/sleep 30>
[signal 15]
? 143
logos:@W@$ seq 1 20000
<count @SEQN@>
logos:@W@$ /bin/false
<bg>
<sig -3 -3 -3 -1 -3 -3 -3 -3 [] [] [] []>
<fg /bin/false>
[exit 1]
? 1
logos:@W@$ /bin/echo @LONGX@
logosh: /bin/echo: command line too long
? 1
logos:@W@$ /bin/echo @MANYA@
logosh: /bin/echo: command line too long
? 1
logos:@W@$ cd @LONGY@
logosh: cd: @LONGY@: file name too long
? 1
logos:@W@$ cat @LONGY@
logosh: cat: @LONGY@: file name too long
? 1
logos:@W@$ mkdir @LONGY@
logosh: mkdir: @LONGY@: file name too long
? 1
logos:@W@$ ./@LONGY@
logosh: ./@LONGY@: file name too long
? 126
logos:@W@$ @LONGY@
logosh: @LONGY@: command not found
? 127
logos:@W@$ mv @LONGY@ x
logosh: mv: @LONGY@: file name too long
? 1
logos:@W@$ exit
<exit>
<end>
EOF

# The driver: the WM's side of the contract, in plain (not kit-style) LA.
cat > "$T/drv.la" <<'EOF'
import("logosh.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph NIL = la n. la c. n(n)
glyph CONS = la h. la t. la n. la c. c(h)(t)
glyph SUB = la s. la lo. la hi. lt(lo)(hi)(la _. concat(str_at(s)(lo))(SUB(s)(add(lo)(1))(hi)))(la _. "")("!")
glyph LEN = la s. str_to_int(str_len(s))
glyph FINDSP = la s. la i. lt(i)(LEN(s))(la _. str_eq(str_at(s)(i))(" ")(la _. i)(la _. FINDSP(s)(add(i)(1)))("!"))(la _. i)("!")
glyph SPLITNL = la s. (la n. Z(la go. la i. la lo.
     lt(i)(n)
       (la _. str_eq(str_at(s)(i))("\n")
           (la _. CONS(SUB(s)(lo)(i))(go(add(i)(1))(add(i)(1))))
           (la _. go(add(i)(1))(lo))("!"))
       (la _. lt(lo)(n)(la _. CONS(SUB(s)(lo)(n))(NIL))(la _. NIL)("!"))("!"))(0)(0))(LEN(s))
glyph JOINSP = la l. l(la _. "")(la h. la t. t(la _. h)(la a. la b. concat(h)(concat(" ")(JOINSP(t)))))
glyph BR = la s. concat("[")(concat(s)("]"))
# "@MODE CMD": MODE is int / hup (run CMD, wait 300 ms, interrupt / hang it
# up), bg (start CMD, keep the job), count (report only the byte count of its
# output); "@fg" / "@fghup" finish the newest kept job (hanging it up first);
# "@sigcheck" prints the signal guards' answers; "@kill PID" prints what
# interrupt(PID) and hangup(PID) return. Any other line is a command.
glyph MODE = la line. str_eq(str_at(line)(0))("@")(la _. SUB(line)(1)(FINDSP(line)(0)))(la _. "job")("!")
glyph CMDOF = la line. str_eq(str_at(line)(0))("@")(la _. SUB(line)(add(FINDSP(line)(0))(1))(LEN(line)))(la _. line)("!")
glyph DRAIN = la rfd. Z(la go. la u. (la d. str_eq(d)("")(la _. "")(la _. SEQ(write("1")(d))(go("!")))("!"))(read(rfd)("4096")))("!")
glyph DRAINCOUNT = la rfd. Z(la go. la n. (la d. str_eq(d)("")(la _. n)(la _. go(add(n)(LEN(d))))("!"))(read(rfd)("4096")))(0)
glyph STATUS = la sh. (la st. int_eq(st)(0)(la _. "")(la _. print(concat("? ")(int_to_str(st))))("!"))(sh(la c. la s. s))
glyph NOW = la parse. la u. parse(clock_gettime("1"))(la _. 0)(la s. la r. r(la _. 0)(la ns. la r2.
    add(mul(str_to_int(s))(1000000))(div(str_to_int(ns))(1000))))
glyph MSLINE = la mode. la t0. la t2. la t3. la cmd.
    print(concat("#ms ")(concat(mode)(concat(" ")(concat(int_to_str(sub(t3)(t0)))
      (concat(" finish ")(concat(int_to_str(sub(t3)(t2)))(concat(" ")(cmd))))))))
glyph MAIN =
  (la PK. la K. PK(la parse. la norm. K(la new. la prompt. la run. la finish. la interrupt. la hangup.
    (la now.
    # REAP(sh)(pid)(rfd)(mode)(cmd)(t0)(k): drain (or count), close, finish,
    # print the text and the status, then k(sh').
    (la REAP.
    SEQ(sigprocmask("0")("16386"))(
    SEQ(open("/dev/null")("0"))(
    SEQ(print(concat("#me ")(getpid("!"))))(
    Z(la loop. la sh. la bg. la lines. lines
        (la _. print("<end>"))
        (la line. la rest. (la mode. la cmd.
          str_eq(mode)("sigcheck")
            (la _. SEQ(print(concat("<sig ")(concat(JOINSP(
                     CONS(interrupt("0"))(CONS(hangup("abc"))(CONS(interrupt(""))(CONS(interrupt(getpid("!")))
                     (CONS(interrupt("4294967296"))(CONS(hangup("4294967296"))(CONS(hangup("8589934592"))
                     (CONS(interrupt("18446744073709551616"))
                     (CONS(BR(finish(sh)("1")(la s2. la t. t)))(CONS(BR(finish(sh)("0")(la s2. la t. t)))
                     (CONS(BR(finish(sh)("4294967295")(la s2. la t. t)))
                     (CONS(BR(finish(sh)("4294967296")(la s2. la t. t)))(NIL))))))))))))))(">"))))
                   (loop(sh)(bg)(rest)))
            (la _. str_eq(mode)("kill")
            (la _. SEQ(print(concat("<kill ")(concat(cmd)(concat(" ")(concat(interrupt(cmd))
                     (concat(" ")(concat(hangup(cmd))(">"))))))))
                   (loop(sh)(bg)(rest)))
            (la _. str_eq(SUB(mode)(0)(2))("fg")
              (la _. bg(la _. SEQ(print("<no kept job>"))(loop(sh)(bg)(rest)))
                       (la j. la bt. j(la pid. la rfd. la jcmd.
                          SEQ(print(concat("<fg ")(concat(jcmd)(">"))))(
                          SEQ(str_eq(mode)("fghup")(la _. hangup(pid))(la _. "")("!"))(
                          REAP(sh)(pid)(rfd)(mode)(jcmd)(now("!"))(la sh3. loop(sh3)(bt)(rest)))))))
              (la _.
                SEQ(write("1")(concat(prompt(sh))(concat(cmd)("\n"))))(
                (la t0. run(sh)(cmd)(la sh2. la out. la act. (la t1.
                   SEQ(print(concat("#perf run ")(concat(int_to_str(sub(t1)(t0)))(concat(" ")(cmd)))))(
                   SEQ(write("1")(out))(
                   act
                     (la _. SEQ(STATUS(sh2))(loop(sh2)(bg)(rest)))
                     (la _. SEQ(print("<clear>"))(SEQ(STATUS(sh2))(loop(sh2)(bg)(rest))))
                     (la _. SEQ(print("<exit>"))(SEQ(STATUS(sh2))(loop(sh2)(bg)(rest))))
                     (la pid. la rfd. la _.
                        str_eq(mode)("bg")
                          (la _. SEQ(print("<bg>"))(loop(sh2)(CONS(la k. k(pid)(rfd)(cmd))(bg))(rest)))
                          (la _.
                            SEQ(str_eq(mode)("int")
                                  (la _. SEQ(poll("")("300"))(interrupt(pid)))
                                  (la _. str_eq(mode)("hup")(la _. SEQ(poll("")("300"))(hangup(pid)))(la _. "")("!"))("!"))(
                            REAP(sh2)(pid)(rfd)(mode)(cmd)(t0)(la sh3. loop(sh3)(bg)(rest))))("!"))
                     ("!"))))(now("!"))))(now("!"))))("!"))("!"))("!"))
          (MODE(line))(CMDOF(line))))
      (new("/"))(NIL)(SPLITNL(read_file("script.txt")))))))
    (la sh. la pid. la rfd. la mode. la cmd. la t0. la k.
       SEQ(str_eq(mode)("count")
             (la _. print(concat("<count ")(concat(int_to_str(DRAINCOUNT(rfd)))(">"))))
             (la _. DRAIN(rfd))("!"))(
       SEQ(close(rfd))(
       (la t2. finish(sh)(pid)(la sh3. la text. (la t3.
           SEQ(write("1")(text))(
           SEQ(STATUS(sh3))(
           SEQ(MSLINE(mode)(t0)(t2)(t3)(cmd))(
           k(sh3)))))(now("!"))))(now("!"))))))
    (NOW(parse)))))
  (SHELL_PURE_KIT(concat)(str_at)(str_len)(str_eq)(str_to_int)(add)(sub)(div)(lt)(int_eq))
  (SHELL_KIT(concat)(str_at)(str_len)(str_eq)(ord)(str_to_int)(int_to_str)
     (add)(sub)(mul)(div)(mod)(lt)(int_eq)
     (read_file)(stat)(mkdir)(rmdir)(unlink)(rename)(getpid)
     (pipe)(fork)(dup2)(open)(close)(execv)(exit)(sigprocmask)
     (waitpid)(kill)(poll))
EOF

# rundrv.py DIR TIMEOUT [UID]: run the compiled driver in DIR the way a WM is
# started: SIGINT/SIGTERM at their defaults (a gate started in the background
# would otherwise pass them on IGNORED, and an ignored signal survives execve),
# stdin a FIFO that never ends, its own session, as UID if given (setpriv), and
# its process group killed afterwards so no job outlives a failure. Writes
# DIR/session.out and DIR/session.err and prints the driver's exit status.
cat > "$T/rundrv.py" <<'PYEOF'
import os, signal, subprocess, sys
D, TO = sys.argv[1], float(sys.argv[2])
for s in (signal.SIGINT, signal.SIGTERM, signal.SIGQUIT):
    signal.signal(s, signal.SIG_DFL)
os.mkfifo(D + '/stdin.fifo')
fd = os.open(D + '/stdin.fifo', os.O_RDWR)   # never reaches EOF and never has data
cmd = ['./logos_secd']
if len(sys.argv) > 3:
    cmd = ['setpriv', '--reuid=' + sys.argv[3], '--regid=' + sys.argv[3], '--clear-groups'] + cmd
p = subprocess.Popen(cmd, cwd=D, stdin=fd, start_new_session=True,
                     stdout=open(D + '/session.out', 'wb'), stderr=open(D + '/session.err', 'wb'))
try:
    rc = p.wait(timeout=TO)
except subprocess.TimeoutExpired:
    rc = 'timeout'
try:
    os.killpg(p.pid, signal.SIGKILL)         # any job left behind
except ProcessLookupError:
    pass
print(rc)
PYEOF
# cmpout.py OUT EXPECT: the transcript (lines not starting with #) against the
# expected text, @NAME@ markers filled in from the environment; prints OK or
# the first difference.
cat > "$T/cmpout.py" <<'PYEOF'
import os, sys
out = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
exp = open(sys.argv[2]).read()
for k, v in (('@W@', 'W'), ('@LS_ERR@', 'ls_err'), ('@LS_ST@', 'ls_st'), ('@SEQN@', 'seq_n'),
             ('@LONGX@', 'LONGX'), ('@MANYA@', 'MANYA'), ('@LONGY@', 'LONGY')):
    if k in exp:
        exp = exp.replace(k, os.environ[v].strip())
exp = exp.replace('@SP@', ' ')         # a trailing space, spelled out
exp = exp.split('\n')
me = [l[4:] for l in out if l.startswith('#me ')]
act = [l for l in out if not l.startswith('#')]
i = 0
for j, e in enumerate(exp):
    if e == '@HELP@':
        k = i
        while k < len(act) and not act[k].startswith('logos:'):
            k += 1
        text = '\n'.join(act[i:k])
        if not text.strip() or 'cd' not in text:
            print('help text empty or does not mention cd'); sys.exit()
        i = k
        continue
    if e == '@PID@':
        e = me[0] if me else '(no #me line)'
        if not e.isdigit():
            print('pid is not a number:', e); sys.exit()
    if i >= len(act) or act[i] != e:
        print('line %d: expected %r, got %r' % (j + 1, e, act[i] if i < len(act) else '<eof>')); sys.exit()
    i += 1
print('OK' if i == len(act) else 'extra output after the transcript: %r' % act[i:i + 3])
PYEOF

cp "$T/drv.la" "$T/logos_source.la"
cp "$T/compiler.bin" "$T/logos_program.bin"
crc=0
( cd "$T" && timeout "$WM_VM_TIMEOUT" ./logos_secd >/dev/null 2>"$T/vce" ) || crc=$?
if [ "$crc" != 0 ]; then
    fail "session: the driver did not compile ($(head -c 200 "$T/vce"))"
else
    # a copy of the compiled driver for the runs below, in directories of their own
    cp "$T/logos_program.bin" "$T/drv.bin"
    drc=$(python3 "$T/rundrv.py" "$T" 300)
    res=$(python3 "$T/cmpout.py" "$T/session.out" "$T/session.expect")
    if [ "$drc" = 0 ] && [ "$res" = OK ]; then
        pass "session (VM): $(grep -c '^logos:' "$T/session.out") command lines, the transcript matches"
    else
        fail "session (VM): driver rc=$drc; $res"
    fi
    slow=$(awk '$1=="#ms" && ($2=="int" || $2=="hup" || $2=="fghup") && ($3 > 3000000 || $5 > 1000000) {print}' "$T/session.out")
    nsig=$(awk '$1=="#ms" && ($2=="int" || $2=="hup" || $2=="fghup")' "$T/session.out" | wc -l)
    if [ "$nsig" = 4 ] && [ -z "$slow" ]; then
        pass "session (VM): interrupt, hangup, hangup of a stopped job and of a kept job all end promptly (under 3 s, finish under 1 s)"
    else
        fail "session (VM): interrupt/hangup timings: $nsig lines; slow: $slow"
    fi
    # /bin/echo B runs start to finish while slow.sh (started first, still
    # holding its own pipe) sleeps for 2 s: one job never waits on another.
    b_us=$(awk '$1=="#ms" && $2=="job" && $NF=="B" && $(NF-1)=="/bin/echo" {print $3}' "$T/session.out")
    if [ -n "$b_us" ] && [ "$b_us" -lt 1800000 ]; then
        pass "session (VM): a second job starts and finishes ($((b_us / 1000)) ms) while the first still runs"
    else
        fail "session (VM): the second job took ${b_us:-?} us (the first job sleeps 2 s)"
    fi

    # ── 2b. in a pid namespace ──────────────────────────────────────────────
    # kill(-1) signals every process the sender may signal, so the guard
    # against a pid the kernel reads as -1 is tested only inside a pid
    # namespace, where -1 reaches nothing but the namespace's own processes: a
    # kept /bin/sleep 30 must still be alive for @fghup to hang it up.
    # Then the same namespace without its own /proc: the driver is pid 2 and
    # its first job pid 3 there, while /proc still shows the outer namespace,
    # where pid 3 is a kernel thread whose parent is pid 2 (kthreadd). A
    # finish that trusted that /proc waited for it to become a zombie forever.
    NS=""
    if unshare -pf --mount-proc true 2>/dev/null; then NS="unshare -pf"
    elif unshare -rpf --mount-proc true 2>/dev/null; then NS="unshare -rpf"; fi
    if [ -z "$NS" ]; then
        echo "SKIP  shell: no pid namespaces here (unshare -pf / -rpf): the pid -1 and outer-/proc checks did not run"
    else
        mkdir "$T/nsk"
        cp "$T/logos_secd" "$T/nsk/"; cp "$T/drv.bin" "$T/nsk/logos_program.bin"
        printf '%s\n' '@bg /bin/sleep 30' '@kill 4294967295' '@kill 18446744073709551615' '@fghup' \
            > "$T/nsk/script.txt"
        printf '%s\n' 'logos:/$ /bin/sleep 30' '<bg>' '<kill 4294967295 -3 -3>' \
            '<kill 18446744073709551615 -3 -3>' '<fg /bin/sleep 30>' '[signal 15]' '? 143' '<end>' \
            > "$T/nsk.expect"
        nrc=$($NS --mount-proc python3 "$T/rundrv.py" "$T/nsk" 60)
        res=$(python3 "$T/cmpout.py" "$T/nsk/session.out" "$T/nsk.expect")
        if [ "$nrc" = 0 ] && [ "$res" = OK ]; then
            pass "pid namespace (VM): interrupt and hangup refuse \"4294967295\" (the kernel's pid -1): -3, and the kept job is still there to hang up"
        else
            fail "pid namespace (VM): driver rc=$nrc; $res"
        fi
        mkdir "$T/nsp"
        cp "$T/logos_secd" "$T/nsp/"; cp "$T/drv.bin" "$T/nsp/logos_program.bin"
        printf '%s\n' '/bin/echo hi' '/bin/false' '/bin/true' > "$T/nsp/script.txt"
        printf '%s\n' 'logos:/$ /bin/echo hi' 'hi' 'logos:/$ /bin/false' '[exit 1]' '? 1' \
            'logos:/$ /bin/true' '<end>' > "$T/nsp.expect"
        nrc=$($NS python3 "$T/rundrv.py" "$T/nsp" 60)
        res=$(python3 "$T/cmpout.py" "$T/nsp/session.out" "$T/nsp.expect")
        nme=$(sed -n 's/^#me //p' "$T/nsp/session.out")
        if [ "$nrc" = 0 ] && [ "$res" = OK ]; then
            pass "pid namespace, outer /proc (VM): finish falls back to waitpid ([exit 1]; the WM was pid ${nme:-?} there)"
        else
            fail "pid namespace, outer /proc (VM): driver rc=$nrc; $res"
        fi
    fi
fi

# ── 3. the filesystem afterwards ────────────────────────────────────────────
if [ -d "$W/keep" ] && [ ! -e "$W/sub" ] && [ ! -e "$W/d1" ] && [ ! -e "$W/d2" ] \
   && [ ! -e "$W/f.txt" ] && [ ! -e "$W/g.txt" ] && [ -f "$W/noeol.txt" ]; then
    pass "filesystem: keep/ made; sub/, d1/, d2/ removed; f.txt moved round and removed"
else
    fail "filesystem: unexpected state in $W: $(ls -A "$W" | tr '\n' ' ')"
fi

# ── 4. timings (VM) ─────────────────────────────────────────────────────────
[ -f "$T/session.out" ] && python3 - "$T/session.out" <<'PYEOF'
import statistics, sys
lines = open(sys.argv[1], errors='replace').read().split('\n')
runs = [l.split(' ', 3) for l in lines if l.startswith('#perf run ')]
jobs = [l.split() for l in lines if l.startswith('#ms job ')]
def med(xs):
    return '%.2f ms' % (statistics.median(xs) / 1000) if xs else '-'
runs = [r for r in runs if len(r[3]) < 100]      # not the deliberately over-long lines
builtin = [int(r[2]) for r in runs if r[3].split(' ')[0] in ('echo', 'pwd', 'word', 'pid', 'help', 'clear', 'exit')]
cd = [int(r[2]) for r in runs if r[3].startswith('cd ')]
cat = [int(r[2]) for r in runs if r[3].startswith('cat ')]
spawn = [int(r[2]) for r in runs if r[3].split(' ')[0] in ('/bin/echo', '/bin/false', '/bin/true', 'ls', '/bin/pwd', '/bin/cat', '/bin/ls')]
print('INFO  shell timings (VM): run of echo/pwd/word/pid/help %s; cd %s; cat %s;'
      ' run starting a program %s; program start to finish returning %s; finish %s'
      % (med(builtin), med(cd), med(cat), med(spawn),
         med([int(j[2]) for j in jobs]), med([int(j[4]) for j in jobs])))
PYEOF

[ "$ok" = 1 ] || exit 1
