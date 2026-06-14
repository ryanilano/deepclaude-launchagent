#!/usr/bin/env bash
set -euo pipefail

# DeepClaude proxy installer — run from the repo directory.
# Prompts for paths with sensible defaults, then installs the wrapper and LaunchAgent.

# ── Defaults ────────────────────────────────────────────────────────────
WRAPPER_SRC="$PWD/deepclaude-proxy-wrapper.sh"
PLIST_SRC="$PWD/com.deepclaude.proxy.plist"

DEFAULT_WRAPPER_DEST="$HOME/bin/deepclaude-proxy-wrapper.sh"
DEFAULT_PROXY_DIR="$HOME/code/deepclaude/proxy"
DEFAULT_LOG_DIR="$HOME/Library/Logs"
DEFAULT_NODE_BIN="$HOME/.nvm/versions/node/v24.15.0/bin/node"

# ── Interactive prompts ─────────────────────────────────────────────────
echo "=== DeepClaude proxy installer ==="
echo ""

read -rp "Wrapper install path [$DEFAULT_WRAPPER_DEST]: " WRAPPER_DEST
WRAPPER_DEST="${WRAPPER_DEST:-$DEFAULT_WRAPPER_DEST}"

read -rp "Proxy source directory [$DEFAULT_PROXY_DIR]: " PROXY_DIR
PROXY_DIR="${PROXY_DIR:-$DEFAULT_PROXY_DIR}"

read -rp "Log directory [$DEFAULT_LOG_DIR]: " LOG_DIR
LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"

read -rp "Node binary path [$DEFAULT_NODE_BIN]: " NODE_BIN
NODE_BIN="${NODE_BIN:-$DEFAULT_NODE_BIN}"

echo ""
echo "Installing with:"
echo "  Wrapper:    $WRAPPER_DEST"
echo "  Proxy dir:  $PROXY_DIR"
echo "  Logs:       $LOG_DIR"
echo "  Node:       $NODE_BIN"
echo ""
read -rp "Continue? [Y/n] " CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
  echo "Aborted."
  exit 0
fi

# ── Resolve paths (expand ~ for sed, keep $HOME for shell) ──────────────
WRAPPER_DEST_EXPANDED="${WRAPPER_DEST/#\~/$HOME}"
PROXY_DIR_EXPANDED="${PROXY_DIR/#\~/$HOME}"
LOG_DIR_EXPANDED="${LOG_DIR/#\~/$HOME}"
NODE_BIN_EXPANDED="${NODE_BIN/#\~/$HOME}"
PROXY_ENTRY="$PROXY_DIR_EXPANDED/start-proxy.js"

# ── Create target directories ──────────────────────────────────────────
mkdir -p "$(dirname "$WRAPPER_DEST_EXPANDED")" "$LOG_DIR_EXPANDED"

# ── Check secrets.env permissions ──────────────────────────────────────
SECRETS_ENV="$HOME/.config/deepclaude/secrets.env"
if [ -f "$SECRETS_ENV" ]; then
  chmod 700 "$HOME/.config/deepclaude"
  chmod 600 "$SECRETS_ENV"
  echo "Locked down permissions on $SECRETS_ENV"
else
  echo "Warning: $SECRETS_ENV not found. Create it before running the proxy:"
  echo "  mkdir -p ~/.config/deepclaude"
  echo "  echo 'export OP_SERVICE_ACCOUNT_TOKEN=\"your-token\"' > $SECRETS_ENV"
  echo "  chmod 700 ~/.config/deepclaude && chmod 600 $SECRETS_ENV"
fi

# ── Install wrapper ────────────────────────────────────────────────────
# Template the wrapper: replace NODE_BIN and PROXY_ENTRY with user values.
sed -e "s|NODE_BIN=.*|NODE_BIN=\"$NODE_BIN_EXPANDED\"  # set by install.sh|" \
    -e "s|PROXY_ENTRY=.*|PROXY_ENTRY=\"$PROXY_ENTRY\"|" \
    "$WRAPPER_SRC" > "$WRAPPER_DEST_EXPANDED"
chmod +x "$WRAPPER_DEST_EXPANDED"

# ── Install LaunchAgent plist ──────────────────────────────────────────
PLIST_DEST="$HOME/Library/LaunchAgents/com.deepclaude.proxy.plist"

# Template the plist: replace wrapper path, working directory, and log paths.
sed -e "s|<string>~/bin/deepclaude-proxy-wrapper.sh</string>|<string>$WRAPPER_DEST_EXPANDED</string>|" \
    -e "s|<string>~/code/deepclaude/proxy</string>|<string>$PROXY_DIR_EXPANDED</string>|" \
    -e "s|<string>~/Library/Logs/deepclaude-proxy.log</string>|<string>$LOG_DIR_EXPANDED/deepclaude-proxy.log</string>|" \
    -e "s|<string>~/Library/Logs/deepclaude-proxy.err</string>|<string>$LOG_DIR_EXPANDED/deepclaude-proxy.err</string>|" \
    "$PLIST_SRC" > "$PLIST_DEST"

# ── Load the agent ─────────────────────────────────────────────────────
# Unload any existing agent (ignore errors if not loaded).
launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true

# Clear old logs.
rm -f "$LOG_DIR_EXPANDED/deepclaude-proxy.log" "$LOG_DIR_EXPANDED/deepclaude-proxy.err"

# Load and start.
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"
launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy

echo ""
echo "Done. DeepClaude proxy installed and running."
echo "Logs: $LOG_DIR/deepclaude-proxy.{log,err}"
echo ""
echo "=== Common usage ==="
echo ""
echo "Check proxy status:"
echo "  curl -s http://127.0.0.1:3200/_proxy/status"
echo ""
echo "Switch backend:"
echo "  curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=deepseek'"
echo "  curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=openrouter'"
echo "  curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=anthropic'"
echo ""
echo "View logs:"
echo "  tail -f $LOG_DIR/deepclaude-proxy.log"
echo "  tail -f $LOG_DIR/deepclaude-proxy.err"
echo ""
echo "Restart the agent:"
echo "  launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy"
echo ""
echo "Stop the agent:"
echo "  launchctl bootout gui/$(id -u)/com.deepclaude.proxy"
echo ""
echo "Reload after editing wrapper:"
echo "  launchctl bootout gui/$(id -u)/com.deepclaude.proxy 2>/dev/null || true"
echo "  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.deepclaude.proxy.plist"
echo "  launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy"
