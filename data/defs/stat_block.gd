class_name StatBlock
extends Resource
## A full set of stat values. Used for base stats, item stats, item growth and
## computed totals. See Stat for ids and units.

@export var hp: float = 0.0
@export var mana: float = 0.0
@export var phys_atk: float = 0.0
@export var mag_atk: float = 0.0
@export var phys_def: float = 0.0
@export var mag_def: float = 0.0
@export var crit_rate: float = 0.0
@export var crit_dmg: float = 0.0
@export var speed: float = 0.0
@export var accuracy: float = 0.0
@export var evasion: float = 0.0
@export var jump: float = 0.0
@export_group("Mastery")
@export var fire_mastery: float = 0.0
@export var earth_mastery: float = 0.0
@export var water_mastery: float = 0.0
@export var air_mastery: float = 0.0
@export var sword_mastery: float = 0.0
@export var bow_mastery: float = 0.0
@export var hammer_mastery: float = 0.0


func get_stat(id: Stat.Id) -> float:
	return get(Stat.property_of(id))


func set_stat(id: Stat.Id, value: float) -> void:
	set(Stat.property_of(id), value)


## Adds `other` into this block in place, optionally scaled. Returns self.
func add(other: StatBlock, scale: float = 1.0) -> StatBlock:
	if other == null:
		return self
	for id in Stat.all():
		set_stat(id, get_stat(id) + other.get_stat(id) * scale)
	return self


## Returns a new block with every stat multiplied by `factor`.
func scaled(factor: float) -> StatBlock:
	var out := StatBlock.new()
	for id in Stat.all():
		out.set_stat(id, get_stat(id) * factor)
	return out


## Returns an independent copy (unlike Resource.duplicate, never shares state).
func copy() -> StatBlock:
	return StatBlock.new().add(self)


func is_zero() -> bool:
	for id in Stat.all():
		if not is_zero_approx(get_stat(id)):
			return false
	return true


func equals(other: StatBlock) -> bool:
	for id in Stat.all():
		if not is_equal_approx(get_stat(id), other.get_stat(id)):
			return false
	return true


## Plain-data form for network replication. Omits zero stats.
func to_dict() -> Dictionary:
	var d := {}
	for id in Stat.all():
		var v := get_stat(id)
		if not is_zero_approx(v):
			d[int(id)] = v
	return d


static func from_dict(d: Dictionary) -> StatBlock:
	var out := StatBlock.new()
	for key in d:
		var id := int(key)
		if id >= 0 and id < Stat.COUNT:
			out.set_stat(id as Stat.Id, float(d[key]))
	return out


## Convenience for code and tests: StatBlock.make({Stat.Id.HP: 100}).
static func make(values: Dictionary) -> StatBlock:
	return from_dict(values)


func _to_string() -> String:
	var parts: PackedStringArray = []
	for id in Stat.all():
		var v := get_stat(id)
		if not is_zero_approx(v):
			parts.append("%s=%s" % [Stat.property_of(id), v])
	return "StatBlock(%s)" % ", ".join(parts)
