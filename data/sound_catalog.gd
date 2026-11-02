class_name SoundCatalog
extends RefCounted
## Every sound key the game plays, built from the content, and how a game event
## names its key. The game (SoundDirector) and the sound list in AUDIO_SPEC.md
## (tools/write_audio_spec.gd) both use it, so the list always matches.
##
## Key shapes (all lower case, words joined by "_"; the first word picks the folder,
## see AudioConfig.categories):
## - hero abilities: <tree>_<ability>_cast when used, <tree>_<ability>_hit where it
##   lands; <tree> is fire / water / earth / air, or weapon for Sword, Bow and Hammer
##   arts (fire_fireball_cast, weapon_slash_hit). Items' abilities (potions) use world_.
## - creature attacks: creature_<enemy>_<ability> when used, ..._hit where it lands
##   (creature_wolf_bite, creature_wolf_howl).
## - creatures: creature_<enemy>_aggro / _hurt / _death / _step (+ _grounded, _enrage
##   for those that can).
## - footsteps: footstep_<ground> (footstep_grass, footstep_path…), footstep_default.
## - interface: ui_…; world events: world_…; zone ambience: ambience_<zone>.

const UI_KEYS := {
	"ui_click": "any button is pressed",
	"ui_open": "a window opens (inventory, quests, trees, settings...)",
	"ui_close": "a window closes",
	"ui_error": "an action is refused (the red error text)",
	"ui_coins": "buying or selling at a vendor",
	"ui_equip": "putting on or taking off gear",
	"ui_learn": "placing an item in the learning slot",
	"ui_loot": "loot goes into your bag",
	"ui_quest_accept": "a quest is accepted",
	"ui_quest_complete": "a quest is handed in",
}

const WORLD_KEYS := {
	"world_level_up": "a hero levels up",
	"world_mastered": "a hero masters an ability",
	"world_hero_death": "a hero dies",
	"world_release": "a hero releases to a graveyard",
	"world_zone_enter": "you walk into another map",
	"world_shrine_reset": "the Reset Shrine resets the testing grounds",
	"world_event": "a world event is announced (the bells of Millbrook)",
	"world_miss": "an attack misses",
	"world_whiff": "an attack hits nothing",
	"world_dungeon_enter": "your party enters a dungeon (its own copy)",
	"world_lift": "a mine lift rattles along its shaft (you ride it)",
	"world_party_wipe": "the whole party has fallen in a dungeon",
	"world_wipe_respawn": "the fallen party wakes at the dungeon's entrance",
	"world_act_complete": "an act of the story ends (the end-of-act screen opens)",
}

const CREATURE_EVENTS := {
	"aggro": "notices a hero and starts a fight",
	"hurt": "takes damage",
	"death": "dies",
	"step": "moves one tile (paws, wings...)",
}

const TREE_PREFIX := {"Fire": "fire", "Water": "water", "Earth": "earth", "Air": "air",
		"Sword": "weapon", "Bow": "weapon", "Hammer": "weapon"}

## Ability id -> {"prefix", "name", "sub": true for parts of another ability (zone
## ticks, dive hits): they only have a _hit key; "lands": false when it never
## damages, heals or shields anyone, so it has no _hit key}.
var abilities := {}
## Enemy id -> EnemyDef.
var enemies := {}
## Key -> what it is for (for the spec), grouped by category in keys().
var _keys := {}
## Creature ability id -> the enemy ids that use it (the wolf and the iron wolf
## share a bite): each gets its own keys.
var _users := {}


## `content`: ContentDB (or anything with abilities, items, enemies, zones, tilesets).
func _init(content) -> void:
	var ids: Array = content.enemies.keys()
	ids.sort()
	for id in ids:
		var e: EnemyDef = content.enemies[id]
		enemies[id] = e
		var own: Array = e.abilities.duplicate()
		if e.howl_ability != null:
			own.append(e.howl_ability)
		for a in own:
			_add_ability(a, "creature_%s" % id, false)
			_add_user(a, id)
		# A passive trail is never "used": it only has a _hit key.
		_add_ability(e.trail_ability, "creature_%s" % id, true)
		_add_user(e.trail_ability, id)
	for a in _sorted(content.abilities.values()):
		if a.is_tree_ability() and a.implemented:
			_add_ability(a, TREE_PREFIX.get(a.tree, "world"), false)
	for item in _sorted(content.items.values()):
		if item.use_ability != null and not abilities.has(item.use_ability.id):
			_add_ability(item.use_ability, "world", false)
	_collect_keys(content)


## Records `enemy_id` as a user of `a` and of the abilities it is made of.
func _add_user(a: AbilityDef, enemy_id: StringName) -> void:
	if a == null:
		return
	var list: Array = _users.get(a.id, [])
	if list.has(enemy_id):
		return
	list.append(enemy_id)
	_users[a.id] = list
	for e in a.effects:
		if e != null:
			_add_user(e.zone_ability, enemy_id)
			_add_user(e.pass_ability, enemy_id)


static func _sorted(list: Array) -> Array:
	var out := list.duplicate()
	out.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return out


static func slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


func _add_ability(a: AbilityDef, prefix: String, sub: bool, parent_name: String = "", part := "zone") -> void:
	if a == null or abilities.has(a.id):
		return
	var name := slug(a.display_name)
	# "Fire Dart" in the fire folder is fire_dart, not fire_fire_dart.
	if name.begins_with(prefix + "_"):
		name = name.trim_prefix(prefix + "_")
	var parent := slug(parent_name).trim_prefix(prefix + "_")
	if sub and (name == "" or name == parent):
		# A part of another ability: named after it, e.g. flame_dash_burn.
		name = parent + "_" + slug(String(a.id).get_slice("_", String(a.id).get_slice_count("_") - 1))
	elif name == "":
		name = slug(String(a.id))
	abilities[a.id] = {"prefix": prefix, "name": name, "sub": sub,
			"lands": prefix != "world" and _lands(a), "label": parent_name if sub and parent_name != "" else a.display_name, "part": part}
	for e in a.effects:
		if e == null:
			continue
		_add_ability(e.zone_ability, prefix, true, a.display_name, "zone")
		_add_ability(e.pass_ability, prefix, true, a.display_name, "pass")


## Whether the ability ever damages, heals or shields someone with its own id (what
## plays its _hit key). Over-time ticks are its buff's, not the ability's.
static func _lands(a: AbilityDef) -> bool:
	for e in a.effects:
		if e == null:
			continue
		match e.kind:
			AbilityEffect.Kind.DAMAGE, AbilityEffect.Kind.HEAL, AbilityEffect.Kind.SHIELD, \
					AbilityEffect.Kind.KNOCKBACK, AbilityEffect.Kind.PULL:
				return true
			AbilityEffect.Kind.TERRAIN:
				if e.lift_damage > 0.0:
					return true
	return false


## The key an ability plays when used ("" for parts of other abilities). A creature's
## attack is named after the creature using it (`caster_enemy`), if given.
func cast_key(ability_id: StringName, caster_enemy: StringName = &"") -> StringName:
	var info: Dictionary = abilities.get(ability_id, {})
	if info.is_empty() or info.sub:
		return &""
	var prefix := _prefix(info, caster_enemy)
	if prefix.begins_with("creature_"):
		return StringName("%s_%s" % [prefix, info.name])
	return StringName("%s_%s_cast" % [prefix, info.name])


## The key an ability plays where it lands on someone.
func hit_key(ability_id: StringName, caster_enemy: StringName = &"") -> StringName:
	var info: Dictionary = abilities.get(ability_id, {})
	if info.is_empty() or not info.lands:
		return &""
	if String(info.name).ends_with("_hit"):
		return StringName("%s_%s" % [_prefix(info, caster_enemy), info.name]) # searing_dive_hit
	return StringName("%s_%s_hit" % [_prefix(info, caster_enemy), info.name])


func _prefix(info: Dictionary, caster_enemy: StringName) -> String:
	if caster_enemy != &"" and String(info.prefix).begins_with("creature_"):
		return "creature_%s" % caster_enemy
	return info.prefix


static func creature_key(enemy_id: StringName, event: String) -> StringName:
	return StringName("creature_%s_%s" % [enemy_id, event])


static func footstep_key(terrain: String) -> StringName:
	return StringName("footstep_%s" % (slug(terrain) if terrain != "" else "default"))


static func ambience_key(zone: ZoneDef) -> StringName:
	return zone.ambience if zone.ambience != &"" else StringName("ambience_%s" % zone.id)


func _collect_keys(content) -> void:
	for k in UI_KEYS:
		_keys[StringName(k)] = UI_KEYS[k]
	for k in WORLD_KEYS:
		_keys[StringName(k)] = WORLD_KEYS[k]
	for id in abilities:
		var info: Dictionary = abilities[id]
		for user in _users.get(id, [&""]):
			var c := cast_key(id, user)
			if c != &"":
				_keys[c] = "%s is used" % info.label
			var h := hit_key(id, user)
			if h != &"":
				_keys[h] = "%s lands on someone" % info.label if not info.sub \
						else ("%s: its ground zone hurts someone standing in it" % info.label if info.part == "zone" \
						else "%s hits someone in its path" % info.label)
	for id in enemies:
		var e: EnemyDef = enemies[id]
		for ev in CREATURE_EVENTS:
			if ev == "step" and e.immobile:
				continue # it never moves
			_keys[creature_key(id, ev)] = "%s %s" % [e.display_name, CREATURE_EVENTS[ev]]
		if e.grounded_buff != null:
			_keys[creature_key(id, "grounded")] = "%s is knocked out of the air" % e.display_name
		if e.enrage_buff != null:
			_keys[creature_key(id, "enrage")] = "%s enrages (%s)" % [e.display_name, e.enrage_buff.display_name]
	_keys[footstep_key("")] = "a hero steps on ground without a known surface"
	for z in content.zones.values():
		var enc: BossEncounterDef = z.encounter
		if enc != null and enc.boss != null and enc.heart != null:
			_keys[creature_key(enc.boss.id, "phase")] = "%s enters a new phase of the fight (phases 2 and 3)" % enc.boss.display_name
			if enc.enrage_buff != null:
				_keys[creature_key(enc.boss.id, "enrage")] = "%s enrages (%s, phase 3)" % [enc.boss.display_name, enc.enrage_buff.display_name]
			_keys[creature_key(enc.boss.id, "reset")] = "%s goes back to the start of its phase (after a party wipe)" % enc.boss.display_name
			_keys[creature_key(enc.heart.id, "pulse")] = "%s pulses: adds climb out, the floor turns grey" % enc.heart.display_name
			_keys[creature_key(enc.heart.id, "break")] = "%s breaks and the fight is won" % enc.heart.display_name
	for z in content.zones.values():
		_keys[ambience_key(z)] = "background loop in %s (Ambience bus, OGG)" % z.display_name
		if not z.has_terrain():
			continue
		var ts: TilesetData = content.tilesets.get(z.tileset)
		for c in z.terrain_legend:
			var terrain := str(z.terrain_legend[c])
			if ts != null and ts.terrain_walkable(terrain):
				_keys[footstep_key(terrain)] = "a hero steps on %s" % terrain.replace("_", " ")


## Every key, sorted: key -> what it is for.
func keys() -> Dictionary:
	var names := _keys.keys()
	names.sort_custom(func(a, b): return String(a) < String(b))
	var out := {}
	for k in names:
		out[k] = _keys[k]
	return out
