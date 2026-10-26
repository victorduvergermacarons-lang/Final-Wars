extends SceneTree
## One-off (Milestone 3 step 10): moves the M1/M2 content onto the ability trees.
## Kept for the record; running it again is harmless.

func _init() -> void:
	for id in ["sword", "staff", "shield", "holy_charm", "hunting_bow", "greataxe"]:
		var item: ItemDef = load("res://content/items/%s.tres" % id)
		item.retired = true
		_save(item)
	for id in ["iron_helm", "swift_boots", "frostweave_robe", "acolytes_leggings", "rangers_gloves", "grizzlehide_mantle"]:
		var item: ItemDef = load("res://content/items/%s.tres" % id)
		item.teaches = [] as Array[AbilityDef]
		_save(item)

	var hero: HeroDef = load("res://content/heroes/adventurer.tres")
	hero.starting_items = [] as Array[ItemDef]
	hero.starting_equipment = [] as Array[ItemDef]
	hero.starting_item_ids = [&"rusty_shortsword", &"ember_fist_scroll", &"menders_scroll"] as Array[StringName]
	hero.starting_equipment_ids = [&"rusty_shortsword"] as Array[StringName]
	hero.starting_learning_id = &"ember_fist_scroll"
	_save(hero)

	var hilda: NpcDef = load("res://content/npcs/hilda.tres")
	var keep: Array[ItemDef] = []
	for item in hilda.sells:
		if not item.retired:
			keep.append(item)
	hilda.sells = keep
	hilda.sells_ids = [&"ember_fist_scroll", &"cinder_kick_scroll", &"spark_scroll", &"kindling_scroll",
			&"menders_scroll", &"river_lash_scroll", &"scroll_of_the_current", &"frost_shard_scroll",
			&"open_palm_scroll", &"breeze_scroll", &"featherstep_scroll",
			&"pebble_scroll", &"pillar_scroll", &"stomp_scroll",
			&"rusty_shortsword", &"travelers_longsword", &"hunters_shortbow", &"yew_longbow",
			&"iron_mallet", &"quarry_maul"] as Array[StringName]
	_save(hilda)

	_loot("wolf", {"wave_scroll": 0.02, "blazing_fist_scroll": 0.02})
	_loot("goblin_shaman", {"scroll_of_the_fireball": 0.04, "glacier_scroll": 0.04, "mist_scroll": 0.04,
			"lash_of_embers_scroll": 0.04})
	_loot("bandit_brute", {"bulwark_scroll": 0.05, "scorched_earth_scroll": 0.04, "tidal_scroll": 0.04})
	_loot("fen_skirmisher", {"gale_scroll": 0.04, "scroll_of_burning_feet": 0.04, "leech_tide_scroll": 0.04})
	_loot("old_grizzlehide", {"scroll_of_the_fireball": 0.15, "bulwark_scroll": 0.15, "glacier_scroll": 0.15})

	var fetishes: QuestDef = load("res://content/quests/goblin_fetishes.tres")
	fetishes.reward_choices = fetishes.reward_choices.filter(func(i): return not i.retired)
	fetishes.reward_choice_ids = [&"hunters_shortbow"] as Array[StringName]
	_save(fetishes)
	var beast: QuestDef = load("res://content/quests/beast_of_greenfields.tres")
	beast.reward_choices = [] as Array[ItemDef]
	beast.reward_choice_ids = [&"scroll_of_the_fireball", &"glacier_scroll", &"bulwark_scroll"] as Array[StringName]
	_save(beast)
	_enemy_abilities()
	quit(0)


## Milestone 3 decision 7: enemy melee is Targeted with a wind-up, the Shaman's
## bolt a skillshot, Grizzlehide's Cleave a wound-up cone and Charge a telegraphed
## Ground leap.
func _enemy_abilities() -> void:
	for pair in [["wolf_bite", 0.3], ["crushing_blow", 0.6], ["quick_slash", 0.3]]:
		var a: AbilityDef = load("res://content/abilities/%s.tres" % pair[0])
		a.targeting = AbilityDef.TargetingMode.TARGETED
		a.max_range = 1
		a.windup_seconds = pair[1]
		_save(a)
	var bolt: AbilityDef = load("res://content/abilities/shadow_bolt.tres")
	bolt.targeting = AbilityDef.TargetingMode.SKILLSHOT
	bolt.aim = AbilityDef.Aim.ANY_ANGLE
	_save(bolt)
	var cleave: AbilityDef = load("res://content/abilities/grizzly_cleave.tres")
	cleave.targeting = AbilityDef.TargetingMode.SKILLSHOT
	cleave.line_shape = AbilityDef.LineShape.CONE
	cleave.aim = AbilityDef.Aim.EIGHT_WAY
	cleave.max_range = 1
	cleave.windup_seconds = 0.4
	cleave.description = "A sweeping swipe at the three tiles in front."
	_save(cleave)
	var charge: AbilityDef = load("res://content/abilities/charge.tres")
	charge.targeting = AbilityDef.TargetingMode.GROUND
	charge.area_radius = 0
	charge.windup_seconds = 1.0
	charge.description = "Marks a tile 2-4 tiles away, then rushes there and mauls whoever still stands on it."
	var dash: AbilityEffect = charge.effects[0]
	dash.kind = AbilityEffect.Kind.DASH_TO
	dash.applies = AbilityEffect.Applies.CASTER
	dash.base_amount = 4.0
	_save(charge)


## Drops retired entries and adds tree items by id.
func _loot(id: String, add: Dictionary) -> void:
	var table: LootTable = load("res://content/loot/%s.tres" % id)
	var entries: Array[LootEntry] = []
	for e in table.entries:
		if e.item_id == &"" and e.item != null and e.item.retired:
			continue
		if e.item_id != &"" and add.has(String(e.item_id)):
			continue
		entries.append(e)
	for item_id in add:
		var e := LootEntry.new()
		e.item_id = StringName(item_id)
		e.chance = add[item_id]
		entries.append(e)
	table.entries = entries
	_save(table)


func _save(res: Resource) -> void:
	var err := ResourceSaver.save(res, res.resource_path)
	if err != OK:
		printerr("could not save %s" % res.resource_path)
