# /sync-main — Checkout main, pull, verify

## Steps

1. **Checkout main** — `git checkout main`
2. **Pull latest** — `git pull origin main`
3. **Verify** — `git log --oneline -5` to confirm the expected commits are present
4. **Report** — tell the user the current HEAD commit hash and message
