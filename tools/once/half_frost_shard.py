"""One-off (2026-11-28, water physics phase 4): Frost Shard's sprite (FX-13-4) at 50%
(user request: "Scale the existing shard by 50% both vertically and horizontally
first"), and its 32 pre-rotated cells (RotSprite, as make_effect_sheets.py).

Each 2 x 2 block becomes one pixel of the sprite's own colours: blocks with at least
two opaque pixels stay opaque; a block touching the transparent outside keeps its
darkest colour (the outline), others their most common colour.

    python3 tools/once/half_frost_shard.py
"""
import sys
from collections import Counter
from PIL import Image

sys.path.insert(0, "tools/once")
from make_effect_sheets import rotsprite_sheet  # noqa: E402

SRC = "assets/effects/frost_shard.png"
OUT = "assets/effects/frost_shard_half.png"
OUT_ROT = "assets/effects/frost_shard_half_rot.png"


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def main():
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    half = Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))
    for y in range(h // 2):
        for x in range(w // 2):
            block = [im.getpixel((2 * x + dx, 2 * y + dy)) for dy in (0, 1) for dx in (0, 1)]
            opaque = [c for c in block if c[3] >= 128]
            if len(opaque) < 2:
                continue
            if len(opaque) < 4:
                pick = min(opaque, key=luma)
            else:
                pick = Counter(opaque).most_common(1)[0][0]
            half.putpixel((x, y), pick)
    half.save(OUT)
    rot, cell = rotsprite_sheet(half, (w / 4.0, h / 4.0), 32)
    rot.save(OUT_ROT)
    print(f"wrote {OUT} ({w // 2}x{h // 2}) and {OUT_ROT} (32 x {cell}px)")


if __name__ == "__main__":
    main()
