extends GutHookScript
## Runs before every test: the tests describe the classic rules (timing bars, cast
## times, wind-ups, a 1 s global cooldown), so the temporary instant hero combat
## (CombatRules.action_combat, on in the game) is turned off; tests of the new
## controls turn it on themselves.


func run() -> void:
	ContentDB.rules.action_combat = false
