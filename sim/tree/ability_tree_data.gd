class_name AbilityTreeData
extends RefCounted
## The ability trees as loaded from content/tree/ability_tree.json (made by
## tools/import_ability_tree.gd from design/Ability_Tree.xlsx). Plain data:
## each ability / item / tree is a Dictionary with the keys the importer writes.

const DEFAULT_PATH := "res://content/tree/ability_tree.json"

var abilities := {} # id (StringName) -> Dictionary
var items := {} # item id (StringName) -> Dictionary
var trees := {} # tree name -> Dictionary
var tier_mastery := {} # tier -> Mastery required
var rules: Array = []
var _by_name := {}
var _order: Array[StringName] = []


static func load_file(path: String = DEFAULT_PATH) -> AbilityTreeData:
	var out := AbilityTreeData.new()
	if not FileAccess.file_exists(path):
		push_error("Ability tree data missing: %s (run tools/import_ability_tree.gd)" % path)
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ability tree data unreadable: %s" % path)
		return out
	out.load_dict(parsed)
	return out


func load_dict(d: Dictionary) -> void:
	for t in d.get("tiers", []):
		tier_mastery[int(t.tier)] = int(t.mastery)
	for t in d.get("trees", []):
		trees[t.name] = t
	for a in d.get("abilities", []):
		a.tier = int(a.tier)
		a.mastery_required = int(a.get("mastery_required", 0))
		var id := StringName(a.id)
		abilities[id] = a
		_by_name[a.name] = id
		_order.append(id)
	for i in d.get("items", []):
		i.tier = int(i.tier)
		items[StringName(i.id)] = i
	rules = d.get("rules", [])


func ability(id: StringName) -> Dictionary:
	return abilities.get(id, {})


func id_of(ability_name: String) -> StringName:
	return _by_name.get(ability_name, &"")


## Ability ids in sheet order, optionally only one tree's.
func ids(tree: String = "") -> Array[StringName]:
	if tree == "":
		return _order.duplicate()
	return _order.filter(func(id): return abilities[id].tree == tree)


func tree_names() -> Array:
	return trees.keys()


## The element trees ("any element Mastery N" means any one of these).
func element_trees() -> Array:
	return trees.values().filter(func(t): return t.item_type == "Scroll").map(func(t): return t.name)
