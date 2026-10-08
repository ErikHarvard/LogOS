#!/usr/bin/env bash
# gate_wm_tile.sh — the tiling layout (theourgia_tile.la, TILE_KIT) does what
# WM_DESIGN.md says, on the native VM and on the C host.
#
# WHAT IT GUARDS. The window manager trusts the tree completely: it opens,
# closes, moves focus, swaps, resizes and draws through these thirteen
# operations. A slip in any of them is silent on screen (a window drawn one
# pixel off, focus jumping to the wrong neighbour, a closed window's sibling
# vanishing), so every one is checked against answers that do not come from
# the module itself:
#
#   1. KNOWN ANSWERS (VM and host). A table of expressions with their expected
#      results worked out by hand from the contract: the insert/remove/swap/
#      resize/toggle shapes, the layout formula including truncation at odd
#      sizes, a gap larger than the area, negative w, h and gap, the neighbour
#      rules (nearest beats more overlap, more overlap beats leaf order, zero
#      overlap is not a neighbour, ties go to leaf order), resize clamping,
#      removing the last window, and every operation on an id that is not in
#      the tree (unchanged).
#   2. MODEL (VM). A Python reference model of the same tree, written from the
#      contract, drives a seeded random sequence of a few hundred operations
#      (insert side by side, stacked, with dir 2 and -1 (both stacked), and
#      with bad focus/duplicate/non-positive ids, remove, swap, resize with
#      positive and negative deltas past both clamps, toggle, neighbour in all
#      four directions and a bad one, next, has) over up to 10 windows,
#      drained to EMPTY twice. An LA program applies the same sequence; after
#      every step it prints the query answer, show(t), count, leaves and the
#      layout in five areas (odd sizes, gap larger than the area, gap 0,
#      negative width, negative height). Compared line by line.
#      The model also counts how often the sequence reaches each case (both
#      clamps, a neighbour tie, each direction found and none, absent ids,
#      the last window removed, ...); the gate fails if any count is zero, so
#      a change to the generator cannot quietly stop testing something.
#   3. INVARIANTS (VM output). On every layout the module printed: rectangles
#      lie inside the area, are pairwise disjoint, and together with the gap
#      strips of the tree it printed cover the area exactly; ids are unique
#      and in leaf order; count equals the number of leaves, and both agree
#      with show(t).
#   4. HOST = VM. The C host runs a shorter random sequence (60 steps,
#      WM_TILE_HOST_STEPS; the host's substitution makes the full one take
#      about 4 minutes) and must print exactly what the VM and the model do.
#   5. SHOW ON DEEP TREES (VM, and the host on the smaller ones). show of
#      40- and 256-window chains (depth n-1) and balanced trees, with a concat
#      that reports every string it builds: the text must be the model's, and
#      the bytes concat copies must stay within the bound the module states.
#
# The random sequence is fixed (seed 20261008) so a failure is reproducible;
# WM_TILE_SEED overrides it for exploration.
#
# ISOLATION: a private temporary directory (gate_wm_common.sh); touches no
# tracked file. About 2 to 3 minutes: under 2 minutes for the checks (four VM
# compiles and runs, the host's known answers, its 60 steps and the two
# 40-window show cases) plus building the toolchain.
set -uo pipefail
. "$(dirname "$0")/gate_wm_common.sh"
ok=1
: "${WM_TILE_SEED:=20261008}"
: "${WM_TILE_STEPS:=320}"
: "${WM_TILE_HOST_STEPS:=60}"

wm_setup theourgia_tile.la

# ═══ 1. known answers ═══════════════════════════════════════════════
# EXPR => EXPECTED. In the expressions: t1 = L1, t2 = H500(L1,L2),
# t3 = H500(L1,V500(L2,L3)), t4 = H500(L1,H500(L2,L3)),
# t5 = H500(V500(L1,L2),V300(L3,L4)), t6 = H500(L1,H500(V500(L2,L5),L3));
# LAY prints a layout as id:x,y,w,h; NB a neighbour; LV the leaves; B a
# boolean as T/F; I an integer. The standard area is (0,0,100,50) gap 2:
# side by side, w1 = 98*500/1000 = 49, the second child at 49+2 = 51;
# stacked inside it, h1 = 48*500/1000 = 24, the second at 24+2 = 26.
cat > "$T/ka_table.txt" <<'KAEOF'
show(empty) => E
show(t1) => L1
show(t2) => H500(L1,L2)
show(t3) => H500(L1,V500(L2,L3))
show(t4) => H500(L1,H500(L2,L3))
show(t5) => H500(V500(L1,L2),V300(L3,L4))
show(t6) => H500(L1,H500(V500(L2,L5),L3))
LAY(t3)(0)(0)(100)(50)(2) => 1:0,0,49,50 2:51,0,49,24 3:51,26,49,24
LAY(t2)(0)(0)(101)(10)(2) => 1:0,0,49,10 2:51,0,50,10
LAY(t3)(1)(1)(101)(51)(3) => 1:1,1,49,51 2:53,1,49,24 3:53,28,49,24
LAY(resize(t3)(1)(33))(0)(0)(100)(50)(2) => 1:0,0,52,50 2:54,0,46,24 3:54,26,46,24
LAY(t4)(0)(0)(100)(50)(2) => 1:0,0,49,50 2:51,0,23,50 3:76,0,24,50
LAY(t5)(0)(0)(100)(50)(2) => 1:0,0,49,24 2:0,26,49,24 3:51,0,49,14 4:51,16,49,34
LAY(t6)(0)(0)(100)(50)(2) => 1:0,0,49,50 2:51,0,23,24 5:51,26,23,24 3:76,0,24,50
LAY(toggle(t3)(1))(0)(0)(100)(50)(2) => 1:0,0,100,24 2:0,26,100,11 3:0,39,100,11
LAY(t3)(0)(0)(5)(4)(20) => 1:0,0,0,4 2:5,0,0,0 3:5,4,0,0
LAY(t1)(10)(10)(sub(0)(5))(40)(3) => 1:10,10,0,40
LAY(t1)(10)(10)(40)(sub(0)(5))(3) => 1:10,10,40,0
LAY(t2)(0)(0)(10)(sub(0)(5))(2) => 1:0,0,4,0 2:6,0,4,0
LAY(t3)(0)(0)(10)(sub(0)(5))(2) => 1:0,0,4,0 2:6,0,4,0 3:6,0,4,0
LAY(toggle(t2)(1))(3)(4)(10)(sub(0)(5))(2) => 1:3,4,10,0 2:3,4,10,0
LAY(t3)(5)(5)(sub(0)(1))(sub(0)(1))(sub(0)(1)) => 1:5,5,0,0 2:5,5,0,0 3:5,5,0,0
LAY(t2)(0)(0)(30)(10)(sub(0)(4)) => 1:0,0,15,10 2:15,0,15,10
LAY(t1)(7)(8)(9)(10)(11) => 1:7,8,9,10
LAY(empty)(0)(0)(100)(50)(2) =>
NB(t3)(1)(1)(0)(0)(100)(50)(2) => 2
NB(t3)(2)(0)(0)(0)(100)(50)(2) => 1
NB(t3)(3)(0)(0)(0)(100)(50)(2) => 1
NB(t3)(2)(3)(0)(0)(100)(50)(2) => 3
NB(t3)(3)(2)(0)(0)(100)(50)(2) => 2
NB(t3)(1)(0)(0)(0)(100)(50)(2) => 1
NB(t3)(1)(2)(0)(0)(100)(50)(2) => 1
NB(t3)(1)(3)(0)(0)(100)(50)(2) => 1
NB(t3)(2)(1)(0)(0)(100)(50)(2) => 2
NB(t3)(2)(4)(0)(0)(100)(50)(2) => 2
NB(t3)(9)(1)(0)(0)(100)(50)(2) => 9
NB(empty)(1)(1)(0)(0)(100)(50)(2) => 1
NB(t1)(1)(1)(0)(0)(100)(50)(2) => 1
NB(resize(t3)(3)(300))(1)(1)(0)(0)(100)(50)(2) => 3
NB(resize(t3)(2)(300))(1)(1)(0)(0)(100)(50)(2) => 2
NB(t4)(1)(1)(0)(0)(100)(50)(2) => 2
NB(t4)(3)(0)(0)(0)(100)(50)(2) => 2
NB(t4)(2)(1)(0)(0)(100)(50)(2) => 3
NB(t5)(2)(1)(0)(0)(100)(50)(2) => 4
NB(t5)(1)(1)(0)(0)(100)(50)(2) => 3
NB(t5)(4)(2)(0)(0)(100)(50)(2) => 3
NB(t5)(3)(3)(0)(0)(100)(50)(2) => 4
NB(t5)(4)(0)(0)(0)(100)(50)(2) => 2
NB(t5)(3)(0)(0)(0)(100)(50)(2) => 1
NB(t5)(2)(2)(0)(0)(100)(50)(2) => 1
NB(t6)(1)(1)(0)(0)(100)(50)(2) => 2
NB(t6)(3)(0)(0)(0)(100)(50)(2) => 2
NB(t6)(5)(0)(0)(0)(100)(50)(2) => 1
NB(t6)(5)(1)(0)(0)(100)(50)(2) => 3
NB(t6)(5)(2)(0)(0)(100)(50)(2) => 2
NB(t3)(1)(1)(0)(0)(5)(4)(20) => 1
show(resize(t3)(1)(1000)) => H900(L1,V500(L2,L3))
show(resize(t3)(1)(sub(0)(2000))) => H100(L1,V500(L2,L3))
show(resize(t3)(2)(sub(0)(450))) => H500(L1,V100(L2,L3))
show(resize(t3)(3)(sub(0)(450))) => H500(L1,V900(L2,L3))
show(resize(t3)(3)(250)) => H500(L1,V250(L2,L3))
show(resize(t3)(2)(400)) => H500(L1,V900(L2,L3))
show(resize(t3)(3)(400)) => H500(L1,V100(L2,L3))
show(resize(resize(t3)(1)(450))(1)(sub(0)(100))) => H800(L1,V500(L2,L3))
show(resize(t3)(9)(100)) => H500(L1,V500(L2,L3))
show(resize(t1)(1)(100)) => L1
show(resize(empty)(1)(100)) => E
show(toggle(t3)(1)) => V500(L1,V500(L2,L3))
show(toggle(t3)(3)) => H500(L1,H500(L2,L3))
show(toggle(toggle(t3)(2))(2)) => H500(L1,V500(L2,L3))
show(toggle(t1)(1)) => L1
show(toggle(t3)(9)) => H500(L1,V500(L2,L3))
show(toggle(empty)(1)) => E
show(remove(t3)(1)) => V500(L2,L3)
show(remove(t3)(2)) => H500(L1,L3)
show(remove(t3)(3)) => H500(L1,L2)
show(remove(t5)(1)) => H500(L2,V300(L3,L4))
show(remove(t5)(4)) => H500(V500(L1,L2),L3)
show(remove(t6)(5)) => H500(L1,H500(L2,L3))
show(remove(t1)(1)) => E
show(remove(t3)(7)) => H500(L1,V500(L2,L3))
show(remove(empty)(1)) => E
show(remove(remove(remove(t3)(2))(1))(3)) => E
show(insert(remove(t1)(1))(1)(8)(0)) => L8
show(insert(t3)(9)(4)(0)) => H500(L1,V500(L2,L3))
show(insert(t3)(2)(3)(0)) => H500(L1,V500(L2,L3))
show(insert(t3)(2)(0)(0)) => H500(L1,V500(L2,L3))
show(insert(t3)(2)(sub(0)(3))(0)) => H500(L1,V500(L2,L3))
show(insert(t3)(2)(4)(7)) => H500(L1,V500(V500(L2,L4),L3))
show(insert(t1)(1)(2)(sub(0)(1))) => V500(L1,L2)
show(insert(t3)(3)(4)(sub(0)(7))) => H500(L1,V500(L2,V500(L3,L4)))
show(insert(t3)(1)(4)(0)) => H500(H500(L1,L4),V500(L2,L3))
show(insert(empty)(42)(5)(1)) => L5
show(insert(empty)(42)(0)(1)) => E
show(swap(t3)(1)(3)) => H500(L3,V500(L2,L1))
show(swap(t6)(5)(1)) => H500(L5,H500(V500(L2,L1),L3))
show(swap(t3)(1)(9)) => H500(L1,V500(L2,L3))
show(swap(t3)(9)(1)) => H500(L1,V500(L2,L3))
show(swap(t3)(2)(2)) => H500(L1,V500(L2,L3))
show(swap(empty)(1)(2)) => E
LV(t3) => 1,2,3
LV(t6) => 1,2,5,3
LV(swap(t6)(1)(3)) => 3,2,5,1
LV(empty) =>
I(next(t3)(1)) => 2
I(next(t3)(3)) => 1
I(next(t6)(2)) => 5
I(next(t6)(5)) => 3
I(next(t6)(3)) => 1
I(next(t3)(9)) => 9
I(next(t1)(1)) => 1
I(next(empty)(1)) => 1
B(has(t3)(2)) => T
B(has(t3)(4)) => F
B(has(t1)(1)) => T
B(has(empty)(1)) => F
B(has(remove(t3)(2))(2)) => F
I(count(empty)) => 0
I(count(t1)) => 1
I(count(t6)) => 4
I(count(remove(t6)(2))) => 3
KAEOF

python3 - "$T/ka_table.txt" "$T/ka.la" "$T/ka_expect.txt" <<'PYEOF'
import sys
rows = [l.split(" =>", 1) for l in open(sys.argv[1]).read().splitlines() if l.strip()]
exprs = [r[0].strip() for r in rows]
expect = [r[1].strip() for r in rows]
chain = "print(%s)" % exprs[-1]
for e in reversed(exprs[:-1]):
    chain = "SEQ(print(%s))(%s)" % (e, chain)
la = r'''import("theourgia_tile.la")
glyph SEQ = la a. la b. b
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph JR = Z(la jr. la l. l(la _. "")(la r. la tl.
    concat(r(la i. la x. la y. la w. la h.
        concat(int_to_str(i))(concat(":")(concat(int_to_str(x))(concat(",")(concat(int_to_str(y))
          (concat(",")(concat(int_to_str(w))(concat(",")(int_to_str(h)))))))))))
      (tl(la _. "")(la h2. la t2. concat(" ")(jr(tl))))))
glyph JL = Z(la jl. la l. l(la _. "")(la i. la tl.
    concat(int_to_str(i))(tl(la _. "")(la h2. la t2. concat(",")(jl(tl))))))
glyph MAIN = TILE_KIT(add)(sub)(mul)(div)(lt)(int_eq)(concat)(int_to_str)
  (la empty. la insert. la remove. la layout. la neighbour. la swap. la resize. la toggle.
   la leaves. la next. la has. la count. la show.
   (la LAY. la NB. la LV. la B. la I.
     (la t1. (la t2. (la t3. (la t4. (la t5. (la t6.
       CHAIN
     )(insert(t4)(2)(5)(1))
     )(resize(insert(insert(insert(t1)(1)(3)(0))(1)(2)(1))(3)(4)(1))(3)(sub(0)(200)))
     )(insert(insert(t1)(1)(2)(0))(2)(3)(0))
     )(insert(t2)(2)(3)(1))
     )(insert(t1)(1)(2)(0))
     )(insert(empty)(0)(1)(0))
   )
   (la t. la x. la y. la w. la h. la g. JR(layout(t)(x)(y)(w)(h)(g)))
   (la t. la id. la d. la x. la y. la w. la h. la g. int_to_str(neighbour(t)(id)(d)(x)(y)(w)(h)(g)))
   (la t. JL(leaves(t)))
   (la b. b("T")("F"))
   (la n. int_to_str(n)))
'''.replace("CHAIN", chain)
open(sys.argv[2], "w").write(la)
open(sys.argv[3], "w").write("".join(e + "\n" for e in expect))
PYEOF

ka_check() {   # ENGINE RC OUT
    if [ "$2" = 0 ] && cmp -s "$3" "$T/ka_expect.txt"; then
        echo "PASS  tile known answers ($1): $(wc -l < "$T/ka_expect.txt") hand-derived results"
    else
        echo "FAIL  tile known answers ($1): rc=$2; first differences (expression, expected, got):"
        paste -d'\n' <(sed 's/ =>.*//' "$T/ka_table.txt") "$T/ka_expect.txt" "$3" \
            | paste - - - | awk -F'\t' '$2 != $3 {print "      " $1 "  expected [" $2 "]  got [" $3 "]"}' | head -8
        ok=0
    fi
}
wm_vm ka.la "$T/ka_vm.txt";   ka_check VM "$vrc" "$T/ka_vm.txt"
wm_host ka.la "$T/ka_host.txt"; ka_check host "$hrc" "$T/ka_host.txt"

# ═══ 2-4. the reference model, the random sequence, the invariants ══
cat > "$T/model.py" <<'PYEOF'
# A reference model of the tile tree, written from WM_DESIGN.md and the
# defined edge cases in theourgia_tile.la's header. Trees are tuples:
# ("E",) | ("L", id) | ("S", dir, ratio, first, second).
import random, sys

E = ("E",)

def leaves(t):
    if t[0] == "E": return []
    if t[0] == "L": return [t[1]]
    return leaves(t[3]) + leaves(t[4])

def has(t, i): return i in leaves(t)

def show(t):
    if t[0] == "E": return "E"
    if t[0] == "L": return "L%d" % t[1]
    return "%s%d(%s,%s)" % ("H" if t[1] == 0 else "V", t[2], show(t[3]), show(t[4]))

def path_to(t, i):            # list of 3/4 child indices from the root to leaf i
    if t[0] == "L": return [] if t[1] == i else None
    if t[0] == "E": return None
    for k in (3, 4):
        p = path_to(t[k], i)
        if p is not None: return [k] + p
    return None

def at(t, path):
    for k in path: t = t[k]
    return t

def replace(t, path, new):
    if not path: return new
    k = path[0]
    s = list(t); s[k] = replace(t[k], path[1:], new)
    return tuple(s)

def insert(t, focus, i, d):
    if i <= 0 or has(t, i): return t
    if t[0] == "E": return ("L", i)
    p = path_to(t, focus)
    if p is None: return t
    return replace(t, p, ("S", 0 if d == 0 else 1, 500, ("L", focus), ("L", i)))

def remove(t, i):
    p = path_to(t, i)
    if p is None: return t
    if not p: return E
    parent = at(t, p[:-1])
    sibling = parent[7 - p[-1]]          # the other child (3 <-> 4)
    return replace(t, p[:-1], sibling)

def swap(t, a, b):
    pa, pb = path_to(t, a), path_to(t, b)
    if pa is None or pb is None: return t
    t = replace(t, pa, ("L", b))
    return replace(t, pb, ("L", a))

def clamp(r): return max(100, min(900, r))

def resize(t, i, delta):
    p = path_to(t, i)
    if not p: return t                   # absent, or the root leaf: no parent
    par = at(t, p[:-1])
    share = par[2] if p[-1] == 3 else 1000 - par[2]
    share = share + delta
    r = share if p[-1] == 3 else 1000 - share
    return replace(t, p[:-1], ("S", par[1], clamp(r), par[3], par[4]))

def toggle(t, i):
    p = path_to(t, i)
    if not p: return t
    par = at(t, p[:-1])
    return replace(t, p[:-1], ("S", 1 - par[1], par[2], par[3], par[4]))

def nxt(t, i):
    ls = leaves(t)
    if i not in ls: return i
    return ls[(ls.index(i) + 1) % len(ls)]

def layout(t, x, y, w, h, gap):
    """(rects, gap strips): rects (id,x,y,w,h) in leaf order."""
    w, h, gap = max(0, w), max(0, h), max(0, gap)
    rects, strips = [], []
    def go(n, x, y, w, h):
        if n[0] == "E": return
        if n[0] == "L": rects.append((n[1], x, y, w, h)); return
        _, d, r, a, b = n
        if d == 0:
            g = min(gap, w); w1 = (w - g) * r // 1000; w2 = w - g - w1
            go(a, x, y, w1, h); strips.append((x + w1, y, g, h)); go(b, x + w1 + g, y, w2, h)
        else:
            g = min(gap, h); h1 = (h - g) * r // 1000; h2 = h - g - h1
            go(a, x, y, w, h1); strips.append((x, y + h1, w, g)); go(b, x, y + h1 + g, w, h2)
    go(t, x, y, w, h)
    return rects, strips

def neighbour(t, i, d, area):
    rects, _ = layout(t, *area)
    mine = [r for r in rects if r[0] == i]
    if not mine or d not in (0, 1, 2, 3): return i
    _, rx, ry, rw, rh = mine[0]
    best = None
    for (ci, cx, cy, cw, ch) in rects:
        if ci == i: continue
        if d == 0:   past, dist = cx + cw <= rx, rx - (cx + cw)
        elif d == 1: past, dist = cx >= rx + rw, cx - (rx + rw)
        elif d == 2: past, dist = cy + ch <= ry, ry - (cy + ch)
        else:        past, dist = cy >= ry + rh, cy - (ry + rh)
        if d < 2: ov = min(ry + rh, cy + ch) - max(ry, cy)
        else:     ov = min(rx + rw, cx + cw) - max(rx, cx)
        if not past or ov <= 0: continue
        if best is None or (dist, -ov) < best[0]: best = ((dist, -ov), ci)
    return i if best is None else best[1]

AREAS = [(3, 5, 1001, 767, 7), (0, 0, 13, 9, 20), (0, 2, 257, 131, 0), (10, 10, -5, 40, 3),
         (4, 6, 50, -7, 2)]
NB_AREAS = [AREAS[0], AREAS[2]]

def fmt_rects(rs): return " ".join("%d:%d,%d,%d,%d" % r for r in rs)

def line(ans, t):
    return "|".join([ans, show(t), str(len(leaves(t))), ",".join(map(str, leaves(t)))]
                    + [fmt_rects(layout(t, *a)[0]) for a in AREAS])

def apply(t, op):
    c = op[0]
    if c == 1: return "-", insert(t, op[1], op[2], op[3])
    if c == 2: return "-", remove(t, op[1])
    if c == 3: return "-", swap(t, op[1], op[2])
    if c == 4: return "-", resize(t, op[1], op[2])
    if c == 5: return "-", toggle(t, op[1])
    if c == 6: return str(neighbour(t, op[1], op[2], NB_AREAS[op[3]])), t
    if c == 7: return str(nxt(t, op[1])), t
    if c == 8: return ("T" if has(t, op[1]) else "F"), t
    raise ValueError(op)

def generate(seed, steps):
    rng = random.Random(seed)
    t, nid, ops, seen, n2 = E, 1, [], set(), 0
    drains = [steps // 3, (2 * steps) // 3]
    while len(ops) < steps:
        ids = leaves(t)
        if drains and len(ops) >= drains[0] and ids:   # close every window, in random order
            drains.pop(0)
            for i in rng.sample(ids, len(ids)):
                ops.append((2, i)); t = remove(t, i)
            ops.append(rng.choice([(2, 1), (4, 1, 50), (5, 1), (3, 1, 2), (6, 1, 1, 0), (7, 3), (8, 1)]))
            t = apply(t, ops[-1])[1]
            continue
        absent = [k for k in seen if k not in ids] + [nid + 50, 0]
        some = lambda: rng.choice(ids) if ids and rng.random() < 0.9 else rng.choice(absent)
        r = rng.random()
        if not ids or (r < 0.28 and len(ids) < 10):
            f = rng.choice(ids) if ids and rng.random() < 0.9 else rng.choice(absent)
            q = rng.random()
            if q < 0.06 and ids: i = rng.choice(ids)            # duplicate: unchanged
            elif q < 0.09: i = rng.choice([0, -3])              # not positive: unchanged
            elif q < 0.18 and absent[:-2]: i = rng.choice(absent[:-2])   # reuse a closed id
            else: i = nid; nid += 1
            d = rng.choice([0, 1, 0, 1, 2])
            if d == 2:                                  # every other one -1: also stacked
                n2 += 1; d = 2 if n2 % 2 else -1
            op = (1, f, i, d)
        elif r < 0.34: op = (8, rng.choice(ids + absent[-2:]))
        elif r < 0.46: op = (2, some())
        elif r < 0.56: op = (3, some(), some())
        elif r < 0.70:
            delta = rng.choice([rng.randint(-450, 450), rng.randint(600, 1500), -rng.randint(600, 1500)])
            op = (4, some(), delta)
        elif r < 0.80: op = (5, some())
        elif r < 0.88: op = (7, some())
        else:                                           # one window, every direction
            i, area = some(), rng.choice([0, 0, 1])
            for d in rng.sample([0, 1, 2, 3], 4) + ([rng.choice([4, 7])] if rng.random() < 0.2 else []):
                ops.append((6, i, d, area))
            continue
        ops.append(op)
        if op[0] == 1 and op[2] > 0: seen.add(op[2])
        t = apply(t, op)[1]
    return ops[:steps]

def run(ops):
    t, out = E, []
    for op in ops:
        ans, t = apply(t, op)
        out.append(line(ans, t))
    return out

def coverage(ops):
    """How often the sequence reaches each case the gate claims to cover."""
    c = dict.fromkeys(["clamp_lo", "clamp_hi", "grow_second", "shrink", "nb_found_0", "nb_found_1",
                       "nb_found_2", "nb_found_3", "nb_none", "nb_tie", "nb_bad_dir", "absent_id",
                       "dup_insert", "bad_id", "stacked_insert", "dir2_insert", "dirneg_insert", "last_removed",
                       "op_on_empty", "toggle", "swap", "next_wrap", "has_true", "has_false"], 0)
    t = E
    for op in ops:
        k, ids = op[0], leaves(t)
        if t == E and k != 1: c["op_on_empty"] += 1
        if k in (2, 4, 5, 6, 7) and op[1] not in ids and t != E: c["absent_id"] += 1
        if k == 3 and (op[1] not in ids or op[2] not in ids) and t != E: c["absent_id"] += 1
        if k == 1 and t != E and op[1] not in ids: c["absent_id"] += 1
        if k == 1 and op[2] in ids: c["dup_insert"] += 1
        if k == 1 and op[2] <= 0: c["bad_id"] += 1
        if k == 1 and op[3] != 0 and op[1] in ids and 0 < op[2] and op[2] not in ids:
            c["stacked_insert"] += 1
            if op[3] > 1: c["dir2_insert"] += 1
            if op[3] < 0: c["dirneg_insert"] += 1
        if k == 4 and path_to(t, op[1]):
            p = path_to(t, op[1]); par = at(t, p[:-1])
            share = par[2] if p[-1] == 3 else 1000 - par[2]
            if share + op[2] < 100: c["clamp_lo"] += 1
            if share + op[2] > 900: c["clamp_hi"] += 1
            if p[-1] == 4: c["grow_second"] += 1
            if op[2] < 0: c["shrink"] += 1
        if k == 5 and path_to(t, op[1]): c["toggle"] += 1
        if k == 3 and op[1] in ids and op[2] in ids and op[1] != op[2]: c["swap"] += 1
        if k == 6 and op[1] in ids:
            d, rects = op[2], layout(t, *NB_AREAS[op[3]])[0]
            if d not in (0, 1, 2, 3): c["nb_bad_dir"] += 1
            else:
                _, rx, ry, rw, rh = [r for r in rects if r[0] == op[1]][0]
                keys = []
                for (ci, cx, cy, cw, ch) in rects:
                    dist = [rx - (cx + cw), cx - (rx + rw), ry - (cy + ch), cy - (ry + rh)][d]
                    ov = (min(ry + rh, cy + ch) - max(ry, cy)) if d < 2 else (min(rx + rw, cx + cw) - max(rx, cx))
                    if ci != op[1] and dist >= 0 and ov > 0: keys.append((dist, -ov))
                if not keys: c["nb_none"] += 1
                else:
                    c["nb_found_%d" % d] += 1
                    if keys.count(min(keys)) > 1: c["nb_tie"] += 1
        if k == 7 and len(ids) > 1 and op[1] == ids[-1]: c["next_wrap"] += 1
        if k == 8: c["has_true" if op[1] in ids else "has_false"] += 1
        t2 = apply(t, op)[1]
        if k == 2 and t != E and t2 == E: c["last_removed"] += 1
        t = t2
    return c

def parse_show(s):
    """show text -> tree, so the invariants can be checked against what the
    module itself printed."""
    pos = 0
    def num():
        nonlocal pos
        j = pos
        while pos < len(s) and s[pos].isdigit(): pos += 1
        return int(s[j:pos])
    def node():
        nonlocal pos
        c = s[pos]; pos += 1
        if c == "E": return E
        if c == "L": return ("L", num())
        r = num(); assert s[pos] == "("; pos += 1
        a = node(); assert s[pos] == ","; pos += 1
        b = node(); assert s[pos] == ")"; pos += 1
        return ("S", 0 if c == "H" else 1, r, a, b)
    t = node(); assert pos == len(s)
    return t

def inside(r, a):
    return r[0] >= a[0] and r[1] >= a[1] and r[0] + r[2] <= a[0] + a[2] and r[1] + r[3] <= a[1] + a[3]

def overlap(p, q):
    return min(p[0] + p[2], q[0] + q[2]) > max(p[0], q[0]) and min(p[1] + p[3], q[1] + q[3]) > max(p[1], q[1])

def check(lines):
    """Invariants on the module's own output. Returns a list of problems."""
    bad = []
    for n, l in enumerate(lines, 1):
        f = l.split("|")
        if len(f) != 4 + len(AREAS): bad.append("step %d: malformed line" % n); continue
        try: t = parse_show(f[1])
        except Exception: bad.append("step %d: show %r does not parse" % (n, f[1])); continue
        ids = [int(x) for x in f[3].split(",")] if f[3] else []
        if len(set(ids)) != len(ids): bad.append("step %d: duplicate ids %s" % (n, ids))
        if any(i <= 0 for i in ids): bad.append("step %d: non-positive id" % n)
        if int(f[2]) != len(ids): bad.append("step %d: count %s != %d leaves" % (n, f[2], len(ids)))
        if ids != leaves(t): bad.append("step %d: leaves %s disagree with show" % (n, ids))
        for a, txt in zip(AREAS, f[4:]):
            area = (a[0], a[1], max(0, a[2]), max(0, a[3]))
            rs = [tuple(map(int, p.replace(":", ",").split(","))) for p in txt.split()] if txt else []
            if [r[0] for r in rs] != ids: bad.append("step %d area %s: layout ids %s != leaves" % (n, a, [r[0] for r in rs])); continue
            boxes = [r[1:] for r in rs]
            if any(b[2] < 0 or b[3] < 0 for b in boxes): bad.append("step %d area %s: negative size" % (n, a))
            if not all(inside(b, area) for b in boxes): bad.append("step %d area %s: rectangle outside the area" % (n, a))
            strips = layout(t, *a)[1]           # the gaps implied by the printed tree
            pieces = boxes + strips
            if any(overlap(pieces[i], pieces[j]) for i in range(len(pieces)) for j in range(i)):
                bad.append("step %d area %s: rectangles/gaps overlap" % (n, a))
            if not all(inside(s, area) for s in strips): bad.append("step %d area %s: gap outside" % (n, a))
            if ids and sum(p[2] * p[3] for p in pieces) != area[2] * area[3]:
                bad.append("step %d area %s: leaves + gaps do not cover the area" % (n, a))
    return bad

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "gen":                            # gen SEED STEPS OPSFILE EXPECTFILE
        ops = generate(int(sys.argv[2]), int(sys.argv[3]))
        open(sys.argv[4], "w").write(" ".join(str(v) for op in ops for v in op))
        open(sys.argv[5], "w").write("".join(l + "\n" for l in run(ops)))
        kinds = {}
        for op in ops: kinds[op[0]] = kinds.get(op[0], 0) + 1
        print(len(ops), " ".join("%s=%d" % (k, kinds.get(c, 0)) for c, k in
              enumerate(["", "insert", "remove", "swap", "resize", "toggle", "neighbour", "next", "has"]) if c))
    elif cmd == "coverage":                     # coverage SEED STEPS: cases never reached, or "-"
        cov = coverage(generate(int(sys.argv[2]), int(sys.argv[3])))
        missing = [k for k, v in cov.items() if v == 0]
        print(" ".join(missing) if missing else "-")
        print(" ".join("%s=%d" % kv for kv in cov.items()), flush=True)
    elif cmd == "check":                        # check OUTFILE
        bad = check(open(sys.argv[2]).read().splitlines())
        print(len(bad)); [print("      " + b) for b in bad[:8]]
    elif cmd == "selfcheck":                    # the model satisfies its own invariants
        bad = check(run(generate(int(sys.argv[2]), int(sys.argv[3]))))
        print(len(bad)); [print("      " + b) for b in bad[:8]]
PYEOF

# The LA side: one program reads the operations from a string of decimal
# tokens (opcode then its arguments: 1 insert f id dir, 2 remove id, 3 swap
# a b, 4 resize id delta, 5 toggle id, 6 neighbour id d area, 7 next id,
# 8 has id) and prints the same line the model does. The VM and the host run
# the same program. It is NOT kit style: the C host substitutes a value into a
# body by copying it at every occurrence and walking it once for every binder
# in that body, and a kit closure is large, so here the thirteen operations
# travel as the LAST arguments of small, binder-free glyphs, and every branch
# selects a glyph instead of a thunk that closes over them.
cat > "$T/seq_head.la" <<'LAEOF'
import("theourgia_tile.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph IF = la c. la t. la f. c(t)(f)("!")
glyph PAIR = la a. la b. la k. k(a)(b)
glyph THEN = la a. la b. b

# reading the token string
glyph N   = str_to_int(str_len(OPS))
glyph CH  = la p. str_to_int(ord(str_at(OPS)(p)))
glyph DIG = Z(la dg. la p. la acc.
    IF(lt(p)(N))(la _. (la c. IF(int_eq(c)(32))(la _. acc)(la _. dg(add(p)(1))(add(mul(acc)(10))(sub(c)(48)))))(CH(p)))
      (la _. acc))
glyph TV  = la p. IF(int_eq(CH(p))(45))(la _. sub(0)(DIG(add(p)(1))(0)))(la _. DIG(p)(0))
glyph TN  = Z(la tn. la p. IF(lt(p)(N))(la _. IF(int_eq(CH(p))(32))(la _. add(p)(1))(la _. tn(add(p)(1))))(la _. p))
glyph ARG = Z(la ag. la p. la n. IF(int_eq(n)(0))(la _. TV(p))(la _. ag(TN(p))(sub(n)(1))))
glyph SKIP = Z(la sk. la p. la n. IF(int_eq(n)(0))(la _. p)(la _. sk(TN(p))(sub(n)(1))))

# printing a state line
glyph RECT = la r. r(la i. la x. la y. la w. la h.
    concat(int_to_str(i))(concat(":")(concat(int_to_str(x))(concat(",")(concat(int_to_str(y))
      (concat(",")(concat(int_to_str(w))(concat(",")(int_to_str(h))))))))))
glyph JR = Z(la jr. la l. l(la _. "")(la r. la tl. concat(RECT(r))(tl(la _. "")(la h2. la t2. concat(" ")(jr(tl))))))
glyph JL = Z(la jl. la l. l(la _. "")(la i. la tl. concat(int_to_str(i))(tl(la _. "")(la h2. la t2. concat(",")(jl(tl))))))
glyph LA_A = la t. la lay. JR(lay(t)(3)(5)(1001)(767)(7))
glyph LA_B = la t. la lay. JR(lay(t)(0)(0)(13)(9)(20))
glyph LA_C = la t. la lay. JR(lay(t)(0)(2)(257)(131)(0))
glyph LA_D = la t. la lay. JR(lay(t)(10)(10)(sub(0)(5))(40)(3))
glyph LA_E = la t. la lay. JR(lay(t)(4)(6)(50)(sub(0)(7))(2))
glyph LINE = la ans. la t. la lay. la lv. la ct. la sh.
    concat(ans)(concat("|")(concat(sh(t))(concat("|")(concat(int_to_str(ct(t)))
      (concat("|")(concat(JL(lv(t)))(concat("|")(concat(LA_A(t)(lay))
      (concat("|")(concat(LA_B(t)(lay))(concat("|")(concat(LA_C(t)(lay))
      (concat("|")(concat(LA_D(t)(lay))(concat("|")(LA_E(t)(lay)))))))))))))))))

# one operation: DO_x(t)(q)(ops) = PAIR(answer)(PAIR(tree)(next position))
glyph NB_A = la t. la id. la d. la nb. nb(t)(id)(d)(3)(5)(1001)(767)(7)
glyph NB_C = la t. la id. la d. la nb. nb(t)(id)(d)(0)(2)(257)(131)(0)
glyph DO_INS = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR("-")(PAIR(ins(t)(ARG(q)(0))(ARG(q)(1))(ARG(q)(2)))(SKIP(q)(3)))
glyph DO_REM = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR("-")(PAIR(rem(t)(ARG(q)(0)))(SKIP(q)(1)))
glyph DO_SW  = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR("-")(PAIR(sw(t)(ARG(q)(0))(ARG(q)(1)))(SKIP(q)(2)))
glyph DO_RS  = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR("-")(PAIR(rs(t)(ARG(q)(0))(ARG(q)(1)))(SKIP(q)(2)))
glyph DO_TG  = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR("-")(PAIR(tg(t)(ARG(q)(0)))(SKIP(q)(1)))
glyph DO_NB  = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR(int_to_str(IF(int_eq(ARG(q)(2))(0))(la _. NB_A)(la _. NB_C)(t)(ARG(q)(0))(ARG(q)(1))(nb)))(PAIR(t)(SKIP(q)(3)))
glyph DO_NX  = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR(int_to_str(nx(t)(ARG(q)(0))))(PAIR(t)(SKIP(q)(1)))
glyph DO_HS  = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs.
    PAIR(hs(t)(ARG(q)(0))("T")("F"))(PAIR(t)(SKIP(q)(1)))
glyph DO_BAD = la t. la q. la ins. la rem. la nb. la sw. la rs. la tg. la nx. la hs. PAIR("?")(PAIR(t)(N))
glyph PICK = la op.
    IF(int_eq(op)(1))(la _. DO_INS)(la _. IF(int_eq(op)(2))(la _. DO_REM)(la _. IF(int_eq(op)(3))(la _. DO_SW)
    (la _. IF(int_eq(op)(4))(la _. DO_RS)(la _. IF(int_eq(op)(5))(la _. DO_TG)(la _. IF(int_eq(op)(6))(la _. DO_NB)
    (la _. IF(int_eq(op)(7))(la _. DO_NX)(la _. IF(int_eq(op)(8))(la _. DO_HS)(la _. DO_BAD))))))))

# the loop: print the line for each step, then go on with the new tree
glyph FST = la p. p(la a. la b. a)
glyph SND = la p. p(la a. la b. b)
glyph SHOW_GO = la r. la run. la ins. la rem. la lay. la nb. la sw. la rs. la tg. la lv. la nx. la hs. la ct. la sh.
    THEN(print(LINE(FST(r))(FST(SND(r)))(lay)(lv)(ct)(sh)))
        (run(FST(SND(r)))(SND(SND(r)))(ins)(rem)(lay)(nb)(sw)(rs)(tg)(lv)(nx)(hs)(ct)(sh))
glyph STEP = la run. la t. la p. la ins. la rem. la lay. la nb. la sw. la rs. la tg. la lv. la nx. la hs. la ct. la sh.
    SHOW_GO(PICK(TV(p))(t)(TN(p))(ins)(rem)(nb)(sw)(rs)(tg)(nx)(hs))
      (run)(ins)(rem)(lay)(nb)(sw)(rs)(tg)(lv)(nx)(hs)(ct)(sh)
glyph STOP = la run. la t. la p. la ins. la rem. la lay. la nb. la sw. la rs. la tg. la lv. la nx. la hs. la ct. la sh. ""
glyph RUN = Z(la run. la t. la p. la ins. la rem. la lay. la nb. la sw. la rs. la tg. la lv. la nx. la hs. la ct. la sh.
    lt(p)(N)(STEP)(STOP)(run)(t)(p)(ins)(rem)(lay)(nb)(sw)(rs)(tg)(lv)(nx)(hs)(ct)(sh))
glyph MAIN = TILE_KIT(add)(sub)(mul)(div)(lt)(int_eq)(concat)(int_to_str)
  (la e. la ins. la rem. la lay. la nb. la sw. la rs. la tg. la lv. la nx. la hs. la ct. la sh.
    RUN(e)(0)(ins)(rem)(lay)(nb)(sw)(rs)(tg)(lv)(nx)(hs)(ct)(sh))
LAEOF
mk_seq() {   # OPSFILE OUT.la — the program above with OPS last (a large literal goes last)
    { cat "$T/seq_head.la"; printf 'glyph OPS = "%s"\n' "$(cat "$1")"; } > "$2"
}

selfbad=$(python3 "$T/model.py" selfcheck "$WM_TILE_SEED" "$WM_TILE_STEPS" | head -1)
gen=$(python3 "$T/model.py" gen "$WM_TILE_SEED" "$WM_TILE_STEPS" "$T/ops.txt" "$T/expect.txt")
# The default sequence must reach every case listed in coverage(); an
# exploratory WM_TILE_SEED only reports the cases it misses.
cov=$(python3 "$T/model.py" coverage "$WM_TILE_SEED" "$WM_TILE_STEPS")
missing=$(echo "$cov" | head -1)
if [ "$selfbad" = 0 ] && [ -s "$T/ops.txt" ] && { [ "$missing" = - ] || [ "$WM_TILE_SEED" != 20261008 ]; }; then
    echo "PASS  tile model: $gen (seed $WM_TILE_SEED); the model satisfies the invariants"
    echo "      cases reached: $(echo "$cov" | tail -1)"
    [ "$missing" = - ] || echo "NOTE  tile model: this seed never reaches: $missing"
else
    echo "FAIL  tile model: invariant violations in the model: $selfbad; cases the sequence never reaches: $missing"; ok=0
fi
mk_seq "$T/ops.txt" "$T/seq.la"

wm_vm seq.la "$T/seq_vm.txt"
nexp=$(wc -l < "$T/expect.txt")
if [ "$vrc" = 0 ] && cmp -s "$T/seq_vm.txt" "$T/expect.txt"; then
    echo "PASS  tile model (VM): all $nexp steps match the reference model line by line"
else
    first=$(cmp "$T/seq_vm.txt" "$T/expect.txt" 2>&1 | grep -o 'line [0-9]*' | grep -o '[0-9]*' || true)
    echo "FAIL  tile model (VM): rc=$vrc; $(wc -l < "$T/seq_vm.txt")/$nexp lines; first difference at step ${first:-?}:"
    if [ -n "${first:-}" ]; then
        echo "      op:       $(python3 -c "import sys; sys.path.insert(0, sys.argv[1]); import model
ops = model.generate(int(sys.argv[2]), int(sys.argv[3])); print(ops[int(sys.argv[4]) - 1])" "$T" "$WM_TILE_SEED" "$WM_TILE_STEPS" "$first")"
        echo "      expected: $(sed -n "${first}p" "$T/expect.txt" | cut -c1-220)"
        echo "      got:      $(sed -n "${first}p" "$T/seq_vm.txt" | cut -c1-220)"
    fi
    ok=0
fi

inv=$(python3 "$T/model.py" check "$T/seq_vm.txt")
if [ "$vrc" = 0 ] && [ "$(echo "$inv" | head -1)" = 0 ] && [ -s "$T/seq_vm.txt" ]; then
    echo "PASS  tile invariants (VM): every layout inside its area, disjoint, an exact tiling with the gaps; ids unique; count = leaves = show"
else
    echo "FAIL  tile invariants (VM): $(echo "$inv" | head -1) violations"; echo "$inv" | tail -n +2; ok=0
fi

# The host is a substitution interpreter: on this program it takes about
# 0.7 s a step against the VM's 0.01 s, so by default it runs a shorter
# sequence (WM_TILE_HOST_STEPS, 60) and the VM runs that one too.
if [ "$WM_TILE_HOST_STEPS" = "$WM_TILE_STEPS" ]; then
    cp "$T/seq.la" "$T/hseq.la"; cp "$T/expect.txt" "$T/hexpect.txt"; cp "$T/seq_vm.txt" "$T/hseq_vm.txt"; hvrc=$vrc
else
    python3 "$T/model.py" gen "$WM_TILE_SEED" "$WM_TILE_HOST_STEPS" "$T/hops.txt" "$T/hexpect.txt" >/dev/null
    mk_seq "$T/hops.txt" "$T/hseq.la"
    wm_vm hseq.la "$T/hseq_vm.txt"; hvrc=$vrc
fi
wm_host hseq.la "$T/hseq_host.txt"
if [ "$hrc" = 0 ] && [ "$hvrc" = 0 ] && [ -s "$T/hseq_host.txt" ] && cmp -s "$T/hseq_host.txt" "$T/hseq_vm.txt" \
   && cmp -s "$T/hseq_host.txt" "$T/hexpect.txt"; then
    echo "PASS  tile host = VM: on a $WM_TILE_HOST_STEPS-step sequence the C host prints the same $(wc -l < "$T/hseq_host.txt") lines as the VM and the model"
else
    echo "FAIL  tile host = VM: host rc=$hrc, VM rc=$hvrc; host and VM (or the model) differ on the $WM_TILE_HOST_STEPS-step sequence"; ok=0
fi

# ═══ 5. show on deep trees: the text, and the bytes it copies ═══════
# show of a chain (window i splits window i-1, the newest: depth n-1, the
# shape that MOD+Enter on the newest window again and again builds) and of a
# balanced tree (window i splits window i/2), with 40 and 256 windows, run
# with a concat that prints the length of every string it builds: their sum
# is the number of bytes concat copied (WM_DESIGN.md rule 5). The text must be
# the model's, and the copies must stay within the bound the module's header
# states: a byte produced at depth d (d splits above the node it belongs to)
# is copied at most 3d + 4 times. The first version nested the concats the
# other way round and copied the second child's text 6 times a level, about
# three times the bound on a chain. The host runs the 40-window cases and
# must print the same texts and the same totals.
cat > "$T/show_cost.py" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[2])
import model

CASES = [("chain", 40), ("bal", 40), ("chain", 256), ("bal", 256)]
HOST_CASES = CASES[:2]

def build(shape, n):              # the same sequence the LA program performs
    t = model.insert(model.E, 0, 1, 0)
    for i in range(2, n + 1):
        t = model.insert(t, i - 1 if shape == "chain" else i // 2, i, i % 2)
    return t

def bound(t, d=0):                # sum over the text's bytes of 3d + 4
    if t[0] == "L": return len("L%d" % t[1]) * (3 * d + 4)
    own = len("%s%d(" % ("H" if t[1] == 0 else "V", t[2])) + 2      # head, "," and ")"
    return own * (3 * d + 4) + bound(t[3], d + 1) + bound(t[4], d + 1)

def program(cases, path):
    chain = 'print("# end")'
    for shape, n in reversed(cases):
        focus = "sub(i)(1)" if shape == "chain" else "div(i)(2)"
        chain = ('SEQ(print("# %s %d"))(SEQ(print(concat("= ")(show(BUILD(la i. %s)(%d)))))(%s))'
                 % (shape, n, focus, n, chain))
    open(path, "w").write('''import("theourgia_tile.la")
glyph Z = la f. (la x. f(la v. x(x)(v)))(la x. f(la v. x(x)(v)))
glyph SEQ = la a. la b. b
glyph CC = la a. la b. (la r. SEQ(print(str_len(r)))(r))(concat(a)(b))
glyph MAIN = TILE_KIT(add)(sub)(mul)(div)(lt)(int_eq)(CC)(int_to_str)
  (la empty. la insert. la remove. la layout. la neighbour. la swap. la resize. la toggle.
   la leaves. la next. la has. la count. la show.
   (la BUILD. CHAIN)
   (la focus. la n. Z(la b. la i. la t. lt(n)(i)(la _. t)
        (la _. b(add(i)(1))(insert(t)(focus(i))(i)(sub(i)(mul(div(i)(2))(2)))))(0))(2)(insert(empty)(0)(1)(0))))
'''.replace("CHAIN", chain))

def parse(path):                  # [(case, text, bytes copied)]
    res, cur, tot = [], None, 0
    for line in open(path).read().splitlines():
        if line.startswith("# "): cur, tot = line[2:], 0
        elif line.startswith("= "): res.append((cur, line[2:], tot))
        else: tot += int(line)
    return res

if sys.argv[1] == "prog":         # prog T: the VM and the host programs
    program(CASES, sys.argv[2] + "/showcost.la"); program(HOST_CASES, sys.argv[2] + "/hshowcost.la")
elif sys.argv[1] == "check":      # check T OUT: one line per case, "ok ..." or "bad ..."
    got = parse(sys.argv[3])
    if [g[0] for g in got] != ["%s %d" % c for c in CASES]:
        print("bad output: cases %s" % [g[0] for g in got]); sys.exit()
    for (shape, n), (case, text, copied) in zip(CASES, got):
        t = build(shape, n); want = model.show(t); b = bound(t)
        if text != want: print("bad %s: text differs from the model at byte %d" % (case,
            next(i for i in range(min(len(text), len(want)) + 1) if text[i:i+1] != want[i:i+1])))
        elif copied > b: print("bad %s: copied %d bytes for %d of text, %.1f a byte; the bound is %d (%.1f a byte)"
                               % (case, copied, len(text), copied / len(text), b, b / len(text)))
        else: print("ok %s: %d bytes of text, %d copied (%.1f a byte, bound %.1f)"
                    % (case, len(text), copied, copied / len(text), b / len(text)))
elif sys.argv[1] == "same":       # same T HOSTOUT VMOUT: the host's cases agree with the VM's
    h, v = parse(sys.argv[3]), parse(sys.argv[4])
    print("ok" if h and h == v[:len(h)] else "bad")
PYEOF
python3 "$T/show_cost.py" prog "$T"
wm_vm showcost.la "$T/showcost_vm.txt"
sc=$(python3 "$T/show_cost.py" check "$T" "$T/showcost_vm.txt" 2>&1)
if [ "$vrc" = 0 ] && [ -n "$sc" ] && ! echo "$sc" | grep -qv '^ok'; then
    echo "PASS  tile show cost (VM): deep and balanced trees, the model's text, bytes copied within sum(3d + 4)"
    echo "$sc" | sed 's/^ok /      /'
else
    echo "FAIL  tile show cost (VM): rc=$vrc"; echo "$sc" | sed 's/^/      /'; ok=0
fi
wm_host hshowcost.la "$T/showcost_host.txt"
if [ "$hrc" = 0 ] && [ "$(python3 "$T/show_cost.py" same "$T" "$T/showcost_host.txt" "$T/showcost_vm.txt" 2>&1)" = ok ]; then
    echo "PASS  tile show cost host = VM: the 40-window texts and byte totals agree"
else
    echo "FAIL  tile show cost host = VM: host rc=$hrc; the host's texts or byte totals differ from the VM's"; ok=0
fi

[ "$ok" = 1 ] || exit 1
