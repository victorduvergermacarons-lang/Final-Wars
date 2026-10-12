class_name InputActions
extends RefCounted
## Registers the game's input actions at startup, so default keybinds live in
## code and can be rebound at runtime (action bar keybinds, step 10).

const MOVE := {
	&"move_up": [KEY_W, KEY_UP], ## grid (0,-1): screen up-right
	&"move_right": [KEY_D, KEY_RIGHT], ## grid (1,0): screen down-right
	&"move_down": [KEY_S, KEY_DOWN], ## grid (0,1): screen down-left
	&"move_left": [KEY_A, KEY_LEFT], ## grid (-1,0): screen up-left
}
const DIRECTIONS := {
	&"move_up": Vector2i.UP,
	&"move_right": Vector2i.RIGHT,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
}
const OTHER := {
	&"target_next": [KEY_TAB],
	&"target_clear": [KEY_ESCAPE],
	&"release": [KEY_R],
	&"toggle_spellbook": [KEY_P],
	&"toggle_character": [KEY_C],
	&"toggle_inventory": [KEY_B],
	&"toggle_quest_log": [KEY_L],
	&"toggle_trees": [KEY_T],
	&"interact": [KEY_E],
}


## Keys that can't be bound to action bar slots.
static func is_reserved_key(key: int) -> bool:
	if key == KEY_NONE or key == KEY_ESCAPE:
		return true
	for table in [MOVE, OTHER]:
		for action in table:
			if table[action].has(key):
				return true
	return false


## Action name for switching to action bar page p (0-based): Shift + number.
static func page_action(p: int) -> StringName:
	return StringName("action_page_%d" % (p + 1))


## Action name for action bar slot i (0-based).
static func slot_action(i: int) -> StringName:
	return StringName("action_slot_%d" % (i + 1))


## Points the action_slot_N actions at the action bar's current keys.
static func apply_action_bar_keys(bar: ActionBarModel) -> void:
	for i in ActionBarModel.SLOT_COUNT:
		var action := slot_action(i)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		if bar.keys[i] != KEY_NONE:
			var ev := InputEventKey.new()
			ev.physical_keycode = bar.keys[i]
			InputMap.action_add_event(action, ev)


static func ensure_registered() -> void:
	for table in [MOVE, OTHER]:
		for action in table:
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action)
			for key in table[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)
	for p in ActionBarModel.PAGE_COUNT:
		var action := page_action(p)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = ActionBarModel.DEFAULT_KEYS[p]
			ev.shift_pressed = true
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action(&"select_target"):
		InputMap.add_action(&"select_target")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"select_target", click)
