# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

The `@AGENTS.md` import above pulls in additional memory (code style + how the 1Password token is resolved via `op inject`). Consult it before reworking secret handling.

## What this repo is

This repo is **only the launcher**, not the proxy. It packages a macOS LaunchAgent, a wrapper script, a 1Password key resolver, and an installer that run the [DeepClaude proxy](https://github.com/aattaran/deepclaude) (a separate clone). The proxy intercepts Claude Code's API calls on `http://127.0.0.1:3200` and routes them to cheaper backends (DeepSeek, OpenRouter, Fireworks) or passes through to Anthropic.

There is **no package manager, build, or test suite** — it's Bash scripts, a plist, and Markdown slash commands. "Testing" means running the installer and curling the proxy.

## Two-tree layout (critical)

Edits in this repo do **not** take effect until reinstalled. `install.sh` *templates* the source files (substituting user paths via `sed`) into their live destinations:

| Repo source                     | Live destination (after install)                         |
| ------------------------------- | -------------------------------------------------------- |
| `deepclaude-proxy-wrapper.sh`   | `~/.config/deepclaude/deepclaude-proxy-wrapper.sh`       |
| `resolve-keys.sh`               | `~/.config/deepclaude/resolve-keys.sh`                   |
| `com.deepclaude.proxy.plist`    | `~/Library/LaunchAgents/com.deepclaude.proxy.plist`      |
| `commands/*.md`                 | `~/.claude/commands/*.md` (global slash commands)        |

So after changing the wrapper or plist in this repo, re-run `bash install.sh` (or manually copy + reload the agent) for it to matter on the running machine.

## The launchd / `op` constraint (the core design decision)

`op` (1Password CLI) **must never run under launchd.** In a background context it triggers macOS disk-access / 1Password desktop dialogs that can't be authorized, so they pile up and stall startup. The whole architecture is built around this:

- **`resolve-keys.sh` runs in the foreground only** (at install, or manually after rotating keys). It calls `op read` to pull keys from the 1Password vault and caches them to `~/.config/deepclaude/resolved.env` (chmod 600).
- It invokes `op` via `env -i` exposing **only** `OP_SERVICE_ACCOUNT_TOKEN` — this forces headless service-account auth and bypasses 1Password desktop integration entirely.
- **`deepclaude-proxy-wrapper.sh` (run by launchd) never runs `op`** — it just `source`s the cached `resolved.env` and `exec`s node.

When editing these scripts, preserve this split. Do not add `op` calls to the wrapper or plist.

## Key resolution flow

1. `secrets.env` (user-created, gitignored) holds `OP_SERVICE_ACCOUNT_TOKEN` — either as a raw value or as an `op://` reference.
2. `resolve-keys.sh` pipes `secrets.env` through `op inject -f` (foreground only) and sources the result, so an `op://Agentic Vault/.../credential` reference is resolved via 1Password desktop integration. A reference-free file passes through untouched with no auth, so raw-token files keep working. If `op` is missing or desktop is locked, it falls back to sourcing the file as-is.
3. With the token in hand, it reads keys from the `VAULT` (default `"Agentic Vault"`, set near the top of the script) via the headless `env -i` `op read`, and writes `resolved.env`.
4. All keys are **optional**. Whichever resolve enable their backend; with no keys/token the proxy still starts in **Anthropic passthrough** mode. Resolution failures degrade gracefully — never hard-fail the install.

## Backend switching

The proxy has one global backend shared across all connected sessions. Switch it via HTTP:

```bash
curl -s http://127.0.0.1:3200/_proxy/status
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=deepseek'   # or openrouter | anthropic
```

The slash commands in `commands/` (`/deepseek`, `/openrouter`, `/anthropic`) are thin wrappers around that `curl` call, run from inside a Claude Code session. `dc` is a separate shell alias (`ANTHROPIC_BASE_URL=http://127.0.0.1:3200 claude`) the user adds manually — the installer does not create it. Note the alias is **terminal-only**: launching Claude from the VS Code/Cursor extension bypasses it, so to route GUI sessions through the proxy set `ANTHROPIC_BASE_URL` in `~/.claude/settings.json`'s `env` block instead.

## Operating the live agent

```bash
# Reinstall everything (re-templates sources into live destinations)
bash install.sh

# After rotating keys in 1Password: refresh cache, then restart
bash ~/.config/deepclaude/resolve-keys.sh
launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy

# Reload after editing the wrapper/plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.deepclaude.proxy.plist 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.deepclaude.proxy.plist
launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy

# Diagnose (last exit code, config errors)
launchctl print gui/$(id -u)/com.deepclaude.proxy
tail -f ~/Library/Logs/deepclaude-proxy.log   # stdout
tail -f ~/Library/Logs/deepclaude-proxy.err   # stderr
```

`KeepAlive: true` + `RunAtLoad: true` mean launchd starts the proxy on login and restarts it on crash. A `WorkingDirectory` that doesn't exist fails with `EX_CONFIG (78)` *before* the wrapper runs, so no logs are written — check that the proxy source dir exists and contains `start-proxy.js`.

## Gotchas specific to this repo

- The proxy clone has a **nested** `proxy/` subdir: the entry point is `~/.config/deepclaude/proxy/proxy/start-proxy.js`. `install.sh` accepts either the clone root or the nested dir and descends into `proxy/` automatically (aborting if `start-proxy.js` is found in neither). A wrong path here is the classic failure: `MODULE_NOT_FOUND` crash loop, or `EX_CONFIG (78)` with no logs if `WorkingDirectory` is also bad.
- The proxy is pure Node ESM with **no dependencies** — there is no `npm install` for it.
- Wrapper templating works by `sed` replacing whole lines matching `NODE_BIN=.*` and `PROXY_ENTRY=.*`. Keep those assignments on single lines or the installer's substitution breaks.
