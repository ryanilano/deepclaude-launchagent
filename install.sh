#!/usr/bin/env bash
set -euo pipefail

# DeepClaude proxy installer — run from the repo directory.
# Prompts for paths with sensible defaults, then installs the wrapper and LaunchAgent.

# ── Colors ──────────────────────────────────────────────────────────────
# Disable colors if stdout is not a terminal (e.g. piped to a file).
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[32m'; CYAN=$'\033[36m'; YELLOW=$'\033[33m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; CYAN=""; YELLOW=""
fi

# ── Defaults ────────────────────────────────────────────────────────────
WRAPPER_SRC="$PWD/deepclaude-proxy-wrapper.sh"
PLIST_SRC="$PWD/com.deepclaude.proxy.plist"

DEFAULT_WRAPPER_DEST="$HOME/.config/deepclaude/deepclaude-proxy-wrapper.sh"
DEFAULT_PROXY_DIR="$HOME/.config/deepclaude/proxy"
DEFAULT_LOG_DIR="$HOME/Library/Logs"
# Default to whatever node is currently on PATH (nvm's active version), so this
# doesn't go stale every Node upgrade. Falls back to a placeholder if none found.
DEFAULT_NODE_BIN="$(command -v node || echo "$HOME/.nvm/versions/node/<version>/bin/node")"

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
if [[ "$CONFIRM" == [nN]* ]]; then
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
sed -e "s|<string>~/.config/deepclaude/deepclaude-proxy-wrapper.sh</string>|<string>$WRAPPER_DEST_EXPANDED</string>|" \
    -e "s|<string>~/.config/deepclaude/proxy</string>|<string>$PROXY_DIR_EXPANDED</string>|" \
    -e "s|<string>~/Library/Logs/deepclaude-proxy.log</string>|<string>$LOG_DIR_EXPANDED/deepclaude-proxy.log</string>|" \
    -e "s|<string>~/Library/Logs/deepclaude-proxy.err</string>|<string>$LOG_DIR_EXPANDED/deepclaude-proxy.err</string>|" \
    "$PLIST_SRC" > "$PLIST_DEST"

# ── Install Claude Code slash commands ─────────────────────────────────
# Copy /deepseek, /openrouter, /anthropic into the user's global commands dir
# so they're available in every project. Skipped if the source dir is absent.
COMMANDS_SRC="$PWD/commands"
COMMANDS_DEST="$HOME/.claude/commands"
if [ -d "$COMMANDS_SRC" ]; then
  mkdir -p "$COMMANDS_DEST"
  cp -f "$COMMANDS_SRC"/*.md "$COMMANDS_DEST"/
  echo "Installed slash commands to $COMMANDS_DEST: $(ls "$COMMANDS_SRC" | sed 's/\.md//' | sed 's/^/\//' | tr '\n' ' ')"
fi

# ── Load the agent ─────────────────────────────────────────────────────
# Unload any existing agent (ignore errors if not loaded).
launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true

# Clear old logs.
rm -f "$LOG_DIR_EXPANDED/deepclaude-proxy.log" "$LOG_DIR_EXPANDED/deepclaude-proxy.err"

# Load and start.
launchctl bootstrap gui/$(id -u) "$PLIST_DEST"
launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy

echo ""
echo "${GREEN}${BOLD}✓ Done.${RESET} ${BOLD}DeepClaude proxy installed and running.${RESET}"
echo "${DIM}Logs: $LOG_DIR/deepclaude-proxy.{log,err}${RESET}"
echo ""
echo "${BOLD}${CYAN}=== Common usage ===${RESET}"
echo ""
echo "${YELLOW}Check proxy status:${RESET}"
echo "  ${CYAN}curl -s http://127.0.0.1:3200/_proxy/status${RESET}"
echo ""
echo "${YELLOW}Switch backend:${RESET}"
echo "  ${CYAN}curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=deepseek'${RESET}"
echo "  ${CYAN}curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=openrouter'${RESET}"
echo "  ${CYAN}curl -sX POST http://127.0.0.1:3200/_proxy/mode -d 'backend=anthropic'${RESET}"
echo ""
echo "${YELLOW}View logs:${RESET}"
echo "  ${CYAN}tail -f $LOG_DIR/deepclaude-proxy.log${RESET}"
echo "  ${CYAN}tail -f $LOG_DIR/deepclaude-proxy.err${RESET}"
echo ""
echo "${YELLOW}Restart the agent:${RESET}"
echo "  ${CYAN}launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy${RESET}"
echo ""
echo "${YELLOW}Stop the agent:${RESET}"
echo "  ${CYAN}launchctl bootout gui/$(id -u)/com.deepclaude.proxy${RESET}"
echo ""
echo "${YELLOW}Reload after editing wrapper:${RESET}"
echo "  ${CYAN}launchctl bootout gui/$(id -u)/com.deepclaude.proxy 2>/dev/null || true${RESET}"
echo "  ${CYAN}launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.deepclaude.proxy.plist${RESET}"
echo "  ${CYAN}launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy${RESET}"
