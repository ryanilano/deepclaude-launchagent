---
allowed-tools: Bash(curl:*)
description: Switch the DeepClaude proxy to the OpenRouter backend
---

Switch the local DeepClaude proxy to the **OpenRouter** backend.

!`curl -sS -X POST http://127.0.0.1:3200/_proxy/mode -d 'backend=openrouter'; echo; curl -sS http://127.0.0.1:3200/_proxy/status`

Report the active backend to the user in one short line. If the curl failed to connect, the proxy isn't running — tell them to check `launchctl print gui/$(id -u)/com.deepclaude.proxy` and the logs in `~/Library/Logs/deepclaude-proxy.err`. Note: OpenRouter requests will only work if an `OPENROUTER_API_KEY` is present in the 1Password vault.
