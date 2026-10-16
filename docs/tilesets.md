# Tilesets and tiled zones

The ground is drawn from isometric tilesets. A tileset is one folder under
`assets/tiles/` holding the tile images and a `tileset.json` catalog. Adding a
tileset needs only that folder, no code: the game finds every folder with a
`tileset.json` at startup (`ContentDB.tilesets`).

## The art

- Each image is one 32 × 32 cell. A block is a 32 × 16 diamond top with an 8 px
  side below it. One height level is one block side (8 art px).
- The world draws art at 2× (`PixelCamera.ART_SCALE`): a 32 px tile covers the
  64 px wide grid cell, and one level is 16 world px, as before.
- The camera only zooms to whole art scales (1×, 2×, 3×… screen pixels per art
  pixel, counting the window's stretch) and moves by whole pixels. Filtering is
  nearest-neighbour and the images import without mipmaps.

## tileset.json

```json
{
 "id": "iso_basic", "name": "Basic isometric terrain",
 "file_pattern": "tile_%03d.png",       // image name for a tile id
 "cell_size": [32, 32], "top_y": 8,     // where a block's top corner is in the cell
 "level_height": 8,
 "tiles": [ {"id": 0, "name": "Dirt", "category": "ground", "kind": "block",
             "walkable": true, "blocks_sight": false}, ... ],
 "animations": {"sparkle": {"frames": [82, 83, 84, 85], "fps": 6}},
 "terrains": {"grass": {"tiles": [22, 23, 24], "fill": "dirt"}, ...},
 "props": {"logs": {"tiles": [48, 49, 50, 51]}, ...}
}
```

**Tiles**
- `category`: ground, path, foliage, prop, rock, water or effect.
- `kind`:
  - `block`: a full block on its cell.
  - `prop`: drawn standing on the block beneath it.
  - `surface`: a flat top without sides.
  - `overlay`: a small sprite drawn over a tile.
- `walkable` and `blocks_sight` are the gameplay flags. A tile that blocks sight
  stops line of sight and projectiles, whatever its height.
- Optional `drop`: art px its surface sits below a ground block's. Water uses 4;
  highlights on it sit on the water.
- Optional `shore`: the sides that show foam, as grid directions: `n` = −y
  (top-right edge), `w` = −x (top-left), `e` = +x (bottom-right), `s` = +y
  (bottom-left).

**Terrains** are what maps use.
- `tiles` lists variants; `[id, weight]` makes one rarer or commoner. Each cell
  picks a variant from a hash of its position, so it's stable and varied.
- `fill` is the terrain drawn under the top block on raised ground. Grass sits on
  dirt.
- `shore: true` picks the tile whose foam best matches which sides touch land,
  instead of a variant.
- `walkable` overrides the tiles' own flag. `stone_wall` is cobblestone you
  can't walk on.
- All variants of a terrain must agree on walkability.

**Props** are groups of prop tiles a map can scatter. The variant is picked by
position, like terrains.

**Animations:** `sparkle` twinkles on about one water tile in five.

The catalog is checked at load and by `tests/unit/test_tileset.gd`. The checks:
- unknown categories or kinds
- missing images
- terrains or props using the wrong kind of tile
- fill loops
- animation frames that don't exist

## Tiled zones

A zone (`content/zones/*.tres`) uses a tileset with these fields:

- `tileset = &"iso_basic"`
- `terrain_rows`: one char per tile.
- `terrain_legend`: maps those chars to terrain names, e.g. `".": "grass"`.
- `prop_rows`: one char per tile, `.` for none.
- `prop_legend`: maps those chars to prop groups.
- `height_rows` as before.

Walkability and sight come from the catalog. At load, ContentDB rebuilds
`walk_rows` and `sight_rows` from the terrain and props. The files keep a copy
so they can be read, and `tests/unit/test_zone_layout.gd` checks the copies match.
The same test checks that every spawn, NPC, graveyard, patrol point, landmark
and linked map edge stays walkable and reachable on foot.

Zones without a `tileset` (the test zones built in code) keep the placeholder
diamonds.

Drawing: each tile is a column of blocks, bottom first, then its prop. Rows are
drawn back to front, and characters are fitted into the order so the tiles in
front of them, props included, cover them.
