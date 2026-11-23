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
## - a buff with an end animation just ended (BuffDef.end_anim: Stone Skin ->
##   "stone_shatter", the stone armour cracks off), once;
## - an ability just went off: its own animation (Slash, Lunge, Quick Shot, Aimed
##   Shot, while that weapon type is in hand; the element abilities since
##   2026-11-21; CreatureArtDef.ability_anims), from its strike frame, else "cast"
##   (other spells, hammer arts, potions);
## - casting an ability with its own animation: its wind-up (Rock Throw's root,
##   then its hold looping; or the frames before the strike, holding the last);
## - just hit: "hit" once;
## - walking: "run", following the distance walked; else "idle".
func pick_hero(actor: Actor, art: CreatureArtDef, t: float) -> Dictionary:
	return art.mirrored(_pick_hero(actor, art, t))


func _pick_hero(actor: Actor, art: CreatureArtDef, t: float) -> Dictionary:
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
	var ended := t - float(times.get("buff_end", Hero.NEVER))
	var end_anim := str(times.get("buff_end_anim", ""))
	if end_anim != "" and art.sheets.has(end_anim) and ended >= 0.0 and ended < art.duration(end_anim):
		return _once(art, end_anim, dir, ended, false)
	var act := action_anim(hero, art)
	var acted := t - float(times.get("act_at", Hero.NEVER))
	var first := action_first_frame(hero, art)
	if act != "" and acted >= 0.0 and acted < (art.frame_count(act) - first) / art.anim_fps(act):
		return _from(art, act, dir, first, acted)
	var entry := _stance_entry(hero, art, dir, t)
	if not entry.is_empty():
		return entry
	var windup := _windup(hero, art, dir, t)
	if not windup.is_empty():
		return windup
	var hit := t - float(times.get("hit", Hero.NEVER))
	if hit >= 0.0 and hit < art.duration("hit"):
		return _once(art, "hit", dir, hit, false)
	if actor.move.is_moving(t):
		return {"anim": "run", "dir": dir, "frame": art.run_frame(actor.move, dir)}
	var idle_n := maxi(art.frame_count("idle"), 1)
	return {"anim": "idle", "dir": dir, "frame": int(t * art.anim_fps("idle")) % idle_n}


## Just after entering a stance (host time Hero.stance_at): its entry animation
## (CreatureArtDef.stance_anim), the second one held stance_hold_seconds. {} after.
func _stance_entry(hero: Hero, art: CreatureArtDef, dir: int, t: float) -> Dictionary:
	if hero == null or hero.stance <= 0:
		return {}
	var since := t - hero.stance_at
	if since < 0.0:
		return {}
	var names := art.stance_anim(hero.stance_tree, hero.stance)
	if names.is_empty():
		return {}
	var first: String = names[0]
	if since < art.duration(first):
		return _once(art, first, dir, since, false)
	if names.size() > 1:
		var held := since - art.duration(first)
		if held < art.stance_hold_seconds:
			var then: String = names[1]
			var n := maxi(art.frame_count(then), 1)
			return {"anim": then, "dir": dir, "frame": int(held * art.anim_fps(then)) % n}
	return {}


## The animation for the hero's last ability: its own while its weapon type is in
## hand, else "cast".
static func action_anim(hero: Hero, art: CreatureArtDef) -> String:
	if hero == null:
		return "cast"
	var own := _own(hero, art, StringName(hero.anim.act))
	return own.anim if not own.is_empty() else "cast"


## The frame the last ability's animation starts at when it goes off: its strike
## frame (the hit lands as it shows), or 0 for "cast" and "from_start" entries.
static func action_first_frame(hero: Hero, art: CreatureArtDef) -> int:
	if hero == null:
		return 0
	var own := _own(hero, art, StringName(hero.anim.act))
	if own.is_empty() or own.from_start:
		return 0
	return mini(own.strike, maxi(art.frame_count(own.anim) - 1, 0))


## The ability's own animation entry if the hero can play it now (its weapon in
## hand, its sheet in the art), else {}.
static func _own(hero: Hero, art: CreatureArtDef, ability_id: StringName) -> Dictionary:
	var own := art.ability_anim(ability_id)
	if own.is_empty() or not art.sheets.has(own.anim):
		return {}
	if own.weapon != "" and not hero.wields(own.weapon):
		return {}
	return own


## While the hero casts an ability with its own animation (cast bar, wind-up or
## timing bar, from the cast's host start time): its "windup" once then its "loop",
## or the frames before its strike frame, holding the last. {} otherwise.
func _windup(hero: Hero, art: CreatureArtDef, dir: String, t: float) -> Dictionary:
	if hero == null or hero.casting.is_empty():
		return {}
	var ability = hero.casting.get("ability")
	if ability == null:
		return {}
	var own := _own(hero, art, ability.id)
	if own.is_empty():
		return {}
	var since := t - float(hero.casting.get("start", t))
	if own.windup != "" and art.sheets.has(own.windup):
		var w := art.duration(own.windup)
		if since < w or own.loop == "" or not art.sheets.has(own.loop):
			return _once(art, own.windup, dir, since, true)
		var n := maxi(art.frame_count(own.loop), 1)
		return {"anim": own.loop, "dir": dir, "frame": int((since - w) * art.anim_fps(own.loop)) % n}
	if own.strike > 0 and not own.from_start:
		var f := mini(floori(maxf(since, 0.0) * art.anim_fps(own.anim) + 0.0001), own.strike - 1)
		return {"anim": own.anim, "dir": dir, "frame": f}
	return {}


## Plays `anim` once from frame `first`, `since` seconds after it started there.
static func _from(art: CreatureArtDef, anim: String, dir: String, first: int, since: float) -> Dictionary:
	var n := maxi(art.frame_count(anim), 1)
	var frame := first + floori(maxf(since, 0.0) * art.anim_fps(anim) + 0.0001)
	return {"anim": anim, "dir": dir, "frame": clampi(frame, 0, n - 1)}


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
	return art.mirrored(_pick(actor, art, t))


func _pick(actor: Actor, art: CreatureArtDef, t: float) -> Dictionary:
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
		# match the ground at any speed and in any direction. Art with a walk
		# (the stag) walks while not fighting and runs in a fight.
		var anim := "walk" if art.sheets.has("walk") and not _fighting(actor) else "run"
		return {"anim": anim, "dir": dir, "frame": art.run_frame(actor.move, dir, anim, t)}
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


static func _fighting(actor: Actor) -> bool:
	return actor is Enemy and (actor as Enemy).state == Enemy.State.COMBAT


## Death plays once from the host's time of death, the corpse lies still for
## corpse_seconds, then fades out over fade_seconds. Without a death sheet
## (fallback): idle's first frame tipping over onto its side ("tip" 0 -> 1).
func _death_frame(actor: Enemy, art: CreatureArtDef, t: float, dir: String) -> Dictionary:
	if actor.died_at < 0.0:
		return {}
	var since := t - actor.died_at
	var length := art.death_length()
	var alpha := 1.0
	var fading := since - length - art.corpse_seconds
	if fading > 0.0:
		alpha = 1.0 - fading / maxf(art.fade_seconds, 0.001)
	if alpha <= 0.0:
		return {}
	if not art.sheets.has("death"):
		return {"anim": "idle", "dir": dir, "frame": 0, "alpha": alpha,
				"tip": clampf(since / maxf(length, 0.001), 0.0, 1.0)}
	var n := art.frame_count("death")
	var frame := mini(floori(maxf(since, 0.0) * art.anim_fps("death") + 0.0001), n - 1)
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
	elif ability is AbilityDef and art.sheets.has(art.fallback_attack_anim):
		# No attack art (fallback): hold the last frame of the fallback animation
		# through the wind-up, then lunge toward the target on the hit.
		_attacks[actor.id] = {"anim": art.fallback_attack_anim, "fallback": true,
				"start": float(c.get("start", t)), "hit_at": float(c.get("end", t)), "resolved": false}
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
	if a.get("fallback", false):
		var after := t - float(a.hit_at)
		if not a.resolved:
			return {"anim": a.anim, "frame": n - 1}
		if after > art.fallback_lunge_seconds:
			_attacks.erase(actor.id)
			return {}
		var k := clampf(after / maxf(art.fallback_lunge_seconds, 0.001), 0.0, 1.0)
		return {"anim": a.anim, "frame": n - 1, "lunge": art.fallback_lunge_px * sin(PI * k)}
	var frame := floori((t - a.start) * art.anim_fps(a.anim) + 0.0001)
	if frame >= n:
		_attacks.erase(actor.id)
		return {}
	return {"anim": a.anim, "frame": maxi(frame, 0)}
