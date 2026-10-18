class_name CreatureAnimator
extends RefCounted
## Picks the animation frame an animated creature shows, from replicated state
## only (host times for casts, steps and death), so every player sees the same
## frame at the same moment. One animator per view; it remembers each creature's
## last attack so the frames after the hit (recovery) still play once the
## host's wind-up has ended.

var _attacks := {} # actor id -> {"anim", "start", "hit_at", "resolved"}


## {"anim", "dir", "frame", "alpha"} for `actor` at time `t` (empty: draw nothing).
func pick(actor: Enemy, art: CreatureArtDef, t: float) -> Dictionary:
	var dir := CreatureArtDef.direction_for(actor.facing)
	if not actor.alive:
		_attacks.erase(actor.id)
		return _death_frame(actor, art, t, dir)
	var attack := _attack_frame(actor, art, t)
	if not attack.is_empty():
		attack.dir = dir
		return attack
	if actor.move.is_moving(t):
		var n := art.frame_count("run")
		var frame := int(actor.move.progress(t) * art.run_frames_per_tile) % maxi(n, 1)
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
