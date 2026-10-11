class_name EnemyBrain
extends RefCounted
## Enemy behaviour, run once per tick by WorldSim:
## IDLE → (hero in aggro radius with line of sight, or took damage) → COMBAT:
## attack the top of the threat table when an ability is ready, otherwise step
## toward it on the step cooldown → (threat table empty, or pulled past the
## leash radius) → EVADING: heal to full, untargetable, walk home → IDLE.
## DEAD → respawn at the spawn point when the timer is up.


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
		var dist := GridModel.distance(enemy.tile(), hero.tile())
		if dist > enemy.def.aggro_radius:
			continue
		if not LineOfSight.has_los(world.grid, enemy.tile(), hero.tile(), world.rules.los_height_tolerance):
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

	var in_range := false
	for ability in enemy.def.abilities:
		var result := AbilityResolver.validate(world.ctx, enemy, ability, target)
		if result == AbilityResolver.Result.OK:
			world.cast(enemy, ability, target)
			return
		if result != AbilityResolver.Result.OUT_OF_RANGE and result != AbilityResolver.Result.NO_LINE_OF_SIGHT:
			in_range = true
	if in_range:
		return # waiting for a cooldown

	if not enemy.move.can_start_step(true, enemy.cooldowns, world.now):
		return
	var path := Pathfinder.find_path(world.grid, enemy.tile(), target.tile(),
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
