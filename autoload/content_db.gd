extends Node
## Loads all content resources once and looks them up by id. Used by the
## session/UI layers (the sim itself is handed resources directly).

const RULES_PATH := "res://content/rules/default_rules.tres"
const DIRS := {
	"abilities": "res://content/abilities",
	"items": "res://content/items",
	"enemies": "res://content/enemies",
	"heroes": "res://content/heroes",
	"zones": "res://content/zones",
	"buffs": "res://content/buffs",
	"npcs": "res://content/npcs",
	"quests": "res://content/quests",
}

var rules: CombatRules
var abilities := {} # id -> AbilityDef
var items := {} # id -> ItemDef
var enemies := {} # id -> EnemyDef
var heroes := {} # id -> HeroDef
var zones := {} # id -> ZoneDef
var buffs := {} # id -> BuffDef
var npcs := {} # id -> NpcDef
var quests := {} # id -> QuestDef
## Ability trees from design/Ability_Tree.xlsx (via tools/import_ability_tree.gd).
var tree: AbilityTreeData
var tree_tuning: TreeTuning
## Isometric tilesets (res://assets/tiles/<id>/tileset.json), by id.
var tilesets := {} # id -> TilesetData
const TREE_TUNING_PATH := "res://content/tree/tuning.tres"


func _init() -> void:
	reload()


func reload() -> void:
	rules = load(RULES_PATH)
	abilities = _load_dir(DIRS.abilities)
	items = _load_dir(DIRS.items)
	enemies = _load_dir(DIRS.enemies)
	heroes = _load_dir(DIRS.heroes)
	zones = _load_dir(DIRS.zones)
	buffs = _load_dir(DIRS.buffs)
	npcs = _load_dir(DIRS.npcs)
	quests = _load_dir(DIRS.quests)
	tree = AbilityTreeData.load_file()
	tilesets = TilesetData.load_all()
	for z in zones.values():
		if z.has_terrain() and tilesets.has(z.tileset):
			z.bake_walkability(tilesets[z.tileset])
	tree_tuning = load(TREE_TUNING_PATH) if ResourceLoader.exists(TREE_TUNING_PATH) else TreeTuning.new()
	var built := TreeContent.build(tree, tree_tuning)
	abilities.merge(built.abilities)
	items.merge(built.items)
	_link_tree_items()
	if OS.is_debug_build():
		for w in CastResolver.dodge_warnings(abilities.values(), rules):
			print("DODGE WARNING: " + w)


## Content (.tres) can name ability-tree items only by id, since those are built
## at load time. Puts the real items in place; safe to repeat (replaces by id).
func _link_tree_items() -> void:
	for h in heroes.values():
		_link_list(h.starting_items, h.starting_item_ids)
		_link_list(h.starting_equipment, h.starting_equipment_ids)
		h.starting_learning = _item(h.starting_learning_id) if h.starting_learning_id != &"" else null
	for n in npcs.values():
		_link_list(n.sells, n.sells_ids)
	for q in quests.values():
		_link_list(q.reward_items, q.reward_item_ids)
		_link_list(q.reward_choices, q.reward_choice_ids)
	for e in enemies.values():
		if e.loot != null:
			for entry in e.loot.entries:
				if entry.item_id != &"":
					entry.item = _item(entry.item_id)


func _link_list(list: Array, ids: Array) -> void:
	for id in ids:
		for i in range(list.size() - 1, -1, -1):
			if list[i] == null or list[i].id == id:
				list.remove_at(i)
		var item := _item(id)
		if item != null:
			list.append(item)


func _item(id: StringName) -> ItemDef:
	if not items.has(id):
		push_error("Content names an unknown item: %s" % id)
		return null
	return items[id]


## Every problem found in the loaded content; empty when all is valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for a in abilities.values():
		errors.append_array(a.validate())
	for i in items.values():
		errors.append_array(i.validate())
	for z in zones.values():
		errors.append_array(z.validate())
	for t in tilesets.values():
		errors.append_array(t.validate())
	for z in zones.values():
		if z.has_terrain():
			errors.append_array(z.validate_terrain(tilesets.get(z.tileset)))
	for q in quests.values():
		errors.append_array(q.validate())
		for id in [q.giver, q.turn_in_npc()]:
			if not npcs.has(id):
				errors.append("Quest %s: unknown NPC %s" % [q.id, id])
		for pre in q.prerequisites:
			if not quests.has(pre):
				errors.append("Quest %s: unknown prerequisite %s" % [q.id, pre])
	return errors


static func _load_dir(path: String) -> Dictionary:
	var out := {}
	var files := ResourceLoader.list_directory(path)
	files.sort()
	for file in files:
		# Exported builds list "x.tres.remap"; ResourceLoader resolves the original name.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(path.path_join(name))
		if res != null and "id" in res:
			out[res.id] = res
	return out
