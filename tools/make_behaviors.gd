extends SceneTree
## Writes the starting behavior files for the first tree abilities:
## content/tree/behaviors/<ID>.tres (shape, targeting, effects) and the buffs they
## apply in content/buffs/ (so clients can look them up by id).
##   godot --headless --path . -s res://tools/make_behaviors.gd [-- --force]
## Existing files are left alone unless --force is given, so hand-tuned .tres files
## survive a re-run. Names, tiers, cooldowns, Mastery numbers and item names are
## not set here: they come from the spreadsheet (TreeContent).

const BEHAVIORS := "res://content/tree/behaviors"
const BUFFS := "res://content/buffs"

var force := false
var written := 0
var kept := 0

const T := AbilityDef.TargetingMode
const K := AbilityEffect.Kind
const MAG := AbilityEffect.DamageType.MAGICAL
const PHYS := AbilityEffect.DamageType.PHYSICAL


func _init() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BEHAVIORS))
	_fire()
	_earth()
	_water()
	_air()
	_weapons()
	print("Behaviors: %d written, %d kept (use --force to overwrite)." % [written, kept])
	quit(0)


# --- Fire ---------------------------------------------------------------------

func _fire() -> void:
	_save("F01", _ab(T.TARGETED, 1, [_dmg(MAG)], {"mana_cost": 5.0}))
	var burn := _buff(&"fire_kick_burn", "Burning", 3.0, {"is_debuff": true})
	_save("F02", _ab(T.TARGETED, 1, [_dmg(MAG, 0.8), _fx(K.DAMAGE_OVER_TIME, {"base_amount": -1.0,
			"sheet_scaling": true, "power": 0.6, "damage_type": MAG, "buff": burn, "can_crit": false})],
			{"mana_cost": 8.0}))
	_save("F03", _ab(T.SKILLSHOT, 4, [_dmg(MAG)], {"projectile_speed": 16.0, "ranged": true, "mana_cost": 6.0}))
	var kindled := _buff(&"kindled", "Sun Warrior's Fire", 20.0, {"damage_dealt_multiplier": 1.3, "affects_tree": "Fire",
			"charges": 3})
	var breath := _buff(&"sun_breath", "Sun Warrior's Breath", 10.0, {"mana_regen_percent": 1.0})
	_save("F04", _ab(T.SELF, 0, [_fx(K.BUFF, {"buff": kindled}), _fx(K.BUFF, {"buff": breath})],
			{"target": AbilityDef.TargetType.SELF,
			"mana_cost": 10.0, "on_gcd": false}))
	_save("F05", _ab(T.GROUND, 3, [
			_fx(K.DASH_TO, {"base_amount": 3.0, "applies": AbilityEffect.Applies.CASTER}),
			_fx(K.ZONE, {"applies": AbilityEffect.Applies.AREA, "duration_seconds": 3.0, "zone_tick_seconds": 1.0,
				"zone_ability": _zone_hit("F05_burn", "Fire", 2, Stat.Id.MAG_ATK, 0.4)})],
			{"charges_base": 1, "mastery_per_charge": 300.0, "aim": AbilityDef.Aim.EIGHT_WAY, "mana_cost": 10.0,
			"requires_line_of_sight": false}))
	_save("F06", _ab(T.SKILLSHOT, 3, [_dmg(MAG, 1.1)], {"aim": AbilityDef.Aim.EIGHT_WAY, "pierce": true,
			"mana_cost": 10.0}))
	_save("F07", _ab(T.GROUND, 5, [_dmg(MAG, 1.2)], {"area_radius": 1, "telegraph_seconds": 0.4, "ranged": true,
			"mana_cost": 15.0}))
	_save("F08", _ab(T.GROUND, 4, [_fx(K.ZONE, {"applies": AbilityEffect.Applies.AREA, "duration_seconds": 6.0,
			"zone_tick_seconds": 1.0, "zone_ability": _zone_hit("F08_burn", "Fire", 2, Stat.Id.MAG_ATK, 0.35)})],
			{"area_radius": 1, "mana_cost": 15.0}))
	_save("F09", _ab(T.TARGETED, 1, [_dmg(MAG, 0.5), _dmg(MAG, 0.5), _dmg(MAG, 0.5),
			_fx(K.KNOCKBACK, {"base_amount": 1.0})], {"mana_cost": 12.0}))


# --- Earth --------------------------------------------------------------------

func _earth() -> void:
	_save("E01", _ab(T.SKILLSHOT, 4, [_dmg(PHYS)], {"arc_seconds": 0.3, "ranged": true, "mana_cost": 6.0}))
	_save("E03", _ab(T.GROUND, 3, [_fx(K.TERRAIN, {"applies": AbilityEffect.Applies.AREA, "base_amount": 1.0,
			"duration_seconds": 15.0, "mastery_per_extra": 500.0, "max_extra": 1})], {"mana_cost": 8.0}))
	_save("E04", _ab(T.SELF, 0, [_fx(K.TAUNT)], {"area_radius": 1, "mana_cost": 8.0}))
	_save("E05", _ab(T.GROUND, 4, [_fx(K.TERRAIN, {"applies": AbilityEffect.Applies.AREA, "base_amount": 2.0,
			"duration_seconds": 12.0, "wall_line": true, "lift_damage": 10.0, "mastery_per_extra": 300.0})],
			{"mana_cost": 15.0}))


# --- Water --------------------------------------------------------------------

func _water() -> void:
	var ally := AbilityDef.TargetType.ALLY
	_save("W01", _ab(T.TARGETED, 2, [_heal()], {"target": ally, "mana_cost": 8.0}))
	_save("W02", _ab(T.TARGETED, 3, [_dmg(MAG)], {"ranged": true, "mana_cost": 6.0}))
	var haste := _buff(&"flow_state", "Haste", 30.0, {"cooldown_multiplier": 0.75, "step_cooldown_multiplier": 0.75})
	_save("W03", _ab(T.TARGETED, 3, [_fx(K.BUFF, {"buff": haste})], {"target": ally, "mana_cost": 10.0}))
	var chill := _buff(&"frost_shard_chill", "Chilled", 2.0, {"is_debuff": true, "step_cooldown_multiplier": 1.5})
	_save("W04", _ab(T.SKILLSHOT, 4, [_dmg(MAG, 0.9), _fx(K.BUFF, {"buff": chill})],
			{"projectile_speed": 12.0, "ranged": true, "mana_cost": 8.0}))
	var mist := _buff(&"soothing_mist", "Soothing Mist", 12.0, {"tick_seconds": 1.0})
	_save("W05", _ab(T.TARGETED, 4, [_fx(K.HEAL_OVER_TIME, {"base_amount": -1.0, "sheet_scaling": true,
			"power": 1.5, "buff": mist})], {"target": ally, "mana_cost": 12.0}))
	_save("W06", _ab(T.SKILLSHOT, 3, [_dmg(MAG, 0.9), _fx(K.KNOCKBACK, {"base_amount": 1.0, "push_along_cast": true})],
			{"aim": AbilityDef.Aim.EIGHT_WAY, "pierce": true, "mana_cost": 12.0}))
	var leech := _dmg(MAG)
	leech.lifesteal = 0.5
	_save("W07", _ab(T.TARGETED, 3, [leech], {"ranged": true, "mana_cost": 12.0}))
	var blessing := _buff(&"tidal_blessing", "Tidal Blessing", 45.0,
			{"modifiers": [_mod(Stat.Id.PHYS_DEF, 20.0), _mod(Stat.Id.MAG_DEF, 20.0)] as Array[StatModifier]})
	_save("W08", _ab(T.TARGETED, 3, [_fx(K.BUFF, {"buff": blessing})], {"target": ally, "mana_cost": 12.0}))
	var spikes := _buff(&"ice_spikes_chill", "Chilled", 3.0, {"is_debuff": true, "step_cooldown_multiplier": 1.5})
	_save("W09", _ab(T.GROUND, 4, [_dmg(MAG), _fx(K.BUFF, {"buff": spikes})], {"area_radius": 1,
			"telegraph_seconds": 0.4, "ranged": true, "mana_cost": 15.0}))


# --- Air ----------------------------------------------------------------------

func _air() -> void:
	_save("A01", _ab(T.TARGETED, 1, [_dmg(MAG, 0.6), _fx(K.KNOCKBACK, {"base_amount": 1.0})], {"mana_cost": 6.0}))
	_save("A02", _ab(T.TARGETED, 3, [_dmg(MAG, 0.5), _fx(K.INTERRUPT)], {"ranged": true, "mana_cost": 8.0,
			"on_gcd": false}))
	var step := _buff(&"air_step", "Air Step", 10.0, {"free_steps": true, "charges": 5})
	_save("A03", _ab(T.SELF, 0, [_fx(K.BUFF, {"buff": step})], {"target": AbilityDef.TargetType.SELF,
			"mana_cost": 8.0, "on_gcd": false}))
	_save("A05", _ab(T.TARGETED, 3, [_dmg(MAG, 0.6), _fx(K.KNOCKBACK, {"base_amount": 3.0, "impact_damage": 25.0})],
			{"ranged": true, "mana_cost": 12.0}))


# --- Weapon arts (no mana) ----------------------------------------------------

func _weapons() -> void:
	_save("S01", _ab(T.TARGETED, 1, [_dmg(PHYS)], {}))
	_save("S04", _ab(T.TARGETED, 3, [_fx(K.DASH_TO, {"base_amount": 2.0, "applies": AbilityEffect.Applies.CASTER}),
			_dmg(PHYS, 1.1)], {"hit_range": 1}))
	_save("B01", _ab(T.TARGETED, 5, [_dmg(PHYS, 0.9)], {"ranged": true}))
	_save("B02", _ab(T.SKILLSHOT, 7, [_dmg(PHYS, 1.8)], {"cast_seconds": 1.0, "projectile_speed": 14.0,
			"ranged": true}))
	_save("H01", _ab(T.TARGETED, 1, [_dmg(PHYS, 1.6)], {"windup_seconds": 0.3}))
	_save("H02", _ab(T.SELF, 0, [_dmg(PHYS)], {"area_radius": 1}))


# --- Helpers ------------------------------------------------------------------

func _ab(targeting: AbilityDef.TargetingMode, max_range: int, effects: Array, props: Dictionary) -> AbilityDef:
	var a := AbilityDef.new()
	a.targeting = targeting
	a.max_range = max_range
	var list: Array[AbilityEffect] = []
	list.assign(effects)
	a.effects = list
	for k in props:
		a.set(k, props[k])
	return a


func _fx(kind: AbilityEffect.Kind, props: Dictionary = {}) -> AbilityEffect:
	var e := AbilityEffect.new()
	e.kind = kind
	for k in props:
		e.set(k, props[k])
	return e


## Damage at the tier default plus the sheet's Scales With stats, × power.
func _dmg(type: AbilityEffect.DamageType, power: float = 1.0) -> AbilityEffect:
	return _fx(K.DAMAGE, {"base_amount": -1.0, "sheet_scaling": true, "damage_type": type, "power": power})


func _heal(power: float = 1.0) -> AbilityEffect:
	return _fx(K.HEAL, {"base_amount": -1.0, "sheet_scaling": true, "power": power})


## What a ground zone does each tick (its own little ability; tier default damage).
func _zone_hit(id: String, tree: String, tier: int, stat: Stat.Id, power: float) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = StringName(id)
	a.tree = tree
	a.tier = tier
	a.targeting = T.TARGETED
	var e := _fx(K.DAMAGE, {"base_amount": -1.0, "damage_type": MAG, "power": power, "can_crit": false})
	e.scaling = [AbilityScaling.make(stat, 1.0)] as Array[AbilityScaling]
	a.effects = [e] as Array[AbilityEffect]
	return a


func _mod(stat: Stat.Id, flat: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	m.flat = flat
	return m


## Saves a buff to content/buffs (unless it exists) and returns the saved one.
func _buff(id: StringName, name: String, seconds: float, props: Dictionary) -> BuffDef:
	var path := "%s/%s.tres" % [BUFFS, id]
	if ResourceLoader.exists(path) and not force:
		kept += 1
		return load(path)
	var b := BuffDef.new()
	b.id = id
	b.display_name = name
	b.duration_seconds = seconds
	for k in props:
		b.set(k, props[k])
	_write(b, path)
	return load(path)


func _save(id: String, ability: AbilityDef) -> void:
	var path := "%s/%s.tres" % [BEHAVIORS, id]
	if ResourceLoader.exists(path) and not force:
		kept += 1
		return
	ability.id = StringName(id)
	_write(ability, path)


func _write(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("ERROR: could not write %s (%s)" % [path, error_string(err)])
		return
	written += 1
