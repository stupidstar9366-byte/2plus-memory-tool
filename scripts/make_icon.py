"""Build the project's original 2+ pixel icon using only the Python stdlib.

No game assets, fonts, downloaded images or other artwork are used.
SPDX-License-Identifier: MIT
"""
from pathlib import Path
import struct

GLYPHS = (("11111", "00001", "00001", "11111", "10000", "10000", "11111"),
          ("00100", "00100", "00100", "11111", "00100", "00100", "00100"))


def dib(size):
    pixels = bytearray()
    for y in reversed(range(size)):
        for x in range(size):
            u, v = x * 32 // size, y * 32 // size
            rgb = (18, 25, 32)
            if 2 <= u < 30 and 2 <= v < 30:
                rgb = (21, 131, 112)
            for origin, glyph in zip((5, 17), GLYPHS):
                col, row = (u - origin) // 2, (v - 9) // 2
                if 0 <= col < 5 and 0 <= row < 7 and glyph[row][col] == "1":
                    rgb = (245, 250, 248)
            pixels.extend((rgb[2], rgb[1], rgb[0], 255))
    mask = bytes(((size + 31) // 32) * 4 * size)
    header = struct.pack('<IiiHHIIiiII', 40, size, size * 2, 1, 32, 0, len(pixels), 0, 0, 0, 0)
    return header + pixels + mask


def main():
    sizes = (16, 32, 48, 64)
    bodies = [dib(size) for size in sizes]
    out = bytearray(struct.pack('<HHH', 0, 1, len(sizes)))
    offset = 6 + len(sizes) * 16
    for size, body in zip(sizes, bodies):
        out.extend(struct.pack('<BBBBHHII', size, size, 0, 0, 1, 32, len(body), offset))
        offset += len(body)
    out.extend(b''.join(bodies))
    target = Path(__file__).resolve().parent.parent / 'build' / 'app.ico'
    target.parent.mkdir(exist_ok=True)
    target.write_bytes(out)
    print('Built original 2+ icon from scripts/make_icon.py')


if __name__ == '__main__':
    main()
