#!/usr/bin/env bash
#
# check-remap.sh — warn when the installed DeepClaude proxy can't remap the
# Claude model ids in active use.
#
# WHY THIS EXISTS
#   The proxy (aattaran/deepclaude, cloned by install.sh into
#   ~/.config/deepclaude/proxy) remaps Anthropic model ids → backend model ids
#   via a hardcoded MODEL_REMAP table in proxy/model-proxy.js. If a request's
#   model id is NOT in that table, the proxy SILENTLY forwards the raw claude-*
#   id to the backend instead of remapping it — the backend then serves its
#   default model and nothing warns you. The table goes stale on every Claude
#   release (e.g. it shipped covering claude-opus-4-7 while Claude Code already
#   defaulted to claude-opus-4-8), so this bites in normal use.
#   Upstream bug: https://github.com/aattaran/deepclaude/issues/39
#
#   The proxy exposes no model-map endpoint, so this guard reads the installed
#   model-proxy.js statically and checks whether the model ids we care about are
#   present in MODEL_REMAP for the given mode. It is advisory: it prints a loud
#   warning and exits non-zero, but never edits the proxy or blocks the switch.
#
# USAGE
#   ./check-remap.sh <mode> [model-id ...]
#     <mode>       deepseek | openrouter   (anthropic needs no remap → always ok)
#     [model-id]   one or more Claude model ids to verify are mapped.
#                  Defaults to the CURRENT_CLAUDE_MODELS list below.
#
# EXIT CODES
#   0  every checked model id is present in MODEL_REMAP[mode]   (or mode=anthropic)
#   1  at least one model id is unmapped → would silently mis-route
#   2  setup error (proxy file not found / mode has no table)

set -uo pipefail

PROXY_JS="${DEEPCLAUDE_PROXY_JS:-$HOME/.config/deepclaude/proxy/proxy/model-proxy.js}"

# The Claude model ids this machine is expected to run through the proxy. Keep
# this in sync with the Claude Code build you use; one id per tier is enough,
# since a fan-out launches whatever Claude Code defaults to. Update on upgrade.
CURRENT_CLAUDE_MODELS=(
  "claude-opus-4-8"
  "claude-sonnet-4-6"
  "claude-haiku-4-5-20251001"
)

mode="${1:-}"
if [ -z "$mode" ]; then
  echo "usage: $0 <mode> [model-id ...]" >&2
  exit 2
fi
shift || true

# anthropic passthrough does not remap — nothing to check.
if [ "$mode" = "anthropic" ]; then
  exit 0
fi

models=("$@")
if [ "${#models[@]}" -eq 0 ]; then
  models=("${CURRENT_CLAUDE_MODELS[@]}")
fi

if [ ! -f "$PROXY_JS" ]; then
  echo "warn: proxy source not found at $PROXY_JS — cannot verify model remap." >&2
  echo "      (set DEEPCLAUDE_PROXY_JS if it lives elsewhere)" >&2
  exit 2
fi

# Extract the keys of MODEL_REMAP[<mode>] from model-proxy.js without executing
# it. node parses its own source far more reliably than a regex would; fall back
# to grep only if node is unavailable.
mapped_keys=""
if command -v node >/dev/null 2>&1; then
  mapped_keys="$(node - "$PROXY_JS" "$mode" <<'NODE' 2>/dev/null
const fs = require('fs');
const [file, mode] = process.argv.slice(1);
const src = fs.readFileSync(file, 'utf8');
// Grab the `const MODEL_REMAP = { ... };` object literal and eval it in
// isolation (it is plain data — string→string maps, no code).
const m = src.match(/const\s+MODEL_REMAP\s*=\s*(\{[\s\S]*?\});/);
if (!m) process.exit(3);
let table;
try { table = (0, eval)('(' + m[1] + ')'); } catch { process.exit(3); }
const sub = table[mode] || {};
console.log(Object.keys(sub).join('\n'));
NODE
)"
fi
if [ -z "$mapped_keys" ]; then
  # Fallback: pull quoted keys from the file (coarse — matches all modes, but a
  # present key is still a present key for an "is it mapped at all" check).
  mapped_keys="$(grep -oE "'claude-[^']+'" "$PROXY_JS" 2>/dev/null | tr -d "'" | sort -u)"
fi

missing=()
for want in "${models[@]}"; do
  if ! grep -qxF "$want" <<<"$mapped_keys"; then
    missing+=("$want")
  fi
done

if [ "${#missing[@]}" -eq 0 ]; then
  exit 0
fi

# Loud, actionable warning. Goes to stderr so callers can show it inline.
{
  echo ""
  echo "⚠️  DeepClaude remap gap — mode '$mode' will SILENTLY mis-route these models:"
  for m in "${missing[@]}"; do echo "      • $m"; done
  echo ""
  echo "   MODEL_REMAP[$mode] in model-proxy.js has no entry for them, so the proxy"
  echo "   forwards the raw claude-* id to the backend, which serves its DEFAULT model"
  echo "   (not the one you pinned). Output will differ with no further warning."
  echo ""
  echo "   Fix: add the id(s) to MODEL_REMAP.$mode in"
  echo "        $PROXY_JS"
  echo "   Upstream bug: https://github.com/aattaran/deepclaude/issues/39"
  echo ""
} >&2
exit 1
