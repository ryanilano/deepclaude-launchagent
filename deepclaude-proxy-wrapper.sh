#!/usr/bin/env bash
set -euo pipefail

# ── Paths ───────────────────────────────────────────────────────────────
# "Agentic" is the 1Password vault that stores all LLM / AI API keys.
CONFIG_DIR="$HOME/.config/deepclaude"
SECRETS_ENV="$CONFIG_DIR/secrets.env"
DEEPSEEK_REF='op://Agentic/DEEPSEEK_API_KEY/credential'  # "Agentic" vault — your LLM API key vault
NODE_BIN="$HOME/.nvm/versions/node/v24.15.0/bin/node"                    # set by run-command.sh
PROXY_ENTRY="$HOME/code/deepclaude/proxy/start-proxy.js"

# ── PATH ────────────────────────────────────────────────────────────────
# LaunchAgents inherit a minimal PATH; ensure Homebrew (op) and nvm (node) are reachable.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── Secrets from file (optional) ───────────────────────────────────────
# secrets.env can set OP_SERVICE_ACCOUNT_TOKEN and other env vars.
if [ -f "$SECRETS_ENV" ]; then
  # shellcheck disable=SC1090
  source "$SECRETS_ENV"
fi

if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "OP_SERVICE_ACCOUNT_TOKEN is not set" >&2
  exit 1
fi

# ── Required key ────────────────────────────────────────────────────────
DEEPSEEK_API_KEY="$(op read "$DEEPSEEK_REF")"
if [ -z "$DEEPSEEK_API_KEY" ]; then
  echo "Failed to read DEEPSEEK_API_KEY from 1Password" >&2
  exit 1
fi
export DEEPSEEK_API_KEY

# ── Optional keys (read once, export if present) ───────────────────────
# Each key is fetched once from the "Agentic" vault to avoid redundant API calls.
read_optional_key() {
  local ref="$1" var="$2" val
  if val="$(op read "$ref" 2>/dev/null)" && [ -n "$val" ]; then
    export "$var=$val"
    echo "Loaded $var from 1Password"
  else
    echo "Skipping $var (not found in 1Password Agentic vault)" >&2
  fi
}

read_optional_key 'op://Agentic/OPENROUTER_API_KEY/credential'  OPENROUTER_API_KEY
read_optional_key 'op://Agentic/FIREWORKS_API_KEY/credential'   FIREWORKS_API_KEY
read_optional_key 'op://Agentic/ANTHROPIC_API_KEY/credential'   ANTHROPIC_API_KEY

exec "$NODE_BIN" "$PROXY_ENTRY"
