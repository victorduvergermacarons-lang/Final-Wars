class_name Rarity
extends RefCounted
## Item rarity tiers. Higher rarity: better stats, growth and abilities.

enum Id {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
}

const NAMES := ["Common", "Uncommon", "Rare", "Epic"]
## Name colours, chosen to read as ink on the paper menus (UiPalette).
const COLORS := [Color("341c27"), Color("2e7d32"), Color("1f5fa8"), Color("7b2fa8")]


static func color(id: Id) -> Color:
	return COLORS[id]
