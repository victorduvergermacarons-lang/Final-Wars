class_name PlayerInput
extends Node
## Turns the local player's keys and clicks into intents. Only sends intents;
## the host decides what actually happens.

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
var _sent_dir := Vector2i(99, 99)
var _sent_angle := 999.0
var _sent_at := -999.0
## When a direction key was last held (render time), and how long "stop" is re-sent
## after it (movement travels unreliably over the network).
var _walked_at := -999.0
const STOP_RESEND_SECONDS := 0.5
## Aiming a skillshot or ground ability: {"ability", "action" (key to release, or
## &"" when started by clicking the bar: then a left click fires), "mouse" (where
## the mouse was when aiming started)}.
var _aiming := {}


func setup(p_session, p_client: ClientState, p_view: WorldView) -> void:
	session = p_session
	client = p_client
	view = p_view


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
	# Without a view (tests), keep the last angle sent.
	var angle := _sent_angle if absf(_sent_angle) <= PI else hero.aim_angle
	if view != null and is_inside_tree():
		angle = mouse_angle(hero, world_mouse())
	var t: float = session.render_time()
	var tick: float = session.rules().tick_seconds
	# Every tick while walking; on a client also for STOP_RESEND_SECONDS after
	# stopping, since movement travels unreliably (Net.send_intent) and a lost "stop"
	# must not keep you walking.
	if _held != Vector2i.ZERO:
		_walked_at = t
	var resend: bool = _held != Vector2i.ZERO \
			or (session is ClientSession and t - _walked_at < STOP_RESEND_SECONDS)
	if _held != _sent_dir or absf(angle_difference(angle, _sent_angle)) > ANGLE_STEP \
			or (resend and t - _sent_at >= tick - 0.001):
		_send_move(_held, angle)


func _send_move(dir: Vector2i, angle: float) -> void:
	_sent_dir = dir
	_sent_angle = angle
	_sent_at = session.render_time()
	session.send_intent({"type": "move", "dir": dir, "face": angle})


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
	# A right-click or Space during a timing bar is the press (before anything else
	# uses it). So is the ability's own key again (_second_press).
	var bar_press: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT) or event.is_action_pressed(&"timing_press")
	if bar_press and press_timing_bar():
		get_viewport().set_input_as_handled()
		return
	if not _aiming.is_empty() and _aim_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"select_target"):
		var picked: Actor = view.actor_at(view.get_global_mouse_position())
		client.target_id = picked.id if picked != null else -1
	elif event.is_action_pressed(&"target_next"):
		_target_next_enemy()
	elif event.is_action_pressed(&"target_clear"):
		client.target_id = -1
	elif event.is_action_pressed(&"release"):
		session.send_intent({"type": "release"})
	elif event.is_action_pressed(&"interact"):
		if not pick_up_nearest():
			talk_to_nearest()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var picked: Actor = view.actor_at(view.get_global_mouse_position())
		if picked is Npc:
			session.send_intent({"type": "talk", "npc": picked.id})
		elif picked is Hero and picked.id != session.local_hero_id:
			player_menu_requested.emit(picked.id, get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SHIFT:
		# Shift leaves the bending stance.
		var hero: Hero = session.local_hero()
		if hero != null and hero.stance > 0:
			session.send_intent({"type": "stance", "tree": "", "stance": 0})
	else:
		for p in ActionBarModel.PAGE_COUNT:
			if event.is_action_pressed(InputActions.page_action(p), false, true):
				client.action_bar.set_page(p)
				get_viewport().set_input_as_handled()
				return
		for i in ActionBarModel.SLOT_COUNT:
			if InputMap.has_action(InputActions.slot_action(i)) \
					and event.is_action_pressed(InputActions.slot_action(i), false, true):
				use_slot(i, InputActions.slot_action(i))
				get_viewport().set_input_as_handled()
				return


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
	# Letting go of right-click (or Space) ends a hold, wherever the pointer is
	# (even over the HUD).
	if session != null and event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		release_timing_bar()
	if session != null and event.is_action_released(&"timing_press"):
		release_timing_bar()
	# So does letting go of the hotkey that played the bar (a second press).
	if session != null and _bar_key != &"" and event.is_action_released(_bar_key):
		_bar_key = &""
		release_timing_bar()


## Fires whatever ability is in action bar slot i. `key` is the action that was
## pressed (aimed abilities fire when it's released); "" for a click on the bar.
## The number of branch keys a stance has (keys 1-4 while one is held).
const BRANCH_KEYS := 4


func use_slot(i: int, key: StringName = &"") -> void:
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	# In a stance, the first four keys cast its branches (the slots there are set
	# aside until the stance is left); the others keep their slots.
	if hero.stance > 0 and i < BRANCH_KEYS:
		use_branch(hero, i + 1, key)
		return
	var id := client.action_bar.slots[i]
	if id == &"":
		return
	if ActionBarModel.is_stance_slot(id):
		var st := ActionBarModel.stance_of(id)
		enter_stance(st[0], st[1])
		return
	if ActionBarModel.is_item_slot(id):
		use_item(ActionBarModel.item_id_of(id))
		return
	var ability := hero.find_ability(id)
	if ability == null:
		client.error("You can't use that right now")
		return
	use_ability(ability, key)


## Enters (or switches to) a bending stance; its entry cast, if any, goes at the
## current target and the cursor.
func enter_stance(tree: String, n: int) -> void:
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	if hero.stance_tree == tree and hero.stance == n:
		return
	session.send_intent({"type": "stance", "tree": tree, "stance": n, "target": client.target_id,
			"aim": mouse_point(null)})


## Branch key `b` (1-4) in the stance held: casts that branch's ability, or says
## what it is and why it can't be used. Pressed again during the ability's own
## timing bar, it plays the bar (the second press).
func use_branch(hero: Hero, b: int, key: StringName = &"") -> void:
	var def := WorldSim.stance_ability(ContentDB.abilities, hero.stance_tree, hero.stance, b)
	if def == null:
		client.error("%s %d → %d: no ability" % [hero.stance_tree, hero.stance, b])
		return
	var ability := hero.find_ability(def.id)
	if ability == null:
		client.error("%s %d → %d: %s, %s" % [hero.stance_tree, hero.stance, b, def.display_name,
				_why_not(hero, def)])
		return
	use_ability(ability, key)


static func _why_not(hero: Hero, def: AbilityDef) -> String:
	if not def.implemented:
		return "not in the game yet"
	var need := int(def.sheet.get("mastery_required", 0))
	if Mastery.permanent(hero, def.tree) + 0.0001 < need:
		return "needs %s Mastery %d" % [def.tree, need]
	return "not learned yet"


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
	if ability.uses_hitbox() and ability.hitbox.shape == HitboxDef.Shape.CONE:
		# A melee swing goes off at once toward the mouse (no hold to aim).
		session.send_intent({"type": "cast", "ability": ability.id, "target": -1, "aim": mouse_point(ability)})
		return
	if AimPreview.is_aimed(ability):
		start_aiming(ability, key)
		return
	var picked := Targeting.pick(hero, ability, session.get_actor(client.target_id))
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
	elif what.kind == "fill":
		session.send_intent({"type": "fill_water"})
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
	if npc != null:
		return {"kind": "talk", "npc": npc}
	if hero.has_water_pouch() and hero.water < session.rules().water_pouch_capacity and WaterTiles.nearest(WaterTiles.of(session.zone()), hero.move.pos,
			session.rules().water_fill_reach) != null:
		return {"kind": "fill"}
	return {}


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
	return not _aiming.is_empty()


## Only the cursor preview of a running timing bar (Esc then cancels the cast, not an aim).
func is_aiming_bar() -> bool:
	return _aiming.get("during_bar", false)


func _process(_delta: float) -> void:
	_go_off_at_bar_end()
	if _aiming.get("during_bar", false):
		_follow_bar_aiming()
	elif not _aiming.is_empty():
		_update_aim()


## Where the aimed ability points now (a tile position, as Vector2): always the
## cursor (2026-11-15: it used to aim at the targeted enemy until the mouse moved,
## so a Slash pressed with a target selected swung at the target, not the cursor).
func aim_point() -> Vector2:
	return mouse_point(_aiming.ability)


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
	if ability == null or ability.uses_hitbox():
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
	if event.is_action_pressed(&"target_clear") or (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT):
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
