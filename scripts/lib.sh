#!/usr/bin/env bash
# Shared bash helpers for the authoring scripts (newpost.sh, newsource.sh,
# finishsource.sh, publish-draft.sh, ship.sh). Source, don't execute:
#   source "$SCRIPT_DIR/lib.sh"
#
# These were previously copy-pasted verbatim across those five scripts, which
# had already drifted (two different implementations of the same RFC3339
# timestamp). Fix or extend a helper here once, for every caller.

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Title -> URL slug, matching the Obsidian Templater templates in
# ~/Notes/Meta/templates/Website byte for byte. Two rules do the work beyond
# lowercasing: NFKD-decompose and drop combining marks, so "Montréal" slugs as
# "montreal" rather than losing the letter to the separator pass; and delete
# apostrophes outright, so possessives and contractions read "louisianas" and
# "whered" like the rest of the archive, not "louisiana-s" and "where-d". A
# plain sed pipeline can't do the first, hence python3 (already required by
# eight preflight checks).
slugify() {
  python3 -c '
import re, sys, unicodedata
value = unicodedata.normalize("NFKD", sys.argv[1]).lower()
value = "".join(c for c in value if not unicodedata.combining(c))
value = re.sub(r"[\x27\u2018\u2019\u02bc]+", "", value)
value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
sys.stdout.write(value)
' "$1"
}

rfc3339_now() {
  date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
}

read_optional() {
  local prompt="$1" value
  read -r -p "$prompt: " value || value=""
  printf '%s' "$value"
}

read_with_default() {
  local prompt="$1" default_value="$2" value
  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt [$default_value]: " value || value=""
    value=$(trim "$value")
    [[ -z "$value" ]] && value="$default_value"
  else
    read -r -p "$prompt: " value || value=""
  fi
  printf '%s' "$value"
}

# field KEY VALUE [INDENT]
# Prints `INDENTkey: "value"` if value is non-empty after trimming; otherwise
# prints nothing. INDENT defaults to none (top-level front matter field).
field() {
  local key="$1" value indent="${3:-}"
  value=$(trim "$2")
  [[ -z "$value" ]] && return 0
  printf '%s%s: "%s"\n' "$indent" "$key" "$(yaml_escape "$value")"
}

# numeric_field KEY VALUE
# Like field, but prints the value unquoted (for YAML integers).
numeric_field() {
  local key="$1" value
  value=$(trim "$2")
  [[ -z "$value" ]] && return 0
  printf '%s: %s\n' "$key" "$value"
}

_emit_list_field() {
  local key="$1"; shift
  [[ $# -eq 0 ]] && return 0
  printf '%s:\n' "$key"
  local item
  for item in "$@"; do
    printf '  - "%s"\n' "$(yaml_escape "$item")"
  done
}

# list_field KEY "a, b, c"
# Prints a 2-space-indented YAML block list from a comma-separated string, for
# fields typed directly by a user (tags, sources). Prints
# nothing if every item is empty.
list_field() {
  local key="$1" raw="$2" item items=() trimmed=()
  IFS=',' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    item=$(trim "$item")
    [[ -n "$item" ]] && trimmed+=("$item")
  done
  _emit_list_field "$key" "${trimmed[@]}"
}

# list_field_lines KEY $'a\nb\nc'
# Same output as list_field, but for a value that is already one item per
# line (e.g. extracted from an existing YAML list) rather than comma-separated.
list_field_lines() {
  local key="$1" values="$2" item items=()
  while IFS= read -r item; do
    item=$(trim "$item")
    [[ -n "$item" ]] && items+=("$item")
  done <<< "$values"
  _emit_list_field "$key" "${items[@]}"
}
