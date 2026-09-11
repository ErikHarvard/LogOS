#!/usr/bin/env python3
# Generate the HAL.5d UDP/DNS query frame as a space-separated decimal string,
# with the IPv4 header checksum computed (UDP checksum left 0 = disabled, legal
# for IPv4). Emits FRAMEDATA and the RX verification offsets for nic5d.la.
#
# Layout: eth(14) + ip(20) + udp(8) + dns(12 + qname + 4)
# Query: A record for QNAME (default dns.google), sent to 10.0.2.3:53.

QNAME_STR = "dns.google"
SRC_MAC = [0x52, 0x54, 0x00, 0x12, 0x34, 0x56]      # our MAC (from 5b/5c)
DST_MAC = [0x52, 0x55, 0x0a, 0x00, 0x02, 0x03]      # SLIRP MAC for 10.0.2.3
SRC_IP  = [10, 0, 2, 15]
DST_IP  = [10, 0, 2, 3]
SRC_PORT = 5000
DST_PORT = 53

def ip_checksum(hdr):
    s = 0
    for i in range(0, len(hdr), 2):
        s += (hdr[i] << 8) + hdr[i+1]
    while s >> 16:
        s = (s & 0xffff) + (s >> 16)
    return (~s) & 0xffff

def qname_bytes(name):
    out = []
    for label in name.split('.'):
        out.append(len(label))
        out.extend(ord(c) for c in label)
    out.append(0)
    return out

# --- DNS message ---
qn = qname_bytes(QNAME_STR)
dns = ([0x12, 0x34,        # id
        0x01, 0x00,        # flags: RD
        0x00, 0x01,        # qdcount
        0x00, 0x00,        # ancount
        0x00, 0x00,        # nscount
        0x00, 0x00]        # arcount
       + qn
       + [0x00, 0x01,      # qtype A
          0x00, 0x01])     # qclass IN

# --- UDP ---
udp_len = 8 + len(dns)
udp = [SRC_PORT >> 8, SRC_PORT & 0xff,
       DST_PORT >> 8, DST_PORT & 0xff,
       udp_len >> 8, udp_len & 0xff,
       0x00, 0x00]         # checksum 0 = disabled (IPv4 legal)

# --- IP ---
ip_total = 20 + udp_len
ip = ([0x45, 0x00,
       ip_total >> 8, ip_total & 0xff,
       0x00, 0x00,         # id
       0x00, 0x00,         # flags/frag
       0x40,               # ttl 64
       0x11,               # proto 17 = UDP
       0x00, 0x00]         # checksum placeholder
      + SRC_IP + DST_IP)
csum = ip_checksum(ip)
ip[10] = csum >> 8
ip[11] = csum & 0xff

frame = DST_MAC + SRC_MAC + [0x08, 0x00] + ip + udp + dns

print("# QNAME =", QNAME_STR, " frame len =", len(frame))
print('glyph FRAMEDATA = "' + " ".join(str(b) for b in frame) + '"')
print()
# RX offsets: RB(off) reads frame byte (off-4). Compute the peek offsets.
def rb(frame_byte):  # returns the RB() argument for a given frame byte index
    return frame_byte + 4
eth_type = 12
ip_proto = 14 + 9
udp_sport = 14 + 20 + 0
dns_flags = 14 + 20 + 8 + 2
dns_ancount = 14 + 20 + 8 + 6
print(f"# RB(ethertype hi/lo) = RB({rb(eth_type)}) RB({rb(eth_type+1)})  -> 08 00")
print(f"# RB(ip proto)        = RB({rb(ip_proto)})                -> 11 (UDP)")
print(f"# RB(udp sport hi/lo) = RB({rb(udp_sport)}) RB({rb(udp_sport+1)})  -> 00 35 (reply from :53)")
print(f"# RB(dns flags hi)    = RB({rb(dns_flags)})                -> 0x81/0x85 (QR=1)")
print(f"# RB(dns ancount hi/lo)= RB({rb(dns_ancount)}) RB({rb(dns_ancount+1)}) -> >= 00 01")
