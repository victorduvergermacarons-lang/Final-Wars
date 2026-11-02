extends Node
## Prints the balance scenarios (Milestone 3 ability trees). Run:
##   godot --headless --path . tests/balance/balance_report.tscn

const S := preload("res://tests/balance/balance_scenarios.gd")


func _ready() -> void:
	var c = ContentDB
	print("(seconds = fight length, hp_lost_pct = worst hero's lowest HP point)")
	for row in (S.ROWS if OS.get_environment("BALANCE_ONLY") == "" else []):
		print("%-34s %s" % [row[0], BalanceSim.tree_average(c, row[1], row[2], row[3], 10, row[4])])
	if OS.get_environment("BALANCE_ONLY") == "foreman" or OS.get_environment("BALANCE_ONLY") == "":
		for row in S.FOREMAN_ROWS:
			print("%-34s %s" % [row[0], BalanceSim.boss_average(c, row[1], 6, row[2])])
	get_tree().quit()
