#!/usr/bin/env bash
# Run the GUT unit test suite headless.
# Usage: ./run_tests.sh [extra gut args, e.g. -gselect=test_cooldowns.gd]
# Set GODOT to your Godot 4.7 binary if it isn't on PATH as `godot`.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"

# Import once so class_name globals and resources are registered.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json "$@"
