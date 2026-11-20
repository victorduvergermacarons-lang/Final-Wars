"""The Wilds (2026-11-19): a 64 x 64 map in place of the Enemy Testing Grounds,
reached through the same gate in Millbrook's north-east hedge (and from Tidereach
Shore). Streams wind across it (water, not walkable; stone-slab fords where the path
and a few other spots cross), puddles of light water lie about, and dense vegetation
covers most of the land: tall and dense grass (walkable), leafy bush thickets
(not walkable), flowers, weeds, logs and stumps. Left empty: no enemies, people,
quests or loot. The tileset has no trees, so bushes, logs and stumps stand in.

Run from the project root: python3 tools/once/make_wilds.py
Writes content/zones/wilds.tres; ContentDB bakes its walk and sight rows at load.
"""
import json
import math
import random
from collections import deque

W = H = 64
SEED = 1119
rng = random.Random(SEED)
CAT = json.load(open("assets/tiles/iso_basic/tileset.json"))

# Gates: Millbrook's north-east gate (town x 15-16, row 0) lands on our south row
# at x 3-4 (offset 12); Tidereach Shore's east side (rows 0-13) lands on our west
# column at rows 0-9 (offset -4).
SOUTH_GATE = range(2, 6)
WEST_GATE = range(2, 10)
SPAWN = (4, 60)

terrain = [["tall_grass"] * W for _ in range(H)]
prop = [[""] * W for _ in range(H)]
height = [[0] * W for _ in range(H)]


def inside(x, y):
    return 0 <= x < W and 0 <= y < H


# Ground cover by smooth noise: patches of tall grass, dense grass, meadow and grass.
def noise(x, y, s):
    return (math.sin(x * 0.21 + s) + math.sin(y * 0.17 + s * 1.7) + math.sin((x + y) * 0.11 + s * 0.3)) / 3.0


for y in range(H):
    for x in range(W):
        n = noise(x, y, 1.3)
        terrain[y][x] = "tall_grass" if n > 0.15 else ("dense_grass" if n > -0.25 else
                                                     ("meadow" if n > -0.55 else "grass"))

# A few low hummocks (one level up) for some relief.
for _ in range(6):
    cx, cy, r = rng.randint(10, 54), rng.randint(8, 50), rng.randint(3, 5)
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                height[y][x] = 1

# Bush thickets: clusters of leafy bushes (they block movement).
for _ in range(70):
    cx, cy = rng.randint(1, W - 2), rng.randint(1, H - 2)
    for _ in range(rng.randint(3, 9)):
        x, y = cx + rng.randint(-2, 2), cy + rng.randint(-2, 2)
        if inside(x, y):
            terrain[y][x] = "bush"

# The border is a bush hedge, but for the gates.
for i in range(W):
    for (x, y) in [(i, 0), (i, H - 1), (0, i), (W - 1, i)]:
        terrain[y][x] = "bush"
for x in SOUTH_GATE:
    terrain[H - 1][x] = "path"
for y in WEST_GATE:
    terrain[y][0] = "path"

# Winding streams (1-2 tiles of water).
streams = []
for (start, end, wide) in [((20, 0), (8, 63), 2), ((63, 14), (0, 40), 1), ((44, 0), (63, 52), 2),
                           ((63, 58), (30, 26), 1)]:
    pts = []
    (x0, y0), (x1, y1) = start, end
    steps = max(abs(x1 - x0), abs(y1 - y0)) * 2
    phase = rng.random() * 6
    for i in range(steps + 1):
        t = i / steps
        bx, by = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        # meander sideways to the stream's direction
        dx, dy = (y1 - y0), -(x1 - x0)
        ln = math.hypot(dx, dy) or 1
        off = math.sin(t * 9 + phase) * 4 + math.sin(t * 23 + phase) * 1.5
        pts.append((round(bx + dx / ln * off), round(by + dy / ln * off)))
    tiles = set()
    for (px, py) in pts:
        for ox in range(wide):
            for oy in range(wide):
                if inside(px + ox, py + oy):
                    tiles.add((px + ox, py + oy))
    for (x, y) in tiles:
        terrain[y][x] = "water"
        height[y][x] = 0
    streams.append(sorted(tiles, key=lambda p: (p[1], p[0])))

# Puddles of light water.
for _ in range(22):
    cx, cy = rng.randint(3, W - 4), rng.randint(3, H - 4)
    r = rng.choice([1, 1, 1.5, 2])
    for y in range(H):
        for x in range(W):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r and terrain[y][x] != "water":
                terrain[y][x] = "light_water"
                height[y][x] = 0

# The path: from the south gate north to a clearing, with a branch west to
# Tidereach's opening; fords where it crosses water.
def carve_path(points):
    for (a, b) in zip(points, points[1:]):
        (x0, y0), (x1, y1) = a, b
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / max(n, 1))
            y = round(y0 + (y1 - y0) * i / max(n, 1))
            for (ox, oy) in [(0, 0), (1, 0)]:
                if inside(x + ox, y + oy) and 0 < x + ox < W - 1 and 0 < y + oy < H - 1:
                    water = terrain[y + oy][x + ox] in ("water", "light_water")
                    terrain[y + oy][x + ox] = "ford" if water else "path"
                    prop[y + oy][x + ox] = ""
                    height[y + oy][x + ox] = 0


carve_path([(3, 62), (5, 54), (10, 46), (18, 40), (26, 32), (32, 24), (34, 14), (38, 8)])
carve_path([(18, 40), (12, 30), (6, 18), (2, 10), (1, 5)])
carve_path([(26, 32), (38, 36), (48, 30), (56, 22)])
carve_path([(26, 32), (30, 44), (40, 52), (52, 58)])

# A clearing around the spawn by the gate.
for y in range(57, 63):
    for x in range(1, 9):
        if terrain[y][x] not in ("path", "ford"):
            terrain[y][x] = "meadow"

# Every stream gets a few more fords so no bank is cut off.
for tiles in streams:
    for k in range(1, 5):
        x, y = tiles[len(tiles) * k // 5]
        for (ox, oy) in [(0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (0, -1)]:
            if inside(x + ox, y + oy) and terrain[y + oy][x + ox] == "water":
                terrain[y + oy][x + ox] = "ford"

# Props on open ground: flowers, weeds, logs, stumps, a few rocks.
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if terrain[y][x] in ("tall_grass", "dense_grass", "meadow", "grass") and abs(x - SPAWN[0]) + abs(y - SPAWN[1]) > 3:
            r = rng.random()
            if r < 0.06:
                prop[y][x] = "flowers"
            elif r < 0.12:
                prop[y][x] = "weeds"
            elif r < 0.135:
                prop[y][x] = "logs"
            elif r < 0.145:
                prop[y][x] = "stump"
            elif r < 0.15:
                prop[y][x] = "small_rocks"

# Walkability from the catalog (terrain tiles, terrain overrides, props).
tiles = CAT["tiles"]
tile_walk = {int(k): v.get("walkable", True) for k, v in (tiles.items() if isinstance(tiles, dict) else enumerate(tiles))}


def terrain_walkable(t):
    td = CAT["terrains"][t]
    if "walkable" in td:
        return td["walkable"]
    ids = [e[0] if isinstance(e, list) else e for e in td["tiles"]]
    return all(tile_walk.get(i, True) for i in ids)


def prop_walkable(p):
    if p == "":
        return True
    ids = [e[0] if isinstance(e, list) else e for e in CAT["props"][p]["tiles"]]
    return all(tile_walk.get(i, True) for i in ids)


def walkable(x, y):
    return terrain_walkable(terrain[y][x]) and prop_walkable(prop[y][x])


# Anything walkable the spawn can't reach becomes thicket (no pockets).
seen = {SPAWN}
q = deque([SPAWN])
while q:
    x, y = q.popleft()
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        nx, ny = x + dx, y + dy
        if inside(nx, ny) and (nx, ny) not in seen and walkable(nx, ny) \
                and abs(height[ny][nx] - height[y][x]) <= 1:
            seen.add((nx, ny))
            q.append((nx, ny))
cut = 0
for y in range(H):
    for x in range(W):
        if walkable(x, y) and (x, y) not in seen:
            terrain[y][x] = "bush"
            prop[y][x] = ""
            cut += 1
reach = len(seen)
for x in SOUTH_GATE:
    assert (x, H - 1) in seen, "south gate cut off"
for y in WEST_GATE:
    assert (0, y) in seen, "west gate cut off"

# Write the zone.
tletters = {}
pletters = {}


def letter(table, name):
    if name not in table:
        table[name] = "abcdefghijklmnopqrstuvwxyz"[len(table)]
    return table[name]


terrain_rows = ["".join(letter(tletters, terrain[y][x]) for x in range(W)) for y in range(H)]
prop_rows = ["".join(letter(pletters, prop[y][x]) if prop[y][x] else "." for x in range(W)) for y in range(H)]
height_rows = ["".join(str(height[y][x]) for x in range(W)) for y in range(H)]
walk_rows = ["".join("." if walkable(x, y) else "#" for x in range(W)) for y in range(H)]


def arr(rows):
    return "PackedStringArray(" + ", ".join('"%s"' % r for r in rows) + ")"


def legend(table):
    return "{\n" + ",\n".join('"%s": "%s"' % (v, k) for k, v in sorted(table.items(), key=lambda kv: kv[1])) + "\n}"


out = """[gd_resource type="Resource" script_class="ZoneDef" format=3]

[ext_resource type="Script" path="res://data/defs/zone_edge.gd" id="s_edge"]
[ext_resource type="Script" path="res://data/defs/zone_def.gd" id="s_zone"]

[sub_resource type="Resource" id="edge_town"]
script = ExtResource("s_edge")
side = Vector2i(0, 1)
to_zone = &"town"
offset = 12

[sub_resource type="Resource" id="edge_shore"]
script = ExtResource("s_edge")
side = Vector2i(-1, 0)
to_zone = &"tidereach_shore"
offset = 4

[resource]
script = ExtResource("s_zone")
id = &"wilds"
display_name = "The Wilds"
height_rows = %s
walk_rows = %s
graveyards = Array[Vector2i]([Vector2i(%d, %d)])
hero_spawns = Array[Vector2i]([Vector2i(%d, %d), Vector2i(%d, %d), Vector2i(%d, %d), Vector2i(%d, %d)])
edges = Array[ExtResource("s_edge")]([SubResource("edge_town"), SubResource("edge_shore")])
tileset = &"iso_basic"
terrain_rows = %s
terrain_legend = %s
prop_rows = %s
prop_legend = %s
""" % (arr(height_rows), arr(walk_rows), SPAWN[0] + 2, SPAWN[1],
       SPAWN[0], SPAWN[1], SPAWN[0] + 1, SPAWN[1], SPAWN[0], SPAWN[1] - 1, SPAWN[0] + 1, SPAWN[1] - 1,
       arr(terrain_rows), legend(tletters), arr(prop_rows), legend(pletters))
open("content/zones/wilds.tres", "w").write(out)
counts = {}
for row in terrain:
    for t in row:
        counts[t] = counts.get(t, 0) + 1
print("wrote content/zones/wilds.tres: %d reachable tiles, %d pocket tiles turned to thicket" % (reach, cut))
print({k: v for k, v in sorted(counts.items(), key=lambda kv: -kv[1])})
