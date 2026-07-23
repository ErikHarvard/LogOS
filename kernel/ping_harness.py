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

def icmp_echo_request():
    icmp=[8,0,0,0, 0,1,0,1]                 # type8 code0 cksum id1 seq1
    c=ipck(icmp); icmp[2]=c>>8; icmp[3]=c&0xff
    ln=20+len(icmp)
    ip=[0x45,0,ln>>8,ln&0xff,0,0,0,0,64,1,0,0]+list(PINGER_IP)+list(GUEST_IP)
    c=ipck(ip); ip[10]=c>>8; ip[11]=c&0xff
    f=bytes(GUEST_MAC)+bytes(PINGER_MAC)+b'\x08\x00'+bytes(ip)+bytes(icmp)
    if len(f)<60: f=f+b'\x00'*(60-len(f))   # pad to Ethernet min so the NIC keeps it
    return f

def udp_request():
    p=UDP_PAYLOAD; ul=8+len(p)
    udp=[SENDER_UDP_PORT>>8,SENDER_UDP_PORT&0xff, OUR_UDP_PORT>>8,OUR_UDP_PORT&0xff,
         ul>>8,ul&0xff, 0,0]+list(p)              # udp checksum 0 = disabled (IPv4 legal)
    il=20+ul
    ip=[0x45,0,il>>8,il&0xff,0,0,0,0,64,17,0,0]+list(PINGER_IP)+list(GUEST_IP)
    c=ipck(ip); ip[10]=c>>8; ip[11]=c&0xff
    f=bytes(GUEST_MAC)+bytes(PINGER_MAC)+b'\x08\x00'+bytes(ip)+bytes(udp)
    if len(f)<60: f=f+b'\x00'*(60-len(f))
    return f

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
        proto=f[23]; t="?"
        if proto==1 and len(f)>=35: t=f"icmp_type={f[34]}"
        elif proto==17 and len(f)>=38: t=f"udp {(f[34]<<8)|f[35]}->{(f[36]<<8)|f[37]}"
        return f"IPv4 proto={proto} {t}"
    return f"et={et:04x}"

MODES={
    "ping": (icmp_echo_request, valid_echo_reply, "ICMP echo request", "ECHO REPLY"),
    "udp":  (udp_request,        valid_udp_echo,   "UDP datagram",      "UDP ECHO"),
}

def main():
    mode,port,secs=sys.argv[1],int(sys.argv[2]),float(sys.argv[3])
    build,validate,label,name=MODES[mode]
    s=connect(port); print("PINGER: connected")
    got_reply=False
    # retry the request so at least one lands AFTER the guest enables RX
    # (a request sent before RX-enable is dropped; several spaced sends cover it)
    import threading
    req=build()
    def sender():
        prev=0.0
        for t in (0.6,1.4,2.4,3.4):
            time.sleep(t-prev); prev=t
            try: send_frame(s,req); print(f"PINGER: sent {label} (t~{t}s)")
            except OSError: return
    threading.Thread(target=sender,daemon=True).start()
    for f in recv_frames(s, secs):
        print("PINGER RX:", decode(f))
        if validate(f): got_reply=True; print(f"PINGER: valid {name.lower()} verified"); break
    print("PINGER:", f"{name} RECEIVED" if got_reply else f"no {name.lower()}")
    sys.exit(0 if got_reply else 1)

if __name__=="__main__": main()
