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


## A UI preference ([ui] section), or `default` if not saved yet.
static func load_ui(key: String, default: Variant, path: String = DEFAULT_PATH) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return default
	return cfg.get_value("ui", key, default)


static func save_ui(key: String, value: Variant, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # keep other sections
	cfg.set_value("ui", key, value)
	cfg.save(path)


static func save_action_bar(bar: ActionBarModel, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # keep other sections if any
	cfg.set_value("action_bar", "layout", bar.to_dict())
	cfg.save(path)
