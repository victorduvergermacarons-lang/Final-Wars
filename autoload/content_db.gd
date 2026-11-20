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
	"elements": "res://content/elements",
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
## The four elements a new character picks from (the element screen), by id.
var elements := {} # id -> StartingElementDef
## Every line of dialogue (content/dialogue/act1.json), by id.
var dialogue: DialogueLines
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
	elements = _load_dir(DIRS.elements)
	dialogue = DialogueLines.load_file()
	tree = AbilityTreeData.load_file()
	tilesets = TilesetData.load_all()
	for z in zones.values():
		if z.enemy_pens:
			TestingGrounds.build(z, enemies.values(), npcs.get(&"reset_shrine"))
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


## Again after the map editor reloaded some files (safe to repeat).
func link_tree_items() -> void:
	_link_tree_items()


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
		q.element_rewards = _link_by_element(q.element_reward_ids)
		q.element_choices = _link_by_element(q.element_choice_ids)
	for e in enemies.values():
		_time_abilities_to_art(e)
	for e in enemies.values():
		if e.loot != null:
			for entry in e.loot.entries:
				if entry.item_id != &"":
					entry.item = _item(entry.item_id)


## Attacks timed by a creature's art wind up until their hit frame (the bite
## lands when the jaws close), whatever the frame rate is set to.
func _time_abilities_to_art(e: EnemyDef) -> void:
	if e.art == null:
		return
	var timed: Array = e.abilities.duplicate()
	if e.howl_ability != null:
		timed.append(e.howl_ability)
	for a in timed:
		var w := e.art.windup_for(a.id)
		if w >= 0.0:
			a.windup_seconds = w


func _link_list(list: Array, ids: Array) -> void:
	for id in ids:
		for i in range(list.size() - 1, -1, -1):
			if list[i] == null or list[i].id == id:
				list.remove_at(i)
		var item := _item(id)
		if item != null:
			list.append(item)


## {element: [item ids]} -> {element (String): Array[ItemDef]}.
func _link_by_element(ids: Dictionary) -> Dictionary:
	var out := {}
	for e in ids:
		var list: Array[ItemDef] = []
		for id in ids[e]:
			var item := _item(StringName(id))
			if item != null:
				list.append(item)
		out[String(e)] = list
	return out


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
	for e: StartingElementDef in elements.values():
		var mastered: AbilityDef = abilities.get(e.mastered_ability_id)
		var scroll: ItemDef = items.get(e.mastered_scroll_id)
		var learning: ItemDef = items.get(e.learning_scroll_id)
		if mastered == null or not mastered.implemented:
			errors.append("Element %s: its first ability %s isn't built" % [e.id, e.mastered_ability_id])
		if scroll == null or scroll.tree_ability() != mastered:
			errors.append("Element %s: %s doesn't teach %s" % [e.id, e.mastered_scroll_id, e.mastered_ability_id])
		if learning == null or learning.tree_ability() == null or not learning.tree_ability().implemented:
			errors.append("Element %s: its learning scroll %s teaches nothing built" % [e.id, e.learning_scroll_id])
		for c in e.clothes_ids:
			if not items.has(c):
				errors.append("Element %s: unknown starting item %s" % [e.id, c])
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
		for o in q.objectives:
			if o == null:
				continue
			if o.npc != &"" and not npcs.has(o.npc):
				errors.append("Quest %s: objective names unknown NPC %s" % [q.id, o.npc])
			if o.zone != &"" and not zones.has(o.zone):
				errors.append("Quest %s: objective names unknown zone %s" % [q.id, o.zone])
			if o.kind == QuestObjective.Kind.ESCORT and npcs.has(o.npc) and npcs[o.npc].max_hp <= 0.0:
				errors.append("Quest %s: escorted %s has no max_hp" % [q.id, o.npc])
		for what in ["offer", "complete"]:
			if not dialogue.has(q.line_id(what)):
				errors.append("Quest %s: no dialogue line %s" % [q.id, q.line_id(what)])
	for n in npcs.values():
		if not dialogue.has("npc.%s.greeting" % n.id):
			errors.append("NPC %s: no dialogue line npc.%s.greeting" % [n.id, n.id])
	errors.append_array(dialogue.validate())
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
