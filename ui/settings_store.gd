class_name SettingsStore
extends RefCounted
## Client preferences saved on this computer (not game progress).

const DEFAULT_PATH := "user://settings.cfg"


static func load_action_bar(bar: ActionBarModel, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var d = cfg.get_value("action_bar", "layout", {})
	if typeof(d) == TYPE_DICTIONARY:
		bar.load_dict(d)


static func save_action_bar(bar: ActionBarModel, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # keep other sections if any
	cfg.set_value("action_bar", "layout", bar.to_dict())
	cfg.save(path)
