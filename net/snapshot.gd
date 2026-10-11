class_name Snapshot
extends RefCounted
## Full world state as plain data, sent from the host to clients every tick.
## Content (items, abilities, enemy types, buffs) is referenced by id only.

const KIND_HERO := 0
const KIND_ENEMY := 1


static func capture(world: WorldSim) -> Dictionary:
	var actors: Array = []
	for hero in world.heroes():
		var d := _actor(hero)
		d.kind = KIND_HERO
		d.level = hero.level
		d.xp = hero.xp
		d.bag = hero.bag.to_array()
		var eq := {}
		var equipment := hero.equipment()
		for slot in equipment:
			eq[int(slot)] = equipment[slot].id
		d.eq = eq
		d.ap = hero.ap.duplicate()
		d.mastered = hero.mastered.keys()
		d.ack = world.intent_ack(hero.id)
		actors.append(d)
	for enemy in world.enemies():
		var d := _actor(enemy)
		d.kind = KIND_ENEMY
		d.def = enemy.def.id
		d.state = int(enemy.state)
		d.spawn = enemy.spawn_tile
		actors.append(d)
	var projectiles: Array = world.projectiles().map(func(p): return p.to_dict())
	return {"tick": world.tick_count, "now": world.now, "actors": actors, "projectiles": projectiles}


static func _actor(a: Actor) -> Dictionary:
	return {
		"id": a.id,
		"name": a.display_name,
		"hp": a.hp,
		"mana": a.mana,
		"alive": a.alive,
		"evading": a.evading,
		"combat_until": a.combat_until,
		"stats": a.stats.to_dict(),
		"move": a.move.to_dict(),
		"facing": a.facing,
		"cd": a.cooldowns.to_dict(),
		"buffs": a.buffs.to_dict(),
	}
