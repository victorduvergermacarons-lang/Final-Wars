class_name Snapshot
extends RefCounted
## World state as plain data, sent from the host to each client every tick.
## Content (items, abilities, enemy types, buffs) is referenced by id only.
## Each client gets its own copy: other heroes' bags, gold, AP and quests stay
## private; only the viewer's own hero carries a "private" block.

const KIND_HERO := 0
const KIND_ENEMY := 1
const KIND_NPC := 2


static func capture(world: WorldSim, viewer_id: int) -> Dictionary:
	var actors: Array = []
	for hero in world.heroes():
		var d := _actor(hero)
		d.kind = KIND_HERO
		d.level = hero.level
		var eq := {}
		var equipment := hero.equipment()
		for slot in equipment:
			eq[int(slot)] = equipment[slot].id
		d.eq = eq
		if hero.id == viewer_id:
			d.private = {
				"xp": hero.xp,
				"gold": hero.gold,
				"bag": hero.bag.to_array(),
				"base": hero.base_stats.to_dict(),
				"growth": hero.growth.to_dict(),
				"ap": hero.ap.duplicate(),
				"mastered": hero.mastered.keys(),
				"learning": String(hero.learning_item.id) if hero.learning_item != null else "",
				"contrib": hero.mastery_contrib.duplicate(),
				"quests": hero.quest_state,
				"loot": world.pending_loot_for(hero.id),
				"def": hero.def_id,
				"ack": world.intent_ack(hero.id),
			}
		actors.append(d)
	for enemy in world.enemies():
		var d := _actor(enemy)
		d.kind = KIND_ENEMY
		d.def = enemy.def.id
		d.level = enemy.def.level
		d.state = int(enemy.state)
		d.spawn = enemy.spawn_tile
		actors.append(d)
	for npc in world.npcs():
		var d := _actor(npc)
		d.kind = KIND_NPC
		d.def = npc.def.id
		actors.append(d)
	var projectiles: Array = world.projectiles().map(func(p): return p.to_dict())
	return {"tick": world.tick_count, "now": world.now, "zone": world.zone.id, "actors": actors,
			"projectiles": projectiles, "flags": world.world_flags.keys()}


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
