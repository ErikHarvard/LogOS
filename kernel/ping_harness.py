#!/usr/bin/env python3
# QEMU socket-netdev pinger/sniffer for the HAL.5g ICMP-responder gate.
# QEMU runs `-netdev socket,id=n0,listen=127.0.0.1:PORT`; this connects as the
# sole L2 peer. Frames on the wire are prefixed with a 4-byte big-endian length.
#
# Modes:
#   sniff PORT SECS            — connect, print every frame the guest sends
#   ping  PORT SECS            — send an ICMP echo REQUEST to the guest, then
#                                report whether an ICMP echo REPLY came back
import socket, struct, sys, time

GUEST_MAC = bytes([0x52,0x54,0x00,0x12,0x34,0x56])   # the LA kernel's MAC
PINGER_MAC= bytes([0x52,0x55,0x0a,0x00,0x02,0x02])   # our (pinger) MAC
GUEST_IP  = bytes([10,0,2,15]); PINGER_IP = bytes([10,0,2,2])
UDP_PAYLOAD = b"LOGOS-UDP-ECHO-42!"                  # 18 bytes -> a 60-byte frame
OUR_UDP_PORT = 7                                     # the guest's echo port (req dst)
SENDER_UDP_PORT = 40000                              # our ephemeral port (req src)

def ipck(h):
    s=sum((h[i]<<8)+h[i+1] for i in range(0,len(h),2))
    while s>>16: s=(s&0xffff)+(s>>16)
    return (~s)&0xffff

def icmp_echo_request(opts=None):
    # opts=None -> IHL=5 (what every gate before HAL.5j sent). opts=[...] ->
    # IHL=5+len(opts)//4, so the ICMP header no longer sits at the fixed frame
    # offset 34 that HAL.5g assumed. See IP_OPTS_NOP4 below.
    opts = opts or []
    assert len(opts)%4==0, "IP options must be a multiple of 4 bytes (IHL counts words)"
    ihl = 5 + len(opts)//4
    icmp=[8,0,0,0, 0,1,0,1]                 # type8 code0 cksum id1 seq1
    c=ipck(icmp); icmp[2]=c>>8; icmp[3]=c&0xff
    ln=4*ihl+len(icmp)
    ip=[0x40|ihl,0,ln>>8,ln&0xff,0,0,0,0,64,1,0,0]+list(PINGER_IP)+list(GUEST_IP)+opts
    c=ipck(ip); ip[10]=c>>8; ip[11]=c&0xff
    f=bytes(GUEST_MAC)+bytes(PINGER_MAC)+b'\x08\x00'+bytes(ip)+bytes(icmp)
    if len(f)<60: f=f+b'\x00'*(60-len(f))   # pad to Ethernet min so the NIC keeps it
    return f

def icmp_echo_request_opts():
    return icmp_echo_request(IP_OPTS_NOP4)

# IP OPTIONS. A 4-byte block of three NOPs + End-of-Option-List: the minimal
# legal way to make IHL=6 instead of 5. Deliberately semantics-free — the point
# is to move where the UDP header STARTS, not to ask the kernel to honour an
# option. Options are counted in 32-bit words, so the block must be a multiple
# of 4 for IHL to be an integer.
IP_OPTS_NOP4 = [0x01,0x01,0x01,0x00]

def udp_request(opts=None):
    # opts=None -> IHL=5 (a 20-byte header, the classic case every earlier gate
    # sent). opts=[...] -> IHL=5+len(opts)//4, so the UDP header no longer sits
    # at the fixed frame offset 34 that HAL.5h assumed.
    opts = opts or []
    assert len(opts)%4==0, "IP options must be a multiple of 4 bytes (IHL counts words)"
    ihl = 5 + len(opts)//4
    p=UDP_PAYLOAD; ul=8+len(p)
    udp=[SENDER_UDP_PORT>>8,SENDER_UDP_PORT&0xff, OUR_UDP_PORT>>8,OUR_UDP_PORT&0xff,
         ul>>8,ul&0xff, 0,0]+list(p)              # udp checksum 0 = disabled (IPv4 legal)
    il=4*ihl+ul
    ip=[0x40|ihl,0,il>>8,il&0xff,0,0,0,0,64,17,0,0]+list(PINGER_IP)+list(GUEST_IP)+opts
    c=ipck(ip); ip[10]=c>>8; ip[11]=c&0xff
    f=bytes(GUEST_MAC)+bytes(PINGER_MAC)+b'\x08\x00'+bytes(ip)+bytes(udp)
    if len(f)<60: f=f+b'\x00'*(60-len(f))
    return f

def udp_request_opts():
    return udp_request(IP_OPTS_NOP4)

def valid_udp_echo(f):
    # rigorous: IPv4/UDP, addresses swapped back, ports swapped, payload echoed exactly
    if len(f)<42 or (f[12]<<8|f[13])!=0x0800 or f[23]!=17: return False
    if bytes(f[26:30])!=GUEST_IP or bytes(f[30:34])!=PINGER_IP: return False  # src=guest, dst=us
    il=(f[16]<<8)|f[17]; ihl=(f[14]&0x0f)*4; udp=f[14+ihl:14+il]
    if len(udp)<8: return False
    sport=(udp[0]<<8)|udp[1]; dport=(udp[2]<<8)|udp[3]
    if sport!=OUR_UDP_PORT or dport!=SENDER_UDP_PORT: return False            # ports swapped
    return bytes(udp[8:])==UDP_PAYLOAD                                        # payload echoed

def connect(port):
    for _ in range(50):
        try:
            s=socket.create_connection(("127.0.0.1",port),timeout=1); return s
        except OSError: time.sleep(0.1)
    print("PINGER: could not connect"); sys.exit(2)

def serve(port):
    """Listen and let QEMU connect to US (-netdev socket,connect=...).

    ★ WHY THIS EXISTS. With QEMU listening and the harness connecting, there is
    a startup RACE: a requester kernel (HAL.5c/5k/5d/5l) transmits its ARP and
    request within the first few hundred ms of boot, and QEMU DROPS transmitted
    frames while no peer is attached. The harness then legitimately sees zero
    guest frames and the gate reports a failure that says nothing about the
    kernel -- which is exactly what happened on 5k's first run. Reversing the
    direction removes the race by construction: we are listening before QEMU is
    even launched, so no guest frame can be sent into a void. Responder kernels
    (5g/5j/5h/5i) never hit this, because they transmit only AFTER receiving,
    by which time the peer is necessarily attached."""
    srv=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1",port)); srv.listen(1); srv.settimeout(30)
    print("PINGER: listening", flush=True)   # the gate waits for this before starting QEMU
    try:
        conn,_=srv.accept()
    except socket.timeout:
        print("PINGER: qemu never connected"); sys.exit(2)
    finally:
        srv.close()
    return conn

def send_frame(s,f): s.sendall(struct.pack(">I",len(f))+f)

def recv_frames(s, secs):
    s.settimeout(0.3); end=time.time()+secs; buf=b''
    while time.time()<end:
        try: chunk=s.recv(4096)
        except socket.timeout: continue
        if not chunk: break
        buf+=chunk
        while len(buf)>=4:
            n=struct.unpack(">I",buf[:4])[0]
            if len(buf)<4+n: break
            yield buf[4:4+n]; buf=buf[4+n:]

def valid_echo_reply(f):
    # rigorous: IPv4/ICMP, type 0, addresses swapped back to us, ICMP checksum OK
    if len(f)<34 or (f[12]<<8|f[13])!=0x0800 or f[23]!=1: return False
    if bytes(f[26:30])!=GUEST_IP or bytes(f[30:34])!=PINGER_IP: return False   # src=guest, dst=us
    iplen=(f[16]<<8)|f[17]                      # IP total length
    icmp=f[14+ (f[14]&0x0f)*4 : 14+iplen]       # ICMP = IP payload
    if len(icmp)<8 or icmp[0]!=0: return False  # type 0 = echo reply
    s=0                                          # verify ICMP checksum sums to 0xffff
    for i in range(0,len(icmp)-1,2): s+=(icmp[i]<<8)|icmp[i+1]
    if len(icmp)%2: s+=icmp[-1]<<8
    while s>>16: s=(s&0xffff)+(s>>16)
    return s==0xffff

def decode(f):
    if len(f)<14: return "runt"
    et=(f[12]<<8)|f[13]
    if et==0x0806 and len(f)>=42:
        return f"ARP op={(f[20]<<8)|f[21]}"
    if et==0x0800 and len(f)>=34:
        proto=f[23]; ihl=(f[14]&0x0f)*4; u=14+ihl; t="?"
        if proto==1 and len(f)>=u+1: t=f"icmp_type={f[u]}"
        elif proto==17 and len(f)>=u+4: t=f"udp {(f[u]<<8)|f[u+1]}->{(f[u+2]<<8)|f[u+3]}"
        return f"IPv4 ihl={ihl} proto={proto} {t}"
    return f"et={et:04x}"


# ---------------------------------------------------------------------------
# HAL.5k / HAL.5l — INJECTED replies.
# SLIRP cannot emit IP options, so a requester kernel's IHL handling can only be
# exercised by crafting the reply ourselves. These build frames FROM the pinger
# TO the guest (the reverse direction of the request builders above).
# ---------------------------------------------------------------------------

def icmp_echo_reply(opts=None):
    """An ICMP echo REPLY (type 0) addressed to the guest -- what HAL.5c/5k
    expect to receive. With opts the ICMP header no longer sits at frame 34."""
    opts = opts or []
    assert len(opts) % 4 == 0
    ihl = 5 + len(opts)//4
    icmp = [0,0,0,0, 0,1,0,1]                     # type0 code0 cksum id1 seq1
    c = ipck(icmp); icmp[2] = c >> 8; icmp[3] = c & 0xff
    ln = 4*ihl + len(icmp)
    ip = [0x40|ihl,0,ln>>8,ln&0xff,0,0,0,0,64,1,0,0]+list(GUEST_IP)+list(PINGER_IP)+opts
    c = ipck(ip); ip[10] = c >> 8; ip[11] = c & 0xff
    f = bytes(GUEST_MAC)+bytes(PINGER_MAC)+b'\x08\x00'+bytes(ip)+bytes(icmp)
    if len(f) < 60: f = f + b'\x00'*(60-len(f))
    return f

DNS_SRC_IP = bytes([10,0,2,3])          # SLIRP's DNS proxy address, for realism

def dns_response(opts=None):
    """A DNS response over UDP from port 53 with ancount=2 -- the shape
    HAL.5d/5l read (sport at frame u, ancount at u+14). The DNS body only has
    to be well-formed as far as the kernel looks: it reads the answer COUNT out
    of the header and nothing deeper, so the records are representative
    filler, not a parseable RRset. Stated plainly rather than implied."""
    opts = opts or []
    assert len(opts) % 4 == 0
    ihl = 5 + len(opts)//4
    dns = [0x12,0x34, 0x81,0x80, 0,1, 0,2, 0,0, 0,0]   # id flags qd=1 an=2 ns=0 ar=0
    dns += [3,ord('d'),ord('n'),ord('s'),6,ord('g'),ord('o'),ord('o'),
            ord('g'),ord('l'),ord('e'),0, 0,1, 0,1]     # question: dns.google A IN
    dns += [0xc0,0x0c, 0,1, 0,1, 0,0,0,60, 0,4, 8,8,8,8]        # answer 1
    dns += [0xc0,0x0c, 0,1, 0,1, 0,0,0,60, 0,4, 8,8,4,4]        # answer 2
    ul = 8 + len(dns)
    udp = [0,53, 0x9c,0x40, ul>>8,ul&0xff, 0,0] + dns   # sport 53 -> dport 40000
    il = 4*ihl + ul
    ip = [0x40|ihl,0,il>>8,il&0xff,0,0,0,0,64,17,0,0]+list(DNS_SRC_IP)+list(GUEST_IP)+opts
    c = ipck(ip); ip[10] = c >> 8; ip[11] = c & 0xff
    f = bytes(GUEST_MAC)+bytes(PINGER_MAC)+b'\x08\x00'+bytes(ip)+bytes(udp)
    if len(f) < 60: f = f + b'\x00'*(60-len(f))
    return f

def icmp_echo_reply_opts(): return icmp_echo_reply(IP_OPTS_NOP4)
def dns_response_opts():    return dns_response(IP_OPTS_NOP4)

def arp_noise():
    """A plain ARP request from a third party — ethertype 0806, addressed to
    nobody in particular. Exactly the background traffic a real LAN carries,
    and the thing a kernel with no ethertype check will happily parse as IPv4."""
    arp = [0,1, 8,0, 6,4, 0,1] + list(PINGER_MAC) + [10,0,2,99] \
          + [0,0,0,0,0,0] + [10,0,2,15]
    f = b'\xff'*6 + bytes(PINGER_MAC) + b'\x08\x06' + bytes(arp)
    if len(f) < 60: f = f + b'\x00'*(60-len(f))
    return f

def arp_then_ping():
    """HAL.5m: NOISE FIRST, then the real request. Returns a LIST — main()
    sends each frame in order, so the ARP always lands in the ring ahead of the
    ICMP echo request. A kernel that classifies frames skips the ARP, advances
    the RX ring, and answers the ping; a kernel that parses whatever arrives
    first (every 5x kernel up to 5l) chews on the ARP, replies with garbage,
    and never sees the ping. Measured on 5j's real ELF before 5m was written."""
    return [arp_noise(), icmp_echo_request()]


def arp_then_udp():
    """HAL.5n: ARP noise ahead of a UDP echo request (the UDP twin of
    arp_then_ping)."""
    return [arp_noise(), udp_request()]

def arp_then_icmpreply6():
    """HAL.5o: ARP noise ahead of an INJECTED IHL=6 ICMP echo reply. Tests
    classification AND IHL generality in one run — the requester must skip the
    ARP, advance the ring, and then read the 24-byte-header reply correctly."""
    return [arp_noise(), icmp_echo_reply_opts()]

def arp_then_dnsreply6():
    """HAL.5p: ARP noise ahead of an INJECTED IHL=6 DNS response."""
    return [arp_noise(), dns_response_opts()]

def saw_guest_frame(f):
    """The ONLY thing an inject mode can honestly assert: a frame came FROM the
    guest, so the kernel ran and transmitted. It does NOT corroborate the RX
    parse -- that is observable only on the guest's serial, which is why the
    5k/5l gates are single-witness and say so."""
    return len(f) >= 12 and bytes(f[6:12]) == GUEST_MAC

MODES={
    "ping":   (icmp_echo_request,  valid_echo_reply, "ICMP echo request", "ECHO REPLY"),
    "udp":    (udp_request,        valid_udp_echo,   "UDP datagram",      "UDP ECHO"),
    # HAL.5i: the same datagram behind a 24-byte IP header (IHL=6). The UDP
    # header starts 4 bytes later, so a kernel that assumes a 20-byte header
    # reads the wrong fields and builds a malformed reply -- which is exactly
    # what makes this mode a DISCRIMINATING gate rather than a second copy of
    # `udp`. valid_udp_echo already parses IHL, so the validator needs no change.
    "udpopt": (udp_request_opts,   valid_udp_echo,   "UDP datagram (IHL=6)", "UDP ECHO"),
    # HAL.5j: the ICMP twin of udpopt. valid_echo_reply already parses IHL, so
    # again only the generator changed.
    "pingopt":(icmp_echo_request_opts, valid_echo_reply, "ICMP echo request (IHL=6)", "ECHO REPLY"),
    # HAL.5k/5l inject modes -- see INJECT below for why they do not break early.
    "icmpreply6":(icmp_echo_reply_opts, saw_guest_frame, "ICMP echo REPLY (IHL=6)", "GUEST FRAME"),
    "dnsreply6": (dns_response_opts,    saw_guest_frame, "DNS response (IHL=6)",    "GUEST FRAME"),
    # HAL.5m: ARP noise ahead of the real request. build() returns a LIST.
    "arpthenping":(arp_then_ping,      valid_echo_reply, "ARP noise + ICMP echo request", "ECHO REPLY"),
    "arpthenudp": (arp_then_udp,       valid_udp_echo,   "ARP noise + UDP datagram",      "UDP ECHO"),
    # 5o/5p: INJECT modes (see INJECT below) with noise ahead of the reply.
    "arpicmprep6":(arp_then_icmpreply6, saw_guest_frame, "ARP noise + ICMP reply (IHL=6)", "GUEST FRAME"),
    "arpdnsrep6": (arp_then_dnsreply6,  saw_guest_frame, "ARP noise + DNS response (IHL=6)", "GUEST FRAME"),
}

# Modes that INJECT a reply rather than solicit one. They must run the whole
# window: breaking on the first valid frame would exit as soon as the guest
# sent its gratuitous ARP, killing QEMU before the injected reply landed.
INJECT = {"icmpreply6", "dnsreply6", "arpicmprep6", "arpdnsrep6"}

def main():
    mode,port,secs=sys.argv[1],int(sys.argv[2]),float(sys.argv[3])
    build,validate,label,name=MODES[mode]
    # Inject modes LISTEN (see serve()); request/response modes connect.
    s=serve(port) if mode in INJECT else connect(port)
    print("PINGER: connected")
    got_reply=False
    # retry the request so at least one lands AFTER the guest enables RX
    # (a request sent before RX-enable is dropped; several spaced sends cover it)
    import threading
    req=build()
    # A builder may return ONE frame or a LIST of frames to send in order (the
    # ordering IS the test for HAL.5m: the noise must land before the request).
    frames = req if isinstance(req, list) else [req]
    def sender():
        prev=0.0
        for t in (0.6,1.4,2.4,3.4):
            time.sleep(t-prev); prev=t
            try:
                for fr in frames: send_frame(s,fr)
                print(f"PINGER: sent {label} (t~{t}s)")
            except OSError: return
    threading.Thread(target=sender,daemon=True).start()
    for f in recv_frames(s, secs):
        print("PINGER RX:", decode(f))
        if validate(f):
            got_reply=True; print(f"PINGER: valid {name.lower()} verified")
            if mode not in INJECT: break      # inject modes run the full window
    print("PINGER:", f"{name} RECEIVED" if got_reply else f"no {name.lower()}")
    sys.exit(0 if got_reply else 1)

if __name__=="__main__": main()
