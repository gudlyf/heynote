#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Append to Heynote
# @raycast.mode silent
# @raycast.packageName Heynote

# Optional parameters:
# @raycast.icon ✏️
# @raycast.description Append text to a Heynote note via the local API
# @raycast.author Heynote
# @raycast.authorURL https://heynote.com

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Text to append" }
# @raycast.argument2 { "type": "text", "placeholder": "Note path (default: scratch.txt)", "optional": true }
# @raycast.argument3 { "type": "text", "placeholder": "Language (default: text)", "optional": true }

# Configuration — set these to match your Heynote config
API_TOKEN="${HEYNOTE_API_TOKEN:-}"
API_PORT="${HEYNOTE_API_PORT:-5095}"

if [ -z "$API_TOKEN" ]; then
    echo "Error: Set HEYNOTE_API_TOKEN environment variable in Raycast preferences or shell profile"
    exit 1
fi

TEXT="$1"
NOTE_PATH="${2:-scratch.txt}"
LANGUAGE="${3:-text}"

# Build JSON payload safely
JSON_TEXT=$(printf '%s' "$TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
JSON_PATH=$(printf '%s' "$NOTE_PATH" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
JSON_LANG=$(printf '%s' "$LANGUAGE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -d "{\"text\": ${JSON_TEXT}, \"path\": ${JSON_PATH}, \"language\": ${JSON_LANG}}" \
    "http://127.0.0.1:${API_PORT}/api/append" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "Added to Heynote"
else
    BODY=$(echo "$RESPONSE" | sed '$d')
    echo "Error ($HTTP_CODE): $BODY"
    exit 1
fi
