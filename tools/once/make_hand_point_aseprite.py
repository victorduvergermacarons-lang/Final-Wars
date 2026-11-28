"""Writes an Aseprite file of a hero animation for marking the hand by hand
(2026-11-25, user request): assets/heroes/pl01/<anim>.png's eight facings as one
timeline (9 frames each, a tag per facing), the art on the bottom layer, and above it
one empty layer per facing named "Hand <FACING> (#FF00FF)" where the user paints one
magenta pixel per frame on the hand. The sprite's palette is that magenta. Frames are
48x48 cells with the feet on (24, 38), exactly as the game draws them, so a painted
pixel is a hand point in the game's own art coordinates.
No Aseprite needed (writes the file format directly). Run from the project root:
python3 tools/once/make_hand_point_aseprite.py [anim] [out.aseprite]
"""
import struct
import sys
import zlib

from PIL import Image

ROWS = ["sw", "se", "nw", "ne", "s", "e", "n", "w"] # the sheet's rows
NAMES = {"sw": "SW", "se": "SE", "nw": "NW", "ne": "NE", "s": "S", "e": "E", "n": "N", "w": "W"}
CELL = 48
MAGENTA = (255, 0, 255, 255)


def string(s):
    b = s.encode("utf-8")
    return struct.pack("<H", len(b)) + b


def chunk(ctype, data):
    return struct.pack("<IH", 6 + len(data), ctype) + data


def layer_chunk(name, visible=True):
    flags = (1 if visible else 0) | 2 # visible, editable
    return chunk(0x2004, struct.pack("<HHHHHHB3x", flags, 0, 0, 0, 0, 0, 255) + string(name))


def cel_chunk(layer, img):
    w, h = img.size
    data = zlib.compress(img.tobytes())
    return chunk(0x2005, struct.pack("<HhhBHh5x", layer, 0, 0, 255, 2, 0) + struct.pack("<HH", w, h) + data)


def palette_chunk(colors):
    body = struct.pack("<III8x", len(colors), 0, len(colors) - 1)
    for c in colors:
        body += struct.pack("<HBBBB", 0, *c)
    return chunk(0x2019, body)


def tags_chunk(tags):
    body = struct.pack("<H8x", len(tags))
    for name, a, b in tags:
        body += struct.pack("<HHBH6x3Bx", a, b, 0, 0, 255, 0, 255) + string(name)
    return chunk(0x2018, body)


def main():
    anim = sys.argv[1] if len(sys.argv) > 1 else "water_whip"
    out = sys.argv[2] if len(sys.argv) > 2 else f"art/heroes/PL-01/{anim}_hand_points.aseprite"
    sheet = Image.open(f"assets/heroes/pl01/{anim}.png").convert("RGBA")
    per_row = sheet.width // CELL
    rows = sheet.height // CELL
    frames = []
    tags = []
    for r in range(rows):
        tags.append((NAMES[ROWS[r]], len(frames), len(frames) + per_row - 1))
        for f in range(per_row):
            frames.append(sheet.crop((f * CELL, r * CELL, f * CELL + CELL, r * CELL + CELL)))
    duration = 50 # ms: 20 fps, as the game plays water_whip
    body = b""
    for i, img in enumerate(frames):
        chunks = []
        if i == 0:
            chunks.append(palette_chunk([MAGENTA]))
            chunks.append(layer_chunk(f"{anim}"))
            for r in range(rows):
                chunks.append(layer_chunk(f"Hand {NAMES[ROWS[r]]} (#FF00FF)"))
            chunks.append(tags_chunk(tags))
        chunks.append(cel_chunk(0, img))
        data = b"".join(chunks)
        body += struct.pack("<IHHH2xI", 16 + len(data), 0xF1FA, min(len(chunks), 0xFFFF), duration, len(chunks)) + data
    header = struct.pack("<IHHHHHIHII", 128 + len(body), 0xA5E0, len(frames), CELL, CELL, 32, 1, duration, 0, 0)
    header += struct.pack("<B3xHBBhhHH", 0, 1, 1, 1, 0, 0, 16, 16)
    header += b"\0" * (128 - len(header))
    with open(out, "wb") as f:
        f.write(header + body)
    print(f"wrote {out}: {len(frames)} frames ({rows} facings x {per_row}), {rows + 1} layers")


if __name__ == "__main__":
    main()
