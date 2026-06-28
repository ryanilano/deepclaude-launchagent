#!/usr/bin/env bash
set -euo pipefail

# Resolve 1Password keys into a cached env file — RUN THIS BY HAND.
#
# This is the manual key tool: run it in the foreground at install time and
# again whenever you rotate keys in 1Password. op works cleanly in your
# interactive session, but under launchd it triggers macOS disk-access /
# 1Password dialogs that can't be authorized in the background. So we resolve
# keys here (foreground, by hand) and cache them; the launchd wrapper only
# sources the cache and never runs op.
#
# Run this whenever you rotate keys in 1Password, then restart the proxy:
#   bash ~/.config/deepclaude/deepclaude-keys.sh
#   launchctl kickstart -k gui/$(id -u)/com.deepclaude.proxy

CONFIG_DIR="$HOME/.config/deepclaude"
SECRETS_ENV="$CONFIG_DIR/secrets.env"
RESOLVED_ENV="$CONFIG_DIR/resolved.env"
DEFAULT_VAULT="Agentic Vault"  # 1Password vault holding your LLM API keys

# Load OP_SERVICE_ACCOUNT_TOKEN (and any other env) from secrets.env if present.
# The file is piped through `op inject` so the token may be stored as an op://
# reference (resolved via 1Password desktop integration) instead of a raw value.
# A reference-free file passes through untouched and needs no auth, so legacy
# raw-token secrets.env files keep working. Like every op call in this script,
# this runs in the FOREGROUND only — never under launchd.
if [ -f "$SECRETS_ENV" ]; then
  if command -v op >/dev/null 2>&1; then
    injected="$(mktemp)"
    trap 'rm -f "$injected"' EXIT
    if op inject -f -i "$SECRETS_ENV" -o "$injected" >/dev/null 2>&1; then
      # shellcheck disable=SC1090
      source "$injected"
    else
      echo "op inject failed (is 1Password desktop unlocked?) — using secrets.env as-is." >&2
      # shellcheck disable=SC1090
      source "$SECRETS_ENV"
    fi
    rm -f "$injected"
  else
    # op not installed — source raw (only works if the token is a literal value).
    # shellcheck disable=SC1090
    source "$SECRETS_ENV"
  fi
fi

umask 077  # resolved.env contains plaintext keys — owner-only from creation

if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "No OP_SERVICE_ACCOUNT_TOKEN set — writing empty cache (Anthropic passthrough only)." >&2
  : > "$RESOLVED_ENV"
  chmod 600 "$RESOLVED_ENV"
  exit 0
fi

# Ask which 1Password vault to read from — press Enter to accept the default.
# Pre-set VAULT in the environment (or secrets.env) to skip the prompt entirely.
if [ -n "${VAULT:-}" ]; then
  echo "Using vault \"$VAULT\" (from environment)."
elif [ -t 0 ]; then
  read -r -p "1Password vault holding your LLM API keys [$DEFAULT_VAULT]: " VAULT
  VAULT="${VAULT:-$DEFAULT_VAULT}"
else
  VAULT="$DEFAULT_VAULT"
  echo "Non-interactive — using default vault \"$VAULT\"."
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
