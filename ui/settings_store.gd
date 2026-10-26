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


## Bus volumes (0..1 slider values) by bus name; defaults to full volume.
static func load_volumes(path: String = DEFAULT_PATH) -> Dictionary:
	var out := {}
	for bus in AudioConfig.BUSES:
		out[bus] = 1.0
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return out
	for bus in AudioConfig.BUSES:
		out[bus] = clampf(float(cfg.get_value("audio", bus, 1.0)), 0.0, 1.0)
	return out


static func save_volumes(volumes: Dictionary, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # keep other sections
	for bus in volumes:
		cfg.set_value("audio", bus, float(volumes[bus]))
	cfg.save(path)
