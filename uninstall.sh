#!/usr/bin/env bash
set -euo pipefail

# DeepClaude proxy uninstaller — mirrors install.sh.
# Boots out the LaunchAgent and removes the files install.sh placed on disk.
#
# Left in place on purpose (remove by hand if you want them gone):
#   - ~/.config/deepclaude/secrets.env  (holds your service-account token)
#   - the DeepClaude proxy clone        (e.g. ~/.config/deepclaude/proxy)
#   - logs in your log directory        (deepclaude-proxy.{log,err})

# ── Colors ──────────────────────────────────────────────────────────────
# Disable colors if stdout is not a terminal (e.g. piped to a file).
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; YELLOW=""
fi

CONFIG_DIR="$HOME/.config/deepclaude"
PLIST_DEST="$HOME/Library/LaunchAgents/com.deepclaude.proxy.plist"
RESOLVER_DEST="$CONFIG_DIR/resolve-keys.sh"
RESOLVED_ENV="$CONFIG_DIR/resolved.env"
DEFAULT_WRAPPER_DEST="$CONFIG_DIR/deepclaude-proxy-wrapper.sh"

# ── Interactive prompts ─────────────────────────────────────────────────
echo "=== DeepClaude proxy uninstaller ==="
echo ""

read -rp "Wrapper install path [$DEFAULT_WRAPPER_DEST]: " WRAPPER_DEST
WRAPPER_DEST="${WRAPPER_DEST:-$DEFAULT_WRAPPER_DEST}"
WRAPPER_DEST_EXPANDED="${WRAPPER_DEST/#\~/$HOME}"

echo ""
echo "This will:"
echo "  - Boot out and remove the LaunchAgent ($PLIST_DEST)"
echo "  - Remove the wrapper ($WRAPPER_DEST_EXPANDED)"
echo "  - Remove the key resolver and cache (resolve-keys.sh, resolved.env)"
echo "  - Remove the installed slash commands from ~/.claude/commands"
echo ""
echo "It will NOT touch secrets.env, the proxy clone, or your logs."
echo ""
read -rp "Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" == [yY]* ]]; then
  echo "Aborted."
  exit 0
fi

# ── Boot out the LaunchAgent ────────────────────────────────────────────
# Ignore errors if it was never loaded.
launchctl bootout gui/$(id -u) "$PLIST_DEST" 2>/dev/null || true
echo "Booted out the LaunchAgent (if it was loaded)."

# ── Remove installed files ──────────────────────────────────────────────
rm -f "$PLIST_DEST"           && echo "Removed $PLIST_DEST"
rm -f "$WRAPPER_DEST_EXPANDED" && echo "Removed $WRAPPER_DEST_EXPANDED"
rm -f "$RESOLVER_DEST"        && echo "Removed $RESOLVER_DEST"
rm -f "$RESOLVED_ENV"         && echo "Removed $RESOLVED_ENV"

# ── Remove slash commands ───────────────────────────────────────────────
# Only remove the commands this repo installs — derived from commands/*.md
# basenames — so other commands in ~/.claude/commands are left untouched.
COMMANDS_SRC="$PWD/commands"
COMMANDS_DEST="$HOME/.claude/commands"
if [ -d "$COMMANDS_SRC" ]; then
  for cmd in "$COMMANDS_SRC"/*.md; do
    [ -e "$cmd" ] || continue
    target="$COMMANDS_DEST/$(basename "$cmd")"
    rm -f "$target" && echo "Removed $target"
  done
fi

echo ""
echo "${GREEN}${BOLD}✓ Done.${RESET} ${BOLD}DeepClaude proxy uninstalled.${RESET}"
echo ""
echo "${YELLOW}Left in place — remove by hand if you want them gone:${RESET}"
echo "  ${DIM}secrets.env:${RESET}  rm $CONFIG_DIR/secrets.env"
echo "  ${DIM}proxy clone:${RESET}  rm -rf $CONFIG_DIR/proxy"
echo "  ${DIM}logs:${RESET}         rm ~/Library/Logs/deepclaude-proxy.{log,err}"
echo "  ${DIM}config dir:${RESET}   rmdir $CONFIG_DIR  ${DIM}(once empty)${RESET}"
