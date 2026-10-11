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
}

var rules: CombatRules
var abilities := {} # id -> AbilityDef
var items := {} # id -> ItemDef
var enemies := {} # id -> EnemyDef
var heroes := {} # id -> HeroDef
var zones := {} # id -> ZoneDef


func _init() -> void:
	reload()


func reload() -> void:
	rules = load(RULES_PATH)
	abilities = _load_dir(DIRS.abilities)
	items = _load_dir(DIRS.items)
	enemies = _load_dir(DIRS.enemies)
	heroes = _load_dir(DIRS.heroes)
	zones = _load_dir(DIRS.zones)


## Every problem found in the loaded content; empty when all is valid.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for a in abilities.values():
		errors.append_array(a.validate())
	for i in items.values():
		errors.append_array(i.validate())
	for z in zones.values():
		errors.append_array(z.validate())
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
