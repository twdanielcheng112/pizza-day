# Project: Pizza Day (Game Jam)

A Godot 4.6 game jam project. The game subject is TBD — teammates will align on the MVP concept and this file will be updated with the game design once decided. Success = a playable build submitted before the jam deadline.

---

## Absolute Rules (Claude must follow these without exception)

- **Never commit directly to main** — always branch → PR → merge
- **Never skip hooks** — do not use `--no-verify` or `-c commit.gpgsign=false`
- **Never force-push** — if you need to rewrite history, stop and ask
- **Never delete files or branches without confirmation** — ask first if uncertain
- **Never expose secrets** — do not commit `.env`, credentials, or tokens
- **Never run `rm -rf` on directories** — always identify files specifically
- **Never hand-edit `.godot/` cache files** — these are engine-generated; let Godot manage them

When in doubt about a destructive or irreversible action, stop and ask.

---

## Tech Stack

- **Engine**: Godot 4.6 (GL Compatibility renderer, Jolt Physics)
- **Language**: GDScript (default); C# only if teammates explicitly agree
- **Scenes**: stored under `scenes/`
- **Scripts**: stored under `scripts/`
- **Assets**: stored under `assets/` (sprites, sounds, fonts)
- **MCP server**: `@coding-solo/godot-mcp` (local scope — activate with `claude mcp add godot --scope local -- npx @coding-solo/godot-mcp`)

### Godot-specific conventions

- One scene per meaningful game object; avoid mega-scenes
- Prefer signals over direct node references for cross-scene communication
- Export variables for anything a designer might tweak in the editor
- Never store game state in an Autoload unless it truly needs to persist across scenes

---

## Git & GitHub Workflow

### Branch naming

```
feat/<short-description>    # new feature or game mechanic
fix/<short-description>     # bug fix
art/<short-description>     # art/asset additions only
audio/<short-description>   # sound/music additions only
chore/<short-description>   # tooling, config, deps
docs/<short-description>    # documentation only
```

### PR workflow (every change, no exceptions)

1. `git checkout -b <branch-name>`
2. Make changes, stage and commit with a clear message
3. `git push -u origin <branch-name>`
4. Open a PR — use `gh pr create` (or MCP if active)
5. Run `git log --oneline -5` to confirm the commit landed
6. Notify the team the PR is ready for review

### Commit message format

```
<type>: <short summary in imperative mood>

[optional body — explain *why*, not *what*]

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### After every git operation

Run `git log --oneline -5` to confirm the result landed. Never assume a command succeeded without checking.

---

## Tool Priority for GitHub Operations

| Priority | Tool | Use when |
|----------|------|----------|
| 1st | **MCP GitHub tools** (`mcp__github__*`) | MCP server is active |
| 2nd | **`gh` CLI** | MCP not available |
| 3rd | **`git` CLI** | Local git operations |

### Godot MCP tools (when active)

```
mcp__godot__create_scene       # create a new .tscn file
mcp__godot__add_node           # add a node to a scene
mcp__godot__save_scene         # save scene changes
mcp__godot__run_project        # launch the game
mcp__godot__stop_project       # stop the running game
mcp__godot__get_debug_output   # read Godot's output log
mcp__godot__get_project_info   # read project.godot metadata
mcp__godot__get_godot_version  # confirm engine version
mcp__godot__load_sprite        # load a sprite into a node
mcp__godot__list_projects      # list available Godot projects
```

---

## Slash Commands

Slash commands live in `.claude/commands/*.md`.

| Command | What it does |
|---------|--------------|
| `/commit` | Stage, commit, push, and open a PR in one step |
| `/sync-main` | Checkout main, pull, verify the latest commit |
| `/worktree-cleanup` | List all worktrees and prune stale ones |
| `/godot-new-scene` | Scaffold a new scene + script pair |
| `/godot-check` | Run the project and tail debug output for errors |

---

## GitHub Actions / CI

### Workflows in `.github/workflows/`

- **`claude.yml`** — enables `@claude` in PRs and Issues
- **`pr-report.yml`** — auto-comments changed files on every PR open/sync

### CI rules for Claude

- Check CI before declaring a task done: `gh run list --branch <branch> --limit 3`
- If CI fails, read logs before suggesting a fix: `gh run view <run-id> --log-failed`
- Never merge a PR with failing required checks

---

## Multi-Agent Patterns

Use parallel agents when tasks are independent (no shared state, no ordering requirement).

```
✅ One agent creates a scene while another writes a script
✅ Research game mechanic docs while generating boilerplate
✅ Review multiple PRs in parallel

❌ Agent B needs Agent A's output
❌ Both agents write to the same .tscn file
```

After any parallel session, run `/worktree-cleanup`.

---

## Validation Checklist (run before closing any task)

1. `git log --oneline -3` — expected commit is present
2. `gh pr list --head <branch>` — PR is open
3. CI passes: `gh run list --branch <branch>`
4. If Godot scene was changed: open in editor and verify no broken node references

---

## Repository Info

- **Owner**: othsueh
- **Repo**: pizza-day
- **Default branch**: `main`

---

## Game Design — 《失控視界 Unbounded Vision》

> **Full Story Map**: see `game-plan.html` (team reference)
> **Style Bible (R0 deliverable)**: see `docs/style-bible.md`

### Core concept

A 2D maze game built around a **reverse-reward** mechanic: the more "successful" the player is at normal game goals (open chests, solve puzzles, expand vision), the higher the **Instability** value rises, and the closer they get to a bad ending. **True victory = learning to stop expanding.**

### Core loop (every 30 seconds)

Explore in fog → see a tempting object (chest / key / vision core) → decide whether to interact → if interact: gain short-term benefit (e.g. vision 3×3 → 5×5) **but** Instability rises → maze starts to mutate (expand / walls move) → keep exploring under degraded conditions.

### Win / Lose conditions

| Ending | Trigger | Lose or Win |
|--------|---------|-------------|
| **Bad** | Instability reaches 100 | Maze expands infinitely, player trapped |
| **Normal** | Instability < 70, reach the obvious "false" exit | Escape, but carry part of the maze with you |
| **True** | Low instability, few interactions, find the hidden "true" exit | Player understood the theme: stop expanding |

### Three core stats (visible in HUD)

- **Vision** — sight radius (3×3 → 5×5 → 7×7 → 9×9)
- **Achievement** — count of chests opened, puzzles solved, enemies killed
- **Instability** — `vision×10 + chests×5 + puzzles×8 + enemies×3 + explored/10` (computed by the C module)

### Loop-exit trigger (decided: option b)

Instability ≥ 70 triggers a "critical state" event from the C module → Godot shows the UI text "邊界已記住你的貪婪" → both exits remain accessible from the start but the false one starts blinking. The player is **not** forced to a separate scene — the loop ends when they walk into either exit.

### Scene list

- `Maze.tscn` — gameplay TileMap, rendered from C-emitted JSON
- `Player.tscn` — CharacterBody2D + Sprite + Camera2D
- `Chest.tscn` / `Key.tscn` / `VisionCore.tscn` — interactable Area2D objects
- `EndingBad.tscn` / `EndingNormal.tscn` / `EndingTrue.tscn` — three ending screens

### Must-have mechanics for jam submission (R1 / Walking Skeleton)

1. Player movement + 3×3 fog of war
2. **C ↔ Godot JSON pipeline** (`maze_core` executable → `maze_state.json` → TileMap render)
3. Chest / key / vision core spawn and pickup → vision expands
4. **C module computes Instability** from current stats
5. HUD shows three stats; Instability color shifts (green → yellow → orange → red)
6. Instability ≥ 31 triggers maze expansion (C regenerates → Godot re-renders)
7. Two exits visible from the start; reaching either triggers ending judgement
8. Three ending text screens (text taken from PDF)

### Cut list (NOT in MVP)

- Main menu / settings / save system
- Sound options, volume controls
- Multiple maze layouts to choose from
- Multiplayer
- Tutorial overlay (rely on wall hints + in-game text instead)
- Enemy combat (enemies exist as patrolling threats in R2, no health system)
- Multiple chest tiers / inventory UI
- Cinematics or extended ending sequences (R2/R3 only)

### Personas (who we're designing for)

- **黑客松評審** — needs to see technical highlight (C module + instability formula visualization) within 5 min demo
- **一般玩家** — needs to feel the reversal "aha moment" naturally, without being told

See `game-plan.html` for the full release breakdown (R0 Style Bible / R1 MVP / R2 enhancement / R3 polish) and milestones M0–M6.

---

## CLAUDE.md Maintenance

Update this file immediately when:

- The game concept is decided → fill in the Game Design section
- A new workflow pattern proves reliable → document it
- A slash command is added or changed → update the commands table
- A teammate joins with a different role → note their area of ownership

```
## [Section]
- **[Date] [what changed]**: [why it matters]
```
