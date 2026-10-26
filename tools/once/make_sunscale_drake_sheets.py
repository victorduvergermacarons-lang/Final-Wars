"""Builds the Sunscale Drake's sprite sheets from art/Crimson_dragon_animated.aseprite
(2026-10-20). The file is 128 x 128, 56 frames at 100 ms, tags Standing 0-7, kick 8-15,
Fire/dash 16-31, Dying 32-47, Moving 48-55, and two layers: SW (facing down-left)
and NW (facing up-left). Right-facing rows are those layers mirrored.

The shadow is drawn into the art and the drake hovers above it, so each layer is
shifted into a 160 x 128 frame to put its shadow (the average over the Standing
frames) at FEET; mirrored rows then stand on the same point.
Rows: SW (the SW layer mirrored), SE (the SW layer as drawn), NW, NE (mirrored NW). no_shadow/ drops the shadow
pixels (for the hit flash).
Usage: python3 make_sunscale_drake_sheets.py ART.aseprite OUT_DIR"""
import os, sys
from PIL import Image, ImageOps
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aseprite_export as A

FRAME = (160, 128)
FEET = (80, 95)
ANIMS = {
    "idle": list(range(0, 8)),        # Standing
    "run": list(range(48, 56)),       # Moving
    "rake": list(range(8, 16)),       # kick: talons swing through frame 13 (index 5)
    "breath": list(range(16, 24)),    # rear back 16-19, head forward with flames 20-23
    "dive": [24] * 10 + list(range(24, 32)),  # poised for the 1 s lane telegraph, then the dive
    "death": list(range(32, 48)),     # Dying
}
# The "SW" layer's pictures read as facing SE in game (playtest, 2026-10-20), so SE
# uses it as drawn and SW mirrors it.
ROWS = [("sw", "SW", True), ("se", "SW", False), ("nw", "NW", False), ("ne", "NW", True)]


def is_shadow(p):
    return 0 < p[3] < 200 and p[0] < 24 and p[1] < 24 and p[2] < 24


def shadow_center(doc, layer):
    xs = ys = n = 0
    for f in range(0, 8):
        im = A.render(doc, f, [layer])
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                if is_shadow(px[x, y]):
                    xs += x; ys += y; n += 1
    return xs / n, ys / n


def no_shadow(im):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if is_shadow(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    return im


def main(src, out):
    doc = A.parse(src)
    offsets = {}
    for layer in ("SW", "NW"):
        cx, cy = shadow_center(doc, layer)
        offsets[layer] = (round(FEET[0] - cx), round(FEET[1] - cy))
        print(layer, "shadow at", round(cx, 1), round(cy, 1), "-> offset", offsets[layer])
    os.makedirs(os.path.join(out, "no_shadow"), exist_ok=True)
    for name, frames in ANIMS.items():
        sheet = Image.new("RGBA", (FRAME[0] * len(frames), FRAME[1] * len(ROWS)))
        flat = sheet.copy()
        for r, (_, layer, mirror) in enumerate(ROWS):
            for c, f in enumerate(frames):
                cell = Image.new("RGBA", FRAME)
                cell.alpha_composite(A.render(doc, f, [layer]), offsets[layer])
                if mirror:
                    cell = ImageOps.mirror(cell)
                sheet.paste(cell, (c * FRAME[0], r * FRAME[1]))
                flat.paste(no_shadow(cell), (c * FRAME[0], r * FRAME[1]))
        sheet.save(os.path.join(out, "sunscale_drake-%s.png" % name))
        flat.save(os.path.join(out, "no_shadow", "sunscale_drake-%s.png" % name))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
