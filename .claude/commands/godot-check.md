# /godot-check — Run the project and check for errors

## Steps

1. **Run project** — `mcp__godot__run_project` to launch the game
2. **Tail debug output** — `mcp__godot__get_debug_output` — capture the first 50 lines of output
3. **Scan for errors** — look for lines containing `ERROR`, `SCRIPT ERROR`, or `WARNING`
4. **Stop project** — `mcp__godot__stop_project`
5. **Report** — summarize any errors found with the file path and line number; if clean, confirm "No errors detected"
