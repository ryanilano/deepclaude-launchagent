---
allowed-tools: Bash(curl:*)
description: Switch the DeepClaude proxy back to Anthropic passthrough
---

Switch the local DeepClaude proxy back to **Anthropic** passthrough (the real Claude).

!`curl -sS -X POST http://127.0.0.1:3200/_proxy/mode -d 'backend=anthropic'; echo; curl -sS http://127.0.0.1:3200/_proxy/status`

Report the active backend to the user in one short line. In this mode the proxy forwards untouched to Anthropic using Claude Code's own credentials — no vault key required. If the curl failed to connect, the proxy isn't running — tell them to check `launchctl print gui/$(id -u)/com.deepclaude.proxy`.
