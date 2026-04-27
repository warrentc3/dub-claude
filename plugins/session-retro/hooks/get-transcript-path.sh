#!/usr/bin/env bash
# SessionStart hook — reads transcript_path from stdin JSON and injects it into session context.
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
[ -n "$TRANSCRIPT" ] && echo "TranscriptPath: $TRANSCRIPT"
