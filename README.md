# DeepClaude LaunchAgent for macOS

Use Claude Code's interface with cheaper, capable models and flip back to real Claude anytime. DeepClaude proxies Claude Code's API calls and routes them to providers like DeepSeek, OpenRouter, or any other Anthropic API endpoint.

Inside any Claude Code session, switch backends with a slash command — `/deepseek` (cheap coding), `/openrouter` (other open models), or `/anthropic` (back to real Claude).

> **This repo is the macOS launcher, not the [DeepClaude](https://github.com/aattaran/deepclaude) proxy itself.** It makes running DeepClaude on a Mac painless: a wrapper script and LaunchAgent run the proxy (a separate clone) with your secrets in 1Password. This simplifies everything — no manual steps after initial setup.

Works with Claude Code, VS Code, Cursor, OpenCode, and any tool that lets you set an API base URL.

## Prerequisites

- **[Homebrew](https://brew.sh)** and **[1Password CLI](https://developer.1password.com/docs/cli/)**: `brew install 1password-cli`
- A **[1Password Service Account](https://developer.1password.com/docs/cli/service-accounts/)** with read access to your key vault -- though you can rewire it to work without 1Password
- **[Node.js](https://nodejs.org)** on your PATH (the installer defaults to whatever `node` resolves to)

All API keys are **optional**. With no keys (or no token) the proxy still starts in Anthropic passthrough mode; each backend lights up only when its key is present.

## Quickstart

Clone both repos — this launcher and the proxy it runs — then run the installer from the launcher directory:

```bash
# 1. The launcher (this repo)
git clone https://github.com/ryanilano/deepclaude-launchagent.git
cd deepclaude-launchagent

# 2. The proxy it runs (a separate clone)
git clone https://github.com/aattaran/deepclaude.git ~/.config/deepclaude/proxy

# 3. Install
bash install.sh
```

The installer prompts for the wrapper path, proxy source dir, log dir, and node binary — all with sensible defaults. It also offers to point Claude Code at the proxy for you (more on that below).

That's enough to get the proxy running in Anthropic passthrough mode. To unlock the cheaper backends, add your API keys — see [1Password setup](#1password-setup).

## Point Claude Code at the proxy

The installer offers to do this for you — it merges `ANTHROPIC_BASE_URL` into the `env` block of `~/.claude/settings.json` (backing the file up first, preserving your other settings). Claude reads it no matter how it's launched (terminal, **and** the VS Code / Cursor extension).

To set it by hand instead:

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

## Switch the backend

The `/deepseek`, `/openrouter`, and `/anthropic` slash commands are the quickest way — the switch is global to the proxy, so it applies to every connected session. You can equally switch from a terminal:

```bash
curl -s  http://127.0.0.1:3200/_proxy/status
curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=deepseek'
```

`/deepseek` and `/openrouter` only work if the matching key is present; `/anthropic` always works.

## 1Password setup

`resolve-keys.sh` pipes `secrets.env` through `op inject` before reading it, so the service-account token can live in 1Password itself rather than as plaintext on disk.

Recommended setup — store the token as a vault item, then reference it:

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

`op inject` resolves the `op://` reference via 1Password desktop integration when you run the resolver in the foreground (the launchd wrapper still never runs `op`).

Prefer the old way? A raw `export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"` still works — a reference-free `secrets.env` passes through `op inject` untouched with no prompt.

`resolve-keys.sh` reads keys from the **"Agentic Vault"** vault. Name yours whatever you like — just update the `VAULT` variable in the script. Expected items (each with a `credential` field):

| Item                 | Required? | Get a key                                                            |
| -------------------- | --------- | -------------------------------------------------------------------- |
| `DEEPSEEK_API_KEY`   | Yes       | [platform.deepseek.com](https://platform.deepseek.com)               |
| `OPENROUTER_API_KEY` | No        | [openrouter.ai/keys](https://openrouter.ai/keys)                     |
| `FIREWORKS_API_KEY`  | No        | [fireworks.ai/api-keys](https://fireworks.ai/api-keys)               |
| `ANTHROPIC_API_KEY`  | No        | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

## How it works

The proxy listens on `http://127.0.0.1:3200` and starts on login. There's one global backend, switched live.

1. `resolve-keys.sh` reads your API keys from the **"Agentic Vault"** 1Password vault via `op` and caches them to `~/.config/deepclaude/resolved.env` (chmod 600). It runs in the **foreground** — at install, and whenever you re-run it after rotating keys.
2. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
3. The wrapper sources `resolved.env` and `exec`s the proxy via node. **It never runs `op`.**

If the proxy crashes, `KeepAlive: true` tells launchd to restart it.

**Why keys are resolved ahead of time:** running `op` under launchd triggers macOS disk-access / 1Password dialogs that can't be authorized in a background context — they pile up and stall startup. So `op` runs only in the foreground resolver; the launchd wrapper just reads the cached file.

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
