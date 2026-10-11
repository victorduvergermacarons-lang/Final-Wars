extends Node
## Prints the balance scenarios. Run:
##   godot --headless --path . tests/balance/balance_report.tscn

func _ready() -> void:
	var c = ContentDB
	print("(seconds = fight length, hp_lost_pct = worst hero's lowest HP point)")
	var sword := [[&"sword", &"holy_charm"]]
	var staff := [[&"staff", &"holy_charm"]]
	var tank := [[&"sword", &"shield"]]
	print("sword solo vs 1      ", BalanceSim.average(c, sword, [&"strike"], 1))
	print("staff solo vs 1      ", BalanceSim.average(c, staff, [&"fireball"], 1))
	print("sword+shield vs 1    ", BalanceSim.average(c, tank, [&"strike"], 1))
	print("sword+shield blk v1  ", BalanceSim.average(c, tank, [&"strike"], 1, 10, 0.0, true))
	print("sword solo vs 2      ", BalanceSim.average(c, sword, [&"strike"], 2))
	print("sword solo heal vs 2 ", BalanceSim.average(c, sword, [&"strike"], 2, 10, 0.5))
	print("pair vs 2            ", BalanceSim.average(c, [[&"sword", &"shield"], [&"staff", &"holy_charm"]], [&"strike", &"fireball"], 2, 10, 0.5))
	get_tree().quit()
