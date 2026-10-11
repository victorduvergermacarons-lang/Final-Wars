class_name EnemyBrain
extends RefCounted
## Enemy behaviour, run once per tick by WorldSim:
## IDLE → (hero in aggro radius with line of sight, or took damage) → COMBAT:
## attack the top of the threat table when an ability is ready, otherwise step
## toward it on the step cooldown → (threat table empty, or pulled past the
## leash radius) → EVADING: heal to full, untargetable, walk home → IDLE.
## DEAD → respawn at the spawn point when the timer is up.
##
## Enemies see heroes where they were `def.reaction_seconds` ago (aggro, chasing,
## turning and aiming), so a hero who steps aside just in time makes a bite whiff.


static func update(world: WorldSim, enemy: Enemy) -> void:
	match enemy.state:
		Enemy.State.DEAD:
			if world.now >= enemy.respawn_at and not world.is_occupied(enemy.spawn_tile, enemy):
				enemy.reset_at_spawn()
				world.emit({"type": "respawn", "target": enemy.id})
		Enemy.State.IDLE:
			if enemy.threat.is_empty():
				var hero := _find_aggro_target(world, enemy)
				if hero == null:
					return
				enemy.threat.add(hero.id, 0.0)
				world.emit({"type": "aggro", "source": enemy.id, "target": hero.id})
			enemy.state = Enemy.State.COMBAT
			_fight(world, enemy)
		Enemy.State.COMBAT:
			_fight(world, enemy)
		Enemy.State.EVADING:
			_walk_home(world, enemy)


static func _find_aggro_target(world: WorldSim, enemy: Enemy) -> Hero:
	var best: Hero = null
	var best_dist := 0
	for hero in world.heroes():
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
	if enemy.threat.is_empty() \
			or GridModel.distance(enemy.tile(), enemy.spawn_tile) > enemy.def.leash_radius:
		_start_evade(world, enemy)
		return
	var target := world.get_actor(enemy.threat.top())
	if target == null:
		enemy.threat.remove(enemy.threat.top())
		return

	# Act on where the target seems to be. Face it when it seems adjacent (turning
	# is free), then use the first ready ability that would reach that tile.
	var seen := world.perceived_tile(target, enemy.def.reaction_seconds)
	if GridModel.distance(enemy.tile(), seen) == 1:
		enemy.face(seen - enemy.tile())
	var in_reach := false
	for ability in enemy.def.abilities:
		if not AbilityShapes.reaches_tile(world.ctx, enemy, ability, seen):
			continue
		in_reach = true
		if AbilityResolver.validate(world.ctx, enemy, ability, target) == AbilityResolver.Result.OK:
			world.cast(enemy, ability, target)
			return
	if in_reach:
		return # waiting for a cooldown

	if not enemy.move.can_start_step(true, enemy.cooldowns, world.now):
		return
	var path := Pathfinder.find_path(world.grid, enemy.tile(), seen,
			StatCalc.jump_levels(enemy.current_stats(world.now)), world.occupied_tiles(enemy))
	if path.size() > 2:
		world.try_step(enemy, path[1])


static func _start_evade(world: WorldSim, enemy: Enemy) -> void:
	enemy.state = Enemy.State.EVADING
	enemy.evading = true
	enemy.threat.clear()
	enemy.buffs.clear()
	enemy.hp = enemy.stats.hp
	enemy.mana = enemy.stats.mana
	enemy.combat_until = -1.0
	world.emit({"type": "evade", "target": enemy.id})


static func _walk_home(world: WorldSim, enemy: Enemy) -> void:
	if enemy.move.is_moving(world.now):
		return
	if enemy.tile() == enemy.spawn_tile:
		enemy.state = Enemy.State.IDLE
		enemy.evading = false
		return
	var path := Pathfinder.find_path(world.grid, enemy.tile(), enemy.spawn_tile,
			StatCalc.jump_levels(enemy.current_stats(world.now)), world.occupied_tiles(enemy))
	if path.size() >= 2 and not world.is_occupied(path[1], enemy):
		world.try_step(enemy, path[1])
	elif path.is_empty() and not world.is_occupied(enemy.spawn_tile, enemy):
		enemy.move.place(enemy.spawn_tile) # stuck: snap home
