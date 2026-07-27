#!/usr/bin/env bash
# Mark a source finished: flip status to read, stamp the finish date, derive
# read_year, and record finished_announced so the reading feed treats the event
# as new rather than as an old midnight post.
#
# Usage: finishsource.sh [slug]
# With no argument, lists sources currently marked `status: "reading"`.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
SOURCES_ROOT="$REPO_ROOT/content/sources"
source "$SCRIPT_DIR/lib.sh"

PUSH=false
SLUG="${1:-}"
if [[ "$SLUG" == "--push" ]]; then PUSH=true; SLUG="${2:-}"; fi

current_slugs() {
  local f
  for f in "$SOURCES_ROOT"/*/_index.md; do
    [[ -e "$f" ]] || continue
    grep -q '^status: *"reading"' "$f" && basename "$(dirname "$f")"
  done
}

if [[ -z "$SLUG" ]]; then
  mapfile -t CANDIDATES < <(current_slugs)
  if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    echo "Nothing is marked as currently reading." >&2
    exit 1
  fi
  echo "Currently reading:" >&2
  select choice in "${CANDIDATES[@]}"; do
    [[ -n "${choice:-}" ]] && { SLUG="$choice"; break; }
  done
fi

FILE="$SOURCES_ROOT/$SLUG/_index.md"
[[ -f "$FILE" ]] || { echo "No source at content/sources/$SLUG/_index.md" >&2; exit 1; }

TODAY=$(date +%Y-%m-%d)
FINISHED=$(read_with_default "Finished (YYYY-MM-DD)" "$TODAY")
READ_YEAR="${FINISHED%%-*}"
ANNOUNCED=$(rfc3339_now)

FINISHED="$FINISHED" READ_YEAR="$READ_YEAR" ANNOUNCED="$ANNOUNCED" python3 - "$FILE" <<'PY'
import os, pathlib, re, sys

path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines()
end = lines.index("---", 1)
head, body = lines[1:end], lines[end:]

values = {
    "status": '"read"',
    "read_year": os.environ["READ_YEAR"],
    "finished": '"%s"' % os.environ["FINISHED"],
    "finished_announced": '"%s"' % os.environ["ANNOUNCED"],
}

out, seen = [], set()
for line in head:
    match = re.match(r"^([a-z_]+):", line)
    key = match.group(1) if match else None
    if key in values:
        out.append("%s: %s" % (key, values[key]))
        seen.add(key)
    elif key == "started":
        out.append(line)
    else:
        out.append(line)
for key, value in values.items():
    if key not in seen:
        out.append("%s: %s" % (key, value))

path.write_text("\n".join(["---"] + out + body) + "\n")
PY

echo "Marked $SLUG finished on $FINISHED." >&2
if $PUSH; then
  TITLE="$(sed -n 's/^title: *"\(.*\)"[[:space:]]*$/\1/p' "$FILE" | head -1)"
  "$SCRIPT_DIR/ship.sh" "Finished reading: ${TITLE:-$SLUG}"
fi
