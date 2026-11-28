"""Body anchors of a hero's animations, per facing and per frame (2026-11-25): where
the right hand, left hand, feet, head and body centre are, saved to a JSON file the
game loads (content/heroes/pl01_anchors.json, CreatureArtDef.anchors_path). The game
never reads marker images; this tool turns them into numbers.

Points are in art pixels from the feet, x to the right, y up (the hand points'
convention), at the centre of the marked pixel. Cells are 48x48 with the feet on
(24, 38), as the game draws them. Facings: sw se nw ne s e n w (the sheets' rows).

Run from the project root:
  python3 tools/hand_anchors.py guess water_whip
      A best guess at the right hand on every frame (the furthest opaque pixel
      toward the facing, in the arm's band; south and north, where the body hides
      the hand, between their two diagonals). Only fills frames not marked by hand.
  python3 tools/hand_anchors.py aseprite art/heroes/PL-01/water_whip_hand_points.aseprite [water_whip] [right_hand]
      Reads one #FF00FF pixel per frame from the "Hand <FACING> (#FF00FF)" layers (a
      tag per facing; any layer with that magenta works), as written by
      tools/once/make_hand_point_aseprite.py. Marked frames replace the guesses.
  python3 tools/hand_anchors.py png SHEET.png water_whip [right_hand]
      The same from a PNG laid out like the game's sheet (a row per facing, 48 px
      cells) with one magenta pixel per frame.
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "once"))

OUT = os.environ.get("ANCHORS_OUT", "content/heroes/pl01_anchors.json")
SHEETS = "assets/heroes/pl01"
ROWS = ["sw", "se", "nw", "ne", "s", "e", "n", "w"]
CELL = 48
FEET = (24, 38)
MAGENTA = (255, 0, 255)
# Screen directions of the facings (x right, y down).
FACING = {"e": (1, 0), "w": (-1, 0), "se": (1, 0.5), "sw": (-1, 0.5), "ne": (1, -0.5), "nw": (-1, -0.5)}
# The arm's band, art px above the feet: raised in the lash, by the hips otherwise
# (higher would find the head).
BANDS = {"water_whip": (8, 30)}
BAND = (6, 20)
# Anchors that don't follow the frame (art px from the feet), until marked.
FIXED = {"feet": [0.0, 0.0], "head": [0.0, 31.0], "body_centre": [0.0, 17.0]}


def load():
    if os.path.exists(OUT):
        with open(OUT) as f:
            return json.load(f)
    return {"version": 1, "feet_px": list(FEET), "marked": {}, "anchors": {}}


def save(doc):
    for name, at in FIXED.items():
        doc["anchors"].setdefault(name, {"default": at})
    doc["anchors"].setdefault("left_hand", {})
    with open(OUT, "w") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
        f.write("\n")
    print("wrote", OUT)


def to_anchor(px, py):
    return [round(px + 0.5 - FEET[0], 2), round(FEET[1] - (py + 0.5), 2)]


def guess_cell(img, facing, band=BAND):
    dx, dy = FACING[facing]
    best, best_s = None, None
    px = img.load()
    for y in range(FEET[1] - band[1], FEET[1] - band[0]):
        for x in range(CELL):
            if px[x, y][3] < 128:
                continue
            s = x * dx + y * dy
            if best_s is None or s > best_s:
                best, best_s = (x, y), s
    return to_anchor(*best) if best else [0.0, 17.0]


def cells(sheet):
    per_row = sheet.width // CELL
    for r in range(sheet.height // CELL):
        yield ROWS[r], [sheet.crop((f * CELL, r * CELL, f * CELL + CELL, r * CELL + CELL)) for f in range(per_row)]


def put(doc, anchor, anim, facing, frame, point, marked):
    rows = doc["anchors"].setdefault(anchor, {}).setdefault(anim, {})
    lst = rows.setdefault(facing, [])
    while len(lst) <= frame:
        lst.append(None)
    key = f"{anchor}/{anim}/{facing}/{frame}"
    if marked:
        doc["marked"][key] = True
    elif doc["marked"].get(key):
        return # a hand-marked point wins over a guess
    lst[frame] = point


def guess(anim):
    doc = load()
    sheet = Image.open(f"{SHEETS}/{anim}.png").convert("RGBA")
    rows = dict(cells(sheet))
    band = BANDS.get(anim, BAND)
    for facing, frames in rows.items():
        for i, img in enumerate(frames):
            if facing in FACING:
                p = guess_cell(img, facing, band)
            else: # s / n: the hand is hidden; between the two diagonals
                a, b = ("sw", "se") if facing == "s" else ("nw", "ne")
                pa, pb = guess_cell(rows[a][i], a, band), guess_cell(rows[b][i], b, band)
                p = [round((pa[0] + pb[0]) / 2, 2), round((pa[1] + pb[1]) / 2, 2)]
            put(doc, "right_hand", anim, facing, i, p, False)
    save(doc)


def magenta_in(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0 and (r, g, b) == MAGENTA:
                return x, y
    return None


def from_aseprite(path, anim, anchor):
    import aseprite_export as ase
    doc = load()
    ase_doc = ase.parse(path)
    hand_layers = [l["name"] for l in ase_doc["layers"] if l["name"].startswith("Hand ")]
    found = 0
    for tag in ase_doc["tags"]:
        facing = tag["name"].lower()
        if facing not in ROWS:
            continue
        for i, f in enumerate(range(tag["from"], tag["to"] + 1)):
            at = magenta_in(ase.render(ase_doc, f, only_layers=hand_layers))
            if at:
                put(doc, anchor, anim, facing, i, to_anchor(*at), True)
                found += 1
    print(f"{found} marked points read")
    save(doc)


def from_png(path, anim, anchor):
    doc = load()
    found = 0
    for facing, frames in cells(Image.open(path).convert("RGBA")):
        for i, img in enumerate(frames):
            at = magenta_in(img)
            if at:
                put(doc, anchor, anim, facing, i, to_anchor(*at), True)
                found += 1
    print(f"{found} marked points read")
    save(doc)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "guess":
        for a in sys.argv[2:]:
            guess(a)
    elif cmd == "aseprite":
        from_aseprite(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "water_whip",
                sys.argv[4] if len(sys.argv) > 4 else "right_hand")
    elif cmd == "png":
        from_png(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "right_hand")
    else:
        print(__doc__)
        sys.exit(1)
