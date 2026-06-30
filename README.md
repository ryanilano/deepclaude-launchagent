<!-- markdownlint-disable MD033 -->

# DeepClaude LaunchAgent for macOS

Use Claude Code's interface with cheaper, capable models and flip back to real Claude anytime. DeepClaude proxies Claude Code's API calls and routes them to providers like DeepSeek, OpenRouter, or any other Anthropic API endpoint.

> **This repo is the macOS launcher, not the [DeepClaude](https://github.com/aattaran/deepclaude) proxy itself.** It makes running DeepClaude on a Mac painless: a wrapper script and LaunchAgent run the proxy (a separate clone) with your secrets in 1Password. No manual steps after initial setup.

Works with Claude Code, VS Code, Cursor, OpenCode, and any tool that lets you set an API base URL. Inside any Claude Code session, switch backends with a slash command: `/deepseek` (cheap coding), `/openrouter` (other open models), or `/anthropic` (back to real Claude).

## Prerequisites

- **[Node.js](https://nodejs.org)** on your PATH
- **1Password** for key storage (optional, you can [run it without 1Password](#1password-setup))
  - **[Homebrew](https://brew.sh)** + **[1Password CLI](https://developer.1password.com/docs/cli/)**: `brew install 1password-cli`
  - A **[1Password Service Account](https://developer.1password.com/docs/cli/service-accounts/)** with read access to your key vault

Every API key is optional. With none, the proxy still runs in Anthropic passthrough mode; each backend turns on when its key is present.

## Quickstart

Clone both repos (this launcher and the proxy it runs), then run the installer from the launcher directory:

```bash
# 1. The launcher (this repo)
git clone https://github.com/ryanilano/deepclaude-launchagent.git
cd deepclaude-launchagent

# 2. The proxy it runs (a separate clone)
git clone https://github.com/aattaran/deepclaude.git ~/.config/deepclaude/proxy

# 3. Install
bash install.sh
```

Defaults are sensible, so press enter through the prompts (it also offers to point Claude Code at the proxy for you). The proxy starts in Anthropic passthrough mode; add keys to unlock the cheaper backends ([1Password setup](#1password-setup)).

## Point Claude Code at the proxy

The installer offers to do this for you: it adds `ANTHROPIC_BASE_URL` to the `env` block of `~/.claude/settings.json` (backed up first). Claude reads it however it's launched, whether from the terminal or the VS Code / Cursor extension. You still reach real Claude anytime via `/anthropic`, so there's no downside to leaving it on.

<details>
<summary><strong>Prefer to set it up by hand?</strong></summary>

Add it to the `env` block of `~/.claude/settings.json` yourself:

```json
"env": {
  "ANTHROPIC_BASE_URL": "http://127.0.0.1:3200"
}
```

Or, for a per-invocation opt-in, skip the setting and add a terminal alias instead. Then plain `claude` stays on Anthropic and `dc` opts in:

```bash
echo "alias dc='ANTHROPIC_BASE_URL=http://127.0.0.1:3200 claude'" >> ~/.zshrc && source ~/.zshrc
```

Note the alias is **terminal-only**: a shell alias can't reach Claude launched from a GUI/editor. Use the settings.json approach if you work in VS Code or Cursor.

</details>

## Switch the backend

The `/deepseek`, `/openrouter`, and `/anthropic` slash commands are the quickest way. The switch is global to the proxy, so it applies to every connected session.

`/deepseek` and `/openrouter` only work if the matching key is present; `/anthropic` always works.

## 1Password setup

`deepclaude-keys.sh` reads your keys from 1Password and caches them, so nothing but a token reference lives on disk. You **run it by hand** — the installer copies it into place but does not run it.

<details>
<summary><strong>Store the token in 1Password (recommended)</strong></summary>

Save the token as a vault item, then point `secrets.env` at it by reference:

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

Prefer the old way? A raw `export OP_SERVICE_ACCOUNT_TOKEN="your-token-here"` still works: a reference-free `secrets.env` passes through `op inject` untouched with no prompt.

</details>

<details>
<summary><strong>Run it without 1Password (less secure)</strong></summary>

Skip 1Password entirely and write the keys straight into the cache the proxy reads:

```bash
mkdir -p ~/.config/deepclaude && chmod 700 ~/.config/deepclaude
cat > ~/.config/deepclaude/resolved.env <<'EOF'
export DEEPSEEK_API_KEY="sk-..."
export OPENROUTER_API_KEY="sk-or-..."
EOF
chmod 600 ~/.config/deepclaude/resolved.env

launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy
```

The wrapper just sources this file, so the keys take effect on restart. The trade-offs: they sit in plaintext on disk, there's no rotation, and **don't run `deepclaude-keys.sh` afterward: it rewrites `resolved.env` from the vault and will wipe these.**

</details>

`deepclaude-keys.sh` reads keys from the **"Agentic Vault"** by default. Name yours whatever you like — the script **prompts you for the vault name** when you run it (press Enter to accept the default), or pre-set `VAULT` in the environment to skip the prompt. Expected items (each with a `credential` field):

| Item                 | Required? | Get a key                                                            |
| -------------------- | --------- | -------------------------------------------------------------------- |
| `DEEPSEEK_API_KEY`   | Yes       | [platform.deepseek.com](https://platform.deepseek.com)               |
| `OPENROUTER_API_KEY` | No        | [openrouter.ai/keys](https://openrouter.ai/keys)                     |
| `FIREWORKS_API_KEY`  | No        | [fireworks.ai/api-keys](https://fireworks.ai/api-keys)               |
| `ANTHROPIC_API_KEY`  | No        | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

## How it works

The proxy listens on `http://127.0.0.1:3200`, starts on login, and restarts on crash (`KeepAlive`). One global backend, switched live.

<details>
<summary><strong>The full startup flow</strong></summary>

1. `deepclaude-keys.sh` reads your API keys from your 1Password vault (default **"Agentic Vault"**) via `op` and caches them to `~/.config/deepclaude/resolved.env` (chmod 600). You **run it by hand** in the **foreground** — once after install and again after rotating keys — and it **prompts for the vault name** (Enter accepts the default).
2. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
3. The wrapper sources `resolved.env` and `exec`s the proxy via node. **It never runs `op`.**

**Why resolve keys ahead of time?** Running `op` under launchd triggers 1Password dialogs that can't be authorized in the background, so they pile up and stall startup. `op` runs only in the foreground resolver; the wrapper just reads the cache.

</details>

## Files

| File                          | Purpose                                                    |
| ----------------------------- | ---------------------------------------------------------- |
| `deepclaude-keys.sh`          | Resolves 1Password keys to a cache (run by hand)           |
| `deepclaude-proxy-wrapper.sh` | Sources the cached keys and starts the proxy               |
| `com.deepclaude.proxy.plist`  | macOS LaunchAgent definition                               |
| `install.sh` / `uninstall.sh` | Interactive installer / uninstaller                        |
| `commands/`                   | Claude Code slash commands for switching backend           |
| `check-remap.sh`              | Warns at switch time if the proxy can't remap your model   |

## Logs

```bash
tail -f ~/Library/Logs/deepclaude-proxy.log   # stdout
tail -f ~/Library/Logs/deepclaude-proxy.err   # stderr
```

## Uninstall

```bash
bash uninstall.sh
```

Boots out the LaunchAgent and removes the files `install.sh` placed (plist, wrapper, `deepclaude-keys.sh`, `resolved.env`, slash commands), and drops `ANTHROPIC_BASE_URL` back out of `~/.claude/settings.json` if it still points here. It leaves `secrets.env`, the proxy clone, and your logs. Remove those by hand.

## Troubleshooting

- **`op` / 1Password dialogs you can't authorize:** the resolver invokes `op` in a clean environment (`env -i`) exposing only `OP_SERVICE_ACCOUNT_TOKEN`, forcing headless service-account auth with no desktop integration.
- **Proxy not responding on `:3200`:** check `launchctl print gui/$(id -u)/com.deepclaude.proxy`. A common cause is a bad `WorkingDirectory` (launchd fails with `EX_CONFIG (78)` before writing logs). Confirm the proxy source dir exists and contains `start-proxy.js`.
- **`⚠️  DeepClaude remap gap` warning after switching backend:** the cloned proxy's `MODEL_REMAP` table (`proxy/model-proxy.js`) has no entry for the Claude model id you're running, so it forwards the raw `claude-*` id to the backend, which then serves its **default** model instead of the one you pinned — silently, with correct-looking 200s. The table is a hardcoded allowlist that goes stale on each Claude release. Fix: add the id to `MODEL_REMAP.<mode>` in the clone, or re-run `check-remap.sh <mode>` to see exactly which ids are missing. Upstream bug: [aattaran/deepclaude#39](https://github.com/aattaran/deepclaude/issues/39). The `/deepseek` and `/openrouter` slash commands run this check automatically after switching.
