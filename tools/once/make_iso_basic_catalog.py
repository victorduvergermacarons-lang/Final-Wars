# One-off (kept for the record, like the rest of tools/once/): wrote assets/tiles/iso_basic/tileset.json.
# Edit that data directly now; running this again would overwrite hand edits.
# Usage: python3 tools/once/make_iso_basic_catalog.py <output tileset.json>
import json, sys
T = {}
def add(i, name, cat, kind="block", walk=True, sight=False, **extra):
    d = {"id": i, "name": name, "category": cat, "kind": kind, "walkable": walk, "blocks_sight": sight}
    d.update(extra); T[i] = d
# Row 0: dirt blocks
dirt_names = {0:"Dirt", 1:"Dirt, smooth", 2:"Dirt, pebbled", 3:"Dark dirt", 4:"Dirt, light", 5:"Dirt, worn",
              6:"Dirt, speckled", 7:"Dirt, pale patches", 8:"Dirt, scuffed", 9:"Dirt, sandy", 10:"Dirt, dark edge"}
for i, n in dirt_names.items(): add(i, n, "ground")
# Row 1
for i in (11, 12, 13): add(i, "Rocky dirt %d" % (i - 10), "ground")
for i in (14, 15, 16): add(i, "Dirt path %d" % (i - 13), "path")
add(17, "Cracked earth 1", "ground"); add(18, "Cracked earth 2", "ground")
add(19, "Cracked earth, sprouts 1", "ground"); add(20, "Cracked earth, sprouts 2", "ground")
add(21, "Dark earth", "ground")
# Rows 2-3
for i in (22, 23, 24): add(i, "Grass %d" % (i - 21), "ground")
add(25, "Tilled soil", "ground"); add(26, "Tilled soil, sprouting", "ground")
add(27, "Dense grass 1", "foliage"); add(28, "Dense grass 2", "foliage")
for k, i in enumerate(range(29, 36)): add(i, "Leafy bush %d" % (k + 1), "foliage", walk=False)
add(36, "Tall grass", "foliage")
for i in (37, 38, 39): add(i, "Meadow %d" % (i - 36), "ground")
add(40, "Dark grass", "ground")
add(41, "Flower clump, orange", "prop", "prop"); add(42, "Single flower", "prop", "prop"); add(43, "Weeds", "prop", "prop")
# Row 4
add(44, "Flower clump, pink", "prop", "prop"); add(45, "Small bush", "prop", "prop")
add(46, "Flower patch, red and yellow", "prop", "prop"); add(47, "Scattered flowers", "prop", "prop")
add(48, "Log", "prop", "prop", walk=False); add(49, "Broken logs", "prop", "prop", walk=False)
add(50, "Mossy log", "prop", "prop", walk=False); add(51, "Overgrown log", "prop", "prop", walk=False)
add(52, "Tree stump", "prop", "prop", walk=False)
add(53, "Small brown rock", "rock", "prop", walk=False); add(54, "Brown rock", "rock", "prop", walk=False)
# Rows 5-7
add(55, "Brown rock pillar", "rock", "prop", walk=False, sight=True)
add(56, "Brown twin rocks", "rock", "prop", walk=False, sight=True)
add(57, "Brown boulder", "rock", "prop", walk=False, sight=True)
add(58, "Brown rock stack, small", "rock", "prop", walk=False)
add(59, "Brown rock stack", "rock", "prop", walk=False, sight=True)
add(60, "Brown boulder, tall", "rock", "prop", walk=False, sight=True)
add(61, "Cobblestone", "rock")
add(62, "Grey rock pile, small", "rock", "prop", walk=False)
add(63, "Stone slab", "rock")
add(64, "Grey boulder, tall", "rock", "prop", walk=False, sight=True)
add(65, "Grey boulder", "rock", "prop", walk=False, sight=True)
add(66, "Cobblestone in water", "rock")
add(67, "Grey rock pile", "rock", "prop", walk=False)
add(68, "Grey standing stone", "rock", "prop", walk=False, sight=True)
add(69, "Stone slab in water", "rock")
add(70, "Rocks in water 1", "rock", walk=False)
add(71, "Rocks in water 2", "rock", walk=False)
add(72, "Tall rock in water 1", "rock", walk=False, sight=True)
add(73, "Standing stone in water", "rock", walk=False, sight=True)
add(74, "Boulder in water", "rock", walk=False, sight=True)
add(75, "Pebble in shallow water", "rock", walk=False)
add(76, "Small rock in shallow water", "rock", walk=False)
add(77, "Flat rocks in water", "rock", walk=False)
add(78, "Rocks in water 3", "rock", walk=False)
add(79, "Tall rock in water 2", "rock", walk=False, sight=True)
add(80, "Standing stone in water 2", "rock", walk=False, sight=True)
add(81, "Boulder in water 2", "rock", walk=False, sight=True)
for k, i in enumerate(range(82, 86)): add(i, "Water sparkle %d" % (k + 1), "effect", "overlay", animation="sparkle")
# Rows 8-10
water_names = ["Water, streaks", "Water, ripple", "Water, swell", "Water, rings", "Deep water, swell",
               "Deep water, ripple", "Deep water, still", "Deep water, specks", "Deep water, flecks"]
# Water blocks sit 4 art px below a ground block: "drop" tells the view where the surface is.
for k, i in enumerate(range(86, 95)): add(i, water_names[k], "water", walk=False, drop=4)
for k, i in enumerate(range(95, 104)): add(i, water_names[k] + " (surface)", "water", "surface", walk=False)
T[95]["name"] = "Water, streaks (surface, half)"
# Foam marks the edges that touch land. Edges by screen side; "shore" lists them in
# grid directions (n = -y top-right, w = -x top-left, e = +x bottom-right, s = +y bottom-left).
light = [("Light water", []), ("Light water, foam top-right", ["n"]), ("Light water, foam top-left", ["w"]),
         ("Light water, foam bottom-right", ["e"]), ("Light water, foam bottom-left", ["s"]),
         ("Light water, foam both top edges", ["n", "w"]), ("Light water, foam both bottom edges", ["e", "s"]),
         ("Light water, foam both left edges", ["w", "s"]), ("Light water, foam both right edges", ["n", "e"]),
         ("Light water, foam all edges", ["n", "w", "e", "s"])]
for k, i in enumerate(range(104, 114)): add(i, light[k][0], "water", walk=False, shore=light[k][1], drop=4)
add(114, "Purple crystal", "rock", walk=False)
assert sorted(T) == list(range(115)), [i for i in range(115) if i not in T]
cat = {
  "id": "iso_basic",
  "name": "Basic isometric terrain",
  "file_pattern": "tile_%03d.png",
  "cell_size": [32, 32],
  "top_y": 8,
  "level_height": 8,
  "tiles": [T[i] for i in range(115)],
  "animations": {"sparkle": {"frames": [82, 83, 84, 85], "fps": 6}},
  "terrains": {
    "dirt":        {"tiles": [0, 1, 2, 4, 5, 6, 8, 9, 10, [7, 0.3], [3, 0.3]]},
    "dark_earth":  {"tiles": [21, [17, 0.5], [18, 0.5]], "fill": "dirt"},
    "rocky_dirt":  {"tiles": [11, 12, 13], "fill": "dirt"},
    "path":        {"tiles": [14, 15, 16], "fill": "dirt"},
    "cracked":     {"tiles": [17, 18, [19, 0.4], [20, 0.4]], "fill": "dirt"},
    "tilled":      {"tiles": [25, [26, 0.6]], "fill": "dirt"},
    "grass":       {"tiles": [22, 23, 24], "fill": "dirt"},
    "meadow":      {"tiles": [37, 38, 39], "fill": "dirt"},
    "dark_grass":  {"tiles": [40], "fill": "dirt"},
    "dense_grass": {"tiles": [27, 28], "fill": "dirt"},
    "tall_grass":  {"tiles": [36], "fill": "dirt"},
    "bush":        {"tiles": [29, 30, 31, 32, 33, 34, 35], "fill": "dirt"},
    "cobble":      {"tiles": [61]},
    "slab":        {"tiles": [63], "fill": "cobble"},
    "ford":        {"tiles": [69, [66, 0.5]]},
    "water":       {"tiles": [86, 87, 88, 89, [90, 0.5], [91, 0.5]]},
    "deep_water":  {"tiles": [90, 91, 92, 93, 94]},
    "light_water": {"tiles": [104, 105, 106, 107, 108, 109, 110, 111, 112, 113], "shore": True, "fill": "cobble"},
    "water_rocks": {"tiles": [70, 71, 77, 78]},
    "water_tall_rocks": {"tiles": [72, 73, 74, 79, 80, 81]},
    "crystal":     {"tiles": [114], "fill": "cobble"},
    "rocky_ground": {"tiles": [11, 12, 13, [61, 0.6], [63, 0.6]], "fill": "cobble"},
    "stone_wall":  {"tiles": [63], "fill": "cobble", "walkable": False}
  },
  "props": {
    "flowers":        {"tiles": [41, 44, 46, 47, [42, 0.5]]},
    "weeds":          {"tiles": [43, 45]},
    "logs":           {"tiles": [48, 49, 50, 51]},
    "stump":          {"tiles": [52]},
    "small_rocks":    {"tiles": [53, 54, 58, 62, 67]},
    "brown_boulders": {"tiles": [55, 56, 57, 59, 60]},
    "grey_boulders":  {"tiles": [64, 65, 68]}
  }
}
def dumps(c):
    lines = ["{"]
    keys = list(c)
    for n, k in enumerate(keys):
        comma = "," if n < len(keys) - 1 else ""
        v = c[k]
        if k == "tiles":
            lines.append(' "tiles": [')
            lines += ["  " + json.dumps(t) + ("," if j < len(v) - 1 else "") for j, t in enumerate(v)]
            lines.append(" ]" + comma)
        elif isinstance(v, dict):
            lines.append(" %s: {" % json.dumps(k))
            sub = list(v)
            lines += ["  %s: %s%s" % (json.dumps(s2), json.dumps(v[s2]), "," if j < len(sub) - 1 else "") for j, s2 in enumerate(sub)]
            lines.append(" }" + comma)
        else:
            lines.append(" %s: %s%s" % (json.dumps(k), json.dumps(v), comma))
    lines.append("}")
    return "\n".join(lines) + "\n"
open(sys.argv[1], "w").write(dumps(cat))
json.loads(open(sys.argv[1]).read())
