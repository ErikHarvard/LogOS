# LogosNet — the contract (Citrinitas, after LogosFS and LogosPkg)

CODEX_AUTOPOIETICUS.tex fixes the build order (§"The Staged Architecture of
LogosOS", l. 2311-2333): LogosLang, LogosCompiler, LogosFS, LogosPkg,
**LogosNet**, LogosKernel, LogosHAL. LogosNet is *"Sovereign mesh protocol with
cryptographic self-assigning identities. Not TCP/IP but a recursive protocol
where each node can function as the network"* (l. 2325). The mycelial
architecture (l. 5779-5870) asks for six properties: no centre, redundant
connections (removing a node does not disconnect the rest), sovereign transfer
between equals, self-communication, antifragile growth (neighbours reconnect
around damage), and an invisible foundation. The Λ-protocol (l. 4865-4890)
asks that a message open only under *mutual recognition*: only the recipient
can open it, only the sender could have made it, and anything else yields
noise.

Everything below is written in Lingua Adamica and runs on the native SECD VM
with its existing builtins. Three modules, built in this order, each with its
own gate.

## Shared rules

- Kit style (WM_DESIGN.md "How fast the VM is"): each module exports a
  constructor that takes the builtins and constants it uses as parameters and
  returns a Scott record; no glyph or builtin is named in hot code.
- Bytes are raw binary strings; ids and digests are shown as lowercase hex.
- The crypt record is a parameter: `la s. s(sha256)(hmac)(hkdf)(seal)(open)(hex)`
  with crypt_ref.la's contract (CRYPT_REF today; CRYPT_FAST, logoscrypt.la, when
  it lands — same contract, faster).
- Options are `la none. la some. …` (`none(none)` / `some(x)`); results that can
  fail say so in their header. A malformed argument the contract forbids halts
  loudly with `<module>: <operation>: <reason>` (the `error` builtin).
- Each gate uses known answers or an independent oracle (the Python
  `cryptography` package, when present, or a reference written in the gate),
  never only self-consistency, and is mutation-checked.

## 1. `x25519.la` — `X25519_KIT`

RFC 7748 X25519 Diffie-Hellman, the one public-key primitive LogosNet needs.

`X25519_KIT(<builtins>)` → `la s. s(scalarmult)(public)(shared)`

- `scalarmult(k)(u)` — k and u are 32-byte strings. Decode k with clamping
  (k[0] &= 248, k[31] &= 127, k[31] |= 64) and u little-endian with its top bit
  masked; run the Montgomery ladder over all 255 bits with a conditional swap
  done by arithmetic (the same operations for every bit, no branch on a key
  bit); encode the result as 32 bytes little-endian, fully reduced mod
  p = 2^255 - 19. Any other length halts: `x25519: scalarmult: key and point
  must be 32 bytes`.
- `public(sk)` = `scalarmult(sk)(9)`.
- `shared(sk)(pk)` → option: `none` when the result is all zero (a small-order
  `pk`, RFC 7748 §6.1), `some(secret)` otherwise.

Field arithmetic: radix 2^25.5 (ten limbs, ref10) or sixteen 16-bit limbs
(TweetNaCl); every product and sum must fit a signed 64-bit integer. If any part
of the module is generated (an unrolled multiplication, say), the generator is an
LA program committed beside it: nothing outside LA in the build path.

Gate `gate_x25519.sh`: RFC 7748 §5.2's two test vectors; §5.2 after one
iteration (k = u = 9 → `422c8e7a6227d7bca1350b3e2bb7279f7897b87bb6854b783c60e80311ae3079`);
§6.1 Alice and Bob (both public keys and the shared secret); `shared` refusing
the all-zero result for low-order points (u = 0 and u = 1); the Python
`cryptography` package as an oracle on random key pairs (skipped with a NOTE
when it is absent); the loud halt on a wrong length; VM time per scalarmult.

## 2. `logosnet.la` — `NET_KIT`

### Frames
`frame(payload)` = 4-byte big-endian length ++ payload (payload ≤ 1 MiB;
larger halts). `deframe(buf)(chunk)` → `la k. k(payloads)(buf')`, payloads a
Scott list of the complete frames in order, buf' the incomplete tail; a declared
length above 1 MiB is a protocol error the caller treats as a broken link.

### Noise
`Noise_XX_25519_ChaChaPoly_SHA256` exactly as in the Noise Protocol Framework
(revision 34), prologue `LogosNet/1`, so it interoperates with an independent
implementation: `-> e`, `<- e, ee, s, es`, `-> s, se`; ChaChaPoly's nonce is
4 zero bytes ++ the 64-bit little-endian counter; HKDF is Noise's (HMAC-SHA256).
The handshake states are values: `write_message(hs)(payload)` →
`la k. k(message)(hs')`, `read_message(hs)(message)` → option of
`la k. k(payload)(hs')`; a finished handshake gives the two transport cipher
states and the remote static public key. Transport: `encrypt(cs)(pt)` →
`la k. k(ct)(cs')`, `decrypt(cs)(ct)` → option. Noise's 65535-byte message limit
holds; a longer payload is refused.

For end-to-end messages, the one-way pattern `Noise_X_25519_ChaChaPoly_SHA256`
(`-> e, es, s, ss`) to the destination's static key: only the destination can
open it, and it proves the sender's static key (mutual recognition). A blob that
does not open is dropped; nothing of it is released.

### Identity
A node's static key pair comes from `random("32")`, kept in a key file (mode
0600). Its **NodeID** is the hex of the first 16 bytes of `sha256(public)`:
self-assigned and checkable by anyone holding the public key
(`verify_id(id)(pub)`).

### The node
`NODE(<kits>)(cfg)` runs one node as a process: a poll loop (the WM_LOOP shape:
one `poll` over the listening socket, every link, and the control channel; the
recursive call in tail position). Its address on the local transport is the
AF_UNIX path `<netdir>/<nodeid>.sock`. Each new connection runs the XX handshake;
the link then carries frames of transport-encrypted mesh messages:

- **PRESENCE**(id, pub, path, seq) — on link-up and every T seconds; flooded,
  deduplicated by (id, seq). Each node keeps a directory id → (pub, path, seq,
  last seen) and discards an entry whose id is not the hash of its pub.
- **DATA**(msgid, ttl, dest, blob) — flooded to every link but the one it came
  from, deduplicated by msgid (the last 4096 kept), ttl 16 decremented, dropped
  at 0. Only `dest` opens `blob` (the Noise X message).
- **Repair** — every T seconds (the poll timeout), a node with fewer than K links
  (default 2) connects to directory entries it has no link to; a link that reads
  EOF or fails is dropped.

The node is driven through a control channel (a FIFO or an AF_UNIX socket — the
module documents which): `send <dest> <text>`, `id`, `peers`, `directory`,
`quit`. It logs on stdout: `net: up <id>`, `net: link <id>`, `net: unlink <id>`,
`net: recv <from> <text>`, `net: drop <reason>`.

Gate `gate_logosnet.sh` (several VM node processes in a temp dir, driven from
Python): frames round-trip across arbitrary chunk boundaries; the XX and X
handshakes match a Python Noise implementation byte for byte for fixed
ephemerals, in both roles; NodeIDs are the hash of the public key; in a line
A–B–C, A reaches C through B and B's log never contains the payload; in a ring of
five every pair delivers, and with one node killed every remaining pair still
delivers; killing the only bridge partitions the line (A cannot reach C) and
restarting it repairs the path; a relay that flips a byte of a DATA blob gets it
dropped at the destination; an impostor using another node's id with its own
key is refused; a node learns of a node it was never told about through
presence.

### Out of scope now (named, not hidden)
IP transport — the VM has AF_UNIX sockets only, so LogosNet nodes on different
machines need an AF_INET builtin (a VM change, not LA); onion routing (AegisNet);
traffic shaping and encrypted presence (Meta-E2EE beacons); signatures (Ed25519).
The transport is a record, so an IP transport plugs in without touching the
protocol.

## 3. `logostorrent.la` — `TORRENT_KIT` (meta-torrenting)

Content-addressed sharing over LogosNet (codex §"meta-torrenting", l. 3112).

- `manifest(data)(chunk)` → `"LTOR1\n" ++ length ++ "\n" ++ chunk ++ "\n"` ++
  one hex sha256 per chunk per line; the **root** is the hex sha256 of the
  manifest.
- A node with the torrent service answers `seed <path>` (prints the root) and
  `fetch <root> <out>`. Over LogosNet DATA: WANT(root) floods, HAVE(root)
  answers; the manifest is fetched first and checked against the root; GET(root,
  i) → CHUNK(root, i, bytes) are spread over every HAVE-er; each chunk is checked
  against the manifest, and a bad chunk is fetched again from another peer; the
  file is written atomically when complete and checked whole.

Gate `gate_logostorrent.sh`: manifest and root against a Python computation; a
4-node mesh, a 4 KiB file in 512-byte chunks seeded by two nodes, one of which
serves corrupt chunks — the fetcher assembles the exact file; a seeder killed
mid-fetch — the fetch completes from the other; an unknown root reports not
found after a timeout.
