# Memory

## Project Overview
See @README.md for project overview and @package.json for available npm/pnpm commands for this project.

## Code Style Guidelines
- Use descriptive variable names
- Follow existing patterns in the codebase
- Extract complex conditions into meaningful boolean variables

## Architecture Notes
Add important architectural decisions and patterns here.

## Planned Enhancements

### 1Password CLI integration for secrets.env
**Goal:** Eliminate the raw `OP_SERVICE_ACCOUNT_TOKEN` from `~/.config/deepclaude/secrets.env` by storing it inside 1Password itself and resolving it at launch time.

**Approach — `op inject`:**
1. Store the service account token as a 1Password item (e.g. `op://Agentic/OP_SERVICE_ACCOUNT_TOKEN/credential`)
2. Change `secrets.env` to use `op://` references instead of raw values:
   ```
   export OP_SERVICE_ACCOUNT_TOKEN="op://Agentic/OP_SERVICE_ACCOUNT_TOKEN/credential"
   ```
3. In `deepclaude-proxy-wrapper.sh`, call `op inject -i secrets.env -o /tmp/deepclaude-env` before sourcing, so the resolved values never touch disk persistently
4. Requires a bootstrap step: the first time, the user manually authenticates with `op signin` or has 1Password desktop unlocked so `op inject` can resolve the reference

**Alternative — `op run`:**
- Use `op run --env-file=secrets.env -- node start-proxy.js` to inject all secrets at process launch
- Cleaner than `op inject` (no temp file) but couples the wrapper more tightly to `op run`'s behavior
- Both API keys and the service account token would live in 1Password

**Trade-offs:**
- `op inject` is simpler to reason about, generates a temp file you can inspect
- `op run` is more ephemeral (nothing on disk) but harder to debug
- Either way, the chicken-and-egg problem: you still need *some* way to authenticate with 1Password the first time (desktop unlock via biometrics, or a manually-placed token)

## Common Workflows
Document frequently used workflows and commands here.
