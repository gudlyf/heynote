#!/bin/bash
# PopClip shell script action: append selected text to Heynote
# POPCLIP_TEXT contains the selected text
# POPCLIP_OPTION_* contains the extension options

PORT="${POPCLIP_OPTION_APIPORT:-5095}"
TOKEN="$POPCLIP_OPTION_APITOKEN"
NOTE_PATH="${POPCLIP_OPTION_NOTEPATH:-scratch.txt}"

if [ -z "$TOKEN" ]; then
    echo "Error: API token not configured" >&2
    exit 1
fi

# Build JSON payload, escaping the text for JSON safety
JSON_TEXT=$(printf '%s' "$POPCLIP_TEXT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"text\": ${JSON_TEXT}, \"path\": \"${NOTE_PATH}\"}" \
    "http://127.0.0.1:${PORT}/api/append" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "Added to Heynote"
else
    echo "Error: $BODY" >&2
    exit 1
fi
