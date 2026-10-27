class_name EnemyBrain
extends RefCounted
## Enemy behaviour, run once per tick by WorldSim:
## IDLE → (hero in aggro radius with line of sight, or took damage) → COMBAT:
## attack the top of the threat table when an ability is ready, otherwise step
## toward it on the step cooldown → (threat table empty, or pulled past the
## leash radius) → EVADING: heal to full, untargetable, walk home → IDLE.
## DEAD → respawn at the spawn point when the timer is up. An IDLE enemy with a
## patrol route walks it; it leashes back to where it was pulled ("home").
##
## Per-type behaviour (`EnemyDef.behavior`): MELEE chases; KITER keeps its
## distance and lines up ranged shots; FLANKER circles to the side or back.
##
## Enemies see heroes where they were `def.reaction_seconds` ago (aggro, chasing,
## turning and aiming), so a hero who steps aside just in time makes a bite whiff.
## A FLANKER also sees which way its target faces that late, so it reacts to a
## hero turning toward it after `reaction_seconds`.


## Seconds without attacking after which a FLANKER strikes head-on.
const FLANK_PATIENCE := 2.0
## Chasing: tiles a path search may visit (more than a whole leash area), and
## how long to wait after one finds nothing before searching again. An
## unreachable target would otherwise cost a full search every tick.
const CHASE_SEARCH := 1024
const CHASE_RETRY_SECONDS := 0.5


static func update(world: WorldSim, enemy: Enemy) -> void:
	if enemy.def.immobile and enemy.state != Enemy.State.DEAD:
		return # its encounter decides when it fights
	match enemy.state:
		Enemy.State.DEAD:
			if enemy.temporary:
				if world.now >= enemy.respawn_at:
					world.remove_after_tick(enemy.id)
				return
			if world.now >= enemy.respawn_at and not world.body_blocked(enemy, enemy.spawn_tile):
				enemy.reset_at_spawn()
				world.emit({"type": "respawn", "target": enemy.id})
		Enemy.State.IDLE:
			if enemy.threat.is_empty():
				var hero := _find_aggro_target(world, enemy)
				if hero == null:
					_patrol(world, enemy)
					return
				enemy.threat.add(hero.id, 0.0)
				world.emit({"type": "aggro", "source": enemy.id, "target": hero.id})
			enemy.state = Enemy.State.COMBAT
			enemy.home_tile = enemy.tile()
			enemy.last_attack_at = world.now
			enemy.combat_until = world.combat_until_from_now()
			# A wolf that spots you (or is hit first) howls before it fights; the
			# pack it calls in comes without howling.
			if enemy.def.howl_ability != null and not enemy.called_by_pack \
					and world.cast(enemy, enemy.def.howl_ability, enemy) == AbilityResolver.Result.OK:
				return
			_fight(world, enemy)
		Enemy.State.COMBAT:
			_fight(world, enemy)
		Enemy.State.EVADING:
			_walk_home(world, enemy)


## The nearest living hero (or escorted NPC or caravan) it can see within its
## aggro radius, or null.
static func _find_aggro_target(world: WorldSim, enemy: Enemy) -> Actor:
	var best: Actor = null
	var best_dist := 0
	var candidates: Array[Actor] = []
	candidates.append_array(world.heroes())
	candidates.append_array(world.escortees())
	for hero in candidates:
		if not hero.alive:
			continue
		var seen := world.perceived_tile(hero, enemy.def.reaction_seconds)
		var dist := GridModel.distance(enemy.tile(), seen)
		if dist > enemy.def.aggro_radius:
			continue
		if not LineOfSight.has_los(world.grid, enemy.tile(), seen, world.rules.los_height_tolerance):
			continue
		if best == null or dist < best_dist:
			best = hero
			best_dist = dist
	return best


static func _fight(world: WorldSim, enemy: Enemy) -> void:
	if enemy.def.training_dummy:
		_stand_as_dummy(world, enemy)
		return
	if enemy.threat.is_empty() \
			or GridModel.distance(enemy.tile(), enemy.home_tile) > enemy.def.leash_radius:
		_start_evade(world, enemy)
		return
	_check_enrage(world, enemy)
	var target := world.get_actor(enemy.threat.top())
	if target == null:
		enemy.threat.remove(enemy.threat.top())
		return

	var seen := world.perceived_tile(target, enemy.def.reaction_seconds)
	# Mid-attack (cast bar showing) an enemy stands still: moving would cancel it.
	# Animated creatures also finish their attack's recovery frames.
	if not enemy.casting.is_empty() or world.now < enemy.busy_until:
		return
	match enemy.def.behavior:
		EnemyDef.Behavior.KITER:
			_fight_kiter(world, enemy, target, seen)
		EnemyDef.Behavior.FLANKER:
			_fight_flanker(world, enemy, target, seen)
		_:
			_fight_melee(world, enemy, target, seen)


## MELEE: chase the target, attack whenever an ability would reach it.
static func _fight_melee(world: WorldSim, enemy: Enemy, target: Actor, seen: Vector2i) -> void:
	if _try_attack(world, enemy, target, seen) == Attack.CAST:
		return
	_chase(world, enemy, seen) # does nothing once adjacent


## FLANKER: get to the target's side or back, then strike. In front of the
## target it keeps circling, and strikes head-on only when it hasn't attacked for
## FLANK_PATIENCE seconds (or when there is no way around).
static func _fight_flanker(world: WorldSim, enemy: Enemy, target: Actor, seen: Vector2i) -> void:
	var dist := GridModel.distance(enemy.tile(), seen)
	var facing := world.perceived_facing(target, enemy.def.reaction_seconds)
	var at_front := dist == 1 and CombatMath.flank(enemy.tile(), seen, facing) == CombatMath.Flank.FRONT
	if dist == 1 and (not at_front or world.now - enemy.last_attack_at >= FLANK_PATIENCE):
		_try_attack(world, enemy, target, seen)
		return
	if not _step_ready(world, enemy):
		return
	var path := _path_to_flank(world, enemy, facing, seen)
	if path.size() >= 2 and (not at_front or path.size() <= 4):
		world.try_step(enemy, path[1])
	elif at_front:
		_try_attack(world, enemy, target, seen) # boxed in: fight head-on
	else:
		_chase(world, enemy, seen)


## Shortest path to a free tile behind or beside the target ([] if none).
## Ties go to the tile behind.
static func _path_to_flank(world: WorldSim, enemy: Enemy, facing: Vector2i, seen: Vector2i) -> Array[Vector2i]:
	var back := -facing
	var goals: Array[Vector2i] = [seen + back, seen + Vector2i(back.y, back.x), seen - Vector2i(back.y, back.x)]
	var blocked := world.occupied_tiles(enemy)
	blocked[seen] = true
	var best: Array[Vector2i] = []
	for goal in goals:
		if goal == enemy.tile():
			return [goal] as Array[Vector2i]
		if blocked.has(goal) or not world.grid.is_walkable(goal):
			continue
		var path := world.path_for(enemy, goal, blocked, 512)
		if path.size() >= 2 and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


## KITER: back off when a hero gets within `keep_away_distance`; otherwise line
## up with the target (same row or column, within range) and shoot.
static func _fight_kiter(world: WorldSim, enemy: Enemy, target: Actor, seen: Vector2i) -> void:
	var dist := GridModel.distance(enemy.tile(), seen)
	if dist <= enemy.def.keep_away_distance and _step_ready(world, enemy):
		var away := _best_neighbor(world, enemy, func(t: Vector2i) -> float:
			return -float(GridModel.distance(t, seen)) + 0.01 * GridModel.distance(t, enemy.home_tile))
		if away != enemy.tile() and GridModel.distance(away, seen) > dist:
			world.try_step(enemy, away)
			return
	var delta := seen - enemy.tile()
	var lines_up := enemy.def.abilities.any(func(a): return a.targeting == AbilityDef.TargetingMode.LEGACY)
	if not lines_up:
		if _try_attack(world, enemy, target, seen, false) != Attack.OUT_OF_REACH:
			return
	elif delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0):
		enemy.face(Vector2i(signi(delta.x), signi(delta.y)))
		if _try_attack(world, enemy, target, seen, false) != Attack.OUT_OF_REACH:
			return
	if not _step_ready(world, enemy):
		return
	var max_range := _max_range(enemy)
	var score := func(t: Vector2i) -> float:
		var d := GridModel.distance(t, seen)
		if d <= enemy.def.keep_away_distance:
			return 1000.0
		var off := t - seen
		var line := mini(absi(off.x), absi(off.y)) if lines_up else 0
		return line + maxi(d - max_range, 0)
	var spot := _best_neighbor(world, enemy, score)
	if spot != enemy.tile() and score.call(spot) < score.call(enemy.tile()):
		world.try_step(enemy, spot)
	elif dist > enemy.def.keep_away_distance + 1:
		_chase(world, enemy, seen)


enum Attack { CAST, WAITING, OUT_OF_REACH }


## Uses the first ready ability that would reach `seen`. First turns (free) to
## face the target when it seems to share a row or column within ability range,
## unless `turn` is false.
static func _try_attack(world: WorldSim, enemy: Enemy, target: Actor, seen: Vector2i, turn: bool = true) -> Attack:
	# Never start an attack while still walking onto a tile (it would look like
	# moving mid-attack).
	if enemy.move.is_moving(world.now):
		return Attack.WAITING
	var delta := seen - enemy.tile()
	if turn and delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0) \
			and GridModel.distance(enemy.tile(), seen) <= _max_range(enemy):
		enemy.face(Vector2i(signi(delta.x), signi(delta.y)))
	var result := Attack.OUT_OF_REACH
	for ability in enemy.def.abilities:
		if not AbilityShapes.reaches_tile(world.ctx, enemy, ability, seen):
			continue
		result = Attack.WAITING
		if ability.targeting != AbilityDef.TargetingMode.LEGACY:
			# Aimed where the enemy saw the target (reaction delay), so moving dodges.
			var aim: Variant = null
			var on: Actor = target
			if ability.targeting != AbilityDef.TargetingMode.TARGETED:
				aim = Vector2(seen)
				on = null
				if ability.aim_beside_target:
					var landing: Variant = _landing_beside(world, enemy, seen)
					if landing == null:
						continue
					aim = Vector2(landing)
			if CastResolver.validate(world.ctx, enemy, ability, on, aim) == AbilityResolver.Result.OK \
					and world.cast(enemy, ability, on, aim) == AbilityResolver.Result.OK:
				enemy.last_attack_at = world.now
				return Attack.CAST
			continue
		if AbilityResolver.validate(world.ctx, enemy, ability, target) == AbilityResolver.Result.OK:
			world.cast(enemy, ability, target)
			enemy.last_attack_at = world.now
			return Attack.CAST
	return result


## The free tile beside `seen` nearest the enemy (not its own tile), where a
## pounce lands next to its prey; null if there is none.
static func _landing_beside(world: WorldSim, enemy: Enemy, seen: Vector2i) -> Variant:
	var best: Variant = null
	var best_dist := 0
	for dir in GridModel.DIRECTIONS:
		var t: Vector2i = seen + dir
		if t == enemy.tile() or not world.grid.in_bounds(t) or not world.grid.is_walkable(t) \
				or world.is_occupied(t, enemy):
			continue
		var d := TileGeometry.range_distance(enemy.tile(), t)
		if best == null or d < best_dist:
			best = t
			best_dist = d
	return best


static func _chase(world: WorldSim, enemy: Enemy, seen: Vector2i) -> void:
	if not _step_ready(world, enemy) or (enemy.is_large() and enemy.range_to(seen) <= 1):
		return # a large body is already beside its target
	if world.now < enemy.chase_retry_at:
		return
	if enemy.is_large():
		# A large body can't stand on its target's tile, nor usually fit its body
		# around it: it heads for any spot with its body beside the target.
		var beside := func(c: Vector2i) -> bool:
			for o in enemy.footprint:
				if TileGeometry.range_distance(c + o, seen) <= 1:
					return true
			return false
		var to_beside := world.path_for(enemy, seen, world.occupied_tiles(enemy), CHASE_SEARCH, beside)
		if to_beside.size() >= 2:
			world.try_step(enemy, to_beside[1])
		elif to_beside.is_empty():
			enemy.chase_retry_at = world.now + CHASE_RETRY_SECONDS
		return
	var path := world.path_for(enemy, seen, world.occupied_tiles(enemy), CHASE_SEARCH)
	if path.size() > 2:
		world.try_step(enemy, path[1])
	elif path.is_empty():
		enemy.chase_retry_at = world.now + CHASE_RETRY_SECONDS


static func _step_ready(world: WorldSim, enemy: Enemy) -> bool:
	return enemy.move.can_start_step(true, enemy.cooldowns, world.now) \
			and not enemy.buffs.is_rooted(world.now)


## The neighbouring tile (or the current one) with the lowest `score`, among
## tiles the enemy could step onto right now and that stay within its leash.
static func _best_neighbor(world: WorldSim, enemy: Enemy, score: Callable) -> Vector2i:
	var here := enemy.tile()
	var best := here
	var best_score: float = score.call(here)
	for dir in GridModel.DIRECTIONS:
		var t := here + dir
		if not world.can_move(enemy, here, t) or world.body_blocked(enemy, t):
			continue
		if GridModel.distance(t, enemy.home_tile) > enemy.def.leash_radius:
			continue
		var s: float = score.call(t)
		if s < best_score:
			best = t
			best_score = s
	return best


static func _max_range(enemy: Enemy) -> int:
	var r := 1
	for ability in enemy.def.abilities:
		r = maxi(r, ability.max_range)
	return r


## Enrage (Molten Fury): below `enrage_below` of its max HP it gains its enrage
## buff for the rest of the fight (evading clears it).
static func _check_enrage(world: WorldSim, enemy: Enemy) -> void:
	var buff := enemy.def.enrage_buff
	if buff == null or enemy.def.enrage_below <= 0.0 or enemy.buffs.has(buff.id, world.now):
		return
	if enemy.hp < enemy.def.enrage_below * enemy.current_stats(world.now).hp:
		enemy.buffs.apply(buff, world.now, 0.0, enemy.id, {"duration": 3600.0})
		world.emit({"type": "enrage", "source": enemy.id, "target": enemy.id, "buff": buff.id})


## A training dummy only lets go: heroes who died, left or walked past its leash
## radius come off its threat list; with nobody left it resets (full health).
static func _stand_as_dummy(world: WorldSim, enemy: Enemy) -> void:
	for id in enemy.threat.ids():
		var hero := world.get_actor(id)
		if hero == null or not hero.alive \
				or GridModel.distance(enemy.tile(), hero.tile()) > enemy.def.leash_radius:
			enemy.threat.remove(id)
	if enemy.threat.is_empty():
		_start_evade(world, enemy)


static func _start_evade(world: WorldSim, enemy: Enemy) -> void:
	enemy.state = Enemy.State.EVADING
	enemy.evading = true
	enemy.threat.clear()
	enemy.buffs.clear()
	enemy.hp = enemy.stats.hp
	enemy.mana = enemy.stats.mana
	enemy.combat_until = -1.0
	world.emit({"type": "evade", "target": enemy.id})


## Idle with a patrol route: walk to the next waypoint at the patrol pace.
static func _patrol(world: WorldSim, enemy: Enemy) -> void:
	if enemy.patrol.is_empty() or enemy.move.is_moving(world.now):
		return
	var goal := enemy.patrol[enemy.patrol_index % enemy.patrol.size()]
	if enemy.tile() == goal:
		enemy.patrol_index = (enemy.patrol_index + 1) % enemy.patrol.size()
		return
	var path := world.path_for(enemy, goal, world.occupied_tiles(enemy))
	if path.size() < 2:
		enemy.patrol_index = (enemy.patrol_index + 1) % enemy.patrol.size() # unreachable: skip it
	elif not world.body_blocked(enemy, path[1]):
		world.try_step(enemy, path[1], enemy.def.patrol_step_seconds)


static func _walk_home(world: WorldSim, enemy: Enemy) -> void:
	if enemy.move.is_moving(world.now):
		return
	if enemy.tile() == enemy.home_tile:
		enemy.state = Enemy.State.IDLE
		enemy.called_by_pack = false
		enemy.evading = false
		return
	var path := world.path_for(enemy, enemy.home_tile, world.occupied_tiles(enemy))
	if path.size() >= 2 and not world.body_blocked(enemy, path[1]):
		world.try_step(enemy, path[1])
	elif path.is_empty() and not world.body_blocked(enemy, enemy.home_tile):
		enemy.move.place(enemy.home_tile) # stuck: snap home
