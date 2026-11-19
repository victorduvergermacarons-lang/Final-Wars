"""Boar and stag sprite sheets from the Critters pack (art/critters.zip, 2026-11-19).

The pack draws one strip per facing and animation (one row, frame width = strip
width / frame count; checked: every strip divides evenly). The game wants one sheet
per animation with a row per facing (SW, SE, NW, NE, like the wolf), so this:
  1. copies the strips the game uses into assets/creatures/<creature>/strips/
     (boar/boar_{DIR}_{anim}_strip.png, stag/critter_stag_{DIR}_{anim}.png);
  2. lays each facing's frames into cells of one size, bottom-aligned so the
     feet sit on one point in every row: boar cells 41 x 30, feet (20.5, 28)
     (frame height - 2: the NE/NW strips are 30 high, SE/SW 25, so those get 5 px
     on top; the NW strips are 40 wide, centred in 41); stag cells 32 x 41, feet
     (16, 39);
  3. writes <creature>-<anim>.png, plus no_shadow/ copies without the
     semi-transparent shadow pixels (for the hit flash, like the wolf).
No mirroring: the pack draws all four facings.

Usage (from the project root): python3 tools/once/make_critter_sheets.py art/critters.zip
"""
import io
import os
import sys
import zipfile

from PIL import Image

ROWS = ["SW", "SE", "NW", "NE"]
CRITTERS = {
    "boar": {"path": "critters/boar/boar_{d}_{a}_strip.png", "anims": {"idle": 7, "run": 4}, "cell": (41, 30)},
    "stag": {"path": "critters/stag/critter_stag_{d}_{a}.png", "anims": {"idle": 24, "walk": 11, "run": 10},
             "cell": (32, 41)},
}


def no_shadow(im):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] < 255:
                px[x, y] = (0, 0, 0, 0)
    return im


def main(zip_path):
    z = zipfile.ZipFile(zip_path)
    for name, spec in CRITTERS.items():
        out = os.path.join("assets", "creatures", name)
        os.makedirs(os.path.join(out, "strips"), exist_ok=True)
        os.makedirs(os.path.join(out, "no_shadow"), exist_ok=True)
        cw, ch = spec["cell"]
        for anim, count in spec["anims"].items():
            sheet = Image.new("RGBA", (cw * count, ch * len(ROWS)), (0, 0, 0, 0))
            for r, d in enumerate(ROWS):
                member = spec["path"].format(d=d, a=anim)
                data = z.read(member)
                with open(os.path.join(out, "strips", os.path.basename(member)), "wb") as f:
                    f.write(data)
                strip = Image.open(io.BytesIO(data)).convert("RGBA")
                w, h = strip.size
                if w % count:
                    raise SystemExit(f"{member}: {w} px wide doesn't divide into {count} frames")
                fw = w // count
                ox, oy = (cw - fw) // 2, ch - h
                for c in range(count):
                    frame = strip.crop((c * fw, 0, (c + 1) * fw, h))
                    sheet.paste(frame, (c * cw + ox, r * ch + oy))
                print(f"{member}: {w}x{h}, {count} frames of {fw}x{h}")
            sheet.save(os.path.join(out, f"{name}-{anim}.png"))
            no_shadow(sheet).save(os.path.join(out, "no_shadow", f"{name}-{anim}.png"))


if __name__ == "__main__":
    main(sys.argv[1])
