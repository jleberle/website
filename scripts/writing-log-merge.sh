#!/usr/bin/env bash
# Git merge driver for data/writing-log.json (registered via .gitattributes).
#
# The file is entirely derived from committed git history and
# data/observations/ -- never hand-edited -- so there is no such thing as a
# real conflict in it. Whatever two versions git is trying to reconcile
# (a merge, a rebase, a stash pop), rebuilding from scripts/writing-log.py
# against the resulting history is the one correct answer, so this driver
# regenerates instead of leaving conflict markers for a human to sort out.
#
# Merge-driver contract (see gitattributes(5)): args are %O %A %B (base,
# ours, theirs); overwrite %A with the resolution and exit 0.
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
python3 "$REPO_ROOT/scripts/writing-log.py" >&2
cp "$REPO_ROOT/data/writing-log.json" "$2"
