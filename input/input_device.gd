class_name InputDevice
extends RefCounted
## Which device the player is using: keyboard and mouse, or a controller (any pad
## Godot recognises: Xbox, PlayStation, Switch, Steam…). The last one touched wins,
## so button hints, aiming and movement follow whichever is in your hands.
## Plain static state: one local player per game window.

enum Kind { KEYBOARD, GAMEPAD }

## The family of buttons to name in hints, from the pad's name.
enum Style { XBOX, PLAYSTATION, NINTENDO }

## Below this, a stick counts as centred (radial).
const STICK_DEADZONE := 0.2
## A stick or trigger pushed this far switches the device to the controller.
const SWITCH_THRESHOLD := 0.5
## Mouse movement smaller than this (pixels) doesn't switch back to the keyboard
## (a table knock shouldn't swap the button hints).
const MOUSE_SWITCH_PIXELS := 6.0

static var last: Kind = Kind.KEYBOARD
## The pad last used (device id), or -1.
static var pad: int = -1
## Bumped whenever `last` changes, so views can redraw their hints.
static var revision: int = 0


## Notes which device `event` came from. True if the device changed.
static func note(event: InputEvent) -> bool:
	var kind := last
	if event is InputEventJoypadButton:
		kind = Kind.GAMEPAD
		pad = event.device
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) < SWITCH_THRESHOLD:
			return false
		kind = Kind.GAMEPAD
		pad = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		kind = Kind.KEYBOARD
	elif event is InputEventMouseMotion:
		if event.relative.length() < MOUSE_SWITCH_PIXELS:
			return false
		kind = Kind.KEYBOARD
	else:
		return false
	if kind == last:
		return false
	set_kind(kind)
	return true


static func set_kind(kind: Kind) -> void:
	if kind != last:
		last = kind
		revision += 1


static func using_pad() -> bool:
	return last == Kind.GAMEPAD


## The pad to read: the last one used, else the first connected, else -1.
static func active_pad() -> int:
	var pads := Input.get_connected_joypads()
	if pads.has(pad):
		return pad
	return pads[0] if not pads.is_empty() else -1


## Which buttons to name, from the pad's name.
static func style() -> Style:
	var id := active_pad()
	var name := Input.get_joy_name(id).to_lower() if id >= 0 else ""
	if name.contains("playstation") or name.contains("dualshock") or name.contains("dualsense") \
			or name.contains("ps4") or name.contains("ps5") or name.contains("sony"):
		return Style.PLAYSTATION
	if name.contains("nintendo") or name.contains("switch") or name.contains("joy-con"):
		return Style.NINTENDO
	return Style.XBOX


## The left stick (movement), screen space (x right, y down), length 0..1, with a
## radial deadzone.
static func left_stick() -> Vector2:
	return _stick(&"pad_move_left", &"pad_move_right", &"pad_move_up", &"pad_move_down")


## The right stick (aiming), as left_stick.
static func right_stick() -> Vector2:
	return _stick(&"pad_aim_left", &"pad_aim_right", &"pad_aim_up", &"pad_aim_down")


static func _stick(neg_x: StringName, pos_x: StringName, neg_y: StringName, pos_y: StringName) -> Vector2:
	if not InputMap.has_action(neg_x):
		return Vector2.ZERO
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y, STICK_DEADZONE)
