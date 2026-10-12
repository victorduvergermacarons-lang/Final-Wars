extends SceneTree
## Converts the ability spreadsheet into content/tree/ability_tree.json.
##   godot --headless --path . -s res://tools/import_ability_tree.gd [-- path/to/sheet.xlsx]
## Prints every problem it finds; writes nothing if there are errors (exit code 1).

# Preloaded (not by class name) so this works even before the editor has
# scanned the project's classes.
const Reader := preload("res://tools/xlsx_reader.gd")
const Importer := preload("res://tools/ability_tree_importer.gd")

const DEFAULT_SOURCE := "res://design/Ability_Tree.xlsx"
const OUTPUT := "res://content/tree/ability_tree.json"


func _init() -> void:
	var source := DEFAULT_SOURCE
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		source = args[0]
	print("Reading %s" % source)
	var book := Reader.read(source)
	if book.error != "":
		printerr("ERROR: " + book.error)
		quit(1)
		return
	var shown := source.trim_prefix("res://") if source.begins_with("res://") else source.get_file()
	var result := Importer.convert(book, shown)
	for w in result.warnings:
		print("WARNING: " + w)
	for e in result.errors:
		printerr("ERROR: " + e)
	if not result.errors.is_empty():
		printerr("%d error(s); %s was NOT updated." % [result.errors.size(), OUTPUT])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var f := FileAccess.open(OUTPUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(result.data, "\t", false) + "\n")
	f.close()
	var data: Dictionary = result.data
	print("Imported %d abilities and %d items in %d trees -> %s" % [data.abilities.size(),
			data.items.size(), data.trees.size(), OUTPUT])
	quit(0)
