---
name: session-retro
description: Use this skill to write a session retrospective at the end of a work session. Requires TranscriptPath in session context (provided by the session-retro SessionStart hook).
allowed-tools: Bash, Write
---

# Session Retrospective

Write a session retrospective to `${user_config.retro_dir}` (fallback: `${CLAUDE_PLUGIN_DATA}/retrospectives`). Filename: `YYYY-MM-DD-HH_(three-word-topic).md`. HH = hour (24h) at time of writing.

## Header

Begin with a level-1 heading derived from the filename (underscore replaced with ` — `). Immediately under the heading, run the following bash and paste its output:

```bash
TRANSCRIPT="<TranscriptPath from session context>"

# Last assistant entry — model, usage, version, end timestamp
LAST=$(grep '"type":"assistant"' "$TRANSCRIPT" | tail -1)
MODEL=$(echo "$LAST" | jq -r '.message.model // "n/a"')
END_TS=$(echo "$LAST" | jq -r '.timestamp // "n/a"')
VERSION=$(echo "$LAST" | jq -r '.version // "n/a"')
CTX=$(echo "$LAST" | jq -r '
  (.message.usage.input_tokens // 0)
  + (.message.usage.cache_creation_input_tokens // 0)
  + (.message.usage.cache_read_input_tokens // 0)')

# Context window size — inferred from model name
if echo "$MODEL" | grep -q '\[1m\]'; then CWS=1000000; else CWS=200000; fi
[ "$CWS" -gt 0 ] && CTX_USED="$((CTX * 100 / CWS))%" || CTX_USED="n/a"

# Full-scan metrics — windowed to last session-close/retro; uuid dedup handles compaction replay
STATS=$(jq -s '
  def in_window($w): if $w != "" then select(.timestamp > $w) else . end;
  (
    [.[] | select(.type == "user") | select(.message.content | arrays | any(.type == "text" and (.text | test("session-close|session-retro"))))]
    | last | .timestamp // ""
  ) as $window |
  {
    user_msgs:  ([.[] | select(.type == "user")      | in_window($window) | select(.message.content | arrays | any(.type == "text"))] | unique_by(.uuid) | length),
    agent_msgs: ([.[] | select(.type == "assistant") | in_window($window) | select(.message.content | arrays | any(.type == "text"))] | unique_by(.uuid) | length),
    tool_uses:  ([.[] | select(.type == "assistant") | in_window($window)] | unique_by(.uuid) | [.[].message.content | arrays | .[] | select(.type == "tool_use")] | length),
    subagents:  ([.[] | select(.type == "assistant") | in_window($window)] | unique_by(.uuid) | [.[].message.content | arrays | .[] | select(.type == "tool_use" and .name == "Agent")] | length),
    start:      ([.[] | select(.type == "user")      | in_window($window) | select(.message.content | arrays | any(.type == "text"))] | unique_by(.uuid) | sort_by(.timestamp) | first | .timestamp // "n/a")
  }
' "$TRANSCRIPT")

USER_MSGS=$(echo "$STATS" | jq -r '.user_msgs')
AGENT_MSGS=$(echo "$STATS" | jq -r '.agent_msgs')
TOOL_USES=$(echo "$STATS" | jq -r '.tool_uses')
SUBAGENTS=$(echo "$STATS" | jq -r '.subagents')
START=$(echo "$STATS" | jq -r '.start')

cat <<EOF
- ModelID:  $MODEL
- Version: $VERSION
- EntryPoint: ${CLAUDE_CODE_ENTRYPOINT:-n/a}
- UserMessages:  $USER_MSGS
- AgentMessages: $AGENT_MSGS
- ToolUses:  $TOOL_USES
- SubAgents: $SUBAGENTS
- StartDate:  $START
- EndDateTime: $END_TS
- ContextUsed:  $CTX_USED
EOF
```

If ModelID or OutputStyle changed mid-session, override the relevant line and note the change in section 4.

Example:

    # 2026-04-15-01 — architectural-framing-arc
    - ModelID:  claude-opus-4-7[1m]
    - OutputStyle:  explanatory
    - Version: 2.1.119
    - EntryPoint: claude-vscode
    - UserMessages:  47
    - StartDate:  2026-04-15T13:42:11.234Z
    - EndDateTime: 2026-04-15T17:21:08.901Z
    - ContextUsed:  47%

## Writing mode

**Activate explanatory mode for the retrospective.** Write with educational depth — thorough, detailed, with specific turn references and concrete moments. Provide brief educational explanations about implementation choices using:

`★ Insight ─────────────────────────────────────`
[2-3 key educational points]
`─────────────────────────────────────────────────`

Focus on insights specific to the session's work, not general programming concepts. This mode applies only to the retrospective — it is not the session's output style.

## Four sections

Each must reference a concrete moment from the session — not a generality:

1. One thing we did well together, collaboratively.
2. One thing the operator did that introduced or compounded friction.
3. One thing I (the agent) got wrong or could have handled better. No contrition.
4. One thing that would make the project or collaboration better.
