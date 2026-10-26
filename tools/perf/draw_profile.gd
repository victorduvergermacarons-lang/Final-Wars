extends Node
## Frame time per map, redrawing every tile vs the terrain cache (WorldView).
## Runs the world solo with no window; prints the average and worst frame:
##   godot --headless --path . res://tools/perf/draw_profile.tscn
## Headless frames cost at least ~6.9 ms (the engine's own pacing), so read
## the numbers above that floor.
var zones := [&"town", &"greenfields", &"enemy_testing"]
var zi := 0
var phase := 0 # 0 = full redraw, 1 = terrain cache
var frames := 0
var t0 := 0
var last := 0
var worst := 0
var session: LocalSession
var view: WorldView

func _ready() -> void:
	_begin()

func _begin() -> void:
	if session != null:
		session.queue_free()
	if view != null:
		view.queue_free()
	session = LocalSession.new()
	add_child(session)
	var ch := CharacterData.new_character("Prof", ContentDB.heroes.values()[0])
	session.start(ContentDB.zones.values(), zones[zi], ContentDB.rules, ch, 1)
	view = WorldView.new()
	WorldView.use_terrain_cache = phase == 1
	add_child(view)
	view.setup(session, ClientState.new(), session.zone())
	frames = 0
	worst = 0

func _process(_d: float) -> void:
	frames += 1
	var now := Time.get_ticks_usec()
	if frames == 30:
		t0 = now
	elif frames > 30:
		worst = maxi(worst, now - last)
	last = now
	if frames == 230:
		var ms := (now - t0) / 1000.0 / 200.0
		print("%-14s %-12s avg %6.2f ms  worst %6.2f ms" % [zones[zi], "cache" if phase == 1 else "full redraw", ms, worst / 1000.0])
		phase += 1
		if phase == 2:
			phase = 0
			zi += 1
			if zi == zones.size():
				get_tree().quit()
				return
		_begin()
