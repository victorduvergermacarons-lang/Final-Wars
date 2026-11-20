class_name Rarity
extends RefCounted
## Item rarity tiers. Higher rarity: better stats, growth and abilities.

enum Id {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

const NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
## Name colours, chosen to read as ink on the paper menus (UiPalette).
const COLORS := [Color("341c27"), Color("2e7d32"), Color("1f5fa8"), Color("7b2fa8"), Color("a86b00")]
## Loot beam colours in the world: white, green, blue, purple, gold.
const BEAM_COLORS := [Color(1, 1, 1), Color(0.3, 1.0, 0.35), Color(0.3, 0.6, 1.0), Color(0.75, 0.35, 1.0),
		Color(1.0, 0.78, 0.2)]
## Sound keys picked up per rarity (`world_loot_common` … `world_loot_legendary`).
const SOUND_KEYS := [&"world_loot_common", &"world_loot_uncommon", &"world_loot_rare", &"world_loot_epic",
		&"world_loot_legendary"]


static func color(id: Id) -> Color:
	return COLORS[id]
