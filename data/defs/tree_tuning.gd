class_name TreeTuning
extends Resource
## Numbers for the ability trees that the spreadsheet doesn't hold (decision M3-1,
## M3-5, M3-10): AP to master, item rarity, prices and weapon stats by tier.
## Tuned in content/tree/tuning.tres.

## AP to master an ability, by tier 1..5 (index 0 = tier 1).
@export var ap_by_tier: Array[int] = [20, 30, 40, 50, 50]
## Item rarity by tier 1..5.
@export var rarity_by_tier: Array[Rarity.Id] = [Rarity.Id.COMMON, Rarity.Id.UNCOMMON,
		Rarity.Id.RARE, Rarity.Id.EPIC, Rarity.Id.EPIC]
## Vendor price by tier 1..5.
@export var scroll_price_by_tier: Array[int] = [25, 60, 150, 400, 1000]
@export var weapon_price_by_tier: Array[int] = [30, 75, 180, 450, 1100]
## Weapon stats and growth at tier 1; higher tiers multiply them by
## 1 + weapon_tier_step × (tier − 1).
@export var sword_stats: StatBlock = StatBlock.make({Stat.Id.PHYS_ATK: 10, Stat.Id.ACCURACY: 4})
@export var sword_growth: StatBlock = StatBlock.make({Stat.Id.PHYS_ATK: 3, Stat.Id.HP: 8, Stat.Id.SWORD_MASTERY: 2})
@export var bow_stats: StatBlock = StatBlock.make({Stat.Id.PHYS_ATK: 13, Stat.Id.ACCURACY: 8})
@export var bow_growth: StatBlock = StatBlock.make({Stat.Id.PHYS_ATK: 4, Stat.Id.EVASION: 1, Stat.Id.BOW_MASTERY: 2})
@export var hammer_stats: StatBlock = StatBlock.make({Stat.Id.PHYS_ATK: 15, Stat.Id.PHYS_DEF: 5, Stat.Id.HP: 15})
@export var hammer_growth: StatBlock = StatBlock.make({Stat.Id.PHYS_ATK: 4, Stat.Id.HP: 10, Stat.Id.HAMMER_MASTERY: 2})
@export var weapon_tier_step: float = 0.5


func ap_for(tier: int) -> int:
	return ap_by_tier[clampi(tier, 1, ap_by_tier.size()) - 1]


func rarity_for(tier: int) -> Rarity.Id:
	return rarity_by_tier[clampi(tier, 1, rarity_by_tier.size()) - 1]


func price_for(tier: int, scroll: bool) -> int:
	var table := scroll_price_by_tier if scroll else weapon_price_by_tier
	return table[clampi(tier, 1, table.size()) - 1]


## Tier-scaled stats and growth for a weapon of `kind` (Sword, Bow, Hammer).
func weapon_blocks(kind: String, tier: int) -> Array[StatBlock]:
	var k := 1.0 + weapon_tier_step * (maxi(tier, 1) - 1)
	match kind:
		"Sword":
			return [sword_stats.scaled(k), sword_growth.scaled(k)]
		"Bow":
			return [bow_stats.scaled(k), bow_growth.scaled(k)]
		"Hammer":
			return [hammer_stats.scaled(k), hammer_growth.scaled(k)]
	return [StatBlock.new(), StatBlock.new()]
