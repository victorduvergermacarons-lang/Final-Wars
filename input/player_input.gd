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
## A press shorter than this (from a standstill, facing elsewhere) only turns.
const TURN_HOLD_SECONDS := 0.12

var session
var client: ClientState
var view: WorldView

var _held := Vector2i.ZERO
var _walk_after := 0.0
var _sent_from := Vector2i(-999, -999)
var _sent_at := -999.0


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
	var dir := _held_direction()
	var t: float = session.render_time()
	if dir != _held:
		_on_direction_changed(hero, dir, t)
	if dir == Vector2i.ZERO or t < _walk_after:
		return
	var now: float = session.now()
	var m := hero.move
	var next := hero.tile() + dir
	if m.is_moving(t):
		if m.progress(t) >= BUFFER_AT_PROGRESS and _sent_from != hero.tile():
			_send_step(hero.tile(), next, t)
		return
	if hero.in_combat(now) and not hero.cooldowns.can_step(now):
		return
	if _sent_from != hero.tile() or t - _sent_at >= RESEND_SECONDS:
		_send_step(hero.tile(), next, t)


## Pokémon-style: from a standstill, pressing a direction you aren't facing only
## turns you; keep holding it to start walking. Already facing it, or switching
## direction while walking, walks right away (a step turns you anyway).
func _on_direction_changed(hero: Hero, dir: Vector2i, t: float) -> void:
	var was_holding := _held != Vector2i.ZERO
	_held = dir
	if dir == Vector2i.ZERO:
		return
	if not was_holding and hero.facing != dir:
		session.send_intent({"type": "face", "dir": dir})
		_walk_after = t + TURN_HOLD_SECONDS
	else:
		_walk_after = t


func _send_step(from: Vector2i, to: Vector2i, t: float) -> void:
	_sent_from = from
	_sent_at = t
	session.send_intent({"type": "step", "to": to})


func _held_direction() -> Vector2i:
	for action in InputActions.DIRECTIONS:
		if Input.is_action_pressed(action):
			return InputActions.DIRECTIONS[action]
	return Vector2i.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if session == null:
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
		for i in ActionBarModel.SLOT_COUNT:
			if event.is_action_pressed(InputActions.slot_action(i), false, true):
				use_slot(i)
				get_viewport().set_input_as_handled()
				return


## Fires whatever ability is in action bar slot i.
func use_slot(i: int) -> void:
	var id := client.action_bar.slots[i]
	if id == &"":
		return
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	var ability := hero.find_ability(id)
	if ability == null:
		client.error("You can't use that right now")
		return
	use_ability(ability)


func use_ability(ability: AbilityDef) -> void:
	var hero: Hero = session.local_hero()
	var picked := Targeting.pick(hero, ability, session.get_actor(client.target_id))
	if picked.error != "":
		client.error(picked.error)
		return
	session.send_intent({"type": "cast", "ability": ability.id, "target": picked.target})


## E: talk to the NPC in front of you, or the nearest one within reach.
func talk_to_nearest() -> void:
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	var best: Actor = null
	for a in session.actors():
		if not (a is Npc):
			continue
		var d := GridModel.distance(hero.tile(), a.tile())
		if d > WorldSim.TALK_RANGE:
			continue
		if a.tile() == hero.front_tile():
			best = a
			break
		if best == null or d < GridModel.distance(hero.tile(), best.tile()):
			best = a
	if best == null:
		client.error("There's no one to talk to here")
		return
	session.send_intent({"type": "talk", "npc": best.id})


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
