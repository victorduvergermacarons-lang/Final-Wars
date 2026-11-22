class_name InputActions
extends RefCounted
## Registers the game's input actions at startup: every control on the keyboard and
## mouse and on a controller (2026-11-22, the Hades-style layout). The table below
## is the one place the layout lives; the Escape menu's Controls tab and the button
## hints (hint) read it.
##
## Controller buttons are named by position (Godot's JOY_BUTTON_X is the left face
## button on any pad): left / top / bottom / right = Xbox X / Y / A / B,
## PlayStation Square / Triangle / Cross / Circle, Nintendo Y / X / B / A.

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

## The four ability slots (the wheel): keyboard / mouse, then the controller's face
## button. Slot 1 the weapon, 2 ranged attacks, 3 dash (Earth: defense), 4 the rest.
const SLOT_COUNT := 4
const SLOT_INPUTS := [
	[MOUSE_BUTTON_LEFT, JOY_BUTTON_X],
	[MOUSE_BUTTON_RIGHT, JOY_BUTTON_Y],
	[KEY_Q, JOY_BUTTON_A],
	[KEY_SHIFT, JOY_BUTTON_B],
]

## Every other action: keys (or mouse buttons, as {"mouse": n}), then controller
## buttons (ints) or axes ({"axis": n, "dir": ±1}).
const OTHER := {
	&"timing_press": [[KEY_SPACE], [{"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}]],
	&"element_power": [[KEY_R], [JOY_BUTTON_RIGHT_SHOULDER]],
	&"interact": [[KEY_E], [JOY_BUTTON_LEFT_SHOULDER]],
	&"target_next": [[KEY_TAB], [{"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1}, JOY_BUTTON_DPAD_RIGHT]],
	## Esc / Menu: cancel the aim or cast, close menus, clear the target, open the menu.
	&"target_clear": [[KEY_ESCAPE], [JOY_BUTTON_START]],
	## D-pad left: cancel the aim and clear the target, never opening a menu.
	&"cancel_aim": [[], [JOY_BUTTON_DPAD_LEFT]],
	&"potion_health": [[KEY_1], [JOY_BUTTON_DPAD_UP]],
	&"potion_mana": [[KEY_2], [JOY_BUTTON_DPAD_DOWN]],
	&"toggle_spellbook": [[KEY_P], []],
	&"toggle_character": [[KEY_C], []],
	&"toggle_inventory": [[KEY_B], [JOY_BUTTON_BACK, JOY_BUTTON_TOUCHPAD]],
	&"toggle_quest_log": [[KEY_L], []],
	&"toggle_trees": [[KEY_T], []],
	&"toggle_console": [[KEY_QUOTELEFT], []],
}

## The sticks, as four half-axes each (InputDevice reads them with Input.get_vector).
const STICKS := {
	&"pad_move_left": [JOY_AXIS_LEFT_X, -1],
	&"pad_move_right": [JOY_AXIS_LEFT_X, 1],
	&"pad_move_up": [JOY_AXIS_LEFT_Y, -1],
	&"pad_move_down": [JOY_AXIS_LEFT_Y, 1],
	&"pad_aim_left": [JOY_AXIS_RIGHT_X, -1],
	&"pad_aim_right": [JOY_AXIS_RIGHT_X, 1],
	&"pad_aim_up": [JOY_AXIS_RIGHT_Y, -1],
	&"pad_aim_down": [JOY_AXIS_RIGHT_Y, 1],
}

## A trigger counts as pressed past this.
const TRIGGER_DEADZONE := 0.4

## Hint names per controller input and pad style (InputDevice.Style order: Xbox,
## PlayStation, Nintendo).
const PAD_NAMES := {
	JOY_BUTTON_X: ["X", "Square", "Y"],
	JOY_BUTTON_Y: ["Y", "Triangle", "X"],
	JOY_BUTTON_A: ["A", "Cross", "B"],
	JOY_BUTTON_B: ["B", "Circle", "A"],
	JOY_BUTTON_LEFT_SHOULDER: ["LB", "L1", "L"],
	JOY_BUTTON_RIGHT_SHOULDER: ["RB", "R1", "R"],
	JOY_BUTTON_START: ["Menu", "Options", "+"],
	JOY_BUTTON_BACK: ["View", "Share", "-"],
	JOY_BUTTON_DPAD_UP: ["D-pad up", "D-pad up", "D-pad up"],
	JOY_BUTTON_DPAD_DOWN: ["D-pad down", "D-pad down", "D-pad down"],
	JOY_BUTTON_DPAD_LEFT: ["D-pad left", "D-pad left", "D-pad left"],
	JOY_BUTTON_DPAD_RIGHT: ["D-pad right", "D-pad right", "D-pad right"],
}
const AXIS_NAMES := {
	JOY_AXIS_TRIGGER_LEFT: ["LT", "L2", "ZL"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "R2", "ZR"],
}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click"}


## Action name for wheel slot i (0-based).
static func slot_action(i: int) -> StringName:
	return StringName("action_slot_%d" % (i + 1))


static func ensure_registered() -> void:
	for action in MOVE:
		_add(action, MOVE[action], [])
	for i in SLOT_COUNT:
		_add(slot_action(i), [SLOT_INPUTS[i][0]], [SLOT_INPUTS[i][1]])
	for action in OTHER:
		_add(action, OTHER[action][0], OTHER[action][1])
	for action in STICKS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.1)
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = STICKS[action][0]
		m.axis_value = STICKS[action][1]
		InputMap.action_add_event(action, m)


static func _add(action: StringName, keys: Array, pad: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, TRIGGER_DEADZONE)
	for k in keys:
		InputMap.action_add_event(action, _key_event(k))
	for p in pad:
		InputMap.action_add_event(action, _pad_event(p))


static func _key_event(k) -> InputEvent:
	if k in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and k is int and k < 8:
		var b := InputEventMouseButton.new()
		b.button_index = k
		return b
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	return ev


static func _pad_event(p) -> InputEvent:
	if p is Dictionary:
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = p.axis
		m.axis_value = p.dir
		return m
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = p
	return b


## The keyboard / mouse inputs and the controller inputs of `action`.
static func inputs_of(action: StringName) -> Array:
	if action in MOVE:
		return [MOVE[action], []]
	for i in SLOT_COUNT:
		if slot_action(i) == action:
			return [[SLOT_INPUTS[i][0]], [SLOT_INPUTS[i][1]]]
	return OTHER.get(action, [[], []])


## What to press for `action` on `kind` (the current device by default): "Q",
## "Left click", "X", "RT"… The first input only; "" if none.
static func hint(action: StringName, kind: int = -1) -> String:
	if kind < 0:
		kind = InputDevice.last
	var both := inputs_of(action)
	var list: Array = both[1] if kind == InputDevice.Kind.GAMEPAD else both[0]
	if list.is_empty():
		return ""
	return pad_name(list[0]) if kind == InputDevice.Kind.GAMEPAD else key_name(list[0])


static func key_name(k: int) -> String:
	if MOUSE_NAMES.has(k) and k < 8:
		return MOUSE_NAMES[k]
	return OS.get_keycode_string(k)


static func pad_name(p, style: int = -1) -> String:
	if style < 0:
		style = InputDevice.style()
	if p is Dictionary:
		return AXIS_NAMES.get(p.axis, ["?", "?", "?"])[style]
	return PAD_NAMES.get(p, ["?", "?", "?"])[style]
