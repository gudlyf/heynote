#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title List Heynote Notes
# @raycast.mode fullOutput
# @raycast.packageName Heynote

# Optional parameters:
# @raycast.icon 📋
# @raycast.description List all notes in your Heynote library
# @raycast.author Heynote
# @raycast.authorURL https://heynote.com

# Configuration — set these to match your Heynote config
API_TOKEN="${HEYNOTE_API_TOKEN:-}"
API_PORT="${HEYNOTE_API_PORT:-5095}"

if [ -z "$API_TOKEN" ]; then
    echo "Error: Set HEYNOTE_API_TOKEN environment variable in Raycast preferences or shell profile"
    exit 1
fi

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $API_TOKEN" \
    "http://127.0.0.1:${API_PORT}/api/notes" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "$BODY" | python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
notes = data.get("notes", {})
if not notes:
    print("No notes found.")
else:
    for path, meta in sorted(notes.items()):
        name = meta.get("name", "") if meta else ""
        tags = ", ".join(meta.get("tags", [])) if meta and meta.get("tags") else ""
        line = f"  {path}"
        if name:
            line += f"  ({name})"
        if tags:
            line += f"  [{tags}]"
        print(line)
'
else
    echo "Error ($HTTP_CODE): $BODY"
    exit 1
fi
