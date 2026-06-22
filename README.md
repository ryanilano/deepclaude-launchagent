# DeepClaude LaunchAgent

Wrapper script and macOS LaunchAgent for running the [DeepClaude](https://github.com/aattaran/deepclaude) proxy with 1Password-managed secrets. Set it and forget it.

DeepClaude is a local proxy that intercepts Claude Code's API calls and routes them to cheaper, capable providers (DeepSeek, OpenRouter, Fireworks) or passes through to Anthropic. Works with Claude Code, VS Code, Cursor, OpenCode, and any tool that lets you set an API base URL.

## How it works

The proxy listens on `http://127.0.0.1:3200` and starts on login. There's one global backend, switched live.

1. `resolve-keys.sh` reads your API keys from the **"Agentic Vault"** 1Password vault via `op` and caches them to `~/.config/deepclaude/resolved.env` (chmod 600). It runs in the **foreground** — at install, and whenever you re-run it after rotating keys.
2. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
3. The wrapper sources `resolved.env` and `exec`s the proxy via node. **It never runs `op`.**

If the proxy crashes, `KeepAlive: true` tells launchd to restart it.

**Why keys are resolved ahead of time:** running `op` under launchd triggers macOS disk-access / 1Password dialogs that can't be authorized in a background context — they pile up and stall startup. So `op` runs only in the foreground resolver; the launchd wrapper just reads the cached file.

## Prerequisites

- **[Homebrew](https://brew.sh)** and **[1Password CLI](https://developer.1password.com/docs/cli/)**: `brew install 1password-cli`
- A **[1Password Service Account](https://developer.1password.com/docs/cli/service-accounts/)** with read access to your key vault
- **[Node.js](https://nodejs.org)** on your PATH (the installer defaults to whatever `node` resolves to)

All API keys are **optional**. With no keys (or no token) the proxy still starts in Anthropic passthrough mode; each backend lights up only when its key is present.

## 1Password setup

`resolve-keys.sh` pipes `secrets.env` through `op inject` before reading it, so the service-account token can live in 1Password itself rather than as plaintext on disk. Recommended setup — store the token as a vault item, then reference it:

```bash
# 1. Save the token as a 1Password item (one time, needs desktop 1Password unlocked):
op item create --category "API Credential" --title OP_SERVICE_ACCOUNT_TOKEN \
  --vault "Agentic Vault" "credential=your-token-here"

# 2. Point secrets.env at it by reference (not the raw value):
mkdir -p ~/.config/deepclaude && chmod 700 ~/.config/deepclaude
echo 'export OP_SERVICE_ACCOUNT_TOKEN="op://Agentic Vault/OP_SERVICE_ACCOUNT_TOKEN/credential"' \
  > ~/.config/deepclaude/secrets.env
chmod 600 ~/.config/deepclaude/secrets.env
```

`op inject` resolves the `op://` reference via 1Password desktop integration when you run the resolver in the foreground (the launchd wrapper still never runs `op`). Prefer the old way? A raw `export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"` still works — a reference-free `secrets.env` passes through `op inject` untouched with no prompt.

`resolve-keys.sh` reads keys from the **"Agentic Vault"** vault. Name yours whatever you like — just update the `VAULT` variable in the script. Expected items (each with a `credential` field):

| Item                 | Required? | Get a key                                                            |
| -------------------- | --------- | -------------------------------------------------------------------- |
| `DEEPSEEK_API_KEY`   | Yes       | [platform.deepseek.com](https://platform.deepseek.com)               |
| `OPENROUTER_API_KEY` | No        | [openrouter.ai/keys](https://openrouter.ai/keys)                     |
| `FIREWORKS_API_KEY`  | No        | [fireworks.ai/api-keys](https://fireworks.ai/api-keys)               |
| `ANTHROPIC_API_KEY`  | No        | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

## Install

Clone the proxy (this repo is only the launcher), then run the installer:

```bash
git clone https://github.com/aattaran/deepclaude.git ~/.config/deepclaude/proxy
bash install.sh
```

The proxy is pure Node (ESM, no dependencies) — there's **no `npm install`**. Its entry point lives in a nested subdir (`~/.config/deepclaude/proxy/proxy/start-proxy.js`); the installer descends into `proxy/` automatically and aborts if it can't find `start-proxy.js`.

The installer prompts for the wrapper path, proxy source dir, log dir, and node binary — all with sensible defaults.

## Usage

### 1. Point Claude Code at the proxy

The installer offers to do this for you — it merges `ANTHROPIC_BASE_URL` into the `env` block of `~/.claude/settings.json` (backing the file up first, preserving your other settings). Claude reads it no matter how it's launched (terminal, **and** the VS Code / Cursor extension). To set it by hand instead:

```json
"env": {
  "ANTHROPIC_BASE_URL": "http://127.0.0.1:3200"
}
```

This routes every Claude Code session through the proxy. You still reach real Claude anytime via `/anthropic` (passthrough mode), so there's no downside to leaving it on.

> **Prefer a per-invocation opt-in?** Skip the setting and add a terminal alias instead — then plain `claude` stays on Anthropic and `dc` opts in:
>
> ```bash
> echo "alias dc='ANTHROPIC_BASE_URL=http://127.0.0.1:3200 claude'" >> ~/.zshrc && source ~/.zshrc
> ```
>
> Note this is **terminal-only** — a shell alias can't reach Claude launched from a GUI/editor. Use the settings.json approach above if you work in VS Code or Cursor.

### 2. Switch the backend

Inside a session, use the slash commands: `/deepseek` (cheap coding), `/openrouter` (other open models), `/anthropic` (back to real Claude). The switch is global to the proxy, so it applies to every connected session. You can equally switch from a terminal:

```bash
curl -s  http://127.0.0.1:3200/_proxy/status
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=deepseek'
```

`/deepseek` and `/openrouter` only work if the matching key is present; `/anthropic` always works.

## Files

| File                          | Purpose                                                    |
| ----------------------------- | ---------------------------------------------------------- |
| `resolve-keys.sh`             | Resolves 1Password keys to a cache (run in the foreground) |
| `deepclaude-proxy-wrapper.sh` | Sources the cached keys and starts the proxy               |
| `com.deepclaude.proxy.plist`  | macOS LaunchAgent definition                               |
| `install.sh` / `uninstall.sh` | Interactive installer / uninstaller                        |
| `commands/`                   | Claude Code slash commands for switching backend           |

## Logs

```bash
tail -f ~/Library/Logs/deepclaude-proxy.log   # stdout
tail -f ~/Library/Logs/deepclaude-proxy.err   # stderr
```

## Uninstall

```bash
bash uninstall.sh
```

Boots out the LaunchAgent and removes the files `install.sh` placed (plist, wrapper, `resolve-keys.sh`, `resolved.env`, slash commands). If the installer wired GUI routing, it also drops `ANTHROPIC_BASE_URL` back out of `~/.claude/settings.json` (only when it still points at this proxy; a custom value is left alone). It **leaves** `secrets.env`, the proxy clone, and your logs — remove those by hand. If you set up the `dc` alias instead of GUI routing, drop it from `~/.zshrc` yourself.

## Troubleshooting

- **`op` / 1Password dialogs you can't authorize:** the resolver invokes `op` in a clean environment (`env -i`) exposing only `OP_SERVICE_ACCOUNT_TOKEN`, forcing headless service-account auth with no desktop integration.
- **Proxy not responding on `:3200`:** check `launchctl print gui/$(id -u)/com.deepclaude.proxy`. A common cause is a bad `WorkingDirectory` (launchd fails with `EX_CONFIG (78)` before writing logs) — confirm the proxy source dir exists and contains `start-proxy.js`.
