# Final Wars

2D isometric open-world co-op RPG built with Godot 4.7 (GDScript).
The design doc lives in [CLAUDE.md](CLAUDE.md).

## Requirements
- Godot **4.7.x** (developed against 4.7.2-stable), standard (non-.NET) build.

## Run the game
Open the folder in the Godot editor and press **F5**. The main menu offers
**Play Solo**, **Host Game** (default port 7777) and **Join Game** (host's IP + port).
To play over the internet, the host must forward UDP port 7777 on their router.

Pick or create a **character** in the main menu first. Characters save on your
computer (Godot's user folder, `characters/`) every 60 seconds, when you return to
the menu and when you quit, so you keep your level, gear, AP and mastered abilities.

Command-line shortcuts: `--solo`, `--host`, `--join=ADDRESS`, optionally
`--port=N` and `--name=NAME` (loads that character, creating it if needed). To test co-op on one machine (two instances from
the editor), over LAN or over the internet, see
[docs/local-multiplayer-testing.md](docs/local-multiplayer-testing.md).

| Input | Action |
|-------|--------|
| W A S D / arrows | Move (W = up-right, D = down-right, S = down-left, A = up-left). Tap a new direction to turn in place; hold to walk |
| Strike / Fireball | Aimed where you face: Strike hits the tile in front, Fireball flies straight ahead and stops at the first enemy |
| Left click | Target an ally or enemy for Heal / Resurrect (also: click a party/target frame) |
| Tab / Esc | Next enemy / clear target |
| 1–9, 0 | Action bar slots (rebind with the **Keybinds** button: hover a slot, press a key) |
| Shift+1 – Shift+6 | Show action bar 1–6 (the number is shown bottom-right; the arrows there also flip bars) |
| P | Spellbook: drag abilities onto the action bar; right-click a slot to clear it |
| B | Inventory: equipment + bag. Drag to equip/move, right-click equip/unequip, shift+click split, ctrl+right-click destroy. Hover for tooltips with comparison |
| L | Quest log: active quests, objectives, rewards, Abandon. The tracker on the right shows progress; "!" / "?" over NPCs mark quests to take / hand in |
| C | Character sheet: level, XP, stats (base / growth / gear / buffs), mastered and in-progress abilities |
| E / right-click an NPC | Talk to a townsperson next to you (within 2 tiles). Hilda sells potions: "Browse goods", then right-click bag items to sell them |
| Right-click a potion | Drink it (or drag it onto the action bar). Potions share a 30 s cooldown and work in combat |
| R | Release when dead |
| Leave game (button) | Save and return to the main menu |
| Mouse wheel | Zoom |

Your action bar layout and keybinds are saved in `user://settings.cfg`.

## What's in the game (Milestone 2)
- **Millbrook** (town, where everyone starts and joins): Hilda the trader, quest givers
  Captain Rowan and Old Maren, a graveyard.
- **Greenfields** (through the town's down-right edge): Wolves (Lv1), Goblin Shamans
  (Lv2, ranged, keep their distance), Bandit Brutes (Lv3, slow, hit hard), Fen
  Skirmishers (Lv4, fast, flank) and the elite **Old Grizzlehide** (Lv5, needs a group).
- 12 equippable items in four rarities, each teaching an ability; 5 quests including
  Captain Rowan's 3-quest chain.
- Up to 4 players. Characters save on each player's computer; the host saves world events.

To test every feature step by step (no programming needed), follow
[docs/playtest-checklist.md](docs/playtest-checklist.md).

## Run the tests
Tests use [GUT](https://github.com/bitwes/Gut) 9.7.1, vendored in `addons/gut`.

```bash
./run_tests.sh                       # whole suite
./run_tests.sh -gselect=test_smoke   # one file
GODOT=/path/to/godot ./run_tests.sh  # if godot isn't on PATH
```

You can also run them from the editor's **GUT** bottom panel.

Balance report (scripted fights on the real simulation with shipped content):

```bash
godot --headless --path . tests/balance/balance_report.tscn
```

Network check (four headless Godot processes, host + 3 clients on localhost):

```bash
GODOT=/path/to/godot tests/net/run_net_check.sh
```
