#!/bin/bash

ROOM_ID=<ROOM_ID>
AUTH_TOKEN=<TOKEN>
MESSAGE="<MESSAGE>"

curl -H "Content-Type: application/json" \
     -H "Authorization: Bearer $AUTH_TOKEN" \
     -X POST \
     -d "{\"color\": \"green\", \"message_format\": \"html\", \"message\": \"$MESSAGE\" }" \
     https://api.hipchat.com/v2/room/$ROOM_ID/message
