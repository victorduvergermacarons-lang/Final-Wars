class_name DebugHud
extends CanvasLayer
## Temporary text HUD until the real one (step 10): hero status, abilities with
## cooldowns, target, messages and controls.

const REASONS := {
	"out_of_range": "Out of range",
	"no_line_of_sight": "Target not in line of sight",
	"not_enough_mana": "Not enough mana",
	"on_cooldown": "Not ready yet",
	"invalid_target": "Invalid target",
	"in_combat": "Can't do that in combat",
	"blocked": "Can't go there",
	"occupied": "Someone is in the way",
}

var session
var client: ClientState
var _label: Label


func setup(p_session, p_client: ClientState) -> void:
	session = p_session
	client = p_client
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	session.events_received.connect(_on_events)


func _process(_delta: float) -> void:
	if session == null:
		return
	var hero: Hero = session.local_hero()
	if hero == null:
		return
	var now: float = session.now()
	var s := hero.current_stats(now)
	var lines: PackedStringArray = []
	lines.append("%s  Level %d   XP %d / %d" % [hero.display_name, hero.level, hero.xp,
			Leveling.xp_to_next(hero.level, session.rules())])
	lines.append("HP %d / %d    Mana %d / %d    %s" % [hero.hp, s.hp, hero.mana, s.mana,
			"IN COMBAT" if hero.in_combat(now) else ("DEAD - press R to release" if not hero.alive else "")])
	lines.append("Gear: " + ", ".join(hero.equipped_items().map(func(i): return i.display_name)))
	var gcd := hero.cooldowns.gcd_remaining(now)
	lines.append("Abilities%s:" % ("  (GCD %.1fs)" % gcd if gcd > 0 else ""))
	var abilities := hero.available_abilities()
	for i in mini(abilities.size(), 5):
		var a: AbilityDef = abilities[i]
		var cd := hero.cooldowns.ability_remaining(a.id, now)
		var ap_text := "mastered" if hero.is_mastered(a.id) else "AP %d/%d" % [hero.ap.get(a.id, 0), a.ap_to_master]
		lines.append("  [%d] %s  %s  (%s)" % [i + 1, a.display_name, "%.1fs" % cd if cd > 0 else "ready", ap_text])
	var target: Actor = session.get_actor(client.target_id)
	if target != null:
		lines.append("Target: %s  HP %d / %d%s" % [target.display_name, target.hp,
				target.current_stats(now).hp, "" if target.alive else "  (dead)"])
	lines.append("")
	for m in client.messages:
		lines.append("> " + m)
	lines.append("")
	lines.append("WASD/arrows move · click/Tab target · Esc clear · 1-5 abilities · R release")
	lines.append("F1-F4 equip Sword/Staff/Shield/Holy Charm (temporary) · mouse wheel zoom")
	_label.text = "\n".join(lines)


func _on_events(events: Array) -> void:
	var me: int = session.local_hero_id
	for e in events:
		if e.type == "joined":
			client.say("%s joined the game." % e.name)
		elif e.type == "left":
			client.say("%s left the game." % e.name)
		if e.get("target", -2) != me:
			continue
		match e.type:
			"rejected":
				if e.reason != "not_ready":
					client.say(REASONS.get(e.reason, e.reason.capitalize()))
			"level_up":
				client.say("You reached level %d!" % e.level)
			"mastered":
				client.say("You mastered %s!" % e.ability)
			"death":
				client.say("You died.")
