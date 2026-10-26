"""Builds the Salamander Hound's sprite sheets from art/Red-Salamander-Hound.aseprite
(2026-10-20). The file has one 16-frame "Loop" (idle: smoke puffs, a crouch and a
rise) drawn facing SE and SW, 48 x 48 px. Every animation the game needs is cut
from those frames (see ANIMS); NE and NW reuse SE and SW until back views exist.
Rows: SW, SE, NW, NE (like the wolf). no_shadow/ holds the same sheets without the
shadow pixels (for the hit flash).
Usage: python3 make_salamander_hound_sheets.py ART.aseprite OUT_DIR"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aseprite_export as A

SIZE = 48
SHADOW = (28, 13, 24)
# animation -> frames of the Loop (the only animation in the file)
ANIMS = {
    "idle": list(range(16)),          # the authored loop
    "run": [0, 1, 2, 3],              # placeholder: no run cycle drawn yet
    "bite": [3, 4, 5, 6, 7, 8, 9],    # lunge down; jaws on frame 6 (0.3 s at 20 fps)
    "pounce": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],  # crouch 0.6 s (frame 6 at 10 fps), then spring up
    "death": [4, 5, 6, 7, 8, 9, 10],  # placeholder: sinks low and stays down
}
ROWS = [("sw", "SW"), ("se", "SE"), ("nw", "SW"), ("ne", "SE")]  # NW/NE: placeholders


def no_shadow(im):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 255 and (r, g, b) == SHADOW:
                px[x, y] = (0, 0, 0, 0)
    return im


def main(src, out):
    doc = A.parse(src)
    os.makedirs(os.path.join(out, "no_shadow"), exist_ok=True)
    for name, frames in ANIMS.items():
        sheet = Image.new("RGBA", (SIZE * len(frames), SIZE * len(ROWS)))
        flat = sheet.copy()
        for r, (_, layer) in enumerate(ROWS):
            for c, f in enumerate(frames):
                im = A.render(doc, f, [layer])
                sheet.paste(im, (c * SIZE, r * SIZE))
                flat.paste(no_shadow(im), (c * SIZE, r * SIZE))
        sheet.save(os.path.join(out, "salamander_hound-%s.png" % name))
        flat.save(os.path.join(out, "no_shadow", "salamander_hound-%s.png" % name))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
