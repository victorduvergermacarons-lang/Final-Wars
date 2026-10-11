# Final Wars

2D isometric open-world co-op RPG built with Godot 4.7 (GDScript).
The design doc lives in [CLAUDE.md](CLAUDE.md).

## Requirements
- Godot **4.7.x** (developed against 4.7.2-stable), standard (non-.NET) build.

## Run the game
Open the folder in the Godot editor and press **F5**. The main menu offers
**Play Solo**, **Host Game** (default port 7777) and **Join Game** (host's IP + port).
To play over the internet, the host must forward UDP port 7777 on their router.

Command-line shortcuts (after `--`): `--solo`, `--host`, `--join=ADDRESS`,
optionally `--port=N` and `--name=NAME`.

| Input | Action |
|-------|--------|
| W A S D / arrows | Move (W = up-right, D = down-right, S = down-left, A = up-left) |
| Left click | Target an enemy or ally |
| Tab / Esc | Next enemy / clear target |
| 1–5 | Use your abilities in order (temporary until the action bar) |
| F1–F4 | Equip or unequip Sword / Staff / Shield / Holy Charm (temporary) |
| R | Release when dead |
| Mouse wheel | Zoom |

## Run the tests
Tests use [GUT](https://github.com/bitwes/Gut) 9.7.1, vendored in `addons/gut`.

```bash
./run_tests.sh                       # whole suite
./run_tests.sh -gselect=test_smoke   # one file
GODOT=/path/to/godot ./run_tests.sh  # if godot isn't on PATH
```

You can also run them from the editor's **GUT** bottom panel.

Network check (two headless Godot processes, host + client on localhost):

```bash
GODOT=/path/to/godot tests/net/run_net_check.sh
```
