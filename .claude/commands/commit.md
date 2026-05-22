# /commit — Stage, commit, push, and open a PR

## Steps

1. **Show status** — run `git status` to see what changed; confirm nothing sensitive (`.env`, credentials) is staged
2. **Stage files** — run `git add <specific files>` (never `git add -A` without reviewing first)
3. **Commit** — use the format: `<type>: <imperative summary>` with the Co-Authored-By trailer
4. **Push** — `git push -u origin <branch>` (never force-push)
5. **Open PR** — use `gh pr create` with a title and body summarizing what changed and why
6. **Validate** — run `git log --oneline -5` and `gh pr list --head <branch>` to confirm both the commit and PR landed
