#!/usr/bin/env bash
# Jump straight to a citekey's reading/archival note in Obsidian, from the shell.
#
#   open-source.sh <citekey>
#
# Tries 02 Notes/01 Reading Notes/<citekey>.md first, then falls back to
# 02 Notes/02 Research Notes/<citekey>.md (the Zotero connector's two export
# targets, see Meta/templates/Reading Note.md and Archival Note.md). Requires
# the Advanced URI community plugin in the vault.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <citekey>" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage
CITEKEY="$1"

VAULT_DIR="${WEBSITE_VAULT_DIR:-$HOME/Notes}"
VAULT_NAME="${WEBSITE_VAULT_NAME:-Notes}"

FILEPATH="02 Notes/01 Reading Notes/${CITEKEY}.md"
if [[ ! -f "$VAULT_DIR/$FILEPATH" ]]; then
  FILEPATH="02 Notes/02 Research Notes/${CITEKEY}.md"
fi

if [[ ! -f "$VAULT_DIR/$FILEPATH" ]]; then
  echo "No reading or research note found for citekey: $CITEKEY" >&2
  exit 1
fi

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"
}

open "obsidian://advanced-uri?vault=$(urlencode "$VAULT_NAME")&filepath=$(urlencode "$FILEPATH")"
