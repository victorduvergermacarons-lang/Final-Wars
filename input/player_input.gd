class_name PlayerInput
extends Node
## Turns the local player's keys, clicks and controller into intents. Only sends
## intents; the host decides what actually happens. The layout (2026-11-22, Hades
## style) is in InputActions; which device is in use, in InputDevice.

## Right-click on another player in the world (the HUD opens Trade / Duel).
signal player_menu_requested(hero_id: int, at: Vector2)

## Free movement: the held keys give one of 8 directions on screen (W = up the
## screen), sent with the mouse's angle as a `move` intent whenever either
## changes, and every sim tick while walking (each predicted tick then has its
## own input number to reconcile against; see ClientWorld.predict_tick).
## The facing angle is resent once the mouse has turned this far (radians).
const ANGLE_STEP := 0.05
const TAB_RANGE := 12

var session
var client: ClientState
var view: WorldView

var _held := Vector2i.ZERO
## The left stick (screen space, 0..1) while it's pushed, else zero.
var _stick := Vector2.ZERO
var _sent_stick := Vector2.ZERO
var _sent_dir := Vector2i(99, 99)
var _sent_angle := 999.0
var _sent_at := -999.0
## When a direction key was last held (render time), and how long "stop" is re-sent
## after it (movement travels unreliably over the network).
var _walked_at := -999.0
const STOP_RESEND_SECONDS := 0.5
## The stick is resent once it has moved this much (0..1).
const STICK_STEP := 0.05
## Aiming a skillshot or ground ability: {"ability", "action" (key to release, or
## &"" when started by clicking the bar: then a left click fires), "mouse" (where
## the mouse was when aiming started)}.
var _aiming := {}


func setup(p_session, p_client: ClientState, p_view: WorldView) -> void:
	session = p_session
	client = p_client
	view = p_view
	if not Input.joy_connection_changed.is_connected(_on_joy_connection):
		Input.joy_connection_changed.connect(_on_joy_connection)


## A controller plugged in or out: say so; unplugging the one in use goes back to
## the keyboard and mouse.
func _on_joy_connection(device: int, connected: bool) -> void:
	if client == null:
		return
	if connected:
		client.say("Controller connected: %s" % Input.get_joy_name(device))
	else:
		client.say("Controller disconnected")
		if InputDevice.using_pad() and Input.get_connected_joypads().is_empty():
			InputDevice.set_kind(InputDevice.Kind.KEYBOARD)


func _physics_process(_delta: float) -> void:
	if session == null:
		return
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		_held = Vector2i.ZERO
		if _sent_dir != Vector2i.ZERO and hero != null:
			_send_move(Vector2i.ZERO, _sent_angle if absf(_sent_angle) < 10.0 else hero.facing_angle)
		return
	# Typing in a text box (debug console) doesn't walk.
	var typing := get_viewport().gui_get_focus_owner() is LineEdit if is_inside_tree() else false
	_held = Vector2i.ZERO if typing else held_direction()
	_stick = Vector2.ZERO if typing or _held != Vector2i.ZERO else InputDevice.left_stick()
	if not client.ally_select.is_empty():
		_steer_ally_select(_held, _stick)
		_held = Vector2i.ZERO # the hero stands still while choosing
		_stick = Vector2.ZERO
	# Without a view (tests), keep the last angle sent.
	var angle := _sent_angle if absf(_sent_angle) <= PI else hero.aim_angle
	if InputDevice.using_pad():
		angle = pad_facing(hero, angle)
	elif view != null and is_inside_tree():
		angle = mouse_angle(hero, world_mouse())
	var t: float = session.render_time()
	var tick: float = session.rules().tick_seconds
	# Every tick while walking; on a client also for STOP_RESEND_SECONDS after
	# stopping, since movement travels unreliably (Net.send_intent) and a lost "stop"
	# must not keep you walking.
	var walking := _held != Vector2i.ZERO or _stick != Vector2.ZERO
	if walking:
		_walked_at = t
	var resend: bool = walking \
			or (session is ClientSession and t - _walked_at < STOP_RESEND_SECONDS)
	if _held != _sent_dir or _stick.distance_to(_sent_stick) > STICK_STEP \
			or absf(angle_difference(angle, _sent_angle)) > ANGLE_STEP \
			or (resend and t - _sent_at >= tick - 0.001):
		_send_move(_held, angle)


func _send_move(dir: Vector2i, angle: float) -> void:
	_sent_dir = dir
	_sent_angle = angle
	_sent_stick = _stick if dir == Vector2i.ZERO else Vector2.ZERO
	_sent_at = session.render_time()
	var intent := {"type": "move", "dir": dir, "face": angle}
	if _sent_stick != Vector2.ZERO:
		intent.stick = _sent_stick
	session.send_intent(intent)


## The grid-space angle from the hero to a point on the map (world coordinates).
func mouse_angle(hero: Hero, world_pos: Vector2) -> float:
	var grid: GridModel = session.grid()
	var at := hero.move.position_at(session.render_time())
	var off := Iso.from_screen(world_pos, grid.height_at(hero.tile())) - at
	return off.angle() if off.length() > 0.05 else hero.aim_angle


## Turns the hero toward a point on the map (world coordinates): sends the angle
## right away (the next move intent would carry it anyway).
func face_toward(world_pos: Vector2) -> void:
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		return
	_send_move(_held, mouse_angle(hero, world_pos))


## The held keys as one of 8 screen directions (x right, y down; zero if none or
## opposite keys cancel).
func held_direction() -> Vector2i:
	var d := Vector2i.ZERO
	for action in InputActions.DIRECTIONS:
		if Input.is_action_pressed(action):
			d += InputActions.DIRECTIONS[action]
	return Vector2i(clampi(d.x, -1, 1), clampi(d.y, -1, 1))


func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return
	# The timing button (Space, RT) during a timing bar is the press (before anything
	# else uses it). So is the ability's own button again (_second_press).
	if event.is_action_pressed(&"timing_press") and press_timing_bar():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"timing_press") and switch_mode():
		get_viewport().set_input_as_handled()
		return
	if not _aiming.is_empty() and _aim_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"target_next"):
		_target_next_enemy()
	elif (event.is_action_pressed(&"target_clear") or event.is_action_pressed(&"cancel_aim")) \
			and not client.ally_select.is_empty():
		end_ally_select()
	elif event.is_action_pressed(&"target_clear") or event.is_action_pressed(&"cancel_aim"):
		client.target_id = -1
	elif event.is_action_pressed(&"interact"):
		var hero: Hero = session.local_hero()
		if hero != null and not hero.alive:
			session.send_intent({"type": "release"}) # dead: back to the graveyard
		elif not pick_up_nearest():
			talk_to_nearest()
	elif event.is_action_pressed(&"potion_health"):
		use_potion("health")
	elif event.is_action_pressed(&"potion_mana"):
		use_potion("mana")
	elif event.is_action_pressed(&"element_power"):
		client.error("Element powers aren't in the game yet")
	elif _player_menu(event):
		pass
	else:
		for i in ActionBarModel.SLOT_COUNT:
			if event.is_action_pressed(InputActions.slot_action(i), false, true):
				press_button(i)
				get_viewport().set_input_as_handled()
				return


## Right-click on another player out of combat opens Trade / Duel (in combat the
## right button is your special). True if it did.
func _player_menu(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return false
	var hero: Hero = session.local_hero()
	if view == null or hero == null or hero.in_combat(session.now()):
		return false
	var picked: Actor = view.actor_at(view.get_global_mouse_position())
	if picked is Hero and picked.id != session.local_hero_id:
		player_menu_requested.emit(picked.id, get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
		return true
	return false


## D-pad up / 1: the first health potion in the bag; down / 2: mana.
func use_potion(kind: String) -> void:
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	for i in hero.bag.size():
		var item := hero.bag.item_at(i)
		if item != null and item.use_ability != null and String(item.id).contains(kind + "_potion"):
			session.send_intent({"type": "use_item", "bag_index": i})
			return
	client.error("You have no %s potion" % kind)


## Presses the local hero's timing bar, if one is running: sends how far into
## the bar this is, as seen on this screen (the host judges it), and for an aimed
## ability where the cursor points. The press goes to the bar's next input, as the
## host will count it (TimingBarDef.input_for_press). True if a bar was running.
func press_timing_bar() -> bool:
	var hero: Hero = session.local_hero()
	if hero == null or hero.casting.get("kind", "") != "timing":
		return false
	var start := float(hero.casting.start)
	var state: Dictionary = client.timing_press
	if float(state.get("start", -1.0)) != start:
		state = {"start": start, "next": 0, "presses": []}
		client.timing_press = state
	if _holding(state):
		return true
	var bar: TimingBarDef = hero.casting.ability.timing_bar
	var inputs := bar.inputs()
	var at: float = session.render_time() - start
	var i := bar.input_for_press(state.next, at)
	if i >= inputs.size():
		return true # every input is played
	# On a blue zone this starts a hold, judged when the button is let go.
	state.presses.append({"index": i, "at": at,
			"holding": inputs[i].kind == "hold" and TimingBarDef.starts_hold(inputs[i], at)})
	state.next = i + 1
	session.send_intent(_with_aim({"type": "timing_press", "at": at}))
	return true


## A bar that goes off by itself (AbilityDef.bar_goes_off_at_end: Rock Throw) and
## hasn't been pressed: at its end the client presses for the player, with the
## cursor's aim, so it goes where they point (past every window: miss power).
func _go_off_at_bar_end() -> void:
	if session == null:
		return
	var hero: Hero = session.local_hero()
	if hero == null or hero.casting.get("kind", "") != "timing":
		return
	var ability: AbilityDef = hero.casting.ability
	if not ability.bar_goes_off_at_end:
		return
	var start := float(hero.casting.start)
	var state: Dictionary = client.timing_press
	if float(state.get("start", -1.0)) == start and not state.get("presses", []).is_empty():
		return # pressed already (or pressed for them)
	var at: float = session.render_time() - start
	if at < ability.timing_bar.seconds - session.rules().tick_seconds:
		return
	client.timing_press = {"start": start, "next": ability.timing_bar.inputs().size(),
			"presses": [{"index": -1, "at": at, "holding": false}]}
	session.send_intent(_with_aim({"type": "timing_press", "at": at}))


## Letting go of right-click during a hold ends it (the host judges how long it was).
func release_timing_bar() -> void:
	var state: Dictionary = client.timing_press
	if not _holding(state):
		return
	var hero: Hero = session.local_hero()
	var at: float = session.render_time() - float(state.start)
	if hero != null and hero.casting.get("kind", "") == "timing" and float(hero.casting.start) == float(state.start):
		at = minf(at, hero.casting.ability.timing_bar.seconds)
	state.presses.back().release = at
	session.send_intent(_with_aim({"type": "timing_release", "at": at}))


## The current bar's last press is a hold not let go yet.
static func _holding(state: Dictionary) -> bool:
	var presses: Array = state.get("presses", [])
	return not presses.is_empty() and presses.back().holding and not presses.back().has("release")


## Adds where the cursor points while an aimed ability's bar runs.
func _with_aim(intent: Dictionary) -> Dictionary:
	if _aiming.get("during_bar", false) and session.local_hero() != null and session.local_hero().alive:
		intent.aim = aim_point()
	return intent


func _input(event: InputEvent) -> void:
	# Every event says which device is in use (button hints, aiming, movement).
	InputDevice.note(event)
	# Letting go of the timing button (Space, RT) ends a hold, wherever the pointer
	# is (even over the HUD).
	if session != null and event.is_action_released(&"timing_press"):
		release_timing_bar()
	if session != null:
		for i in ActionBarModel.SLOT_COUNT:
			if event.is_action_released(InputActions.slot_action(i)):
				release_button(i)
	# So does letting go of the hotkey that played the bar (a second press).
	if session != null and _bar_key != &"" and event.is_action_released(_bar_key):
		_bar_key = &""
		release_timing_bar()


## Fires whatever ability is in action bar slot i. `key` is the action that was
## pressed (aimed abilities fire when it's released); "" for a click on the bar.
func use_slot(i: int, key: StringName = &"") -> void:
	var id := client.action_bar.slots[i]
	if id == &"":
		return
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	if ActionBarModel.is_item_slot(id):
		use_item(ActionBarModel.item_id_of(id))
		return
	var ability := hero.find_ability(id)
	if ability == null:
		client.error("You can't use that right now")
		return
	use_ability(ability, key)


## Uses one of the named consumable from the bag.
func use_item(item_id: StringName) -> void:
	var hero: Hero = session.local_hero()
	for i in hero.bag.size():
		var item := hero.bag.item_at(i)
		if item != null and item.id == item_id:
			session.send_intent({"type": "use_item", "bag_index": i})
			return
	client.error("You don't have any left")


## The hotkey that played the running timing bar (a second press): letting it go
## ends a hold, like letting go of right-click or Space.
var _bar_key: StringName = &""


func use_ability(ability: AbilityDef, key: StringName = &"") -> void:
	var hero: Hero = session.local_hero()
	if hero != null and _second_press(hero, ability, key):
		return
	if AimPreview.is_aimed(ability) and aims_during_bar(ability):
		_start_bar_aiming(ability)
		return
	if ability.uses_hitbox() and ability.hitbox.shape == HitboxDef.Shape.CONE \
			and not (ability.manual_aim and InputDevice.using_pad()):
		# A melee swing goes off at once toward the mouse (no hold to aim).
		session.send_intent({"type": "cast", "ability": ability.id, "target": -1, "aim": point_for(ability)})
		return
	if AimPreview.is_aimed(ability):
		start_aiming(ability, key)
		return
	var picked := Targeting.pick(hero, ability, _target_for(hero, ability))
	if picked.error != "":
		client.error(picked.error)
		return
	session.send_intent({"type": "cast", "ability": ability.id, "target": picked.target})


## Pressing an ability's key while it is already chosen; pressing another ability's
## key switches to that one without using either (2026-11-15).
## - Its timing bar is running: the press plays the bar, exactly like a right-click
##   or Space (aimed at the cursor), and letting the key go ends a hold (restored
##   2026-11-21, user request, after a few hours where only right-click and Space did).
## - It is being aimed (no bar): the press fires it where the cursor points.
## - Another ability's bar is running: that bar stops unplayed (the host gives its
##   global cooldown back) and the new ability starts as if nothing ran.
## Key repeat never counts: held keys send no repeated presses (allow_echo off).
## True if the press was handled here.
func _second_press(hero: Hero, ability: AbilityDef, key: StringName) -> bool:
	var c: Dictionary = hero.casting
	if c.get("kind", "") == "timing" and hero.alive:
		if c.ability.id == ability.id:
			_bar_key = key
			press_timing_bar()
			return true
		session.send_intent({"type": "cancel_bar"}) # then the new ability, below
		_bar_key = &""
		cancel_aiming()
		return false
	if not _aiming.is_empty() and not _aiming.get("during_bar", false) and _aiming.ability.id == ability.id:
		fire_aimed()
		return true
	return false


## E: talk to (or use) the NPC or object in front of you, else examine a quest
## spot beside you, else talk to the nearest one within reach.
func talk_to_nearest() -> void:
	var what := interaction(session)
	if what.is_empty():
		client.error("There's no one to talk to here")
	elif what.kind == "examine":
		session.send_intent({"type": "examine", "tile": what.tile})
	else:
		session.send_intent({"type": "talk", "npc": what.npc.id})


## What E would do: {"kind": "talk", "npc": Npc} or {"kind": "examine", "tile":
## Vector2i} (an investigate spot within 1 tile), or {} if nothing.
static func interaction(session) -> Dictionary:
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		return {}
	var npc := talk_target(session)
	if npc != null and npc.covers(hero.front_tile()):
		return {"kind": "talk", "npc": npc}
	var best_spot: Variant = null
	for p in QuestLog.open_spots(hero, ContentDB.quests, session.zone().id):
		var d := GridModel.distance(hero.tile(), p)
		if d <= 1 and (best_spot == null or d < GridModel.distance(hero.tile(), best_spot)):
			best_spot = p
	if best_spot != null:
		return {"kind": "examine", "tile": best_spot}
	return {"kind": "talk", "npc": npc} if npc != null else {}


## The NPC E would talk to: the one in front of the local hero, else the nearest
## within talking range. Null if none (the view shows an "[E] Talk" prompt on it).
static func talk_target(session) -> Actor:
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		return null
	var best: Actor = null
	for a in session.actors():
		if not (a is Npc):
			continue
		var d := GridModel.distance(hero.tile(), a.tile())
		if d > WorldSim.TALK_RANGE:
			continue
		if a.covers(hero.front_tile()):
			best = a
			break
		if best == null or d < GridModel.distance(hero.tile(), best.tile()):
			best = a
	return best


## A neutral creature (a grazing stag) isn't a foe until it fights.
static func _peaceful(a: Actor) -> bool:
	return a is Enemy and (a as Enemy).def.neutral and (a as Enemy).state != Enemy.State.COMBAT


## Your own drop nearest the hero within pickup range, or {}.
func nearest_drop() -> Dictionary:
	var hero: Hero = session.local_hero()
	if hero == null:
		return {}
	var best := {}
	var best_d: float = session.rules().party_play.pickup_range
	for d in session.my_drops():
		var dist: float = hero.move.pos.distance_to(d.pos)
		if dist <= best_d:
			best = d
			best_d = dist
	return best


## E picks up your nearest drop in reach (before talking). True if one was there.
func pick_up_nearest() -> bool:
	var d := nearest_drop()
	if d.is_empty():
		return false
	session.send_intent({"type": "pick_up", "drop": d.id})
	return true


func _target_next_enemy() -> void:
	var hero: Hero = session.local_hero()
	var candidates: Array = []
	for a in session.actors():
		if a.alive and hero.is_hostile_to(a) and not a.evading and not _peaceful(a) \
				and GridModel.distance(hero.tile(), a.tile()) <= TAB_RANGE:
			candidates.append(a)
	if candidates.is_empty():
		client.target_id = -1
		return
	candidates.sort_custom(func(x, y):
		var dx := GridModel.distance(hero.tile(), x.tile())
		var dy := GridModel.distance(hero.tile(), y.tile())
		return dx < dy or (dx == dy and x.id < y.id))
	var ids: Array = candidates.map(func(a): return a.id)
	var i := ids.find(client.target_id)
	client.target_id = ids[(i + 1) % ids.size()]


## Starts aiming a skillshot or ground ability: the affected tiles follow the
## mouse (or the targeted enemy until the mouse moves). Releasing `key` fires; with
## no key (clicked on the bar), a left click on the map fires. Esc or a right
## click cancels.
func start_aiming(ability: AbilityDef, key: StringName = &"") -> void:
	_aiming = {"ability": ability, "action": key, "mouse": _screen_mouse()}
	_update_aim()


## An aimed ability with a timing bar starts its bar at once and aims at the end:
## it fires where the cursor points when the bar is done.
func aims_during_bar(ability: AbilityDef) -> bool:
	return ability.timing_bar != null and session.rules().timing_bars_enabled


## Starts the bar of an aimed ability: the cast goes now (aimed where the cursor is,
## for range checks), the affected tiles keep following the cursor while the bar
## runs, and each input sends the cursor's position (the last one decides).
func _start_bar_aiming(ability: AbilityDef) -> void:
	_aiming = {"ability": ability, "action": &"", "mouse": _screen_mouse(), "during_bar": true,
			"sent_at": session.render_time(), "bar_start": -1.0}
	_update_aim()
	if _aiming.is_empty():
		return # nothing to aim (the hero is dead)
	var picked := Targeting.pick(session.local_hero(), ability, session.get_actor(client.target_id))
	session.send_intent({"type": "cast", "ability": ability.id, "target": picked.target, "aim": aim_point()})


## While an aimed bar runs: keeps the preview, lets a hold still held at the bar's end
## go (with the final aim), and stops once the bar is over (or never started).
func _follow_bar_aiming() -> void:
	var hero: Hero = session.local_hero()
	var c: Dictionary = hero.casting if hero != null else {}
	var running: bool = c.get("kind", "") == "timing" and c.get("ability") == _aiming.ability
	if running:
		_aiming.bar_start = float(c.start)
		if render_time_into_bar(c) >= c.ability.timing_bar.seconds:
			release_timing_bar()
	elif _aiming.bar_start >= 0.0 or session.render_time() - _aiming.sent_at > 1.0:
		cancel_aiming() # the bar is over, or the host refused the cast
		return
	_update_aim()


func render_time_into_bar(c: Dictionary) -> float:
	return session.render_time() - float(c.start)


## For tests: as if `key` was pressed on a slot holding `ability`.
func use_slot_ability_for_test(ability: AbilityDef, key: StringName) -> void:
	use_ability(ability, key)


func _screen_mouse() -> Vector2:
	return get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO


func cancel_aiming() -> void:
	_aiming = {}
	client.aim = {}


func is_aiming() -> bool:
	return not _aiming.is_empty() or not client.ally_select.is_empty()


## Only the cursor preview of a running timing bar (Esc then cancels the cast, not an aim).
func is_aiming_bar() -> bool:
	return _aiming.get("during_bar", false)


func _process(_delta: float) -> void:
	_update_holds()
	_go_off_at_bar_end()
	if _aiming.get("during_bar", false):
		_follow_bar_aiming()
	elif not _aiming.is_empty():
		_update_aim()


## Where the aimed ability points now (a tile position, as Vector2): always the
## cursor (2026-11-15: it used to aim at the targeted enemy until the mouse moved,
## so a Slash pressed with a target selected swung at the target, not the cursor).
func aim_point() -> Vector2:
	return point_for(_aiming.ability)


## Where bility would go now: the cursor, or with a controller the right stick /
## auto-lock (pad_point).
func point_for(ability: AbilityDef) -> Vector2:
	if InputDevice.using_pad() and session.local_hero() != null:
		return pad_point(ability)
	return mouse_point(ability)


## For tests (no real mouse headless): where the cursor is in the world, or null.
var mouse_override: Variant = null


## The cursor in world coordinates (the view's space).
func world_mouse() -> Vector2:
	return mouse_override if mouse_override is Vector2 else view.get_global_mouse_position()


## Where the mouse points on the ground: the exact point for hitbox abilities
## (free movement), the tile under it for grid abilities. Off the map (no tile
## under the cursor) it is the point under the cursor at the hero's own height,
## so the aim still goes toward the cursor, never "straight ahead".
func mouse_point(ability: AbilityDef) -> Vector2:
	var hero: Hero = session.local_hero()
	var mouse := world_mouse()
	var tile: Variant = view.tile_at(mouse)
	var height: int = session.grid().height_at(tile) if tile != null \
			else session.grid().height_at(hero.tile()) if session.grid().in_bounds(hero.tile()) else 0
	var point := Iso.from_screen(mouse, height)
	if ability.uses_hitbox():
		return point
	return Vector2(tile) if tile != null else Vector2(MoveState.tile_of(point))


func _update_aim() -> void:
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		cancel_aiming()
		return
	var ability: AbilityDef = _aiming.ability
	var point := aim_point()
	var p := AimPreview.preview(session.grid(), session.rules(), session.actors(), hero, ability, point,
			session.get_actor(client.target_id), session.now())
	# Red only for aiming problems (range, line of sight); cooldowns and mana show
	# on the action bar.
	var bad: bool = p.result in [AbilityResolver.Result.OUT_OF_RANGE, AbilityResolver.Result.NO_LINE_OF_SIGHT,
			AbilityResolver.Result.INVALID_TARGET]
	client.aim = {"ability": ability, "tiles": p.tiles, "point": point, "valid": not bad,
			"outline": p.get("outline", PackedVector2Array())}


## Handles input while aiming. Returns true if the event was used.
func _aim_input(event: InputEvent) -> bool:
	if _aiming.get("during_bar", false):
		return false # the bar's own inputs (right-click) decide; no key fires it
	var key: StringName = _aiming.action
	if key != &"" and event.is_action_released(key):
		fire_aimed()
		return true
	if key == &"" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		fire_aimed()
		return true
	if event.is_action_pressed(&"target_clear") or event.is_action_pressed(&"cancel_aim"):
		cancel_aiming()
		return true
	return false


## Sends the aimed cast; the host checks range, cooldowns and mana.
func fire_aimed() -> void:
	if _aiming.is_empty():
		return
	var ability: AbilityDef = _aiming.ability
	var point := aim_point()
	var picked := Targeting.pick(session.local_hero(), ability, session.get_actor(client.target_id))
	cancel_aiming()
	session.send_intent({"type": "cast", "ability": ability.id, "target": picked.target, "aim": point})


# --- Controller aiming -----------------------------------------------------------
# The right stick aims; let go, it is the setting (ClientState.pad_aim): Auto-lock
# aims at the nearest enemy ahead, Twin-stick where you walk. Abilities marked
# Manual Aim always use the right stick (and where it was last pushed).

## Auto-lock looks this far (tiles) for an enemy ahead, and this wide (degrees
## either side of where you walk or face)…
const LOCK_RANGE := 9.0
const LOCK_HALF_ANGLE := 75.0
## …and this close all around.
const LOCK_CLOSE := 3.0
## The right stick's last direction (grid angle), for Manual Aim and Twin-stick.
var _pad_aim_angle := NAN


## The angle to face with a controller: the right stick; else (Auto-lock) the
## locked enemy; else where the left stick walks; else `last`.
func pad_facing(hero: Hero, last: float) -> float:
	var rs := InputDevice.right_stick()
	if rs != Vector2.ZERO:
		_pad_aim_angle = Mover.stick_to_grid(rs).angle()
		return _pad_aim_angle
	if client.pad_aim == ClientState.PadAim.AUTO_LOCK:
		var foe := locked_enemy(hero, last)
		if foe != null:
			var off: Vector2 = foe.move.position_at(session.render_time()) - hero.move.position_at(session.render_time())
			if off.length() > 0.05:
				return off.angle()
	if _stick != Vector2.ZERO:
		return Mover.stick_to_grid(_stick).angle()
	return last if absf(last) <= PI else hero.aim_angle


## The enemy Auto-lock aims at: the target picked with Tab / LT if it's in reach;
## else the nearest foe within LOCK_RANGE in the direction you walk (or face);
## else the nearest within LOCK_CLOSE. Null if none.
func locked_enemy(hero: Hero, facing: float) -> Actor:
	var t: float = session.render_time()
	var at := hero.move.position_at(t)
	var picked := session.get_actor(client.target_id) as Actor
	if _is_foe(hero, picked) and picked.move.position_at(t).distance_to(at) <= LOCK_RANGE * 1.5:
		return picked
	var ahead := Mover.stick_to_grid(_stick).angle() if _stick != Vector2.ZERO else facing
	var best: Actor = null
	var best_d := INF
	for a in session.actors():
		if not _is_foe(hero, a):
			continue
		var off: Vector2 = a.move.position_at(t) - at
		var d := off.length()
		var in_front := d <= LOCK_RANGE and absf(rad_to_deg(angle_difference(ahead, off.angle()))) <= LOCK_HALF_ANGLE
		if (in_front or d <= LOCK_CLOSE) and d < best_d:
			best = a
			best_d = d
	return best


func _is_foe(hero: Hero, a: Actor) -> bool:
	return a != null and a.alive and hero.is_hostile_to(a) and not a.evading and not _peaceful(a)


## Where `ability` goes with a controller (a point on the ground, or a tile for grid
## abilities, as mouse_point). Toward the right stick (Manual Aim and Twin-stick,
## or whenever it's pushed), else the locked enemy (Auto-lock), else straight
## ahead. Ground areas land as far as the stick is pushed, up to their reach.
func pad_point(ability: AbilityDef) -> Vector2:
	var hero: Hero = session.local_hero()
	var t: float = session.render_time()
	var at := hero.move.position_at(t)
	var reach := _reach(ability)
	var rs := InputDevice.right_stick()
	var facing := _sent_angle if absf(_sent_angle) <= PI else hero.aim_angle
	var point: Vector2
	if rs == Vector2.ZERO and not ability.manual_aim and client.pad_aim == ClientState.PadAim.AUTO_LOCK \
			and locked_enemy(hero, facing) != null:
		point = locked_enemy(hero, facing).move.position_at(t)
	else:
		var angle := facing
		if rs != Vector2.ZERO:
			angle = Mover.stick_to_grid(rs).angle()
		elif ability.manual_aim and is_finite(_pad_aim_angle):
			angle = _pad_aim_angle
		var dist := reach
		if _lands_on_ground(ability):
			dist = reach * (clampf(rs.length(), 0.25, 1.0) if rs != Vector2.ZERO else 0.6)
		point = at + Vector2.from_angle(angle) * maxf(dist, 1.0)
	if ability.uses_hitbox():
		return point
	return Vector2(MoveState.tile_of(point))


## How far `ability` reaches (tiles).
static func _reach(ability: AbilityDef) -> float:
	if ability.uses_hitbox() and ability.hitbox.reach > 0.0:
		return ability.hitbox.reach
	return float(maxi(ability.max_range, 1))


## Ground areas and lobs land where you aim (so the stick sets how far); lines,
## cones and projectiles only need a direction.
static func _lands_on_ground(ability: AbilityDef) -> bool:
	if ability.uses_hitbox():
		return ability.hitbox.shape in [HitboxDef.Shape.CIRCLE, HitboxDef.Shape.LOB, HitboxDef.Shape.TILES,
				HitboxDef.Shape.LEAP, HitboxDef.Shape.BLINK]
	return ability.targeting == AbilityDef.TargetingMode.GROUND


## Who a targeted ability goes to: the chosen target if it suits the ability; else,
## for an enemy ability, the foe nearest where you aim (the cursor, or the
## controller's lock / stick) within its reach plus a little; for an ally ability, a
## friend near where you aim (else yourself, as Targeting.pick does).
func _target_for(hero: Hero, ability: AbilityDef) -> Actor:
	var chosen := session.get_actor(client.target_id) as Actor
	var enemy_ability := ability.target == AbilityDef.TargetType.ENEMY
	var ally_ability := ability.target in [AbilityDef.TargetType.ALLY, AbilityDef.TargetType.DEAD_ALLY]
	if chosen != null and ((enemy_ability and _is_foe(hero, chosen)) or (ally_ability and hero.is_ally_of(chosen))):
		return chosen
	if not (enemy_ability or ally_ability) or (view == null and mouse_override == null and not InputDevice.using_pad()):
		return chosen
	var t: float = session.render_time()
	var at := hero.move.position_at(t)
	var aim := pad_point(ability) if InputDevice.using_pad() else Iso.from_screen(world_mouse(),
			session.grid().height_at(hero.tile()) if session.grid().in_bounds(hero.tile()) else 0)
	var reach := _reach(ability) + 1.0
	var best: Actor = null
	var best_d := INF
	for a in session.actors():
		var fits: bool = _is_foe(hero, a) if enemy_ability else (a is Hero and hero.is_ally_of(a) \
				and a.alive == (ability.target == AbilityDef.TargetType.ALLY) and a.id != hero.id)
		if not fits:
			continue
		var p: Vector2 = a.move.position_at(t)
		if p.distance_to(at) > reach:
			continue
		var d := p.distance_to(aim)
		if not enemy_ability and d > 1.5:
			continue # a heal goes to a friend only when you point at them
		if d < best_d:
			best = a
			best_d = d
	return best if best != null else chosen

# --- Element kits (2026-11-22, Hades style) ----------------------------------------
# What X / Y / A / B do comes from the hero's element kit (ElementKits): a tap, a
# hold (goes off by itself once held long enough: 3 s for weapons, 1 s for
# elements), a combo (presses in a row), or a charge (let go: the longer, the
# stronger). Heals and buffs on allies take two presses: the first picks an ally,
# the second casts. RT / Space switches modes (Water / Ice). A button the kit
# doesn't cover uses the wheel's own slot.

## Held buttons: slot -> {"entry", "start" (render time), "fired"}.
var _pressed := {}
## The combo in progress: {"slot", "step", "at"}.
var _combo := {}
## The ally choice's last steering direction (to move on each new push only).
var _ally_steer := Vector2.ZERO


## The kit's entry for button `slot` for the local hero ({} if none).
func kit_entry(slot: int) -> Dictionary:
	return ElementKits.entry(session.local_hero(), slot, client.kit_mode) if session != null else {}


## A button pressed (slot 0 X, 1 Y, 2 A, 3 B).
func press_button(slot: int) -> void:
	var hero: Hero = session.local_hero()
	var e := kit_entry(slot)
	if hero == null or e.is_empty():
		use_slot(slot, InputActions.slot_action(slot))
		return
	# The second press of a heal or buff casts it on the chosen ally.
	if not client.ally_select.is_empty():
		if int(client.ally_select.slot) == slot:
			_cast_on_ally()
		else:
			end_ally_select()
		return
	if e.has("combo"):
		var combo: Array = e.combo
		var step := 0
		if int(_combo.get("slot", -1)) == slot and session.render_time() - float(_combo.at) <= ElementKits.combo_reset_seconds():
			step = (int(_combo.step) + 1) % combo.size()
		_combo = {"slot": slot, "step": step, "at": session.render_time()}
		kit_fire(combo[step])
		return
	if e.has("hold") or e.has("charge"):
		_pressed[slot] = {"entry": e, "start": session.render_time(), "fired": false}
		return
	if e.has("tap"):
		kit_fire(e.tap, e)


## A button let go: a tap if it wasn't held long enough, or the charge's release.
func release_button(slot: int) -> void:
	var p: Dictionary = _pressed.get(slot, {})
	_pressed.erase(slot)
	if p.is_empty() or p.fired:
		return
	var held: float = session.render_time() - float(p.start)
	if p.entry.has("charge"):
		kit_fire(p.entry.charge, p.entry, held)
	elif p.entry.has("tap"):
		kit_fire(p.entry.tap, p.entry)


## Holds that reached their time go off by themselves.
func _update_holds() -> void:
	if session == null:
		return
	for slot in _pressed.keys():
		var p: Dictionary = _pressed[slot]
		if p.fired or not p.entry.has("hold"):
			continue
		if session.render_time() - float(p.start) >= ElementKits.hold_seconds(p.entry.weapon):
			p.fired = true
			kit_fire(p.entry.hold, p.entry)


## How far button `slot`'s hold has come (0..1), or -1 if it isn't being held
## toward something (the wheel draws it).
func hold_progress(slot: int) -> float:
	var p: Dictionary = _pressed.get(slot, {})
	if p.is_empty() or p.fired:
		return -1.0
	var held: float = session.render_time() - float(p.start)
	if p.entry.has("hold"):
		return clampf(held / ElementKits.hold_seconds(p.entry.weapon), 0.0, 1.0)
	if p.entry.has("charge"):
		var a: AbilityDef = p.entry.charge
		var full := a.charge_seconds_per_level * maxf(a.charge_max_extra, 1)
		return clampf(held / full, 0.0, 1.0) if full > 0.0 else 1.0
	return -1.0


## Uses a kit ability: aimed where the hero aims (the cursor, or the controller's
## stick or lock), at the tile in front for in_front ones; heals and buffs on
## allies start the ally choice instead. `charge`: seconds the button was held.
func kit_fire(ability: AbilityDef, e: Dictionary = {}, charge := 0.0) -> void:
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		return
	if hero.find_ability(ability.id) == null:
		client.error("You haven't learned %s" % ability.display_name)
		return
	if ability.target in [AbilityDef.TargetType.ALLY, AbilityDef.TargetType.DEAD_ALLY] \
			and ability.targeting == AbilityDef.TargetingMode.TARGETED:
		_start_ally_select(ability, e)
		return
	var intent := {"type": "cast", "ability": ability.id, "target": -1}
	if ability.targeting == AbilityDef.TargetingMode.SELF or (ability.hitbox != null \
			and ability.hitbox.shape in [HitboxDef.Shape.NONE, HitboxDef.Shape.SELF_CIRCLE]):
		intent.target = hero.id
	elif e.get("in_front", false):
		var facing := _sent_angle if absf(_sent_angle) <= PI else hero.aim_angle
		if InputDevice.using_pad() and InputDevice.right_stick() != Vector2.ZERO:
			facing = Mover.stick_to_grid(InputDevice.right_stick()).angle()
		elif not InputDevice.using_pad() and view != null:
			facing = mouse_angle(hero, world_mouse())
		intent.aim = Vector2(MoveState.tile_of(hero.move.position_at(session.render_time()) + Vector2.from_angle(facing)))
	else:
		intent.aim = point_for(ability)
		var picked := _target_for(hero, ability)
		if picked != null and ability.targeting == AbilityDef.TargetingMode.TARGETED:
			intent.target = picked.id
	if charge > 0.0:
		intent.charge = charge
	session.send_intent(intent)


## RT / Space: the next mode of the element (Water -> Ice -> Water). True if the
## element has modes to switch.
func switch_mode() -> bool:
	var hero: Hero = session.local_hero()
	var names := ElementKits.modes(hero.element) if hero != null else []
	if names.size() < 2:
		return false
	client.kit_mode = (client.kit_mode + 1) % names.size()
	client.say("%s mode" % names[client.kit_mode])
	_pressed.clear()
	_combo = {}
	return true


## The current mode's name ("Ice"), or "".
func mode_name() -> String:
	var hero: Hero = session.local_hero() if session != null else null
	var names := ElementKits.modes(hero.element) if hero != null else []
	return names[clampi(client.kit_mode, 0, names.size() - 1)] if not names.is_empty() else ""


# --- Choosing an ally (heals and buffs) --------------------------------------------

func _start_ally_select(ability: AbilityDef, e: Dictionary) -> void:
	var hero: Hero = session.local_hero()
	var slot := -1
	for i in ActionBarModel.SLOT_COUNT:
		var k := kit_entry(i)
		if k.get("tap") == ability or k.get("hold") == ability:
			slot = i
	client.ally_select = {"slot": slot, "ability": ability}
	client.target_id = hero.id # starts on yourself
	_ally_steer = Vector2.ONE * 9.0 # a stick already pushed doesn't move it at once
	client.say("%s: choose an ally, then press again" % ability.display_name)


func end_ally_select() -> void:
	client.ally_select = {}


func _cast_on_ally() -> void:
	var ability: AbilityDef = client.ally_select.ability
	var hero: Hero = session.local_hero()
	var target := session.get_actor(client.target_id) as Actor
	if target == null or not hero.is_ally_of(target):
		target = hero
	end_ally_select()
	session.send_intent({"type": "cast", "ability": ability.id, "target": target.id})


## Allies the choice moves between: you and your party in the zone.
func ally_candidates() -> Array:
	var hero: Hero = session.local_hero()
	var out: Array = []
	for a in session.actors():
		if a is Hero and (a == hero or hero.is_ally_of(a)):
			out.append(a)
	return out


## A new push of the left stick or the arrows moves the choice to the ally nearest
## that way on screen.
func _steer_ally_select(dir: Vector2i, stick: Vector2) -> void:
	var push := Vector2(dir) if dir != Vector2i.ZERO else (stick if stick.length() > 0.6 else Vector2.ZERO)
	if push == Vector2.ZERO:
		_ally_steer = Vector2.ZERO
		return
	if _ally_steer != Vector2.ZERO:
		return # still the same push
	_ally_steer = push
	var current := session.get_actor(client.target_id) as Actor
	if current == null:
		current = session.local_hero()
	var want := Mover.stick_to_grid(push.normalized())
	var best: Actor = null
	var best_score := INF
	for a in ally_candidates():
		if a == current:
			continue
		var off: Vector2 = a.move.pos - current.move.pos
		if off.length() < 0.01 or off.normalized().dot(want) < 0.2:
			continue
		var score := off.length() * (2.0 - off.normalized().dot(want))
		if score < best_score:
			best = a
			best_score = score
	if best != null:
		client.target_id = best.id