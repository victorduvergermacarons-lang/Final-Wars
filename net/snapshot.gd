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
		d.element = String(hero.element)
		d.stance = [hero.stance_tree, hero.stance, hero.stance_at]
		d.stance_water = hero.stance_water
		if not hero.water_out.is_empty(): # every player keeps drawing the water that is out
			d.water_out = {"ability": hero.water_out.ability, "at": hero.water_out.at}
		if not hero.shield_out.is_empty(): # Water Shield's rope: on whom, how much is left
			d.shield_out = {"target": hero.shield_out.target, "at": hero.shield_out.at,
					"left": float(hero.shield_out.get("left", 1.0)), "points": hero.shield_out.points}
		var eq := {}
		var equipment := hero.equipment()
		for slot in equipment:
			eq[int(slot)] = equipment[slot].id
		d.eq = eq
		d.anim = {"died": hero.anim.died, "down": hero.anim.down, "up": hero.anim.up,
				"hit": hero.anim.hit, "act": String(hero.anim.act), "act_at": hero.anim.act_at,
				"buff_end": hero.anim.buff_end, "buff_end_anim": hero.anim.buff_end_anim}
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
				"drops": world.drops.for_owner(hero.id),
				"loot_bonus": hero.loot_bonus,
				"water": hero.water,
				"near_water": hero.near_water,
				"filling": not hero.pouch_fill.is_empty(),
				"social": world.social_view(hero.id),
				"def": hero.def_id,
				"ack": world.intent_ack(hero.id),
			}
		actors.append(d)
	for enemy in world.enemies():
		var d := _actor(enemy)
		d.kind = KIND_ENEMY
		d.def = enemy.def.id
		d.level = enemy.level
		d.state = int(enemy.state)
		d.died_at = enemy.died_at
		if enemy.invulnerable:
			d.invulnerable = true
		d.spawn = enemy.spawn_tile
		actors.append(d)
	for npc in world.npcs():
		var d := _actor(npc)
		d.kind = KIND_NPC
		d.def = npc.def.id
		d.escort = npc.escorting
		actors.append(d)
	var projectiles: Array = world.projectiles().map(func(p): return p.to_dict())
	return {"tick": world.tick_count, "now": world.now, "zone": world.zone.id, "actors": actors,
			"projectiles": projectiles, "flags": world.world_flags.keys(), "telegraphs": world.pending_hits(),
			"terrain": world.changed_terrain(), "zones": world.ground_zones(), "way_out": world.way_out(),
			"rolls": world.rolls.to_array(), "duels": world.duels_view()}


static func _actor(a: Actor) -> Dictionary:
	return {
		"id": a.id,
		"name": a.display_name,
		"hp": a.hp,
		"mana": a.mana,
		"alive": a.alive,
		"evading": a.evading,
		"duel": [a.duel_with, a.duel_live],
		"combat_until": a.combat_until,
		"stats": a.stats.to_dict(),
		"move": a.move.to_dict(),
		"facing": a.facing,
		"angle": a.facing_angle,
		"cd": a.cooldowns.to_dict(),
		"buffs": a.buffs.to_dict(),
		"cast": {} if a.casting.is_empty() else {"ability": a.casting.ability.id, "kind": a.casting.kind,
				"start": a.casting.start, "end": a.casting.end},
	}
