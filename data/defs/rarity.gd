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
const COLORS := [Color(0.92, 0.92, 0.92), Color(0.3, 0.9, 0.35), Color(0.3, 0.55, 1.0), Color(0.72, 0.38, 1.0)]


static func color(id: Id) -> Color:
	return COLORS[id]
