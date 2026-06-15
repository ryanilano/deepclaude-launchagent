#!/usr/bin/env bash
set -euo pipefail

# Resolve 1Password keys into a cached env file — run in the FOREGROUND.
#
# op works cleanly in your interactive session, but under launchd it triggers
# macOS disk-access / 1Password dialogs that can't be authorized in the
# background. So we resolve keys here (foreground) and cache them; the launchd
# wrapper only sources the cache and never runs op.
#
# Re-run this whenever you rotate keys in 1Password, then restart the proxy:
#   bash ~/.config/deepclaude/resolve-keys.sh
#   launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy

CONFIG_DIR="$HOME/.config/deepclaude"
SECRETS_ENV="$CONFIG_DIR/secrets.env"
RESOLVED_ENV="$CONFIG_DIR/resolved.env"
VAULT="Agentic"  # 1Password vault holding your LLM API keys — rename to match yours

# Load OP_SERVICE_ACCOUNT_TOKEN (and any other env) from secrets.env if present.
# shellcheck disable=SC1090
[ -f "$SECRETS_ENV" ] && source "$SECRETS_ENV"

umask 077  # resolved.env contains plaintext keys — owner-only from creation

if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "No OP_SERVICE_ACCOUNT_TOKEN set — writing empty cache (Anthropic passthrough only)." >&2
  : > "$RESOLVED_ENV"
  chmod 600 "$RESOLVED_ENV"
  exit 0
fi

# Run op headlessly with ONLY the service-account token (no desktop integration).
op_read() {
  env -i \
    OP_SERVICE_ACCOUNT_TOKEN="$OP_SERVICE_ACCOUNT_TOKEN" \
    PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" \
    op read "$1"
}

: > "$RESOLVED_ENV"  # truncate before writing

# Resolve a key and append it to the cache if present; skip quietly otherwise.
resolve_key() {
  local ref="$1" var="$2" val
  if val="$(op_read "$ref" 2>/dev/null)" && [ -n "$val" ]; then
    printf 'export %s=%q\n' "$var" "$val" >> "$RESOLVED_ENV"
    echo "Resolved $var"
  else
    echo "Skipping $var (not in vault \"$VAULT\")" >&2
  fi
}

# Every key is optional — whichever resolve enable their backend; the rest are skipped.
resolve_key "op://$VAULT/DEEPSEEK_API_KEY/credential"    DEEPSEEK_API_KEY
resolve_key "op://$VAULT/OPENROUTER_API_KEY/credential"  OPENROUTER_API_KEY
resolve_key "op://$VAULT/FIREWORKS_API_KEY/credential"   FIREWORKS_API_KEY
resolve_key "op://$VAULT/ANTHROPIC_API_KEY/credential"   ANTHROPIC_API_KEY

chmod 600 "$RESOLVED_ENV"
echo "Wrote $RESOLVED_ENV"
