class_name LootRolls
extends RefCounted
## Need / Greed / Pass rolls for a boss's key items (host only; one per zone).
## Every hero who fought the boss gets a roll window; no answer before the timer
## (or leaving the game) is a Pass that earns no bonus. The roll is
## roll_min..roll_max plus the player's bad-luck bonus (Hero.loot_bonus); Need beats
## Greed, the highest total wins, ties roll again between the tied players.
## Bonus: +bonus_need_lost for each Need roll lost, +bonus_pass for each chosen
## Pass, back to 0 on winning. Numbers: PartyPlayDef "Boss rolls".

const CHOICES := ["need", "greed", "pass"]

## {id, item: ItemDef, count, boss, eligible: Array[int], names: {id: name},
##  choices: {id: choice}, ends_at}
var _sessions: Array = []
var _next_id := 1


## A key item: a scroll, a tree weapon, or equipment that would raise the stats of
## at least one of `heroes` if worn instead of what they wear in that place.
static func is_key_item(item: ItemDef, heroes: Array) -> bool:
	if item == null or item.quest_item:
		return false
	if item.is_scroll or item.tree != "":
		return true
	if not item.is_equippable():
		return false
	for h in heroes:
		if improves(item, h):
			return true
	return false


## Whether wearing `item` would add more to `hero`'s stats than what it wears in
## that place now (for accessories, the weaker of the two).
static func improves(item: ItemDef, hero: Hero) -> bool:
	var places := EquipSlot.slots_for(item.slot)
	if places.is_empty():
		return false
	var worst := INF
	for s in places:
		var worn: ItemDef = hero.equipped_in(s)
		worst = minf(worst, stat_total(worn))
	return stat_total(item) > worst


static func stat_total(item: ItemDef) -> float:
	if item == null or item.stats == null:
		return 0.0
	var t := 0.0
	for s in Stat.core():
		t += item.stats.get_stat(s)
	return t


func start(item: ItemDef, count: int, boss: String, heroes: Array, now: float, pp: PartyPlayDef) -> Dictionary:
	var s := {"id": _next_id, "item": item, "count": count, "boss": boss, "eligible": [], "names": {},
			"choices": {}, "ends_at": now + pp.roll_seconds}
	_next_id += 1
	for h in heroes:
		s.eligible.append(h.id)
		s.names[h.id] = h.display_name
	_sessions.append(s)
	return s


func active() -> Array:
	return _sessions


## A player's choice. Returns "" or a reason.
func choose(hero_id: int, roll_id: int, choice: String) -> String:
	if not CHOICES.has(choice):
		return "bad_choice"
	for s in _sessions:
		if s.id != roll_id:
			continue
		if not s.eligible.has(hero_id):
			return "not_eligible"
		if s.choices.has(hero_id):
			return "already_chosen"
		s.choices[hero_id] = choice
		return ""
	return "no_roll"


## Sessions whose every player has chosen, or whose timer ran out (removed).
func due(now: float) -> Array:
	var out: Array = []
	for s in _sessions:
		if now >= s.ends_at or s.choices.size() >= s.eligible.size():
			out.append(s)
	for s in out:
		_sessions.erase(s)
	return out


## Settles a session. `heroes`: id -> Hero for those still in the zone (a missing
## one who hadn't chosen has passed without the bonus). Returns {"winner": id or -1,
## "lines": [{"hero", "name", "choice", "roll", "bonus", "total", "timeout"}],
## "rounds": n}, and updates every bonus.
static func resolve(s: Dictionary, heroes: Dictionary, rng: RandomNumberGenerator, pp: PartyPlayDef) -> Dictionary:
	var lines: Array = []
	var needers: Array = []
	var greeders: Array = []
	for id in s.eligible:
		var choice: String = s.choices.get(id, "")
		var h: Hero = heroes.get(id)
		var timeout := choice == ""
		if timeout:
			choice = "pass"
		var bonus := h.loot_bonus if h != null else 0
		lines.append({"hero": id, "name": s.names.get(id, "?"), "choice": choice, "roll": 0, "bonus": bonus,
				"total": 0, "timeout": timeout})
		if choice == "need":
			needers.append(id)
		elif choice == "greed":
			greeders.append(id)
	# Everyone who chose Need or Greed rolls (all results are shown); the winner
	# comes from the Need rolls if any, else the Greed ones.
	for line in lines:
		if line.choice != "pass":
			line.roll = rng.randi_range(pp.roll_min, pp.roll_max)
			line.total = line.roll + line.bonus
	var pool := needers if not needers.is_empty() else greeders
	var winner := -1
	var rounds := 0
	while not pool.is_empty() and winner < 0:
		rounds += 1
		if rounds > 1: # ties roll again between the tied players
			for line in lines:
				if pool.has(line.hero):
					line.roll = rng.randi_range(pp.roll_min, pp.roll_max)
					line.total = line.roll + line.bonus
		var best := -1
		var tied: Array = []
		for line in lines:
			if not pool.has(line.hero):
				continue
			if line.total > best:
				best = line.total
				tied = [line.hero]
			elif line.total == best:
				tied.append(line.hero)
		if tied.size() == 1:
			winner = tied[0]
		elif rounds > pp.max_rerolls:
			tied.sort()
			winner = tied[0]
		else:
			pool = tied
	# Bad-luck bonus.
	for line in lines:
		var h: Hero = heroes.get(line.hero)
		if h == null:
			continue
		if line.hero == winner:
			h.loot_bonus = 0
		elif line.choice == "pass" and not line.timeout:
			h.loot_bonus += pp.bonus_pass
		elif line.choice == "need" and winner >= 0:
			h.loot_bonus += pp.bonus_need_lost
	return {"winner": winner, "lines": lines, "rounds": rounds}


## Plain data for clients: [{"id", "item", "count", "boss", "ends_at", "eligible", "chosen": [ids]}].
func to_array() -> Array:
	var out: Array = []
	for s in _sessions:
		out.append({"id": s.id, "item": String(s.item.id), "count": s.count, "boss": s.boss,
				"ends_at": s.ends_at, "eligible": s.eligible.duplicate(), "chosen": s.choices.keys()})
	return out
