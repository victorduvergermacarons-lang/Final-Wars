# Final Wars

2D isometric open-world co-op RPG built with Godot 4.7 (GDScript).
The design doc lives in [CLAUDE.md](CLAUDE.md).

## Requirements
- Godot **4.7.x** (developed against 4.7.2-stable), standard (non-.NET) build.

## Run the game
Open the folder in the Godot editor and press **F5**. For now this starts a solo
game in the Greenfields test zone.

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
