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
		Navigator.go(world, enemy, path.back())
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
			Navigator.go(world, enemy, away)
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
		Navigator.go(world, enemy, spot)
	elif dist > enemy.def.keep_away_distance + 1:
		_chase(world, enemy, seen)


enum Attack { CAST, WAITING, OUT_OF_REACH }


## Uses the first ready ability that would reach `seen`. First turns (free) to
## face the target when it seems to share a row or column within ability range,
## unless `turn` is false.
static func _try_attack(world: WorldSim, enemy: Enemy, target: Actor, seen: Vector2i, turn: bool = true) -> Attack:
	# Never start an attack while being shoved or dashing (a forced glide).
	if enemy.move.gliding:
		return Attack.WAITING
	var delta := seen - enemy.tile()
	if turn and delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0) \
			and GridModel.distance(enemy.tile(), seen) <= _max_range(enemy):
		enemy.face(Vector2i(signi(delta.x), signi(delta.y)))
	var result := Attack.OUT_OF_REACH
	var seen_pos := world.perceived_pos(target, enemy.def.reaction_seconds)
	for ability in enemy.def.abilities:
		if ability.uses_hitbox():
			if not reaches(world, enemy, ability, target, seen_pos):
				continue
			result = Attack.WAITING
			# Aimed where the enemy saw the target (reaction delay), so moving dodges.
			var point := seen_pos
			if ability.aim_beside_target:
				point = _point_beside(enemy, target, seen_pos)
			var on: Actor = target if ability.hitbox.shape == HitboxDef.Shape.TARGETED else null
			if CastResolver.validate(world.ctx, enemy, ability, on, point) == AbilityResolver.Result.OK \
					and world.cast(enemy, ability, on, point) == AbilityResolver.Result.OK:
				enemy.last_attack_at = world.now
				Navigator.stop(enemy)
				return Attack.CAST
			continue
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
				Navigator.stop(enemy)
				return Attack.CAST
			continue
		if AbilityResolver.validate(world.ctx, enemy, ability, target) == AbilityResolver.Result.OK:
			world.cast(enemy, ability, target)
			enemy.last_attack_at = world.now
			Navigator.stop(enemy)
			return Attack.CAST
	return result


## Whether a hitbox ability would reach a target seen at `seen_pos` from where
## the enemy stands (continuous distances; a cone a little short of its edge so
## a hit isn't a graze that misses once the target shifts).
static func reaches(world: WorldSim, enemy: Enemy, ability: AbilityDef, target: Actor, seen_pos: Vector2) -> bool:
	var hb := ability.hitbox
	var d := enemy.move.pos.distance_to(seen_pos)
	var r := target.move.radius
	match hb.shape:
		HitboxDef.Shape.TARGETED:
			return d - enemy.move.radius - r <= hb.reach and d - enemy.move.radius - r >= hb.min_reach
		HitboxDef.Shape.CONE:
			return d <= hb.reach + r * 0.5 \
					and Hitbox.has_los(world.grid, enemy.move.pos, seen_pos, world.rules.los_height_tolerance)
		HitboxDef.Shape.RECT, HitboxDef.Shape.PROJECTILE:
			return d <= hb.reach \
					and Hitbox.has_los(world.grid, enemy.move.pos, seen_pos, world.rules.los_height_tolerance)
		HitboxDef.Shape.CIRCLE, HitboxDef.Shape.LOB:
			return d <= hb.reach + hb.radius * 0.5 and d >= hb.min_reach
		HitboxDef.Shape.SELF_CIRCLE:
			return d <= hb.radius + r * 0.5
		HitboxDef.Shape.DASH, HitboxDef.Shape.LEAP, HitboxDef.Shape.BLINK:
			return d <= hb.reach + enemy.move.radius + r and d >= hb.min_reach + enemy.move.radius
		HitboxDef.Shape.NONE:
			return true
	return AbilityShapes.reaches_tile(world.ctx, enemy, ability, MoveState.tile_of(seen_pos))


## Where a pounce lands: beside the target, on the enemy's side of it.
static func _point_beside(enemy: Enemy, target: Actor, seen_pos: Vector2) -> Vector2:
	var away := enemy.move.pos - seen_pos
	if away.length() < 0.01:
		away = Vector2.RIGHT
	return seen_pos + away.normalized() * (enemy.move.radius + target.move.radius + 0.1)


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
	if not _step_ready(world, enemy) or world.now < enemy.chase_retry_at:
		return
	var target := world.get_actor(enemy.threat.top()) if not enemy.threat.is_empty() else null
	var touch := enemy.move.radius + (target.move.radius if target != null else 0.3) + 0.05
	var found: bool
	if enemy.is_large():
		# A large body can't stand on its target's tile, nor usually fit its body
		# around it: it heads for any spot with its body beside the target.
		var beside := func(c: Vector2i) -> bool:
			for o in enemy.footprint:
				if TileGeometry.range_distance(c + o, seen) <= 1:
					return true
			return false
		found = Navigator.go(world, enemy, seen, 1.0, 0.0, beside, CHASE_SEARCH)
	else:
		found = Navigator.go(world, enemy, seen, 1.0, touch, Callable(), CHASE_SEARCH)
	if not found:
		enemy.chase_retry_at = world.now + CHASE_RETRY_SECONDS


## Whether it can move now (free movement: no step cooldown, only roots, stuns
## and forced glides stop it).
static func _step_ready(world: WorldSim, enemy: Enemy) -> bool:
	return not enemy.move.gliding and not enemy.buffs.is_rooted(world.now) \
			and not enemy.buffs.is_stunned(world.now)


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
	if enemy.patrol.is_empty() or enemy.move.gliding:
		return
	var goal := enemy.patrol[enemy.patrol_index % enemy.patrol.size()]
	if enemy.move.pos.distance_to(Vector2(goal)) <= Navigator.REACHED + 0.05:
		enemy.patrol_index = (enemy.patrol_index + 1) % enemy.patrol.size()
		return
	if not Navigator.go(world, enemy, goal, patrol_pace(enemy)):
		enemy.patrol_index = (enemy.patrol_index + 1) % enemy.patrol.size() # unreachable: skip it


## A patrol's pace (0..1 of its speed): `patrol_step_seconds` set the old tile
## pace; 1.5 tiles over that time, so a slow patrol stays a walk.
static func patrol_pace(enemy: Enemy) -> float:
	var speed := enemy.def.move_speed if enemy.def.move_speed > 0.0 else 3.0
	var seconds := enemy.def.patrol_step_seconds if enemy.def.patrol_step_seconds > 0.0 else 1.0
	return clampf(1.5 / (seconds * speed), 0.3, 1.0)


static func _walk_home(world: WorldSim, enemy: Enemy) -> void:
	if enemy.move.gliding:
		return
	if enemy.move.pos.distance_to(Vector2(enemy.home_tile)) <= Navigator.REACHED + 0.05:
		enemy.state = Enemy.State.IDLE
		enemy.called_by_pack = false
		enemy.evading = false
		Navigator.stop(enemy)
		return
	if not Navigator.go(world, enemy, enemy.home_tile) and not world.body_blocked(enemy, enemy.home_tile):
		enemy.move.place(enemy.home_tile) # stuck: snap home
