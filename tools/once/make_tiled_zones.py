# One-off (kept for the record, like the rest of tools/once/): wrote the terrain and prop layers of content/zones/greenfields.tres and town.tres.
# Edit that data directly now; running this again would overwrite hand edits.
# Usage: python3 tools/once/make_tiled_zones.py <path to the project>
"""Writes terrain/prop layers for Greenfields and Millbrook into their .tres files."""
import re, sys, json, math
root = sys.argv[1]
cat = json.load(open(root + "/assets/tiles/iso_basic/tileset.json"))
TILE = {t["id"]: t for t in cat["tiles"]}

def read(zone):
    s = open(f"{root}/content/zones/{zone}.tres").read()
    H = json.loads("[" + re.search(r'height_rows = PackedStringArray\((.*?)\)\n', s).group(1) + "]")
    W = json.loads("[" + re.search(r'walk_rows = PackedStringArray\((.*?)\)\n', s).group(1) + "]")
    return s, [[int(c, 36) for c in r] for r in H], [[c == "." for c in r] for r in W]

def h32(x, y, salt=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    v = (v ^ (v >> 13)) * 1274126177 & 0xffffffffffff
    return (v ^ (v >> 16)) & 0x7fffffff

def noise(x, y, scale, salt):
    """Smooth value noise in 0..1 (bilinear over a coarse grid)."""
    gx, gy = x / scale, y / scale
    x0, y0 = int(math.floor(gx)), int(math.floor(gy))
    fx, fy = gx - x0, gy - y0
    def v(a, b): return h32(a, b, salt) % 1000 / 1000.0
    top = v(x0, y0) * (1 - fx) + v(x0 + 1, y0) * fx
    bot = v(x0, y0 + 1) * (1 - fx) + v(x0 + 1, y0 + 1) * fx
    return top * (1 - fy) + bot * fy

def line(a, b):
    """4-connected path from a to b: along x first, then y."""
    (x0, y0), (x1, y1) = a, b
    out = []
    x, y = x0, y0
    out.append((x, y))
    while x != x1:
        x += 1 if x1 > x else -1; out.append((x, y))
    while y != y1:
        y += 1 if y1 > y else -1; out.append((x, y))
    return out

TERRAIN_WALK = {}
for name, tr in cat["terrains"].items():
    first = tr["tiles"][0][0] if isinstance(tr["tiles"][0], list) else tr["tiles"][0]
    TERRAIN_WALK[name] = tr.get("walkable", TILE[first]["walkable"])
def tid(e): return e[0] if isinstance(e, list) else e
TERRAIN_SIGHT = {n: all(TILE[tid(e)]["blocks_sight"] for e in tr["tiles"]) for n, tr in cat["terrains"].items()}
PROP_WALK = {n: all(TILE[tid(e)]["walkable"] for e in g["tiles"]) for n, g in cat["props"].items()}
PROP_SIGHT = {n: all(TILE[tid(e)]["blocks_sight"] for e in g["tiles"]) for n, g in cat["props"].items()}
for n, g in cat["props"].items():
    assert len({TILE[tid(e)]["walkable"] for e in g["tiles"]}) == 1, n
    assert len({TILE[tid(e)]["blocks_sight"] for e in g["tiles"]}) == 1, n

def write(zone, s, H, W, T, P, tlegend, plegend, allowed_changes):
    n = len(H); w = len(H[0])
    inv_t = {v: k for k, v in tlegend.items()}
    inv_p = {v: k for k, v in plegend.items()}
    trows, prows, wrows, srows = [], [], [], []
    for y in range(n):
        tr = pr = wr = sr = ""
        for x in range(w):
            t = T[y][x]; p = P[y][x]
            tr += inv_t[t]; pr += inv_p[p] if p else "."
            walk = TERRAIN_WALK[t] and (not p or PROP_WALK[p])
            sight = TERRAIN_SIGHT[t] or (p and PROP_SIGHT[p])
            if walk != W[y][x] and (x, y) not in allowed_changes:
                raise SystemExit(f"{zone}: walkability of ({x},{y}) changes ({t}, {p}) from {W[y][x]}")
            wr += "." if walk else "#"; sr += "#" if sight else "."
        trows.append(tr); prows.append(pr); wrows.append(wr); srows.append(sr)
    def arr(rows): return "PackedStringArray(%s)" % ", ".join(json.dumps(r) for r in rows)
    def dic(d): return "{\n" + ",\n".join("%s: %s" % (json.dumps(k), json.dumps(v)) for k, v in sorted(d.items())) + "\n}"
    s = re.sub(r'walk_rows = PackedStringArray\(.*?\)\n', lambda m: "walk_rows = %s\n" % arr(wrows), s)
    s = re.sub(r'tileset = .*?\n', "", s)
    s = re.sub(r'terrain_rows = PackedStringArray\(.*?\)\n', "", s)
    s = re.sub(r'terrain_legend = \{.*?\n\}\n', "", s, flags=re.S)
    s = re.sub(r'prop_rows = PackedStringArray\(.*?\)\n', "", s)
    s = re.sub(r'prop_legend = \{.*?\n\}\n', "", s, flags=re.S)
    s = re.sub(r'sight_rows = PackedStringArray\(.*?\)\n', "", s)
    block = 'tileset = &"iso_basic"\nterrain_rows = %s\nterrain_legend = %s\nprop_rows = %s\nprop_legend = %s\nsight_rows = %s\n' % (
        arr(trows), dic(tlegend), arr(prows), dic(plegend), arr(srows))
    s = re.sub(r'(walk_rows = PackedStringArray\(.*?\)\n)', lambda m: m.group(1) + block, s)
    open(f"{root}/content/zones/{zone}.tres", "w").write(s)
    print(zone)
    for y in range(n): print("%2d %s  %s" % (y, trows[y], prows[y]))

# ---------------- Greenfields ----------------
s, H, W = read("greenfields")
N = 30
T = [["grass"] * N for _ in range(N)]
P = [[None] * N for _ in range(N)]
changes = set()
for y in range(N):
    for x in range(N):
        h, walk = H[y][x], W[y][x]
        river = x in (14, 15)
        n1 = noise(x, y, 5.0, 1)
        if river:
            T[y][x] = "ford" if walk else ("deep_water" if noise(x, y, 4.0, 9) > 0.55 else "water")
        elif not walk:            # rock pillars
            T[y][x] = "cobble"; P[y][x] = "grey_boulders"
        elif h == 4 or (x >= 20 and y <= 9):
            T[y][x] = "rocky_ground"   # the raised rocky plateau
        elif h >= 1 and x <= 12:    # the west hill
            T[y][x] = "meadow" if h >= 2 else "grass"
        elif n1 > 0.68:
            T[y][x] = "dense_grass"
        elif n1 < 0.22:
            T[y][x] = "dark_grass"
        elif noise(x, y, 3.0, 4) > 0.8:
            T[y][x] = "meadow"
# Ramp up to the plateau, and the bandit camp's trampled ground.
for y in (10, 11, 12):
    for x in (24, 25):
        T[y][x] = "rocky_dirt"
for y in range(18, 23):
    for x in range(19, 26):
        if W[y][x] and H[y][x] == 0 and abs(x - 22) + abs(y - 20) <= 4:
            T[y][x] = "cracked" if h32(x, y, 3) % 3 else "dirt"
# Dirt paths: the town edge to the south bridge and the camp; a branch north to
# the north bridge, the graveyard and the ramp.
path = []
path += line((0, 25), (13, 25))
path += line((16, 25), (19, 25)) + line((19, 25), (19, 21))
path += line((8, 25), (8, 13)) + line((8, 13), (13, 13))
path += line((16, 12), (23, 12)) + line((24, 12), (24, 13))
path += line((16, 13), (27, 13)) + line((27, 13), (27, 14))
for (x, y) in path:
    if W[y][x] and T[y][x] not in ("ford",):
        T[y][x] = "path"
# Rocks standing in the river (the river is unwalkable anyway).
for (x, y), kind in {(14, 2): "water_tall_rocks", (15, 6): "water_rocks", (14, 17): "water_rocks",
                     (15, 20): "water_tall_rocks", (14, 28): "water_rocks"}.items():
    T[y][x] = kind
# A pond in the south-east corner, light water with foam, with rocks in it.
pond = [(26, 26), (27, 26), (28, 26), (25, 27), (26, 27), (27, 27), (28, 27), (29, 27),
        (26, 28), (27, 28), (28, 28), (29, 28), (27, 29), (28, 29)]
for (x, y) in pond:
    T[y][x] = "light_water"; changes.add((x, y))
T[27][28] = "water_rocks"
# Decorations: flowers and weeds are walkable; logs, stumps and small rocks are not
# (placed off paths, spawns and the patrol route).
for y in range(N):
    for x in range(N):
        if T[y][x] in ("grass", "meadow", "dark_grass", "dense_grass") and P[y][x] is None:
            r = h32(x, y, 11) % 100
            if r < 6: P[y][x] = "flowers"
            elif r < 9: P[y][x] = "weeds"
solid = {(2, 2): "logs", (11, 1): "stump", (6, 28): "logs", (17, 27): "small_rocks", (28, 17): "stump",
         (12, 19): "small_rocks", (1, 9): "logs", (22, 1): "brown_boulders", (28, 8): "brown_boulders",
         (29, 1): "small_rocks", (21, 7): "small_rocks"}
for (x, y), g in solid.items():
    P[y][x] = g; changes.add((x, y))
tl = {".": "grass", ",": "dark_grass", '"': "dense_grass", "m": "meadow", "p": "path", "d": "dirt",
      "k": "cracked", "r": "rocky_ground", "R": "rocky_dirt", "c": "cobble", "=": "ford", "~": "water",
      "w": "deep_water", "o": "water_rocks", "O": "water_tall_rocks", "l": "light_water"}
pl = {"f": "flowers", "v": "weeds", "L": "logs", "S": "stump", "s": "small_rocks", "B": "brown_boulders",
      "G": "grey_boulders"}
write("greenfields", s, H, W, T, P, tl, pl, changes)

# ---------------- Millbrook (town) ----------------
s, H, W = read("town")
N = 18
T = [["grass"] * N for _ in range(N)]
P = [[None] * N for _ in range(N)]
changes = set()
for y in range(N):
    for x in range(N):
        h, walk = H[y][x], W[y][x]
        if not walk and h == 2:
            T[y][x] = "bush"          # the hedge around town
        elif not walk and h == 3:
            T[y][x] = "stone_wall"    # houses
        elif walk and h == 1:
            T[y][x] = "cobble"        # the raised plaza
        elif not walk and h == 1:
            T[y][x] = "light_water"   # the fountain
        elif noise(x, y, 4.0, 21) > 0.7:
            T[y][x] = "meadow"
path = line((17, 8), (5, 8)) + line((7, 8), (7, 6)) + line((12, 8), (12, 10)) + line((5, 8), (5, 14)) \
     + line((10, 8), (10, 11)) + line((10, 11), (10, 15))
for (x, y) in path:
    if W[y][x] and H[y][x] == 0:
        T[y][x] = "path"
for y in range(N):
    for x in range(N):
        if T[y][x] in ("grass", "meadow") and h32(x, y, 13) % 100 < 7:
            P[y][x] = "flowers"
tl = {".": "grass", "m": "meadow", "p": "path", "c": "cobble", "b": "bush", "H": "stone_wall", "l": "light_water"}
pl = {"f": "flowers"}
write("town", s, H, W, T, P, tl, pl, changes)
