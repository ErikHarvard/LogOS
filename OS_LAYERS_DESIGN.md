# Citrinitas layers 9–13 and AletheiaFS — the design contract

Status: design contract for the build (2026-10-08). ROADMAP.md Phase II lists
thirteen layers; 1–5 are done, 6–8 are partly done (the tiling WM in
WM_DESIGN.md advances 6), and 9–13 were unstarted, as was the filesystem the
roadmap calls its largest omission (G1). This document fixes what each of those
is, in Lingua Adamica, so they can be built in parallel and fit together. The
names and the requirements come from CODEX_AUTOPOIETICUS.tex: the thirteen-layer
table (§"The Complete LogOS Stack", line ~18230), AletheiaFS (§ at line 2881),
the type-distinction security model (line 4808), and LogosPkg (line 2323).

Like logosinit.la and logosipc.la, these run on the native SECD VM on Linux,
the engine with the file, process and socket builtins. Each module's header
says which engines it runs on.

## Rules every module follows

- **Kit style where it is hot** (WM_DESIGN.md, "How fast the VM is"): code that
  runs per byte or per block (all of the cryptography) takes its builtins and
  constants as parameters and never names a glyph or builtin after startup.
  Code that runs once per user-level operation may be written plainly, but
  must not loop over data through named builtins.
- **Cryptography comes in as a record**, never by importing the primitives:
  `crypt = la s. s(sha256)(hmac)(hkdf)(seal)(open)(hex)` with exactly the
  meaning crypt_ref.la documents (raw-byte outputs, a 16-byte tag appended by
  `seal`, `open` returning `la none. la some.` and never unauthenticated bytes).
  `CRYPT_REF` (crypt_ref.la, gated by gate_crypt_ref.sh) is the correct, slow
  record every module can be tested with today; `CRYPT_FAST` (logoscrypt.la)
  will be a drop-in.
- **Shared encodings** as WM_DESIGN.md: Church booleans; Scott lists
  `nil = la n. la c. n(n)`, `cons(h)(t) = la n. la c. c(h)(t)`; options
  `la none. la some.` with `none(none)`; records `la k. k(f1)…(fn)`; **results**
  `la err. la ok. …` with `err(message)` / `ok(value)`.
- **Strings cross the VM syscall boundary as decimals** (fork, pipe, read,
  waitpid, stat, clock_gettime return strings). On this branch's VM,
  `read_file` of a missing file returns `""` silently (a later PR makes it
  halt), so a module that needs to know whether a file exists asks `stat`.
- **Writes are atomic**: write `path.tmp`, then `rename` onto `path`.
- **Fail closed**: an unknown caveat, a malformed token, a broken hash chain, a
  missing signature — each denies or errors loudly. Nothing is accepted by
  default.
- **Tests**: one gate per module, `gate_<module>.sh`, sourcing
  gate_wm_common.sh, known answers or an independent oracle, every operation
  covered, shown to fail on a mutated module.
- **Self-application** (Codex Thm. "true-os-metacursive"): each layer is shown to
  apply to itself, as stated per layer below, and its gate checks it.

## `logoscrypt.la` — `CRYPT_FAST`

`CRYPT_FAST(…builtins…)` returns a record with **exactly** the crypt contract.
Kit style throughout: SHA-256 compression, the HMAC and HKDF compositions,
the ChaCha20 block, Poly1305 (arbitrary precision is not needed: 130-bit
arithmetic in 26-bit limbs, as poly1305.la does), and `seal`/`open`.
Gate: every known answer gate_crypt_ref.sh checks; equality with `CRYPT_REF`
on inputs at the SHA-256 padding boundaries (0, 1, 55, 56, 63, 64, 65, 119,
120 bytes), on HMAC keys longer than a block, on HKDF lengths 1..96, and on
`seal`/`open` of 0, 1, 63, 64, 65 and 300 bytes; a flipped bit in either the
ciphertext or the tag opens to `none`. Report VM time against `CRYPT_REF` for
sha256 and seal of 1 KB and 10 KB; the point of the module is a large factor.

## `logossec.la` — the Γ-Security model (layer 9)

Codex: *"Capability-based security … Every organ holds capabilities (tokens)
specifying exactly what it can access. No ambient authority. No root user. The
sovereign's Γ-seal is the root of all capability delegation."*

**Resources** are slash paths without a leading slash: `obj/<id>`, `obj`,
`fs/home/alice/notes`, `ipc/time`, `proc/spawn`, `svc/ledger`, `sec/policy`.
A resource `r` is **within** a prefix `p` iff `r == p` or `r` starts with
`p ++ "/"`. A request resource containing an empty, `.` or `..` segment is
refused outright.

**Ops** are single letters: `r` read, `w` write, `x` execute, `c` connect/call,
`a` administer.

**Tokens** are HMAC-chained, macaroon-style, so they serialise, cross IPC and
disk, and can be **narrowed by anyone who holds one but widened by no one**:

    token = id "|" caveat1 "|" … "|" caveatN "|" hex(sig)
    sig0 = hmac(K_root)(id);   sig_i = hmac(sig_{i-1})(caveat_i)

`id` is 1–64 characters of `[A-Za-z0-9_.-]`; a caveat is `key=value`, with no
`|` or newline. Caveats:

| caveat | holds for a request (res, op, now) iff |
| --- | --- |
| `res=<prefix>` | `res` is within `<prefix>` |
| `ops=<letters>` | `op` is one of the letters |
| `until=<unix seconds>` | `now` ≤ the value |
| anything else | never (fail closed) |

Every caveat must hold (so adding caveats only narrows). A token with no
caveats grants everything; only the holder of `K_root` can mint one.

`SEC_KIT(…builtins…)(crypt)` returns
`la s. s(mint)(attenuate)(verify)(within)(confine)`:

| op | meaning |
| --- | --- |
| `mint(K_root)(id)(caveats)` | a token; `caveats` a Scott list of strings; a malformed id or caveat is an error result |
| `attenuate(token)(caveat)` | the token with one more caveat (no key needed) |
| `verify(K_root)(revoked)(token)(res)(op)(now)` | `ok(id)` or `err(reason)`: the signature chain recomputes (compared without an early exit), the id is not in `revoked` (a Scott list of ids), and every caveat holds |
| `within(res)(prefix)` | the prefix rule, as a boolean |
| `confine(src)(granted)` | **no ambient authority, checked statically**: parse the LA program `src` (one module, no imports) and return `ok(src)` when every name it uses is a lambda parameter in scope, a glyph `src` defines, or a name in `granted` (a Scott list); otherwise `err` listing the offending names. A program that passes can only reach the outside world through what it is handed. |

`GUARD_KIT(…builtins…)(sec)(K_root)` is the **reference monitor** (VM): it
returns guarded versions of real operations, each of which verifies its token
first and performs the operation only on `ok`:
`la s. s(read)(write)(spawn)(connect)(revoke)(revoked)` with
`read(tok)(path)`, `write(tok)(path)(data)`, `spawn(tok)(path)(args)`,
`connect(tok)(name)` (logosipc CONNECT), each returning a result; `path` is an
absolute host path and the resource is `fs` ++ path. `revoke(tok)(id)` needs a
token for `sec/policy` with op `a`, and returns the guard with `id` added to
its revocation list. **Self-application**: the security policy (the revocation
list) is itself a resource the model protects.

Honest scope to state in the header: this is enforcement in the library and at
load (`confine`); a program that is not confined can still call builtins
directly. Kernel-level enforcement belongs to LogosKernel.

## `aletheiafs.la` — AletheiaFS (G1)

Codex: *"there are no files. Every persistent data entity is a Logos-object … its
own identity, encryption, semantics, history, and access policy … self-describing,
auto-repairing, recursively sealed … ephemeral-capable."*

`FS_KIT(…builtins…)(crypt)(random)` returns
`la s. s(open)(put)(get)(update)(history)(version)(find)(verify)(remove)(ephemeral)(close)`.
`random(n)` is the VM's `random` builtin (passed in, so tests can be
deterministic).

- **The store** is a host directory. `open(root)(K_M)(guard)` creates or opens
  it and returns a handle. `K_M` is 32 bytes; `guard(tok)(res)(op)` is a
  boolean (logossec's verify, partially applied, in real use; a stub in tests).
- **Identity**: an object id is 32 hex characters from 16 random bytes.
- **Recursive sealing**: each object has its own key,
  `K_O = hkdf(id)(K_M)("aletheia/object")(32)`; the index of ids is sealed
  under `hkdf("")(K_M)("aletheia/index")(32)`.
- **Versions** are numbered from 1. Version `n` of object `id` is one sealed
  blob: nonce = `n` as 12 little-endian bytes, AAD = `id ++ "|" ++ n`,
  plaintext = a header (`n=`, `tags=` comma-separated, `owner=`, `prev=` hex
  sha256 of version n-1's sealed blob or `none`, `len=`) and then the
  content. It is written twice, `obj/<id>/<n>` and `mirror/<id>/<n>`; `obj/<id>/head`
  holds the latest `n`.
- **Access policy**: every operation asks `guard(tok)(…)`: `put` needs `obj`
  with `w`; `get`/`history`/`version` need `obj/<id>` with `r`;
  `update`/`remove` need `obj/<id>` with `w`; `find` needs `obj` with `r`.
- Operations: `put(fs)(tok)(content)(tags)(owner)` → `ok(id)`;
  `get(fs)(tok)(id)` → `ok(la k. k(content)(tags)(owner)(n))`;
  `update(fs)(tok)(id)(content)` → `ok(n)`; `history(fs)(tok)(id)` →
  `ok(list of n)` after checking every `prev` link, or `err("chain broken at n")`;
  `version(fs)(tok)(id)(n)` → `ok(content)`; `find(fs)(tok)(tag)` → `ok(list of
  ids whose latest version has the tag)`; `remove(fs)(tok)(id)` → `ok`.
- **Auto-repair**: reading a version opens the primary; if it fails
  authentication it opens the mirror and, if that verifies, rewrites the
  primary. `verify(fs)` walks every version of every object, repairs either
  copy from the other, and returns a report: counts checked/repaired/lost.
- **Ephemeral**: `ephemeral(fs)(content)` returns a handle to an object that is
  never written to disk; `close(fs)` drops them all.

Gate: round trips; version chain and history; a tampered primary repaired from
the mirror (the file changed on disk, the report says repaired, the content
is intact); both copies tampered → `lost` and `get` is an error (no bytes);
a deleted primary repaired; a wrong `K_M` cannot read anything; a stub guard
that denies blocks every operation; ephemeral objects leave no files.
**Self-application**: the filesystem's own index is a sealed object stored by
the filesystem.

## `logosservices.la` — LogosServices (layer 13)

Codex: *"Background processes: time sync, DNS resolution, power management …"*;
*"LogosServices services itself (system services are services managed by the
service manager)."*

A **service** is a descriptor `la k. k(name)(path)(args)(deps)(restart)`:
`path`/`args` as for `execv` (args includes argv[0]); `deps` a Scott list of
names; `restart` one of `"always"`, `"on-failure"`, `"never"`.

`SVC_KIT(…builtins…)` returns `la s. s(manager)` where
`manager(descs)(channel)(logdir)` runs the service manager (VM): it starts the
services in dependency order (a cycle or a missing dependency is a loud
error), captures each one's stdout and stderr through a pipe into
`logdir/<name>.log`, reaps exits (non-blocking, every loop pass), restarts per
policy with a backoff that doubles from 1 s and stops after 5 restarts in a row
(the service is then `failed`), and serves control requests on the logosipc
channel `channel` with typed messages: `status` → one line per service
(`name state pid restarts`), including **the manager itself** as
`logosservices`; `stop <name>`; `start <name>`; `restart <name>`;
`shutdown` (stop everything, then exit 0).

Two services, each its own LA program:

- `logostime.la` — **LogosTime**: serves `now` (realtime `"<sec> <nsec>"`) and
  `mono` on the channel `time`.
- `logosledger.la` — **the GlyphLedger** (the Codex's signed system-event log):
  serves `append <text>` → `ok <n>`, `verify` → `ok <n>` or `broken <i>`, and
  `tail <k>`, on the channel `ledger`. Entry `i` is the line
  `i|<unix seconds>|<hex sha256 of entry i-1, or 64 zeros>|<text>`, so editing
  any entry breaks every link after it.

Gate: start the manager with the two services plus one that exits with status 3
after a second (`on-failure`); `status` shows all of them and the manager;
the failing one is restarted with growing gaps and ends `failed`; time answers;
ledger appends, verifies, and reports `broken` after an entry in its file is
edited; `stop`/`start`; `shutdown` ends everything with rc 0 and no process
left behind.

## `logospkg.la` — LogosPkg (layer 12)

Codex: *"Autoteloscriptic packages (self-verifying, b_τ ≡ f_τ). Advisory Update
Protocol. Content-addressed distribution"*; *"LogosPkg updates itself (the
package manager is a package managed by the package manager)."*

- **A package** is one archive string:
  `logospkg1\n` then header lines `name=`, `version=` (dotted decimals),
  `deps=` (comma-separated names, may be empty), `test=` (the file name of its
  self-test program), then for each file `file <name> <length>\n<bytes>\n`, then
  `end\n`. The file `<test>.expected` holds the self-test's exact expected
  stdout. Its **id** is `hex(sha256(archive))`.
- **A repository** is a directory: `pkg/<id>` archives; `index` with lines
  `name version id`; `index.sig` = `hex(hmac(K_repo)(index))`. (A symmetric
  repository key is the honest limit today: there are no public-key signatures
  in LA yet.)
- **An installation** is a directory: `pkgs/<name>/<version>/…files`,
  `current/<name>` (the active version), `installed` (lines `name version id`).

`PKG_KIT(…builtins…)(crypt)(cfg)` with `cfg = la s. s(vm)(compiler)`, the paths of
the VM binary and compiler.bin, returns
`la s. s(pack)(unpack)(publish)(install)(remove)(advise)(update)(rollback)(list)`:

| op | meaning |
| --- | --- |
| `pack(name)(version)(deps)(test)(files)` | the archive (`files` a Scott list of `la k. k(name)(bytes)`) |
| `unpack(archive)` | `ok(la k. k(name)(version)(deps)(test)(files))` or `err` |
| `publish(repo)(K_repo)(archive)` | add it and re-sign the index |
| `install(inst)(repo)(K_repo)(name)` | the newest version and, first, its dependencies (topological; a cycle is an error). For each: the index signature verifies, the archive's sha256 equals its id, it unpacks into `staging/`, and **its self-test is compiled and run on the VM** in a child process (with every dependency's files beside it), and its stdout must equal `<test>.expected` byte for byte. Only then is it moved into `pkgs/`, `current/` and `installed` updated (atomically). Any failure leaves the installation exactly as it was. |
| `remove(inst)(name)` | refuses while an installed package depends on it |
| `advise(inst)(repo)(K_repo)` | the **Advisory Update Protocol**: a list of `la k. k(name)(installed)(available)`; nothing is changed |
| `update(inst)(repo)(K_repo)(name)` | install the newer version (same checks); the old one stays in `pkgs/` |
| `rollback(inst)(name)` | `current/<name>` back to the previous version |
| `list(inst)` | the installed packages |

Gate: pack/unpack round trip; install with dependencies in order; a package
whose self-test output differs is refused and leaves nothing behind; a
tampered archive (id mismatch) and a tampered index (bad signature) are
refused; remove refuses a needed dependency; advise/update/rollback; and
**self-application**: logospkg packaged as a package, installed by logospkg,
and updated from 1.0 to 1.1 by the installed copy.

## `logossession.la` — LogosSession (layer 11)

Codex: *"Manages login (Γ-seal authentication), session state, screen lock,
suspend/resume, multi-sovereign isolation"*; *"LogosSession manages itself (the
session manager's session is the managed session)."*

`SESSION_KIT(…builtins…)(crypt)(sec)(fs)(random)` returns
`la s. s(adduser)(login)(lock)(unlock)(suspend)(resume)(state)(logout)`:

- **Users** live in `<root>/users/<name>`: a random salt and a verifier, never
  the passphrase. `stretch(pass)(salt)` is PBKDF2-HMAC-SHA256 (RFC 8018) with
  an iteration count stored in the record; the verifier is
  `hmac(stretch)("logos/verifier")`.
- `login(root)(name)(pass)` → `ok(session)` or `err`: the session carries the
  user's **Γ-seal** `K_U = hkdf(salt)(stretch)("logos/gamma")(32)`, from which
  everything else derives: the user's AletheiaFS master
  `hkdf("")(K_U)("aletheia/master")(32)` over `<root>/home/<name>`, and the
  user's capability root `hkdf("")(K_U)("gamma/root")(32)`, with a root token for
  the user's own resources.
- `lock(session)` → a locked session that no longer holds `K_U` or anything
  derived from it; `unlock(locked)(pass)` → the session again, or `err`.
- `suspend(session)(state)` stores `state` (a string the WM supplies: windows,
  layout, working directories) as a sealed object in the user's AletheiaFS and
  returns the locked session; `resume(root)(name)(pass)` →
  `ok(la k. k(session)(state))`.
- **Isolation**: a second user's session cannot read the first user's objects
  (different `K_M`) and the first user's tokens do not verify under the second
  user's capability root.
- **Self-application**: the session manager's own record of the session is
  part of the state it saves and restores.

Gate: adduser/login; a wrong passphrase is refused; lock drops the keys (the
locked value cannot read the user's objects) and unlock restores them;
suspend/resume round-trips the state; two users are isolated both ways; the
stored user record contains neither the passphrase nor `K_U`.

## Later: `logoskit.la` — LogosKit (layer 10)

The UI framework comes after the WM's renderer lands (WM_DESIGN.md), and
follows the Codex's ontoglyphic law, *Meaning(e) ≡ Structure(e) ≡ State(e)*:
interface elements are generated from state, and the accessible text of every
element is derived from the same tree, so it cannot be skipped
(the accessibility invariant 𝔄_acc).
