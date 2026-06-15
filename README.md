# DeepClaude LaunchAgent

Wrapper script and macOS LaunchAgent for running the [DeepClaude](https://github.com/aattaran/deepclaude) proxy with 1Password-managed secrets. Set it and forget it!

DeepClaude is a local proxy that intercepts Claude Code's API calls and routes them to inexpensive but capable providers such as DeepSeek and OpenRouter. Use capable open weight models directly inside Claude Code, VS Code, Cursor, and other coding tools. Switch models and providers live in session via slash commands or curl.

## How it works

The proxy starts on boot. Authentication comes from 1Password, even faster via biometrics (Touch ID, Face ID, Apple Watch). If it crashes, launchd restarts it.

Claude Code, VS Code, Cursor, OpenCode all just work — no setup per session. No exported env vars, no remembering to start anything — the endpoint is just there.

For full details on DeepClaude itself — supported backends, cost breakdowns, what works and what doesn't — check out the [original DeepClaude repo](https://github.com/aattaran/deepclaude).

## Integrations

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code):** [CLI](https://docs.anthropic.com/en/docs/claude-code) and [VS Code extension](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code); use `/deepseek`, `/openrouter`, `/anthropic` slash commands to switch backends live; add VS Code keyboard shortcuts for one-key switching
- **[Cline](https://cline.bot):** autonomous coding agent for VS Code/JetBrains; point it at the proxy for DeepSeek-powered agentic editing at a fraction of the cost
- **[Cursor](https://cursor.sh):** configure a terminal profile pointing to `deepclaude` for AI coding with cheaper models
- **[OpenCode](https://opencode.ai):** free, open-source Claude Code alternative from SST; point it at the proxy for cheaper models with the same agent loop

## Why DeepSeek?

- **19x cheaper:** Running [Artificial Analysis](https://artificialanalysis.ai)'s full Intelligence Index benchmark costs ~`$268` on DeepSeek V4 Pro vs ~`$5,117` on Claude Opus 4.7 ([source](https://apidog.com/blog/deepseek-v4-pro-permanent-price-cut/)); output tokens at `$0.87`/M vs Anthropic's `$15`/M
- **Comparable quality:** DeepSeek V4 Pro scores [96.4% on LiveCodeBench](https://livecodebench.github.io/leaderboard.html) and [80.6% on SWE-bench Verified](https://benchlm.ai/blog/posts/deepseek-v4-vs-claude-opus-4-7-vs-gpt-5-5); handles ~80% of routine coding tasks at parity with [Claude Opus 4.7](https://benchlm.ai/models/claude-opus-4-7-adaptive)
- **Auto context caching:** repeat turns cost `$0.004`/M (120x cheaper on agent loops)
- **Near-identical UX:** file editing, bash, git, subagents all work unchanged; some features are degraded (no image input, MCP tools, or prompt caching forwarding)
- **Live switching:** drop to Anthropic for hard problems via `/anthropic`, switch back via `/deepseek`

## Why this setup?

Running DeepClaude on its own works, but you have to start it manually every session, manage API keys in your shell, and restart it if it crashes. This repo adds:

- **Starts on login:** macOS LaunchAgent boots the proxy automatically; no terminal, no `dc` command, no remembering
- **Crash recovery:** `KeepAlive: true` means launchd restarts the proxy if it exits; your tools never see a dead endpoint
- **[Secrets in 1Password](https://developer.1password.com/docs/cli/):** API keys live in the "Agentic" vault, not in `.env` files, shell history, or exported variables; rotate keys in 1Password and the proxy picks them up on next restart
- **Always-on endpoint:** `http://127.0.0.1:3200` is available to Claude Code, VS Code, Cursor, OpenCode, and any other tool without launching anything first

## How it works

1. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
2. The wrapper script reads API keys from the **"Agentic" 1Password vault** (your LLM/AI key vault) using `op read`. You can rename this to whatever vault you use.
3. Keys are exported as environment variables, then the proxy starts via `exec node`.

If the proxy crashes, `KeepAlive: true` tells launchd to restart it automatically.

## Prerequisites

- **[Homebrew](https://brew.sh)**: required for 1Password CLI install
- **[1Password CLI](https://developer.1password.com/docs/cli/)** (`op`) installed via Homebrew: `brew install 1password-cli`
- **[1Password Service Account](https://developer.1password.com/docs/cli/service-accounts/)** with access to the "Agentic" vault
- `OP_SERVICE_ACCOUNT_TOKEN` set in `~/.config/deepclaude/secrets.env` (or exported in your shell)
- **[Node.js](https://nodejs.org)** installed via **[nvm](https://github.com/nvm-sh/nvm)** (path in wrapper script must match your version)

## Files

| File                          | Purpose                                          |
| ----------------------------- | ------------------------------------------------ |
| `deepclaude-proxy-wrapper.sh` | Loads secrets from 1Password, starts the proxy   |
| `com.deepclaude.proxy.plist`  | macOS LaunchAgent definition                     |
| `install.sh`                  | Interactive installer script                     |
| `commands/`                   | Claude Code slash commands for switching backend |

## 1Password Setup

The wrapper reads keys from the **"Agentic" vault**, this is my dedicated vault for LLM API keys stored in 1Password. You can name yours whatever you like; just update the vault name in `deepclaude-proxy-wrapper.sh`. [Why use a separate vault?](https://support.1password.com/create-share-vaults/)

Create a service account at [1Password.com -> Settings -> Service Accounts](https://my.1password.com) and grant it read access to your vault. Then save the token:

```bash
mkdir -p ~/.config/deepclaude
echo 'export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"' > ~/.config/deepclaude/secrets.env
chmod 700 ~/.config/deepclaude
chmod 600 ~/.config/deepclaude/secrets.env
```

`chmod 600` ensures only your user can read or write the secrets file — other users and group members are locked out. `chmod 700` does the same for the directory itself. Without this, the service account token would be world-readable on a multi-user machine.

**Expected items in the Agentic vault:** _(rename to match your vault)_

| Item name            | Field        | Required? | Get a key                                                            |
| -------------------- | ------------ | --------- | -------------------------------------------------------------------- |
| `DEEPSEEK_API_KEY`   | `credential` | Yes       | [platform.deepseek.com](https://platform.deepseek.com)               |
| `OPENROUTER_API_KEY` | `credential` | No        | [openrouter.ai/keys](https://openrouter.ai/keys)                     |
| `FIREWORKS_API_KEY`  | `credential` | No        | [fireworks.ai/api-keys](https://fireworks.ai/api-keys)               |
| `ANTHROPIC_API_KEY`  | `credential` | No        | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

## Install

First clone the [DeepClaude proxy](https://github.com/aattaran/deepclaude) — this repo is only the launcher, it does not contain the proxy itself:

```bash
git clone https://github.com/aattaran/deepclaude.git ~/.config/deepclaude/proxy
```

The proxy is pure Node (ESM, no dependencies) — there is **no `npm install`** step. Its entry point lives in a nested `proxy/` subdirectory: `~/.config/deepclaude/proxy/proxy/start-proxy.js`. That nested path (`~/.config/deepclaude/proxy/proxy`) is what you give the installer as the **proxy source directory**.

Then run the installer from this repo directory:

```bash
bash install.sh
```

The script prompts for paths with sensible defaults:

- **Wrapper install path:** where to put the wrapper script (default: `~/.config/deepclaude/deepclaude-proxy-wrapper.sh`)
- **Proxy source directory:** the folder containing `start-proxy.js` — the nested `proxy/` inside the clone, e.g. `~/.config/deepclaude/proxy/proxy`
- **Log directory:** where to write logs (default: `~/Library/Logs/`)
- **Node binary:** path to your node executable (default: whatever `node` is currently on your PATH)

## Customize before installing

Edit these in `deepclaude-proxy-wrapper.sh`:

- `NODE_BIN:` your nvm node path (update when you change Node versions)
- `PROXY_ENTRY:` path to `start-proxy.js` in your proxy checkout

Edit `WorkingDirectory` in `com.deepclaude.proxy.plist` if your proxy source is not at `~/.config/deepclaude/proxy`.

## Test

```bash
curl -s http://127.0.0.1:3200/_proxy/status
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d "backend=deepseek"
curl -s http://127.0.0.1:3200/_proxy/status
```

## Switching backends

`install.sh` installs three Claude Code slash commands into `~/.claude/commands/` (available in every project):

| Command       | Effect                                                            |
| ------------- | ----------------------------------------------------------------- |
| `/deepseek`   | Route through DeepSeek (cheap)                                    |
| `/openrouter` | Route through OpenRouter                                          |
| `/anthropic`  | Passthrough to the real Claude — no vault key required            |

Each is a thin wrapper around the `curl .../_proxy/mode` call, so they switch the **single shared proxy** for every connected session — not per-window. `/deepseek` and `/openrouter` only function if the matching key is present in your vault; `/anthropic` always works.

A `dc` shell alias is the convenient way to launch Claude Code through the proxy while leaving plain `claude` on Anthropic:

```bash
alias dc='ANTHROPIC_BASE_URL=http://127.0.0.1:3200 claude'
```

## Logs

```bash
tail -f ~/Library/Logs/deepclaude-proxy.log   # stdout
tail -f ~/Library/Logs/deepclaude-proxy.err   # stderr
```

## Notes

- The proxy listens on `http://127.0.0.1:3200`.
- Claude Code and other coding tools should point to this endpoint.
- The wrapper uses `op read` with the **Agentic** vault: your 1Password vault for LLM API keys.
- `KeepAlive: true` means launchd will restart the proxy if it exits.

## Troubleshooting

**`op` / 1Password dialogs that you can't authorize:** If the 1Password desktop app is installed with CLI integration enabled, `op` will try to route through the desktop app (biometric/disk-access prompts). Under launchd there's no interactive session, so those prompts pile up and can't be dismissed. The wrapper avoids this by invoking `op` in a clean environment (`env -i`) that exposes **only** `OP_SERVICE_ACCOUNT_TOKEN`, forcing fully headless service-account auth — no desktop integration, no dialogs.

**Proxy not responding on `:3200`:** Check `last exit code` with `launchctl print gui/$(id -u)/com.deepclaude.proxy`. A common cause is a `WorkingDirectory` that doesn't exist (launchd fails with `EX_CONFIG (78)` before the wrapper runs and writes no logs) — confirm the proxy source directory exists and contains `start-proxy.js`.

## Coming Next

**Full 1Password CLI integration:** The raw `OP_SERVICE_ACCOUNT_TOKEN` in `secrets.env` will be replaced with a `op://` reference, resolved at launch time via `op inject` or `op run`. The token itself will live in 1Password — nothing on disk but a template. Bootstrap still requires a one-time manual unlock (Touch ID or desktop unlock) to seed the reference.
