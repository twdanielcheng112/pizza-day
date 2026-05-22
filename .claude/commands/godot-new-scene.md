# /godot-new-scene — Scaffold a new scene + script pair

Prompts for a name, then creates a matching .tscn and .gd file following project conventions.

## Steps

1. **Ask for name** — if not provided as an argument, ask: "What is the scene name? (PascalCase, e.g. PlayerCharacter)"
2. **Create scene file** — use `mcp__godot__create_scene` with the given name; place under `scenes/<name>.tscn`
3. **Create script file** — write a GDScript stub at `scripts/<name>.gd` with:
   - `extends Node` (or appropriate base class)
   - `func _ready() -> void: pass`
   - `func _process(delta: float) -> void: pass`
4. **Attach script** — use `mcp__godot__add_node` or note in the scene that the script path is `res://scripts/<name>.gd`
5. **Save scene** — `mcp__godot__save_scene`
6. **Validate** — confirm both files exist with `ls scenes/ scripts/`
