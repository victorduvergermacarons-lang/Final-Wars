class_name SettingsStore
extends RefCounted
## Client preferences saved on this computer (not game progress).

const DEFAULT_PATH := "user://settings.cfg"


## The action bar of character `owner` (each keeps its own, 2026-11-28; "" = the one
## shared layout, as before). A character without one yet starts with an empty bar
## (its abilities are placed as it has them) and the shared layout's keybinds.
static func load_action_bar(bar: ActionBarModel, path: String = DEFAULT_PATH, owner: String = "") -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var d = cfg.get_value(_bar_section(owner), "layout", {}) if cfg.has_section_key(_bar_section(owner), "layout") else null
	if d == null and owner != "":
		var shared = cfg.get_value("action_bar", "layout", {})
		d = {"keys": shared.get("keys", [])} if typeof(shared) == TYPE_DICTIONARY else {}
	if typeof(d) == TYPE_DICTIONARY:
		bar.load_dict(d)


static func _bar_section(owner: String) -> String:
	return "action_bar" if owner == "" else "action_bar." + CharacterStore.slug(owner)


## Forgets a character's action bar (it was deleted).
static func forget_action_bar(owner: String, path: String = DEFAULT_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(_bar_section(owner)):
		return
	cfg.erase_section(_bar_section(owner))
	cfg.save(path)


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


static func save_action_bar(bar: ActionBarModel, path: String = DEFAULT_PATH, owner: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(path) # keep other sections if any
	cfg.set_value(_bar_section(owner), "layout", bar.to_dict())
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
