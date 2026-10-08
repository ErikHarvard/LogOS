#!/usr/bin/env python3
"""wm_shot.py - convert a raw frame from the headless WM into a PNG.

theourgia_wm_sim.la writes each requested frame exactly as it would hand it to
present(): H rows of PITCH bytes, each pixel 4 bytes B, G, R, 0 (XRGB8888,
little-endian). This turns one into an RGB PNG using only the standard library.

Usage: wm_shot.py FRAME.bin W H PITCH OUT.png
"""
import struct
import sys
import zlib


def png(width, height, rgb_rows):
    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    raw = b"".join(b"\0" + row for row in rgb_rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def main(argv):
    if len(argv) != 6:
        raise SystemExit(__doc__)
    frame = open(argv[1], "rb").read()
    w, h, pitch = int(argv[2]), int(argv[3]), int(argv[4])
    if len(frame) < h * pitch:
        raise SystemExit(f"wm_shot: frame is {len(frame)} bytes, expected {h * pitch}")
    rows = []
    for y in range(h):
        line = frame[y * pitch: y * pitch + 4 * w]
        rgb = bytearray(3 * w)
        rgb[0::3], rgb[1::3], rgb[2::3] = line[2::4], line[1::4], line[0::4]
        rows.append(bytes(rgb))
    with open(argv[5], "wb") as f:
        f.write(png(w, h, rows))


if __name__ == "__main__":
    main(sys.argv)
