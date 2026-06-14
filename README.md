# DeepClaude LaunchAgent

Wrapper script and macOS LaunchAgent for running the [DeepClaude](https://github.com/aattaran/deepclaude) proxy with 1Password-managed secrets.

DeepClaude is a local proxy that intercepts Claude Code's API calls and routes them to cheaper or alternative backends — DeepSeek, OpenRouter, Fireworks AI, or Anthropic. It keeps Claude Code's full UX (tool loop, file editing, bash, git, subagents) while swapping which model thinks behind the scenes. Supports live backend switching mid-session via slash commands or curl.

## Integrations

- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** — [CLI](https://docs.anthropic.com/en/docs/claude-code) and [VS Code extension](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code); use `/deepseek`, `/openrouter`, `/anthropic` slash commands to switch backends live; add VS Code keyboard shortcuts for one-key switching
- **[Cline](https://cline.bot)** — autonomous coding agent for VS Code/JetBrains; point it at the proxy for DeepSeek-powered agentic editing at a fraction of the cost
- **[Cursor](https://cursor.sh)** — configure a terminal profile pointing to `deepclaude` for AI coding with cheaper models
- **[OpenCode](https://opencode.ai)** — free, open-source Claude Code alternative from SST; point it at the proxy for cheaper models with the same agent loop

## Why DeepSeek?

- **19x cheaper** — Running [Artificial Analysis](https://artificialanalysis.ai)'s full Intelligence Index benchmark costs ~`$268` on DeepSeek V4 Pro vs ~`$5,117` on Claude Opus 4.7 ([source](https://apidog.com/blog/deepseek-v4-pro-permanent-price-cut/)); output tokens at `$0.87`/M vs Anthropic's `$15`/M
- **Comparable quality** — DeepSeek V4 Pro scores [93.5% on LiveCodeBench](https://livecodebench.github.io/leaderboard.html) and [80.6% on SWE-bench Verified](https://benchlm.ai/blog/posts/deepseek-v4-vs-claude-opus-4-7-vs-gpt-5-5); handles ~80% of routine coding tasks at parity with [Claude Opus 4.7](https://benchlm.ai/models/claude-opus-4-7-adaptive)
- **Auto context caching** — repeat turns cost `$0.004`/M (120x cheaper on agent loops)
- **Same UX** — file editing, bash, git, subagents all work unchanged; only the model behind the scenes is different
- **Live switching** — drop to Anthropic for hard problems via `/anthropic`, switch back via `/deepseek`

## Why this setup?

Running DeepClaude on its own works, but you have to start it manually every session, manage API keys in your shell, and restart it if it crashes. This repo adds:

- **Starts on login** — macOS LaunchAgent boots the proxy automatically; no terminal, no `dc` command, no remembering
- **Crash recovery** — `KeepAlive: true` means launchd restarts the proxy if it exits; your tools never see a dead endpoint
- **[Secrets in 1Password](https://developer.1password.com/docs/cli/)** — API keys live in the "Agentic" vault, not in `.env` files, shell history, or exported variables; rotate keys in 1Password and the proxy picks them up on next restart
- **Always-on endpoint** — `http://127.0.0.1:3200` is available to Claude Code, VS Code, Cursor, OpenCode, and any other tool without launching anything first

## How it works

1. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
2. The wrapper script reads API keys from the **"Agentic" 1Password vault** (your LLM/AI key vault) using `op read`. You can rename this to whatever vault you use.
3. Keys are exported as environment variables, then the proxy starts via `exec node`.

If the proxy crashes, `KeepAlive: true` tells launchd to restart it automatically.

## Prerequisites

- **[Homebrew](https://brew.sh)** — required for 1Password CLI install
- **[1Password CLI](https://developer.1password.com/docs/cli/)** (`op`) installed via Homebrew: `brew install 1password-cli`
- **[1Password Service Account](https://developer.1password.com/docs/cli/service-accounts/)** with access to the "Agentic" vault
- `OP_SERVICE_ACCOUNT_TOKEN` set in `~/.config/deepclaude/secrets.env` (or exported in your shell)
- **[Node.js](https://nodejs.org)** installed via **[nvm](https://github.com/nvm-sh/nvm)** (path in wrapper script must match your version)

## Files

| File                          | Purpose                                        |
| ----------------------------- | ---------------------------------------------- |
| `deepclaude-proxy-wrapper.sh` | Loads secrets from 1Password, starts the proxy |
| `com.deepclaude.proxy.plist`  | macOS LaunchAgent definition                   |
| `install.sh`                  | Interactive installer script                   |

## 1Password Setup

The wrapper reads keys from the **"Agentic" vault** — this is my dedicated vault for LLM API keys stored in 1Password. You can name yours whatever you like; just update the vault name in `deepclaude-proxy-wrapper.sh`. [Why use a separate vault?](https://support.1password.com/create-share-vaults/)

Create a service account at [1Password.com -> Settings -> Service Accounts](https://my.1password.com) and grant it read access to your vault. Then save the token:

```bash
mkdir -p ~/.config/deepclaude
echo 'export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"' > ~/.config/deepclaude/secrets.env
chmod 700 ~/.config/deepclaude
chmod 600 ~/.config/deepclaude/secrets.env
```

**Expected items in the Agentic vault:** _(rename to match your vault)_

| Item name            | Field        | Required? | Get a key                                                            |
| -------------------- | ------------ | --------- | -------------------------------------------------------------------- |
| `DEEPSEEK_API_KEY`   | `credential` | Yes       | [platform.deepseek.com](https://platform.deepseek.com)               |
| `OPENROUTER_API_KEY` | `credential` | No        | [openrouter.ai/keys](https://openrouter.ai/keys)                     |
| `FIREWORKS_API_KEY`  | `credential` | No        | [fireworks.ai/api-keys](https://fireworks.ai/api-keys)               |
| `ANTHROPIC_API_KEY`  | `credential` | No        | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

## Install

Run from this repo directory:

```bash
bash install.sh
```

The script prompts for paths with sensible defaults:

- **Wrapper install path** — where to put the wrapper script (default: `~/bin/`)
- **Proxy source directory** — where DeepClaude proxy lives (default: `~/code/deepclaude/proxy`)
- **Log directory** — where to write logs (default: `~/Library/Logs/`)
- **Node binary** — path to your node executable (default: nvm current version)

## Customize before installing

Edit these in `deepclaude-proxy-wrapper.sh`:

- `NODE_BIN` — your nvm node path (update when you change Node versions)
- `PROXY_ENTRY` — path to `start-proxy.js` in your proxy checkout

Edit `WorkingDirectory` in `com.deepclaude.proxy.plist` if your proxy source is not at `~/code/deepclaude/proxy`.

## Test

```bash
curl -s http://127.0.0.1:3200/_proxy/status
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d "backend=deepseek"
curl -s http://127.0.0.1:3200/_proxy/status
```

## Logs

```bash
tail -f ~/Library/Logs/deepclaude-proxy.log   # stdout
tail -f ~/Library/Logs/deepclaude-proxy.err   # stderr
```

## Notes

- The proxy listens on `http://127.0.0.1:3200`.
- Claude Code and other coding tools should point to this endpoint.
- The wrapper uses `op read` with the **Agentic** vault — your 1Password vault for LLM API keys.
- `KeepAlive: true` means launchd will restart the proxy if it exits.
