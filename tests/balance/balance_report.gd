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
	print("-- Milestone 2 enemies (hero level in brackets) --")
	var axe := [[&"greataxe", &"holy_charm"]]
	var group := [[&"sword", &"shield", &"iron_helm"], [&"greataxe", &"holy_charm"],
			[&"staff", &"frostweave_robe"], [&"staff", &"holy_charm", &"acolytes_leggings"]]
	var rot := [&"strike", &"cleave", &"fireball"]
	print("sword solo vs Shaman [2]   ", BalanceSim.average(c, sword, rot, 1, 10, 0.0, false, &"goblin_shaman", 2))
	print("staff solo vs Shaman [2]   ", BalanceSim.average(c, staff, rot, 1, 10, 0.0, false, &"goblin_shaman", 2))
	print("sword solo vs Brute [3]    ", BalanceSim.average(c, sword, rot, 1, 10, 0.0, false, &"bandit_brute", 3))
	print("axe solo vs Brute [3]      ", BalanceSim.average(c, axe, rot, 1, 10, 0.0, false, &"bandit_brute", 3))
	print("sword solo vs Skirmisher [4]", BalanceSim.average(c, sword, rot, 1, 10, 0.0, false, &"fen_skirmisher", 4))
	print("sword solo vs Grizzlehide [5]", BalanceSim.average(c, sword, rot, 1, 10, 0.5, false, &"old_grizzlehide", 5))
	print("pair vs Grizzlehide [5]    ", BalanceSim.average(c, [[&"sword", &"shield"], [&"staff", &"holy_charm"]], rot, 1, 10, 0.5, false, &"old_grizzlehide", 5))
	print("group of 4 vs Grizzlehide [5]", BalanceSim.average(c, group, rot, 1, 10, 0.5, false, &"old_grizzlehide", 5))
	get_tree().quit()
