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

## Game Design (TBD)

> This section is intentionally blank. Once the team agrees on the MVP concept, fill in:
> - Core loop (what does the player do every 30 seconds?)
> - Win/lose condition
> - Scene list (main menu, gameplay, game over)
> - Must-have mechanics for jam submission
> - Cut list (things we explicitly are NOT building)

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
