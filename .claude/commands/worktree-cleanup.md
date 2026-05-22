# /worktree-cleanup — List and prune stale worktrees

## Steps

1. **List worktrees** — `git worktree list` — show all active worktrees and their branches
2. **Identify stale** — flag any worktree whose branch has already been merged into main
3. **Prune** — `git worktree prune` to remove stale admin entries automatically
4. **Manual removal** — for each stale worktree path, run `git worktree remove <path>` (ask user to confirm before removing)
5. **Verify** — run `git worktree list` again to confirm cleanup
