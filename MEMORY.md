# DeepClaude LaunchAgent

Wrapper script and macOS LaunchAgent for running the DeepClaude proxy with 1Password-managed secrets. Set it and forget it!

## How it works

1. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
2. The wrapper script reads API keys from the **"Agentic Vault" 1Password vault** (your LLM/AI key vault) using `op read`.
3. Keys are exported as environment variables, then the proxy starts via `exec node`.

If the proxy crashes, `KeepAlive: true` tells launchd to restart it automatically.

## Files

| File | Purpose |
|------|---------|
| `deepclaude-proxy-wrapper.sh` | Loads secrets from 1Password, starts the proxy |
| `com.deepclaude.proxy.plist` | macOS LaunchAgent definition |
| `install.sh` | Interactive installer script |

## 1Password Setup

- **Vault:** "Agentic Vault" — your dedicated vault for LLM API keys
- **Service account:** needs read access to the Agentic Vault
- **Token:** `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/deepclaude/secrets.env`
- `chmod 700 ~/.config/deepclaude && chmod 600 secrets.env`

**Expected items in the Agentic Vault:**

| Item name | Field | Required? | Get a key |
|-----------|-------|-----------|-----------|
| `DEEPSEEK_API_KEY` | `credential` | Yes | [platform.deepseek.com](https://platform.deepseek.com) |
| `OPENROUTER_API_KEY` | `credential` | No — verified | [openrouter.ai/keys](https://openrouter.ai/keys) |
| `FIREWORKS_API_KEY` | `credential` | No | [fireworks.ai/api-keys](https://fireworks.ai/api-keys) |
| `ANTHROPIC_API_KEY` | `credential` | No | [console.anthropic.com](https://console.anthropic.com/settings/keys) |

## Install

```bash
bash install.sh
```

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
- The wrapper uses `op read` with the **Agentic Vault**, your 1Password vault for LLM API keys.
- `KeepAlive: true` means launchd will restart the proxy if it exits.
- `WorkingDirectory` in the plist must point to the proxy source (not this repo).
- `NODE_BIN` in the wrapper must match your nvm node version.
- DeepSeek V4 Pro permanent pricing: $0.435/M input, $0.87/M output (75% cut made permanent May 2026).
