# Final Wars

2D isometric open-world co-op RPG built with Godot 4.7 (GDScript).
The design doc lives in [CLAUDE.md](CLAUDE.md).

## Requirements
- Godot **4.7.x** (developed against 4.7.2-stable), standard (non-.NET) build.

## Run the game
Open the folder in the Godot editor and press **F5**. The main menu offers
**Play Solo**, **Host Game** (default port 7777) and **Join Game** (host's IP + port).
To play over the internet, the host must forward UDP port 7777 on their router.

Command-line shortcuts: `--solo`, `--host`, `--join=ADDRESS`, optionally
`--port=N` and `--name=NAME`. To test co-op on one machine (two instances from
the editor), over LAN or over the internet, see
[docs/local-multiplayer-testing.md](docs/local-multiplayer-testing.md).

| Input | Action |
|-------|--------|
| W A S D / arrows | Move (W = up-right, D = down-right, S = down-left, A = up-left). Tap a new direction to turn in place; hold to walk |
| Strike / Fireball | Aimed where you face: Strike hits the tile in front, Fireball flies straight ahead and stops at the first enemy |
| Left click | Target an ally or enemy for Heal / Resurrect (also: click a party/target frame) |
| Tab / Esc | Next enemy / clear target |
| 1–9, 0 | Action bar slots (rebind with the **Keybinds** button: hover a slot, press a key) |
| P | Spellbook: drag abilities onto the action bar; right-click a slot to clear it |
| C | Character panel: equip items, see stats and AP progress (out of combat) |
| R | Release when dead |
| Mouse wheel | Zoom |

Your action bar layout and keybinds are saved in `user://settings.cfg`.

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

Network check (two headless Godot processes, host + client on localhost):

```bash
GODOT=/path/to/godot tests/net/run_net_check.sh
```
