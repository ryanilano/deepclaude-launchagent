# DeepClaude LaunchAgent

Wrapper script and macOS LaunchAgent for running the DeepClaude proxy with 1Password-managed secrets.

## How it works

1. macOS loads the LaunchAgent on login (`RunAtLoad: true`).
2. The wrapper script reads API keys from the **"Agentic" 1Password vault** (your LLM/AI key vault) using `op read`.
3. Keys are exported as environment variables, then the proxy starts via `exec node`.

If the proxy crashes, `KeepAlive: true` tells launchd to restart it automatically.

## Files

| File | Purpose |
|------|---------|
| `deepclaude-proxy-wrapper.sh` | Loads secrets from 1Password, starts the proxy |
| `com.deepclaude.proxy.plist` | macOS LaunchAgent definition |
| `install.sh` | Interactive installer script |

## 1Password Setup

- **Vault:** "Agentic" — your dedicated vault for LLM API keys
- **Service account:** needs read access to the Agentic vault
- **Token:** `OP_SERVICE_ACCOUNT_TOKEN` in `~/.config/deepclaude/secrets.env`

**Expected items in the Agentic vault:**

| Item name | Field | Required? |
|-----------|-------|-----------|
| `DEEPSEEK_API_KEY` | `credential` | Yes |
| `OPENROUTER_API_KEY` | `credential` | No — verified |
| `FIREWORKS_API_KEY` | `credential` | No |
| `ANTHROPIC_API_KEY` | `credential` | No |

## Install

```bash
bash run-command.txt
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
- The wrapper uses `op read` with the **Agentic** vault — your 1Password vault for LLM API keys.
- `KeepAlive: true` means launchd will restart the proxy if it exits.
- `WorkingDirectory` in the plist must point to the proxy source (not this repo).
- `NODE_BIN` in the wrapper must match your nvm node version.
