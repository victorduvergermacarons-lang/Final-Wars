class_name PlayerInput
extends Node
## Turns the local player's keys and clicks into intents. Only sends intents;
## the host decides what actually happens.

## Resend a step that hasn't started yet (blocked, cooldown) at most this often.
const RESEND_SECONDS := 0.15
## Send the next held step once the current walk is this far along, so it's
## buffered on the host and movement doesn't stutter.
const BUFFER_AT_PROGRESS := 0.6
const TAB_RANGE := 12

var session
var client: ClientState
var view: WorldView

var _held := Vector2i.ZERO
var _walk_after := 0.0
var _sent_from := Vector2i(-999, -999)
var _sent_at := -999.0
var _press_order: Array[Vector2i] = []
var _face_sent := Vector2i.ZERO
var _face_sent_at := -999.0
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
		return
	# Typing in a text box (debug console) doesn't walk.
	var typing := get_viewport().gui_get_focus_owner() is LineEdit if is_inside_tree() else false
	var dir := Vector2i.ZERO if typing else _held_direction()
	var t: float = session.render_time()
	if view != null and is_inside_tree():
		face_toward(view.get_global_mouse_position())
	if dir != _held:
		_on_direction_changed(hero, dir, t)
	if dir == Vector2i.ZERO or t < _walk_after:
		return
	var now: float = session.now()
	var m := hero.move
	var next := hero.tile() + dir
	if m.is_moving(t):
		# Out of combat, queue the next step so walking is smooth. In combat the
		# next step waits for the step cooldown anyway; queuing it would turn the
		# hero back toward it later, even after the player had turned elsewhere.
		if m.progress(t) >= BUFFER_AT_PROGRESS and _sent_from != hero.tile() and not hero.in_combat(now):
			_send_step(hero.tile(), next, t)
		return
	if hero.in_combat(now) and not hero.cooldowns.can_step(now):
		return
	if _sent_from != hero.tile() or t - _sent_at >= RESEND_SECONDS:
		_send_step(hero.tile(), next, t)


## A direction key always walks, straight away (facing follows the mouse, see
## _face_mouse()).
func _on_direction_changed(_hero: Hero, dir: Vector2i, t: float) -> void:
	_held = dir
	_walk_after = t


## Turns the hero toward a point on the map (world coordinates): the mouse.
## Sends a face intent only when the facing should change (again after
## RESEND_SECONDS if the host hasn't turned the hero yet, e.g. right after a step).
func face_toward(world_pos: Vector2) -> void:
	var hero: Hero = session.local_hero()
	if hero == null or not hero.alive:
		return
	var grid: GridModel = session.grid()
	var off := Iso.from_screen(world_pos, grid.height_at(hero.tile())) - Vector2(hero.tile())
	if off.length() < 0.5:
		return # pointing at the hero itself
	var dir := Vector2i(int(signf(off.x)), 0) if absf(off.x) >= absf(off.y) else Vector2i(0, int(signf(off.y)))
	if dir == Vector2i.ZERO or dir == hero.facing:
		return
	var t: float = session.render_time()
	if dir == _face_sent and t - _face_sent_at < RESEND_SECONDS:
		return
	_face_sent = dir
	_face_sent_at = t
	session.send_intent({"type": "face", "dir": dir})


func _send_step(from: Vector2i, to: Vector2i, t: float) -> void:
	_sent_from = from
	_sent_at = t
	session.send_intent({"type": "step", "to": to})


## The most recently pressed direction that is still held, so rolling from one
## key to the next turns/walks the new way right away.
func _held_direction() -> Vector2i:
	for action in InputActions.DIRECTIONS:
		var d: Vector2i = InputActions.DIRECTIONS[action]
		var pressed := Input.is_action_pressed(action)
		if pressed and not _press_order.has(d):
			_press_order.append(d)
		elif not pressed:
			_press_order.erase(d)
	return _press_order.back() if not _press_order.is_empty() else Vector2i.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if session == null:
		return
	# A right-click during a timing bar is the press (before anything else uses it).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and press_timing_bar():
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
		talk_to_nearest()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var picked: Actor = view.actor_at(view.get_global_mouse_position())
		if picked is Npc:
			session.send_intent({"type": "talk", "npc": picked.id})
	else:
		for p in ActionBarModel.PAGE_COUNT:
			if event.is_action_pressed(InputActions.page_action(p), false, true):
				client.action_bar.set_page(p)
				get_viewport().set_input_as_handled()
				return
		for i in ActionBarModel.SLOT_COUNT:
			if event.is_action_pressed(InputActions.slot_action(i), false, true):
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
	if _aiming.get("during_bar", false):
		intent.aim = aim_point()
	return intent


func _input(event: InputEvent) -> void:
	# Letting go of right-click ends a hold, wherever the pointer is (even over the HUD).
	if session != null and event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
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


func use_ability(ability: AbilityDef, key: StringName = &"") -> void:
	var hero: Hero = session.local_hero()
	if AimPreview.is_aimed(ability) and aims_during_bar(ability):
		_start_bar_aiming(ability)
		return
	if AimPreview.is_aimed(ability):
		start_aiming(ability, key)
		return
	var picked := Targeting.pick(hero, ability, session.get_actor(client.target_id))
	if picked.error != "":
		client.error(picked.error)
		return
	session.send_intent({"type": "cast", "ability": ability.id, "target": picked.target})


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


func _target_next_enemy() -> void:
	var hero: Hero = session.local_hero()
	var candidates: Array = []
	for a in session.actors():
		if a.alive and hero.is_hostile_to(a) and not a.evading \
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


func _process(_delta: float) -> void:
	if _aiming.get("during_bar", false):
		_follow_bar_aiming()
	elif not _aiming.is_empty():
		_update_aim()


## Where the aimed ability points now (a tile position, as Vector2).
func aim_point() -> Vector2:
	var hero: Hero = session.local_hero()
	var ability: AbilityDef = _aiming.ability
	var target: Actor = session.get_actor(client.target_id)
	var enemy := target != null and target.alive and hero.is_hostile_to(target)
	# Screen position, so the camera following the hero doesn't count as moving.
	if _screen_mouse().distance_to(_aiming.mouse) < 4.0 and enemy:
		return Vector2(target.tile())
	var tile: Variant = view.tile_at(view.get_global_mouse_position())
	if tile == null:
		return AimPreview.default_aim(hero, ability, target)
	return Vector2(tile)


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
	client.aim = {"ability": ability, "tiles": p.tiles, "point": point, "valid": not bad}


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
