class_name ClientWorld
extends RefCounted
## A client's mirror of the host's world, rebuilt from snapshots, plus
## client-side prediction of the local hero's steps.
##
## Prediction: a step is applied locally the moment it is sent. When a snapshot
## arrives, the host's state replaces the mirror, then every step the host has
## not processed yet (seq > ack) is re-applied on top. A step the host rejected
## simply disappears, snapping the hero back to the host's position.

const MAX_PENDING_STEPS := 2

var zone: ZoneDef
var grid: GridModel
var rules: CombatRules
## Lookup tables by id: items, abilities, enemies, buffs (ContentDB or a stand-in).
var content
var now: float = 0.0
var tick: int = 0
var local_hero_id: int = -1

var _actors := {} # id -> Actor
## Projectiles in flight, as plain data from the host (see Projectile.to_dict).
var projectiles: Array = []
var _pending: Array = [] # unacknowledged local intents: {seq, kind: "step"|"face", ...}
var _next_seq := 1


func _init(p_zone: ZoneDef, p_rules: CombatRules, p_content) -> void:
	zone = p_zone
	grid = GridModel.from_zone(zone)
	rules = p_rules
	content = p_content


func actors() -> Array[Actor]:
	var out: Array[Actor] = []
	var ids := _actors.keys()
	ids.sort()
	for id in ids:
		out.append(_actors[id])
	return out


func get_actor(id: int) -> Actor:
	return _actors.get(id)


func local_hero() -> Hero:
	return _actors.get(local_hero_id) as Hero


## Keeps intent numbering going after switching to a new zone's mirror.
func continue_sequence_from(other: ClientWorld) -> void:
	_next_seq = other._next_seq


func take_seq() -> int:
	var s := _next_seq
	_next_seq += 1
	return s


func pending_step_count() -> int:
	return _pending.filter(func(p): return p.kind == "step").size()


## Turns the local hero right away (turning is always legal while alive).
func predict_face(seq: int, dir: Vector2i) -> bool:
	var hero := local_hero()
	if hero == null or not hero.alive or not hero.face(dir):
		return false
	_pending.append({"seq": seq, "kind": "face", "dir": dir})
	return true


## Applies a step locally right away if the mirror says it's legal.
## `t` is the client's estimate of the host clock. Returns true if predicted.
func predict_step(seq: int, to: Vector2i, t: float) -> bool:
	var hero := local_hero()
	if hero == null or not hero.alive or pending_step_count() >= MAX_PENDING_STEPS:
		return false
	if not _step_is_legal(hero, to, t):
		return false
	var start := maxf(t, hero.move.start_time + hero.move.duration)
	_pending.append({"seq": seq, "kind": "step", "to": to, "start": start})
	hero.face(to - hero.tile())
	hero.move.begin(to, start, rules.walk_tile_seconds)
	return true


func _step_is_legal(hero: Hero, to: Vector2i, t: float) -> bool:
	var from := hero.tile()
	if GridModel.distance(from, to) != 1:
		return false
	if not grid.can_step(from, to, StatCalc.jump_levels(hero.current_stats(t))):
		return false
	for a in _actors.values():
		if a != hero and a.alive and a.tile() == to:
			return false
	if hero.in_combat(t) and not hero.cooldowns.can_step(t):
		return false
	return true


func apply_snapshot(snap: Dictionary) -> void:
	tick = snap.tick
	now = snap.now
	projectiles = snap.get("projectiles", [])
	var seen := {}
	for d in snap.actors:
		var id: int = d.id
		seen[id] = true
		var actor: Actor = _actors.get(id)
		if actor == null:
			actor = _create(d)
			if actor == null:
				continue
			_actors[id] = actor
		if id == local_hero_id:
			_apply_local_hero(actor as Hero, d)
		else:
			_apply_actor(actor, d)
	for id in _actors.keys():
		if not seen.has(id):
			_actors.erase(id)


func _create(d: Dictionary) -> Actor:
	if d.kind == Snapshot.KIND_HERO:
		return Hero.new(d.id)
	var def: EnemyDef = content.enemies.get(StringName(d.def))
	if def == null:
		push_warning("Unknown enemy type %s" % d.def)
		return null
	return Enemy.new(d.id, def, d.spawn)


func _apply_actor(a: Actor, d: Dictionary) -> void:
	a.display_name = d.name
	a.stats = StatBlock.from_dict(d.stats)
	a.hp = d.hp
	a.mana = d.mana
	a.alive = d.alive
	a.evading = d.evading
	a.combat_until = d.combat_until
	a.move = MoveState.from_dict(d.move)
	a.facing = d.get("facing", Vector2i.DOWN)
	a.cooldowns = Cooldowns.from_dict(d.cd)
	a.buffs.clear()
	for id in d.buffs:
		var buff: BuffDef = content.buffs.get(StringName(id))
		if buff != null:
			a.buffs.set_expiry(buff, d.buffs[id])
	if a is Hero:
		_apply_hero_extras(a as Hero, d)
	elif a is Enemy:
		(a as Enemy).state = d.state as Enemy.State


func _apply_hero_extras(h: Hero, d: Dictionary) -> void:
	h.level = d.level
	var eq := {}
	for slot in d.eq:
		var item: ItemDef = content.items.get(StringName(d.eq[slot]))
		if item != null:
			eq[int(slot)] = item
	h.set_equipped_raw(eq)
	if not d.has("private"):
		return
	var p: Dictionary = d.private
	h.xp = p.xp
	h.gold = p.gold
	h.def_id = StringName(p.get("def", "adventurer"))
	h.bag = Bag.from_array(p.bag, content.items)
	h.base_stats = StatBlock.from_dict(p.base)
	h.growth = StatBlock.from_dict(p.growth)
	h.ap = {}
	for id in p.ap:
		h.ap[StringName(id)] = int(p.ap[id])
	h.mastered = {}
	for id in p.mastered:
		var ability: AbilityDef = content.abilities.get(StringName(id))
		if ability != null:
			h.mastered[StringName(id)] = ability
	h.quest_state = p.quests


## Host state, then re-apply steps the host hasn't processed yet. If the
## resulting walk is the same one already showing, keep the local timing so the
## hero doesn't visibly jump back by the network delay.
func _apply_local_hero(h: Hero, d: Dictionary) -> void:
	var shown := h.move
	_apply_actor(h, d)
	var ack: int = d.private.ack if d.has("private") else 0
	_pending = _pending.filter(func(p): return p.seq > ack)
	for p in _pending:
		if not h.alive:
			break
		if p.kind == "face":
			h.face(p.dir)
		elif GridModel.distance(h.tile(), p.to) == 1:
			h.face(p.to - h.tile())
			h.move.begin(p.to, maxf(p.start, h.move.start_time + h.move.duration), rules.walk_tile_seconds)
	if h.move.from_tile == shown.from_tile and h.move.to_tile == shown.to_tile:
		h.move.start_time = shown.start_time
		h.move.duration = shown.duration
