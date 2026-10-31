#!/bin/sh
# Toggle raffi launcher: close the running window via niri IPC,
# or spawn a new detached instance if not running.
# Detached via setsid: wayle click actions wait up to 30 s for the
# command to exit — raffi blocks until dismissed.
APP_ID="com.chmouel.raffi"

id=$(niri msg --json windows 2>/dev/null \
	| jq -r --arg app "$APP_ID" \
		'[.[] | select(.app_id == $app)][0].id // empty')

if [ -n "$id" ]; then
	niri msg action close-window --id "$id"
else
	setsid raffi >/dev/null 2>&1 &
fi
