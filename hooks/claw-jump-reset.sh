#!/bin/zsh

set -u

event_payload="$(cat)"
if [[ -z "${event_payload}" ]]; then
  exit 0
fi

normalize_tty() {
  local tty_value="$1"
  tty_value="${tty_value//[[:space:]]/}"
  if [[ -z "${tty_value}" || "${tty_value}" == "?" || "${tty_value}" == "??" || "${tty_value}" == "/dev/tty" ]]; then
    echo ""
    return
  fi
  if [[ "${tty_value}" == /dev/* ]]; then
    echo "${tty_value}"
  else
    echo "/dev/${tty_value}"
  fi
}

claw_jump_tty="$(normalize_tty "$(/bin/ps -o tty= -p $$ 2>/dev/null || true)")"
if [[ -z "${claw_jump_tty}" ]]; then
  claw_jump_tty="$(normalize_tty "$(/bin/ps -o tty= -p $PPID 2>/dev/null || true)")"
fi
export CLAW_JUMP_TTY="${claw_jump_tty}"

/usr/bin/python3 - "$event_payload" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone
from urllib.error import URLError
from urllib.request import Request, urlopen

try:
    raw = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

body = {
    "event": "reset",
    "sessionId": raw.get("session_id"),
    "cwd": raw.get("cwd"),
    "transcriptPath": raw.get("transcript_path"),
    "hookEventName": raw.get("hook_event_name", "UserPromptSubmit"),
    "sourceApp": raw.get("source_app") or os.environ.get("TERM_PROGRAM"),
    "terminalTTY": os.environ.get("CLAW_JUMP_TTY") or None,
    "terminalSessionId": os.environ.get("TERM_SESSION_ID") or os.environ.get("ITERM_SESSION_ID"),
    "timestamp": datetime.now(timezone.utc).astimezone().isoformat(),
}

data = json.dumps(body).encode("utf-8")
request = Request(
    "http://127.0.0.1:47653/event",
    data=data,
    headers={"Content-Type": "application/json"},
    method="POST",
)

try:
    with urlopen(request, timeout=0.8):
        pass
except URLError:
    sys.exit(0)
except Exception:
    sys.exit(0)
PY
