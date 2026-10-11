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
	&"ability_1": [KEY_1],
	&"ability_2": [KEY_2],
	&"ability_3": [KEY_3],
	&"ability_4": [KEY_4],
	&"ability_5": [KEY_5],
	# Temporary until the equip panel (step 10).
	&"debug_equip_sword": [KEY_F1],
	&"debug_equip_staff": [KEY_F2],
	&"debug_equip_shield": [KEY_F3],
	&"debug_equip_charm": [KEY_F4],
}


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
	if not InputMap.has_action(&"select_target"):
		InputMap.add_action(&"select_target")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"select_target", click)
