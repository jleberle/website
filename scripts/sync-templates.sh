#!/usr/bin/env bash
# Keep the Obsidian Templater templates in templates/obsidian/ and the copies
# Obsidian actually loads from ~/Notes/Meta/templates/Website/ identical.
#
# The templates used to live only in the vault. That put ~366 lines of the
# publishing contract — the slug rule, the front-matter field order, the
# collision behaviour — outside version control entirely, with no history, no
# diff, and no way to review a change. Obsidian Sync was the only thing standing
# between a bad edit and a silently different draft format.
#
# The repo copy is canonical, but the vault copy is the one you can actually
# edit and test, since Templater only runs inside Obsidian. So this syncs both
# ways on purpose:
#
#   scripts/sync-templates.sh --check       # do they differ? (preflight runs this)
#   scripts/sync-templates.sh --from-vault  # you edited in Obsidian -> update the repo
#   scripts/sync-templates.sh --to-vault    # you edited in the repo -> update Obsidian
#
# Symlinking the vault folder at the repo would be tidier and does not work:
# Obsidian Sync does not reliably follow symlinked folders, so the templates
# would stop reaching other machines. Copying plus a drift check is the version
# of this that survives contact with Sync.
#
# Exit 3 means the vault isn't on this machine — a skip, not a failure. Only one
# machine needs Obsidian for the repo copy to stay meaningful.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

REPO_DIR="templates/obsidian"
VAULT_DIR="${WEBSITE_TEMPLATES_DIR:-$HOME/Notes/Meta/templates/Website}"

MODE=""
for arg in "$@"; do
  case "$arg" in
    --check)      MODE=check ;;
    --from-vault) MODE=from-vault ;;
    --to-vault)   MODE=to-vault ;;
    --help|-h)    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
[[ -z "$MODE" ]] && { echo "Pick one: --check, --from-vault, or --to-vault." >&2; exit 2; }

[[ -d "$REPO_DIR" ]] || { echo "Missing $REPO_DIR in the repo." >&2; exit 2; }

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "Obsidian templates not on this machine ($VAULT_DIR) — skipping."
  exit 3
fi

case "$MODE" in
  check)
    if DIFF_OUT=$(diff -ru "$REPO_DIR" "$VAULT_DIR" 2>&1); then
      COUNT=$(find "$REPO_DIR" -name '*.md' | wc -l | tr -d ' ')
      echo "Obsidian templates match the vault ($COUNT file(s))"
      exit 0
    fi
    echo "The Obsidian templates in the repo and the vault have diverged:"
    echo
    echo "$DIFF_OUT"
    echo
    echo "Lines starting '-' are the repo's, '+' are the vault's."
    echo "If you edited them in Obsidian:  scripts/sync-templates.sh --from-vault"
    echo "If you edited them in the repo:  scripts/sync-templates.sh --to-vault"
    exit 1
    ;;
  from-vault)
    rsync -a --delete --include='*.md' --exclude='*' "$VAULT_DIR/" "$REPO_DIR/"
    echo "Copied the vault's templates into $REPO_DIR — commit them to record the change."
    ;;
  to-vault)
    rsync -a --delete --include='*.md' --exclude='*' "$REPO_DIR/" "$VAULT_DIR/"
    echo "Copied $REPO_DIR into the vault. Restart Obsidian if Templater has them cached."
    ;;
esac
