class_name CreatureAnimator
extends RefCounted
## Picks the animation frame an animated creature shows, from replicated state
## only (host times for casts, steps and death), so every player sees the same
## frame at the same moment. One animator per view; it remembers each creature's
## last attack so the frames after the hit (recovery) still play once the
## host's wind-up has ended.

var _attacks := {} # actor id -> {"anim", "start", "hit_at", "resolved"}
## The frame a hero with art shows (PL-01-1, 4 facings since 2026-11-16), from the
## host's times in Hero.anim (sent in snapshots), so every player sees the same frame
## at the same moment. In order:
## - dead: "death" once, then lying in "downed"'s last frame until released or
##   revived (downed and death both end lying down; playing downed again would get
##   up and fall twice);
## - stunned: "downed" (falls) and lies there until the stun ends;
## - just up again (stun over, resurrected, released): "revived" once;
## - an ability just went off: its own animation (Slash, Lunge, Quick Shot, Aimed
##   Shot, while that weapon type is in hand; CreatureArtDef.ability_anims), else
##   "cast" (element spells, hammer arts, potions);
## - just hit: "hit" once;
## - walking: "run", following the distance walked; else "idle".
func pick_hero(actor: Actor, art: CreatureArtDef, t: float) -> Dictionary:
	var dir := art.direction_for_angle(actor.facing_angle, actor.facing)
	var hero := actor as Hero
	var times: Dictionary = hero.anim if hero != null else {}
	if not actor.alive:
		var since: float = t - float(times.get("died", Hero.NEVER))
		if since >= 0.0 and since < art.duration("death"):
			return _once(art, "death", dir, since, true)
		return _once(art, "downed", dir, INF, true)
	if actor.buffs.is_stunned(t):
		return _once(art, "downed", dir, _since(times, "down", t), true)
	var up := t - float(times.get("up", Hero.NEVER))
	if up >= 0.0 and up < art.duration("revived"):
		return _once(art, "revived", dir, up, false)
	var act := action_anim(hero, art)
	var acted := t - float(times.get("act_at", Hero.NEVER))
	if act != "" and acted >= 0.0 and acted < art.duration(act):
		return _once(art, act, dir, acted, false)
	var hit := t - float(times.get("hit", Hero.NEVER))
	if hit >= 0.0 and hit < art.duration("hit"):
		return _once(art, "hit", dir, hit, false)
	if actor.move.is_moving(t):
		return {"anim": "run", "dir": dir, "frame": art.run_frame(actor.move, dir)}
	var idle_n := maxi(art.frame_count("idle"), 1)
	return {"anim": "idle", "dir": dir, "frame": int(t * art.anim_fps("idle")) % idle_n}


## The animation for the hero's last ability: its own while its weapon type is in
## hand, else "cast".
static func action_anim(hero: Hero, art: CreatureArtDef) -> String:
	if hero == null:
		return "cast"
	var own: Array = art.ability_anims.get(StringName(hero.anim.act), [])
	if own.size() == 2 and hero.wields(own[1]) and art.sheets.has(own[0]):
		return own[0]
	return "cast"


static func _since(times: Dictionary, key: String, t: float) -> float:
	var at := float(times.get(key, Hero.NEVER))
	return t - at if at > Hero.NEVER else INF # seen already down: the last frame


## Frame `since` seconds into an animation played once (holding its last frame).
static func _once(art: CreatureArtDef, anim: String, dir: String, since: float, hold: bool) -> Dictionary:
	var n := maxi(art.frame_count(anim), 1)
	var frame := n - 1 # seen already down (no start time): the last frame
	if is_finite(since):
		frame = floori(maxf(since, 0.0) * art.anim_fps(anim) + 0.0001)
	return {"anim": anim, "dir": dir, "frame": mini(frame, n - 1) if hold else clampi(frame, 0, n - 1)}


## {"anim", "dir", "frame", "alpha"} for `actor` at time `t` (empty: draw nothing).
## Enemies attack and die; NPCs with art (any actor) idle and walk.
func pick(actor: Actor, art: CreatureArtDef, t: float) -> Dictionary:
	var dir := CreatureArtDef.direction_for(actor.facing)
	if not actor.alive:
		_attacks.erase(actor.id)
		return _death_frame(actor as Enemy, art, t, dir) if actor is Enemy else {}
	var attack := _attack_frame(actor as Enemy, art, t) if actor is Enemy else {}
	if not attack.is_empty():
		attack.dir = dir
		return attack
	if actor.move.free and not actor.move.gliding and actor.move.is_moving(t):
		# Free movement: the run cycle follows the distance walked, so the feet
		# match the ground at any speed and in any direction.
		return {"anim": "run", "dir": dir, "frame": art.run_frame(actor.move, dir)}
	if actor.move.is_moving(t):
		var n := maxi(art.frame_count("run"), 1)
		# One run cycle can span several tiles; which part of it a step plays
		# comes from the tile it starts on, so the stride carries on from tile to
		# tile (with a 2-tile cycle every step alternates halves, in any direction).
		var cycle_tiles := maxi(ceili(float(n) / maxi(art.run_frames_per_tile, 1)), 1)
		var from := actor.move.from_tile
		var part := posmod(from.x + from.y, cycle_tiles)
		var frame := int((actor.move.progress(t) + part) * art.run_frames_per_tile) % n
		return {"anim": "run", "dir": dir, "frame": frame}
	var idle_n := maxi(art.frame_count("idle"), 1)
	# Each creature idles on its own beat, the same on every machine.
	var phase := float(actor.id % 7) / 7.0 * idle_n
	return {"anim": "idle", "dir": dir, "frame": int(t * art.anim_fps("idle") + phase) % idle_n}


## Death plays once from the host's time of death, the corpse lies still for
## corpse_seconds, then fades out over fade_seconds.
func _death_frame(actor: Enemy, art: CreatureArtDef, t: float, dir: String) -> Dictionary:
	if actor.died_at < 0.0:
		return {}
	var since := t - actor.died_at
	var length := art.duration("death")
	var n := art.frame_count("death")
	var frame := mini(floori(maxf(since, 0.0) * art.anim_fps("death") + 0.0001), n - 1)
	var alpha := 1.0
	var fading := since - length - art.corpse_seconds
	if fading > 0.0:
		alpha = 1.0 - fading / maxf(art.fade_seconds, 0.001)
	if alpha <= 0.0:
		return {}
	return {"anim": "death", "dir": dir, "frame": frame, "alpha": alpha}


## The attack animation frame, if one is playing: during the wind-up (the cast
## the host replicates) and, once it has landed, through its recovery frames.
func _attack_frame(actor: Enemy, art: CreatureArtDef, t: float) -> Dictionary:
	var c: Dictionary = actor.casting
	var ability = c.get("ability")
	if ability is AbilityDef and art.timed_abilities.has(ability.id):
		var anim := str(art.timed_abilities[ability.id][0])
		var start := float(c.get("start", t))
		_attacks[actor.id] = {"anim": anim, "start": start, "hit_at": float(c.get("end", t)), "resolved": false}
	var a: Dictionary = _attacks.get(actor.id, {})
	if a.is_empty():
		return {}
	if c.is_empty() and not a.resolved:
		# The wind-up is over: it landed if it ran its course, else it was cancelled.
		if t + 0.06 >= a.hit_at:
			a.resolved = true
		else:
			_attacks.erase(actor.id)
			return {}
	var n := art.frame_count(a.anim)
	var frame := floori((t - a.start) * art.anim_fps(a.anim) + 0.0001)
	if frame >= n:
		_attacks.erase(actor.id)
		return {}
	return {"anim": a.anim, "frame": maxi(frame, 0)}
