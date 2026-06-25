# Memory

## Project Overview

See @README.md. Shell-based repo (no package manager): wrapper, LaunchAgent plist, and `install.sh`. The DeepClaude proxy itself lives in a separate clone (default `~/.config/deepclaude/proxy`).

## Code Style

- Descriptive variable names; follow existing patterns.
- Extract complex conditions into meaningful boolean variables.

## `OP_SERVICE_ACCOUNT_TOKEN` in 1Password (implemented)

`secrets.env` no longer needs the raw token on disk. `resolve-keys.sh` pipes the file through `op inject -f` (foreground only) before sourcing it, so the token can be an `op://Agentic Vault/.../credential` reference resolved via 1Password desktop integration.

- A **reference-free** `secrets.env` passes through `op inject` untouched with no auth, so legacy raw-token files keep working.
- If `op` is missing or desktop is locked, it falls back to sourcing the file as-is — degrade gracefully, never hard-fail.
- Chicken-and-egg caveat: resolving the reference still needs 1Password unlocked the first time (desktop biometric unlock).

⚠️ This `op inject` call — like every `op` call in this repo — stays in the foreground resolver. It must never run under launchd (see the `op`/launchd constraint in CLAUDE.md). The launchd wrapper still only sources the cached `resolved.env`.
