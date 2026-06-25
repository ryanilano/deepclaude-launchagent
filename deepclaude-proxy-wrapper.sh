#!/usr/bin/env bash
set -euo pipefail

# ── Paths ───────────────────────────────────────────────────────────────
CONFIG_DIR="$HOME/.config/deepclaude"
RESOLVED_ENV="$CONFIG_DIR/resolved.env"
NODE_BIN="$HOME/.nvm/versions/node/<version>/bin/node"  # set by install.sh
PROXY_ENTRY="$HOME/.config/deepclaude/proxy/start-proxy.js"  # set by install.sh

# ── PATH ────────────────────────────────────────────────────────────────
# LaunchAgents inherit a minimal PATH; ensure nvm (node) is reachable.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── Load pre-resolved backend keys ──────────────────────────────────────
# Keys are resolved from 1Password in the FOREGROUND by resolve-keys.sh and
# cached to resolved.env. This wrapper never runs op: under launchd op triggers
# macOS disk-access / 1Password dialogs that can't be authorized in the
# background. Reading a plain cache file avoids that entirely.
#
# All keys are optional. Whichever resolved enable their backend; with an empty
# or missing cache the proxy still starts in Anthropic passthrough only.
if [ -f "$RESOLVED_ENV" ]; then
  # shellcheck disable=SC1090
  source "$RESOLVED_ENV"
else
  echo "No $RESOLVED_ENV — run resolve-keys.sh. Starting in Anthropic passthrough only." >&2
fi

exec "$NODE_BIN" "$PROXY_ENTRY"
