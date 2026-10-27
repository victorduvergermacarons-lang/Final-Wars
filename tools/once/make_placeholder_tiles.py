# One-off (kept for the record): placeholder tiles for the Act I zones, made by
# recolouring existing iso_basic tiles (no new art exists yet). Writes
# assets/tiles/iso_basic/tile_115.png ... and their catalog entries, terrains,
# prop group and animation in tileset.json. Safe to re-run: it replaces tiles
# from FIRST on. Usage: python3 tools/once/make_placeholder_tiles.py <project>
import colorsys, json, sys
from PIL import Image

root = sys.argv[1]
folder = root + "/assets/tiles/iso_basic"
FIRST = 115


def recolour(src, hue=None, sat=1.0, val=1.0, hue_shift=0.0, sat_add=0.0):
    """HSV transform of every opaque pixel: hue set (0..1) or shifted, saturation
    and value scaled."""
    im = Image.open(f"{folder}/tile_{src:03d}.png").convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h = hue if hue is not None else (h + hue_shift) % 1.0
            s = min(1.0, max(0.0, s * sat + sat_add))
            v = min(1.0, v * val)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return im


# (source tile, transform, catalog fields)
SPECS = [
    # Grey, polluted river water (Millbrook upstream, the Deepcut stream).
    (86, dict(sat=0.28, val=0.9), {"name": "Grey water, streaks", "category": "water", "walkable": False, "drop": 4}),
    (87, dict(sat=0.28, val=0.9), {"name": "Grey water, ripple", "category": "water", "walkable": False, "drop": 4}),
    (88, dict(sat=0.28, val=0.9), {"name": "Grey water, swell", "category": "water", "walkable": False, "drop": 4}),
    (89, dict(sat=0.28, val=0.9), {"name": "Grey water, rings", "category": "water", "walkable": False, "drop": 4}),
    # Red canyon ground and rock (Deepcut, the road).
    (11, dict(hue=0.025, sat=1.5, sat_add=0.15, val=0.95), {"name": "Red rocky ground 1", "category": "ground"}),
    (12, dict(hue=0.025, sat=1.5, sat_add=0.15, val=0.95), {"name": "Red rocky ground 2", "category": "ground"}),
    (13, dict(hue=0.025, sat=1.5, sat_add=0.15, val=0.95), {"name": "Red rocky ground 3", "category": "ground"}),
    (0, dict(hue=0.035, sat=1.4, sat_add=0.1), {"name": "Red earth 1", "category": "ground"}),
    (2, dict(hue=0.035, sat=1.4, sat_add=0.1), {"name": "Red earth 2", "category": "ground"}),
    (5, dict(hue=0.035, sat=1.4, sat_add=0.1), {"name": "Red earth 3", "category": "ground"}),
    (63, dict(hue=0.02, sat=1.0, sat_add=0.45, val=0.9), {"name": "Red stone", "category": "rock"}),
    # Cold steppe grass (Windsteppe).
    (22, dict(hue=0.2, sat=0.5, val=0.9), {"name": "Steppe grass 1", "category": "ground"}),
    (23, dict(hue=0.2, sat=0.5, val=0.9), {"name": "Steppe grass 2", "category": "ground"}),
    (24, dict(hue=0.2, sat=0.5, val=0.9), {"name": "Steppe grass 3", "category": "ground"}),
    (37, dict(hue=0.13, sat=0.55, val=1.05), {"name": "Dry steppe 1", "category": "ground"}),
    (38, dict(hue=0.13, sat=0.55, val=1.05), {"name": "Dry steppe 2", "category": "ground"}),
    # Roofs for houses and halls (not walkable: terrains say so).
    (25, dict(hue=0.11, sat=0.9, val=1.2), {"name": "Thatch roof", "category": "ground"}),
    (63, dict(hue=0.6, sat=0.6, sat_add=0.1, val=0.75), {"name": "Slate roof", "category": "rock"}),
    (61, dict(hue=0.01, sat=1.0, sat_add=0.5, val=0.85), {"name": "Red tile roof", "category": "rock"}),
    # Red boulders (props).
    (55, dict(hue=0.025, sat=1.4, sat_add=0.15), {"name": "Red rock pillar", "category": "rock", "kind": "prop", "walkable": False, "blocks_sight": True}),
    (57, dict(hue=0.025, sat=1.4, sat_add=0.15), {"name": "Red boulder", "category": "rock", "kind": "prop", "walkable": False, "blocks_sight": True}),
    (54, dict(hue=0.025, sat=1.4, sat_add=0.15), {"name": "Red rock", "category": "rock", "kind": "prop", "walkable": False, "blocks_sight": False}),
    # The Silent Shaft (milestone 4): dark mine rock, rock turned grey, Sunstone
    # seams glowing gold (untouched) and grey (mined out).
    (11, dict(hue=0.07, sat=0.35, val=0.62), {"name": "Mine floor 1", "category": "ground"}),
    (12, dict(hue=0.07, sat=0.35, val=0.62), {"name": "Mine floor 2", "category": "ground"}),
    (13, dict(hue=0.07, sat=0.35, val=0.62), {"name": "Mine floor 3", "category": "ground"}),
    (63, dict(hue=0.07, sat=0.3, val=0.5), {"name": "Mine stone", "category": "rock"}),
    (11, dict(hue=0.6, sat=0.08, val=0.6), {"name": "Grey rock 1", "category": "ground"}),
    (12, dict(hue=0.6, sat=0.08, val=0.6), {"name": "Grey rock 2", "category": "ground"}),
    (114, dict(hue=0.12, sat=1.0, sat_add=0.35, val=1.2), {"name": "Sunstone seam", "category": "rock", "walkable": False}),
    (114, dict(sat=0.06, val=0.6), {"name": "Spent seam", "category": "rock", "walkable": False}),
    (54, dict(hue=0.12, sat=1.0, sat_add=0.45, val=1.25), {"name": "Sunstone cluster", "category": "rock", "kind": "prop", "walkable": False, "blocks_sight": False}),
    (54, dict(sat=0.05, val=0.7), {"name": "Grey cluster", "category": "rock", "kind": "prop", "walkable": False, "blocks_sight": False}),
]

cat = json.load(open(folder + "/tileset.json"))
cat["tiles"] = [t for t in cat["tiles"] if t["id"] < FIRST]
ids = {}
for i, (src, tf, fields) in enumerate(SPECS):
    tid = FIRST + i
    recolour(src, **tf).save(f"{folder}/tile_{tid:03d}.png")
    entry = {"id": tid, "name": fields["name"] + " (placeholder: recolour of tile %d)" % src,
             "category": fields["category"], "kind": fields.get("kind", "block"),
             "walkable": fields.get("walkable", True), "blocks_sight": fields.get("blocks_sight", False)}
    if "drop" in fields:
        entry["drop"] = fields["drop"]
    cat["tiles"].append(entry)
    ids[fields["name"]] = tid

t = lambda *names: [ids[n] for n in names]
cat["animations"]["grey_ripple"] = {"frames": t("Grey water, streaks", "Grey water, ripple", "Grey water, swell", "Grey water, rings"), "fps": 6}
cat["terrains"].update({
    "grey_water": {"tiles": t("Grey water, streaks", "Grey water, ripple", "Grey water, swell", "Grey water, rings"), "animation": "grey_ripple"},
    "red_stone": {"tiles": t("Red stone")},
    "red_wall": {"tiles": t("Red stone"), "walkable": False},
    "red_rock": {"tiles": t("Red rocky ground 1", "Red rocky ground 2", "Red rocky ground 3"), "fill": "red_stone"},
    "red_earth": {"tiles": t("Red earth 1", "Red earth 2", "Red earth 3"), "fill": "red_stone"},
    "steppe": {"tiles": t("Steppe grass 1", "Steppe grass 2", "Steppe grass 3"), "fill": "dirt"},
    "steppe_dry": {"tiles": t("Dry steppe 1", "Dry steppe 2"), "fill": "dirt"},
    "roof_thatch": {"tiles": t("Thatch roof"), "fill": "cobble", "walkable": False},
    "roof_slate": {"tiles": t("Slate roof"), "fill": "cobble", "walkable": False},
    "roof_red": {"tiles": t("Red tile roof"), "fill": "red_stone", "walkable": False},
})
cat["terrains"].update({
    "mine_floor": {"tiles": t("Mine floor 1", "Mine floor 2", "Mine floor 3"), "fill": "mine_stone"},
    "mine_stone": {"tiles": t("Mine stone")},
    "mine_wall": {"tiles": t("Mine stone"), "walkable": False},
    "grey_rock": {"tiles": t("Grey rock 1", "Grey rock 2"), "fill": "mine_stone"},
    "sunstone": {"tiles": t("Sunstone seam"), "fill": "mine_stone", "walkable": False},
    "spent_seam": {"tiles": t("Spent seam"), "fill": "mine_stone", "walkable": False},
})
cat["props"]["sunstone_clusters"] = {"tiles": t("Sunstone cluster")}
cat["props"]["grey_clusters"] = {"tiles": t("Grey cluster")}
cat["props"]["red_boulders"] = {"tiles": t("Red rock pillar", "Red boulder")}
cat["props"]["red_rocks"] = {"tiles": t("Red rock")}
def dump(cat):
    """The catalog's own layout: one tile, terrain, prop or animation per line."""
    one = lambda v: json.dumps(v, ensure_ascii=False)
    out = ["{"]
    keys = list(cat.keys())
    for i, k in enumerate(keys):
        end = "," if i < len(keys) - 1 else ""
        v = cat[k]
        if k == "tiles":
            out.append(' "tiles": [')
            out += ["  " + one(t) + ("," if j < len(v) - 1 else "") for j, t in enumerate(v)]
            out.append(" ]" + end)
        elif isinstance(v, dict):
            out.append(' %s: {' % one(k))
            names = list(v.keys())
            out += ["  %s: %s%s" % (one(n), one(v[n]), "," if j < len(names) - 1 else "") for j, n in enumerate(names)]
            out.append(" }" + end)
        else:
            out.append(" %s: %s%s" % (one(k), one(v), end))
    out.append("}")
    return "\n".join(out) + "\n"


with open(folder + "/tileset.json", "w") as f:
    f.write(dump(cat))
print("wrote tiles", FIRST, "to", FIRST + len(SPECS) - 1)
