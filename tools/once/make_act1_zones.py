# One-off (kept for the record, like the rest of tools/once/): builds the Act I
# zones of milestone 2 by hand-placed shapes: Millbrook (rebuilt), the Crossing,
# the Road to Deepcut, Deepcut, the Windsteppe camps and the Tidereach test shore.
# Writes complete content/zones/<id>.tres files (heights, terrain, props, decor,
# NPCs, enemies, edges). walk_rows / sight_rows come out as placeholders: run
#   godot --headless --path . -s res://tools/once/bake_zone_rows.gd
# afterwards to bake them from the tileset. Running this again overwrites hand
# edits made to those files since.
# Usage: python3 tools/once/make_act1_zones.py <path to the project>
import math, sys

root = sys.argv[1]
H36 = "0123456789abcdefghijklmnopqrstuvwxyz"
REGION = {"heartland": 0, "bedrun": 1, "vael": 2, "tidereach": 3, "ashkara": 4}
CONTEXT = {"town": 1, "explore": 2}
DECOR = {k: i for i, k in enumerate(["well", "dry_well", "ger", "cairn", "cart", "animal", "shrine", "stall",
                                     "sign", "mine", "crates", "label"])}
UP, DOWN, LEFT, RIGHT = (0, -1), (0, 1), (-1, 0), (1, 0)


def h32(x, y, salt=0):
    v = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    v = (v ^ (v >> 13)) * 1274126177 & 0xffffffffffff
    return (v ^ (v >> 16)) & 0x7fffffff


def noise(x, y, scale, salt):
    """Smooth value noise in 0..1."""
    gx, gy = x / scale, y / scale
    x0, y0 = int(math.floor(gx)), int(math.floor(gy))
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    def v(a, b): return h32(a, b, salt) % 1000 / 1000.0
    top = v(x0, y0) * (1 - fx) + v(x0 + 1, y0) * fx
    bot = v(x0, y0 + 1) * (1 - fx) + v(x0 + 1, y0 + 1) * fx
    return top * (1 - fy) + bot * fy


class Map:
    def __init__(self, zid, name, w, d, terrain="grass", h=0):
        self.id, self.name, self.w, self.d = zid, name, w, d
        self.H = [[h] * w for _ in range(d)]
        self.T = [[terrain] * w for _ in range(d)]
        self.P = [[None] * w for _ in range(d)]
        self.decor, self.npcs, self.enemies, self.landmarks, self.edges = [], [], [], [], []
        self.graveyards, self.spawns = [], []
        self.region, self.context, self.respawn_zone = "heartland", "explore", ""

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.d

    def put(self, x, y, t=None, h=None, prop=False):
        if not self.inside(x, y):
            return
        if t is not None:
            self.T[y][x] = t
        if h is not None:
            self.H[y][x] = h
        if prop is not False:
            self.P[y][x] = prop

    def rect(self, x0, y0, x1, y1, t=None, h=None, prop=False):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.put(x, y, t, h, prop)

    def raise_rect(self, x0, y0, x1, y1, by, t=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, t, self.H[y][x] + by)

    def road(self, points, width=2, t="path", h=None):
        """An L-shaped path through `points` (x first, then y), `width` tiles wide
        (growing toward +x / +y)."""
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            x, y = ax, ay
            cells = [(x, y)]
            while x != bx:
                x += 1 if bx > x else -1
                cells.append((x, y))
            while y != by:
                y += 1 if by > y else -1
                cells.append((x, y))
            for cx, cy in cells:
                self.rect(cx, cy, cx + width - 1, cy + width - 1, t, h)

    def house(self, x0, y0, x1, y1, roof="roof_thatch", height=3, label=""):
        base = self.H[y1][x1]
        self.rect(x0, y0, x1, y1, roof, base + height, prop=None)
        if label:
            self.add_decor("label", (x0 + x1) // 2, (y0 + y1) // 2, label)

    def border(self, t="bush", h=1, skip=()):
        for x in range(self.w):
            for y in (0, self.d - 1):
                if (x, y) not in skip:
                    self.put(x, y, t, h, prop=None)
        for y in range(self.d):
            for x in (0, self.w - 1):
                if (x, y) not in skip:
                    self.put(x, y, t, h, prop=None)

    def scatter(self, group, chance, on, salt, area=None):
        x0, y0, x1, y1 = area or (0, 0, self.w - 1, self.d - 1)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.T[y][x] in on and self.P[y][x] is None and h32(x, y, salt) % 1000 < chance * 1000:
                    self.P[y][x] = group

    def patches(self, t, on, scale, threshold, salt, area=None):
        """Replaces terrain `on` with `t` where smooth noise is above threshold."""
        x0, y0, x1, y1 = area or (0, 0, self.w - 1, self.d - 1)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.T[y][x] in on and noise(x, y, scale, salt) > threshold:
                    self.T[y][x] = t

    def add_decor(self, kind, x, y, label="", color=None):
        self.decor.append((kind, x, y, label, color))
        self.P[y][x] = None

    def npc(self, npc_id, x, y, facing=DOWN):
        self.npcs.append((npc_id, x, y, facing))
        self.P[y][x] = None

    def enemy(self, enemy_id, x, y, patrol=()):
        self.enemies.append((enemy_id, x, y, list(patrol)))

    def edge(self, side, to, offset):
        self.edges.append((side, to, offset))

    def clear(self, x, y):
        """Makes sure a gameplay tile holds nothing that blocks."""
        self.P[y][x] = None


# --- .tres writer -------------------------------------------------------------------

SCRIPTS = {
    "zone": "res://data/defs/zone_def.gd", "edge": "res://data/defs/zone_edge.gd",
    "npc_spawn": "res://data/defs/npc_spawn.gd", "enemy_spawn": "res://data/defs/enemy_spawn.gd",
    "landmark": "res://data/defs/zone_landmark.gd", "decor": "res://data/defs/zone_decor.gd",
}
CHARS = ".abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"


def v2(p):
    return "Vector2i(%d, %d)" % (p[0], p[1])


def strings(rows):
    return "PackedStringArray(%s)" % ", ".join('"%s"' % r for r in rows)


def write(m: Map):
    # Gameplay places never hold a prop (they must stay walkable).
    keep = [(x, y) for _, x, y, _ in m.npcs] + [(x, y) for _, x, y in m.landmarks] + m.graveyards + m.spawns
    for _, x, y, patrol in m.enemies:
        keep += [(x, y)] + patrol
    for _, x, y, _, _ in m.decor:
        keep.append((x, y))
    for x, y in keep:
        m.P[y][x] = None
    tnames = sorted({t for row in m.T for t in row})
    tchar = {n: CHARS[i + 1] for i, n in enumerate(tnames)}
    pnames = sorted({p for row in m.P for p in row if p})
    pchar = {n: CHARS[i + 1] for i, n in enumerate(pnames)}
    ext, sub = [], []
    for key in ["zone", "edge", "npc_spawn", "enemy_spawn", "landmark", "decor"]:
        ext.append('[ext_resource type="Script" path="%s" id="s_%s"]' % (SCRIPTS[key], key))
    for n in sorted({n[0] for n in m.npcs}):
        ext.append('[ext_resource type="Resource" path="res://content/npcs/%s.tres" id="npc_%s"]' % (n, n))
    for e in sorted({e[0] for e in m.enemies}):
        ext.append('[ext_resource type="Resource" path="res://content/enemies/%s.tres" id="enemy_%s"]' % (e, e))
    edge_ids, npc_ids, enemy_ids, lm_ids, decor_ids = [], [], [], [], []
    for i, (side, to, off) in enumerate(m.edges):
        sid = "edge_%d" % i
        edge_ids.append(sid)
        sub.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("s_edge")\nside = %s\nto_zone = &"%s"\noffset = %d'
                   % (sid, v2(side), to, off))
    for i, (n, x, y, f) in enumerate(m.npcs):
        sid = "npc_spawn_%d" % i
        npc_ids.append(sid)
        sub.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("s_npc_spawn")\nnpc = ExtResource("npc_%s")\ntile = %s\nfacing = %s'
                   % (sid, n, v2((x, y)), v2(f)))
    for i, (e, x, y, patrol) in enumerate(m.enemies):
        sid = "enemy_spawn_%d" % i
        enemy_ids.append(sid)
        s = '[sub_resource type="Resource" id="%s"]\nscript = ExtResource("s_enemy_spawn")\nenemy = ExtResource("enemy_%s")\ntile = %s' % (sid, e, v2((x, y)))
        if patrol:
            s += "\npatrol = Array[Vector2i]([%s])" % ", ".join(v2(p) for p in patrol)
        sub.append(s)
    for i, (name, x, y) in enumerate(m.landmarks):
        sid = "landmark_%d" % i
        lm_ids.append(sid)
        sub.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("s_landmark")\nname = "%s"\ntile = %s' % (sid, name, v2((x, y))))
    for i, (kind, x, y, label, color) in enumerate(m.decor):
        sid = "decor_%d" % i
        decor_ids.append(sid)
        s = '[sub_resource type="Resource" id="%s"]\nscript = ExtResource("s_decor")\nkind = %d\ntile = %s' % (sid, DECOR[kind], v2((x, y)))
        if label:
            s += '\nlabel = "%s"' % label
        if color:
            s += "\ncolor = Color(%g, %g, %g, 1)" % color
        sub.append(s)
    hrows = ["".join(H36[h] for h in row) for row in m.H]
    trows = ["".join(tchar[t] for t in row) for row in m.T]
    prows = ["".join(pchar[p] if p else "." for p in row) for row in m.P]
    placeholder = ["." * m.w for _ in range(m.d)]
    res = [
        '[resource]', 'script = ExtResource("s_zone")', 'id = &"%s"' % m.id, 'display_name = "%s"' % m.name,
        "height_rows = " + strings(hrows), "walk_rows = " + strings(placeholder),
        "graveyards = Array[Vector2i]([%s])" % ", ".join(v2(p) for p in m.graveyards),
    ]
    if m.respawn_zone:
        res.append('respawn_zone = &"%s"' % m.respawn_zone)
    res += [
        "hero_spawns = Array[Vector2i]([%s])" % ", ".join(v2(p) for p in m.spawns),
        'enemy_spawns = Array[ExtResource("s_enemy_spawn")]([%s])' % ", ".join('SubResource("%s")' % s for s in enemy_ids),
        'landmarks = Array[ExtResource("s_landmark")]([%s])' % ", ".join('SubResource("%s")' % s for s in lm_ids),
        'decor = Array[ExtResource("s_decor")]([%s])' % ", ".join('SubResource("%s")' % s for s in decor_ids),
        'edges = Array[ExtResource("s_edge")]([%s])' % ", ".join('SubResource("%s")' % s for s in edge_ids),
        'npcs = Array[ExtResource("s_npc_spawn")]([%s])' % ", ".join('SubResource("%s")' % s for s in npc_ids),
        'tileset = &"iso_basic"',
        "terrain_rows = " + strings(trows),
        "terrain_legend = {\n%s\n}" % ",\n".join('"%s": "%s"' % (tchar[n], n) for n in tnames),
        "prop_rows = " + strings(prows),
        "prop_legend = {\n%s\n}" % ",\n".join('"%s": "%s"' % (pchar[n], n) for n in pnames) if pnames else "prop_legend = {}",
        "sight_rows = " + strings(placeholder),
        "region = %d" % REGION[m.region],
        "music_context = %d" % CONTEXT[m.context],
    ]
    out = '[gd_resource type="Resource" script_class="ZoneDef" format=3]\n\n' + "\n".join(ext) + "\n\n"
    out += "\n\n".join(sub) + "\n\n" + "\n".join(res) + "\n"
    with open("%s/content/zones/%s.tres" % (root, m.id), "w") as f:
        f.write(out)
    print("wrote", m.id, m.w, "x", m.d)


# --- Millbrook --------------------------------------------------------------------
# A farming village on a river. The river comes from the Crossing (south edge,
# grey: the Deepcut stream), passes the village and the mill pond, and leaves
# north. The east side (rows 1-16) leads to Greenfields, the north gate (15-16)
# to the Enemy Testing Grounds, the south gate (8-11) to the Crossing.

def millbrook():
    m = Map("town", "Millbrook", 32, 32)
    m.context = "town"
    m.patches("meadow", ["grass"], 5, 0.62, 11)
    m.border("bush", 1, skip=[(15, 0), (16, 0)] + [(x, 31) for x in range(8, 12)] + [(31, y) for y in range(1, 17)])
    m.put(15, 0, "path", 0)
    m.put(16, 0, "path", 0)
    # The river: x 24-25, grey upstream (south), clear below the mill pond.
    for y in range(0, 32):
        for x in (24, 25):
            m.put(x, y, "grey_water" if y >= 15 else "water", 0, prop=None)
    m.rect(26, 12, 29, 14, "light_water", 0, prop=None)  # the mill pond (a clear spring)
    m.put(26, 15, "light_water", 0)
    # Roads.
    m.road([(9, 30), (9, 15)], 2)
    m.road([(8, 31), (8, 31)], 4)
    m.road([(15, 0), (15, 8)], 2)
    m.road([(18, 8), (30, 8)], 2)
    m.rect(24, 8, 25, 9, "slab", 0, prop=None)  # bridge to the east fields and Greenfields
    m.road([(26, 8), (31, 8)], 2)
    m.road([(9, 21), (23, 21)], 1)
    m.rect(24, 21, 25, 22, "slab", 0, prop=None)  # bridge to the south fields
    m.road([(26, 21), (29, 21)], 1)
    m.rect(11, 9, 18, 14, "cobble", 0)  # the green
    m.add_decor("well", 15, 11, "Village Well")
    # Houses (thatch roofs) and the healer's hut (slate).
    for box in [(3, 3, 5, 5), (8, 3, 10, 5), (19, 3, 21, 5), (3, 9, 5, 11), (20, 11, 22, 13), (13, 16, 15, 18),
                (4, 15, 6, 17), (18, 24, 20, 26)]:
        m.house(*box)
    m.house(3, 22, 4, 23, "roof_slate", 2, "Healer's Hut")
    m.rect(6, 21, 7, 23, "tilled", 0)  # herb garden
    m.scatter("flowers", 0.5, ["tilled"], 3, (6, 21, 7, 23))
    m.graveyards.append((3, 26))
    # The orchard: high ground, a gentle slope on three sides and a rocky crest
    # (a cliff) on its west side.
    m.rect(12, 23, 17, 29, "grass", 1)
    m.rect(13, 24, 16, 28, "dense_grass", 2)
    m.rect(12, 24, 12, 28, "rocky_ground", 3)
    m.scatter("stump", 0.12, ["dense_grass"], 5, (13, 24, 16, 28))
    m.landmarks.append(("Orchard", 14, 26))
    m.P[26][14] = None
    # Fields east of the river and south of the village.
    m.rect(27, 2, 30, 6, "tilled", 0)
    m.rect(27, 17, 30, 20, "tilled", 0)
    m.rect(27, 23, 30, 29, "tilled", 0)
    m.rect(19, 28, 22, 30, "tilled", 0)
    m.scatter("flowers", 0.08, ["grass", "meadow"], 7)
    m.scatter("small_rocks", 0.15, ["grass"], 9, (22, 15, 23, 31))
    m.add_decor("crates", 7, 4)
    m.add_decor("crates", 22, 10)
    m.add_decor("sign", 12, 30, "Road to the Crossing")
    m.landmarks.append(("Enemy Testing Grounds", 17, 1))
    # People.
    m.npc("hilda", 12, 10, RIGHT)
    m.add_decor("stall", 11, 10)
    m.npc("rowan", 11, 27, LEFT)
    m.npc("maren", 6, 13, UP)
    m.npc("seer_ilyth", 17, 15, DOWN)
    m.npc("healer_wenna", 5, 24, DOWN)
    m.spawns += [(13, 12), (14, 12), (16, 12), (17, 12)]
    m.edge(RIGHT, "greenfields", 13)
    m.edge(UP, "enemy_testing", -12)
    m.edge(DOWN, "crossing", 0)
    return m


# --- The Crossing ---------------------------------------------------------------------
# The market town where the roads meet: Millbrook north (gate 8-11), the Road to
# Deepcut east (rows 18-21), the Windsteppe west (rows 18-21). The grey Deepcut
# stream comes in from the east (rows 26-27) and leaves north toward Millbrook
# (x 24-25). Released heroes from the roads beyond respawn at its shrine.

def crossing():
    m = Map("crossing", "The Crossing", 40, 40)
    m.context = "town"
    m.patches("meadow", ["grass"], 6, 0.64, 21)
    gates = [(x, 0) for x in range(8, 12)] + [(39, y) for y in range(18, 22)] + [(0, y) for y in range(18, 22)]
    m.border("bush", 1, skip=gates)
    # The stream.
    for y in range(0, 28):
        m.put(24, y, "grey_water", 0)
        m.put(25, y, "grey_water", 0)
    for x in range(24, 40):
        m.put(x, 26, "grey_water", 0)
        m.put(x, 27, "grey_water", 0)
    # Roads and the square.
    m.road([(9, 0), (9, 14)], 2)
    m.road([(0, 19), (12, 19)], 2)
    m.road([(22, 19), (39, 19)], 2)
    m.rect(24, 18, 25, 21, "slab", 0, prop=None)  # the bridge east
    m.road([(8, 0), (8, 0)], 4)
    m.rect(0, 18, 0, 21, "path", 0)
    m.rect(39, 18, 39, 21, "path", 0)
    m.rect(12, 14, 22, 25, "cobble", 0)
    m.add_decor("well", 17, 17, "Crossing Well")
    # The Floor Guild hall (north-west), the inn (south-west).
    m.rect(1, 3, 8, 12, "cobble", 1)  # the hall's raised yard
    m.rect(8, 5, 8, 10, "grass", 1)
    m.house(2, 4, 6, 10, "roof_slate", 4, "Floor Guild Hall")
    m.house(2, 24, 7, 30, "roof_thatch", 3, "The Crossed Keys Inn")
    m.rect(8, 23, 10, 31, "cobble", 0)
    m.add_decor("crates", 8, 30)
    # Market stalls on the square.
    m.add_decor("stall", 14, 24, "Market")
    m.add_decor("stall", 17, 24, color=(0.25, 0.45, 0.75))
    m.add_decor("stall", 20, 24, color=(0.35, 0.6, 0.3))
    # The graveyard shrine on its knoll (south-east), stones around it.
    m.rect(28, 29, 37, 37, "grass", 1)
    m.rect(29, 30, 36, 36, "meadow", 2)
    m.add_decor("shrine", 32, 31, "Graveyard Shrine")
    m.graveyards.append((32, 33))
    for p in [(30, 31), (35, 31), (30, 35), (35, 35)]:
        m.put(p[0], p[1], prop="grey_boulders")
    m.road([(23, 30), (28, 30)], 1)
    m.road([(23, 26), (23, 30)], 1)
    # High ground: a rocky hill north-east (a cliff on the stream side), the ridge south.
    m.rect(28, 2, 37, 12, "rocky_ground", 3)
    m.rect(28, 13, 33, 14, "rocky_ground", 2)
    m.rect(28, 15, 33, 15, "rocky_ground", 1)
    m.scatter("grey_boulders", 0.1, ["rocky_ground"], 13, (29, 3, 37, 11))
    m.rect(1, 36, 26, 38, "rocky_ground", 3)
    m.rect(1, 35, 26, 35, "rocky_ground", 2)
    m.scatter("brown_boulders", 0.12, ["rocky_ground"], 15, (1, 37, 26, 38))
    m.scatter("flowers", 0.07, ["grass", "meadow"], 17)
    m.add_decor("sign", 3, 17, "Windsteppe")
    m.add_decor("sign", 36, 17, "Road to Deepcut")
    m.add_decor("sign", 7, 1, "Millbrook")
    # People.
    m.npc("guild_board", 13, 15, DOWN)
    m.npc("warden_dorne", 9, 8, LEFT)
    m.npc("sabra_venn", 11, 26, RIGHT)
    m.npc("innkeeper_bram", 9, 27, LEFT)
    m.npc("trader_tamsin", 14, 23, UP)
    m.npc("apothecary_odo", 17, 23, UP)
    m.spawns += [(16, 19), (18, 19), (16, 20), (18, 20)]
    m.edge(UP, "town", 0)
    m.edge(RIGHT, "deepcut_road", -9)
    m.edge(LEFT, "windsteppe", 2)
    return m


# --- Road to Deepcut ------------------------------------------------------------------
# West to east: the Heartland's grass gives way to red earth and the canyon walls
# rise on both sides. The road (rows 9-12 at both ends) climbs past a ledge; the
# grey stream runs along the south (rows 17-18) back toward the Crossing.

def deepcut_road():
    m = Map("deepcut_road", "Road to Deepcut", 60, 22)
    m.region, m.context, m.respawn_zone = "bedrun", "explore", "crossing"
    for y in range(m.d):
        for x in range(m.w):
            red = x > 18 + 14 * noise(x, y, 6, 31)
            m.T[y][x] = "red_earth" if red else "grass"
    # Canyon sides: grass hills in the west, red cliffs rising east.
    for x in range(m.w):
        wall = 1 if x < 16 else (3 if x < 30 else (5 if x < 45 else 6))
        north = 2 + (1 if noise(x, 0, 4, 33) > 0.5 else 0)
        for y in range(0, north):
            m.put(x, y, "bush" if x < 16 else "red_rock", wall)
        for y in range(20, 22):
            m.put(x, y, "bush" if x < 16 else "red_rock", wall)
    # The stream.
    for x in range(m.w):
        m.put(x, 17, "grey_water", 0, prop=None)
        m.put(x, 18, "grey_water", 0, prop=None)
    m.rect(0, 19, 59, 19, None, 0)
    # The road, winding north around the ledge in the middle.
    m.road([(0, 10), (20, 10), (20, 7), (38, 7), (38, 10), (59, 10)], 2)
    m.rect(0, 9, 0, 12, "path", 0)
    m.rect(59, 9, 59, 12, "path", 0)
    # The ledge: high ground north of the road, reached by a ramp.
    m.rect(24, 2, 34, 4, "red_rock", 3)
    m.rect(29, 5, 30, 5, "red_rock", 2)
    m.rect(29, 6, 30, 6, "red_rock", 1)
    m.scatter("red_boulders", 0.12, ["red_rock"], 35, (24, 2, 34, 3))
    m.landmarks.append(("Lookout Ledge", 28, 3))
    m.P[3][28] = None
    m.scatter("red_rocks", 0.05, ["red_earth"], 37, (19, 5, 59, 16))
    m.scatter("small_rocks", 0.04, ["grass"], 39, (1, 3, 18, 16))
    m.scatter("flowers", 0.05, ["grass"], 41, (1, 3, 18, 16))
    for y in range(m.d):
        for x in range(m.w):
            if m.T[y][x] == "path" and m.P[y][x]:
                m.P[y][x] = None
    m.add_decor("cart", 44, 13, "Abandoned Ore Cart")
    m.add_decor("crates", 45, 13)
    m.add_decor("sign", 3, 8, "The Crossing")
    m.add_decor("sign", 56, 8, "Deepcut")
    m.enemy("wolf", 10, 4)
    m.enemy("wolf", 13, 14)
    m.enemy("bandit_brute", 26, 3)
    m.spawns += [(2, 10), (2, 11)]
    m.edge(LEFT, "crossing", 9)
    m.edge(RIGHT, "deepcut", 7)
    return m


# --- Deepcut --------------------------------------------------------------------------
# A Bedrun mining town in a red canyon. The road comes in from the west (rows
# 16-19) and runs to the mine entrance in the east cliff. The steward's office
# stands on a terrace; the miners' huts lie south of the polluted stream, which
# leaves west (rows 24-25) from the tailings pond by the mine.

def deepcut():
    m = Map("deepcut", "Deepcut", 44, 40, "red_earth", 0)
    m.region, m.context, m.respawn_zone = "bedrun", "town", "crossing"
    m.patches("cracked", ["red_earth"], 5, 0.66, 51)
    # Canyon walls all around (6 high), broken only by the west gate and stream.
    for y in range(m.d):
        for x in range(m.w):
            edge = min(x, y, m.w - 1 - x, m.d - 1 - y)
            if edge < 2 or (x > 38 and 3 <= y <= 36):
                m.put(x, y, "red_rock", 6)
    m.rect(0, 16, 2, 19, "path", 0)
    # The stream and the tailings pond.
    m.rect(0, 24, 34, 25, "grey_water", 0)
    m.rect(33, 22, 38, 28, "grey_water", 0)
    m.rect(17, 24, 18, 25, "slab", 0)  # footbridge to the huts
    # The mine yard and the main street. The mine is cut into a cliff north of the
    # yard (a cliff face the camera sees: entrances in the east wall would face away).
    m.rect(30, 12, 37, 21, "cracked", 0)
    m.road([(0, 17), (36, 17)], 2)
    m.rect(31, 3, 37, 9, "red_rock", 6)
    m.road([(34, 11), (34, 16)], 2)
    m.add_decor("mine", 34, 10, "Mine Entrance")
    for p in [(32, 12), (37, 13), (36, 20)]:
        m.add_decor("cart", p[0], p[1], "Ore Cart" if p == (32, 12) else "")
    m.add_decor("crates", 37, 11)
    # The steward's office on its terrace (north), with a ramp down to the street.
    m.rect(6, 4, 17, 11, "red_stone", 2)
    m.rect(11, 12, 12, 12, "red_stone", 1)
    m.rect(11, 13, 12, 13, "path", 0)
    m.house(8, 5, 12, 8, "roof_red", 3, "Steward's Office")
    m.add_decor("crates", 15, 5)
    # Miners' huts south of the stream, on a low terrace.
    m.rect(6, 28, 30, 35, "red_earth", 1)
    m.rect(17, 26, 18, 27, "path", 0)
    m.road([(17, 26), (17, 30), (28, 30)], 1)
    for box in [(8, 29, 10, 31), (12, 32, 14, 34), (20, 32, 22, 34), (24, 32, 26, 34)]:
        m.house(*box, roof="roof_red", height=3)
    m.landmarks.append(("Miners' Row", 19, 30))
    # High ground: a spur of the north wall with a ramp, over the street.
    m.rect(22, 2, 28, 8, "red_rock", 4)
    m.rect(24, 9, 25, 9, "red_rock", 3)
    m.rect(24, 10, 25, 10, "red_rock", 2)
    m.rect(24, 11, 25, 11, "red_rock", 1)
    # The Collapsed Shaft: an old side entrance in the spur's south face.
    m.add_decor("mine", 27, 9)  # its object (the quest's) stands in front
    m.scatter("red_boulders", 0.08, ["red_rock"], 53)
    m.scatter("red_rocks", 0.04, ["red_earth", "cracked"], 55)
    for y in range(m.d):
        for x in range(m.w):
            if m.T[y][x] in ("path",) and m.P[y][x]:
                m.P[y][x] = None
    # The Ember Hand's fire hounds lurk by the canyon mouth (the escort's danger).
    m.enemy("salamander_hound", 6, 21)
    m.enemy("salamander_hound", 10, 22)
    # People.
    m.npc("steward_marl", 11, 10, DOWN)
    m.npc("mine_board", 14, 15, DOWN)
    m.npc("foreman_brannoc", 33, 14, RIGHT)
    m.npc("ore_caravan", 31, 19, LEFT)
    m.npc("collapsed_shaft", 27, 10, DOWN)
    m.spawns += [(3, 17), (3, 18), (4, 17), (4, 18)]
    m.edge(LEFT, "deepcut_road", -7)
    return m


# --- Windsteppe -----------------------------------------------------------------------
# Cold open grassland west of the Crossing: rolling ground, a rocky ridge, two
# Vael camps of felt tents, stone cairns, dry wells and herds. Iron wolves roam.
# The way back east is at rows 20-23.

def windsteppe():
    m = Map("windsteppe", "Windsteppe", 56, 44, "steppe", 0)
    m.region, m.context, m.respawn_zone = "vael", "explore", "crossing"
    # Rolling ground: smooth noise heights 0-2 (neighbours never differ by more than 1).
    for y in range(m.d):
        for x in range(m.w):
            m.H[y][x] = int(noise(x, y, 9, 61) * 2.99)
    m.patches("steppe_dry", ["steppe"], 6, 0.6, 63)
    m.patches("tall_grass", ["steppe"], 4, 0.82, 65)
    # The ridge (north-west): a rocky crest 4 high with a ramp at its east end.
    m.rect(4, 3, 20, 6, "rocky_ground", 4)
    for i, h in enumerate([3, 2]):
        m.rect(21 + i, 4, 21 + i, 5, "rocky_ground", h)
    m.scatter("grey_boulders", 0.12, ["rocky_ground"], 67, (4, 3, 20, 6))
    m.landmarks.append(("Grey Ridge", 12, 4))
    m.P[4][12] = None
    # The stone's hill.
    m.rect(28, 12, 32, 16, "rocky_ground", 3)
    m.rect(30, 17, 30, 17, "steppe", 2)
    m.rect(30, 18, 30, 18, "steppe", 1)
    m.npc("vael_stone", 30, 14, DOWN)
    m.put(30, 15, prop=None)
    # The track from the Crossing to the main camp.
    m.road([(54, 21), (20, 21)], 2)
    m.rect(55, 20, 55, 23, "path", None)
    for y in range(19, 25):
        for x in range(16, 56):
            if m.T[y][x] == "path":
                m.H[y][x] = 0
    for x in range(50, 56):
        for y in range(19, 25):
            m.H[y][x] = 0
    # Smooth every height step back to at most 1 (the ridges above are cliffs on purpose).
    for _ in range(4):
        for y in range(m.d):
            for x in range(m.w):
                if m.T[y][x] == "rocky_ground":
                    continue
                for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                    nx, ny = x + dx, y + dy
                    if m.inside(nx, ny) and m.T[ny][nx] != "rocky_ground" and m.H[y][x] - m.H[ny][nx] > 1:
                        m.H[y][x] = m.H[ny][nx] + 1
    # The main camp: felt tents round a fire-ring of stones, the elder, a dry well, a herd.
    camp = [(13, 18), (17, 16), (19, 20), (12, 23), (16, 25)]
    m.rect(11, 16, 20, 26, None, 0)
    for p in camp:
        m.add_decor("ger", p[0], p[1], "Ger" if p == (17, 16) else "")
    m.landmarks.append(("Tsaga's Camp", 15, 21))
    m.npc("elder_tsaga", 15, 19, RIGHT)
    m.add_decor("dry_well", 14, 21, "Dry Well")
    m.add_decor("cairn", 18, 23, "Stone Cairn")
    for i, p in enumerate([(23, 25), (24, 27), (22, 28), (25, 26)]):
        m.add_decor("animal", p[0], p[1], "Herd" if i == 0 else "", (0.45, 0.33, 0.24) if i % 2 else (0.72, 0.66, 0.58))
    # The south camp.
    for p in [(36, 34), (39, 36), (34, 37)]:
        m.add_decor("ger", p[0], p[1])
    m.add_decor("dry_well", 37, 32, "Dry Well")
    for i, p in enumerate([(42, 30), (44, 31), (43, 33)]):
        m.add_decor("animal", p[0], p[1], "Herd" if i == 0 else "", (0.5, 0.36, 0.25))
    # Cairns across the steppe.
    for p in [(8, 10), (27, 8), (46, 12), (30, 39), (6, 34), (48, 40)]:
        m.add_decor("cairn", p[0], p[1], "Stone Cairn")
    m.scatter("small_rocks", 0.02, ["steppe", "steppe_dry"], 69)
    m.scatter("weeds", 0.03, ["steppe", "steppe_dry"], 71)
    for y in range(m.d):
        for x in range(m.w):
            if m.T[y][x] == "path" and m.P[y][x]:
                m.P[y][x] = None
    # Iron wolves roam in three packs.
    m.enemy("iron_wolf", 40, 8, [(40, 8), (47, 13), (41, 16)])
    m.enemy("iron_wolf", 43, 7, [(43, 7), (49, 10), (44, 15)])
    m.enemy("iron_wolf", 8, 32, [(8, 32), (12, 38), (4, 39)])
    m.enemy("iron_wolf", 10, 30, [(10, 30), (14, 35), (6, 36)])
    m.enemy("iron_wolf", 26, 31, [(26, 31), (30, 26), (22, 34)])
    m.enemy("iron_wolf", 28, 33, [(28, 33), (32, 28), (24, 36)])
    m.spawns += [(52, 21), (52, 22), (51, 21), (51, 22)]
    m.edge(RIGHT, "crossing", -2)
    return m


# --- Tidereach shore (music test) -------------------------------------------------------
# Not part of Act I: a stretch of Tidereach coast off the Enemy Testing Grounds'
# west gate, so the Tidereach music can be heard (and the crossfade checked).

def tidereach_shore():
    m = Map("tidereach_shore", "Tidereach Shore (test)", 18, 14, "dirt", 0)
    m.region, m.context = "tidereach", "explore"
    for y in range(m.d):
        for x in range(m.w):
            coast = 6 + int(2 * noise(x, y, 4, 81))
            if x < coast - 3:
                m.put(x, y, "deep_water", 0)
            elif x < coast - 1:
                m.put(x, y, "water", 0)
            elif x < coast:
                m.put(x, y, "light_water", 0)
    for p in [(3, 3), (2, 9), (5, 11)]:
        m.put(p[0], p[1], "water_tall_rocks", 0)
    m.rect(12, 11, 17, 13, "rocky_ground", 1)
    m.rect(14, 12, 17, 13, "rocky_ground", 2)
    m.scatter("grey_boulders", 0.2, ["rocky_ground"], 83)
    m.rect(9, 0, 17, 0, "rocky_ground", 1)
    m.scatter("small_rocks", 0.06, ["dirt"], 85, (9, 1, 16, 10))
    m.road([(12, 6), (17, 6)], 2, "path", 0)
    m.add_decor("sign", 14, 4, "Tidereach Shore (music test)")
    m.spawns += [(15, 6), (15, 7), (14, 6), (14, 7)]
    m.edge(RIGHT, "enemy_testing", -4)
    return m


for build in [millbrook, crossing, deepcut_road, deepcut, windsteppe, tidereach_shore]:
    write(build())
