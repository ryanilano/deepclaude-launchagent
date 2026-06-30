---
allowed-tools: Bash(curl:*), Bash(bash:*)
description: Switch the DeepClaude proxy to the DeepSeek backend
---

Switch the local DeepClaude proxy to the **DeepSeek** backend.

!`curl -sS -X POST http://127.0.0.1:3200/_proxy/mode -d 'backend=deepseek'; echo; curl -sS http://127.0.0.1:3200/_proxy/status; echo; bash ~/.config/deepclaude/check-remap.sh deepseek 2>&1 || true`

Report the active backend to the user in one short line. If the curl failed to connect, the proxy isn't running — tell them to check `launchctl print gui/$(id -u)/com.deepclaude.proxy` and the logs in `~/Library/Logs/deepclaude-proxy.err`.

**If the remap guard printed a `⚠️  DeepClaude remap gap` warning, surface it prominently** — it means requests will silently run on the backend's default model instead of the one DeepSeek pins. Tell the user which model id is unmapped and that the fix is to add it to `MODEL_REMAP.deepseek` in the cloned proxy ([upstream bug](https://github.com/aattaran/deepclaude/issues/39)).
