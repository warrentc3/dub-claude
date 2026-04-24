#!/usr/bin/env bash
# Session-ownership gate for ${CLAUDE_PLUGIN_DATA}/divergence_logs/.
# Unix peer of session_ownership.ps1 (Windows). Self-guards on platform so
# registering both in hooks.json is safe: one runs, the other no-ops.
#
# Requires: bash >= 4, jq, coreutils (realpath).
#
# Policy mirrors session_ownership.ps1 exactly. See that file's header for the
# full policy statement.

set -u
IFS=$'\n\t'

# Platform guard: non-Windows only. The pwsh peer handles Windows.
case "${OSTYPE:-}" in
  msys*|cygwin*|win32) exit 0 ;;
esac
[ -n "${WINDIR:-}" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
[ -z "$payload" ] && exit 0

event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null || true)
[ "$event" = "PreToolUse" ] || exit 0

session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty')
tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
tool_input=$(printf '%s' "$payload" | jq -c '.tool_input // {}')

[ -z "${CLAUDE_PLUGIN_DATA:-}" ] && exit 0

if command -v realpath >/dev/null 2>&1; then
  protected_dir="$(realpath -m "$CLAUDE_PLUGIN_DATA/divergence_logs")"
else
  protected_dir="$CLAUDE_PLUGIN_DATA/divergence_logs"
fi
ledger_path="$protected_dir/.ownership.jsonl"

emit_decision() {
  local decision="$1" reason="$2"
  jq -nc --arg d "$decision" --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

resolve_path() {
  local p="$1"
  [ -z "$p" ] && { printf ''; return; }
  # Safe expansion of known env vars only (no eval).
  p="${p//\$\{CLAUDE_PLUGIN_DATA\}/$CLAUDE_PLUGIN_DATA}"
  p="${p//\$CLAUDE_PLUGIN_DATA/$CLAUDE_PLUGIN_DATA}"
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    p="${p//\$\{CLAUDE_PLUGIN_ROOT\}/$CLAUDE_PLUGIN_ROOT}"
    p="${p//\$CLAUDE_PLUGIN_ROOT/$CLAUDE_PLUGIN_ROOT}"
  fi
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

is_under_protected() {
  local rp="$1"
  [ -z "$rp" ] && return 1
  case "$rp" in
    "$protected_dir") return 0 ;;
    "$protected_dir"/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_ledger() { [ "$1" = "$ledger_path" ]; }

record_ownership() {
  local p="$1" ts
  mkdir -p "$protected_dir"
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -nc --arg s "$session_id" --arg f "$p" --arg t "$ts" \
    '{session_id:$s, file_path:$f, ts:$t}' >> "$ledger_path"
}

check_ownership() {
  local p="$1"
  [ -f "$ledger_path" ] || return 1
  jq -e --arg s "$session_id" --arg f "$p" \
    'select(.session_id == $s and .file_path == $f)' \
    "$ledger_path" >/dev/null 2>&1
}

ti_get() { printf '%s' "$tool_input" | jq -r "$1 // empty"; }

case "$tool_name" in
  Write)
    p=$(resolve_path "$(ti_get '.file_path')")
    is_under_protected "$p" || exit 0
    is_ledger "$p" && emit_decision deny "The ownership ledger is not writable by the agent."
    record_ownership "$p"
    emit_decision allow "Recorded session ownership of $(basename "$p")."
    ;;
  Edit)
    p=$(resolve_path "$(ti_get '.file_path')")
    is_under_protected "$p" || exit 0
    is_ledger "$p" && emit_decision deny "The ownership ledger is not editable by the agent."
    check_ownership "$p" && emit_decision allow "Session owns this file."
    emit_decision deny "divergence_logs entries are editable only by the session that wrote them."
    ;;
  Read)
    p=$(resolve_path "$(ti_get '.file_path')")
    is_under_protected "$p" || exit 0
    is_ledger "$p" && emit_decision deny "The ownership ledger is not readable by the agent."
    check_ownership "$p" && emit_decision allow "Session owns this file."
    emit_decision deny "divergence_logs entries are readable only by the session that wrote them."
    ;;
  NotebookEdit)
    p=$(resolve_path "$(ti_get '.notebook_path')")
    is_under_protected "$p" || exit 0
    check_ownership "$p" && emit_decision allow "Session owns this notebook."
    emit_decision deny "divergence_logs entries are editable only by the session that wrote them."
    ;;
  Grep)
    p=$(resolve_path "$(ti_get '.path')")
    is_under_protected "$p" || exit 0
    emit_decision deny "Grep is not permitted in divergence_logs (no enumeration across sessions)."
    ;;
  Glob)
    p=$(resolve_path "$(ti_get '.path')")
    is_under_protected "$p" || exit 0
    emit_decision deny "Glob is not permitted in divergence_logs (no enumeration across sessions)."
    ;;
  Bash)
    cmd=$(ti_get '.command')
    for needle in 'divergence_logs' '${CLAUDE_PLUGIN_DATA}' '$CLAUDE_PLUGIN_DATA' '%CLAUDE_PLUGIN_DATA%' "$protected_dir"; do
      [ -z "$needle" ] && continue
      case "$cmd" in
        *"$needle"*) emit_decision deny "Bash access to divergence_logs is not permitted. Use the Write tool to create artifact files." ;;
      esac
    done
    exit 0
    ;;
  WebFetch)
    url=$(ti_get '.url')
    case "$url" in
      file://*)
        case "$url" in
          *divergence_logs*) emit_decision deny "file:// URLs under divergence_logs are not permitted." ;;
        esac
        stripped="${url#file://}"
        # Handle file:///C:/... (Windows-style) by trimming leading / before a drive letter.
        case "$stripped" in
          /[A-Za-z]:[/\\]*) stripped="${stripped#/}" ;;
        esac
        p=$(resolve_path "$stripped")
        is_under_protected "$p" && emit_decision deny "file:// URLs under divergence_logs are not permitted."
        ;;
    esac
    exit 0
    ;;
  mcp__*)
    if printf '%s' "$tool_input" | jq -e '[.. | strings] | any(. | test("divergence_logs"; "i"))' >/dev/null 2>&1; then
      emit_decision deny "MCP tool reference to divergence_logs is not permitted."
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
