extends RefCounted
## Hero builds and fights used by the balance report and tests (Milestone 3).

const STARTER := {"weapon": "rusty_shortsword", "learning": "ember_fist_scroll", "rotation": ["S01", "F01"]}
const STARTER_HEALER := {"weapon": "rusty_shortsword", "learning": "menders_scroll", "rotation": ["S01"],
		"heal": "W01", "heal_below": 0.5}
## Holds the starting sword for its stats, fights with fire from range.
const CASTER := {"weapon": "rusty_shortsword", "learning": "spark_scroll", "mastered": ["F01"],
		"rotation": ["F03", "F01", "S01"]}
const SWORD_ONLY := {"weapon": "rusty_shortsword", "rotation": ["S01"]}
const ARCHER := {"weapon": "hunters_shortbow", "rotation": ["B01"]}
const HAMMER := {"weapon": "iron_mallet", "rotation": ["H01"]}
## Level 3: Slash, Fire Punch and Healing Touch mastered.
const L3_SWORD := {"weapon": "rusty_shortsword", "mastered": ["F01", "W01"], "learning": "river_lash_scroll",
		"rotation": ["S01", "F01"],
		"mastery": {"Fire": 10, "Water": 10, "Sword": 10}}
const L3_SWORD_HEAL := {"weapon": "rusty_shortsword", "mastered": ["F01", "W01"], "learning": "river_lash_scroll",
		"rotation": ["S01", "F01"],
		"heal": "W01", "heal_below": 0.6, "mastery": {"Fire": 10, "Water": 10, "Sword": 10}}
const L3_SWORD_DODGE := {"weapon": "rusty_shortsword", "mastered": ["F01", "W01"], "learning": "river_lash_scroll",
		"rotation": ["S01", "F01"], "heal": "W01", "heal_below": 0.6, "dodge": true,
		"mastery": {"Fire": 10, "Water": 10, "Sword": 10}}
const STARTER_DODGE := {"weapon": "rusty_shortsword", "learning": "ember_fist_scroll", "rotation": ["S01", "F01"],
		"dodge": true}
## Level 4-5 builds.
const L4_LUNGE := {"weapon": "travelers_longsword", "mastered": ["S01", "F01", "W01"],
		"rotation": ["S04", "S01", "F01"], "heal": "W01", "heal_below": 0.45,
		"mastery": {"Fire": 20, "Water": 15, "Sword": 25}}
const L5_TANK := {"weapon": "quarry_maul", "armor": ["iron_helm", "grizzlehide_mantle"],
		"mastered": ["H01", "E04", "W01"], "rotation": ["E04", "H01", "H02"], "mastery": {"Hammer": 30, "Earth": 20}}
const L5_FIRE := {"mastered": ["F01", "F03", "F02"], "learning": "scroll_of_the_fireball",
		"armor": ["frostweave_robe"], "rotation": ["F07", "F02", "F03", "F01"], "mastery": {"Fire": 60}}
const L5_HEALER := {"mastered": ["W01", "W02", "W05"], "armor": ["acolytes_leggings"], "rotation": ["W02"],
		"heal": "W01", "heal_below": 0.6, "mastery": {"Water": 60}}
const L5_ARCHER := {"weapon": "yew_longbow", "mastered": ["B01"], "armor": ["rangers_gloves"],
		"rotation": ["B02", "B01"], "mastery": {"Bow": 40}}

## [label, heroes, enemy, count, hero level]
const ROWS := [
	["starter vs 1 Wolf [1]", [STARTER], &"wolf", 1, 1],
	["starter vs 2 Wolves [1]", [STARTER], &"wolf", 2, 1],
	["starter healer vs 1 Wolf [1]", [STARTER_HEALER], &"wolf", 1, 1],
	["sword only vs 1 Wolf [1]", [SWORD_ONLY], &"wolf", 1, 1],
	["caster vs 1 Wolf [1]", [CASTER], &"wolf", 1, 1],
	["archer vs 1 Wolf [1]", [ARCHER], &"wolf", 1, 1],
	["hammer vs 1 Wolf [1]", [HAMMER], &"wolf", 1, 1],
	["pair vs 2 Wolves [1]", [STARTER, STARTER_HEALER], &"wolf", 2, 1],
	["caster vs Shaman [2]", [CASTER], &"goblin_shaman", 1, 2],
	["sword no heals vs Brute [3]", [L3_SWORD], &"bandit_brute", 1, 3],
	["sword with heals vs Brute [3]", [L3_SWORD_HEAL], &"bandit_brute", 1, 3],
	["sword heals + dodges vs Brute [3]", [L3_SWORD_DODGE], &"bandit_brute", 1, 3],
	["starter dodging vs 1 Wolf [1]", [STARTER_DODGE], &"wolf", 1, 1],
	["lunge sword vs Skirmisher [4]", [L4_LUNGE], &"fen_skirmisher", 1, 4],
	["lunge sword vs Grizzlehide [5]", [L4_LUNGE], &"old_grizzlehide", 1, 5],
	["pair vs Grizzlehide [5]", [L5_TANK, L5_HEALER], &"old_grizzlehide", 1, 5],
	["group of 4 vs Grizzlehide [5]", [L5_TANK, L5_FIRE, L5_HEALER, L5_ARCHER], &"old_grizzlehide", 1, 5],
]
