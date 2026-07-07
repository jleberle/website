#!/usr/bin/env python3
"""Update the `status` front-matter field of a vault reading note in place.

Used by finishsource.sh to keep a reading note's status aligned with the ledger
event that triggered it (finishing a source marks the note read), so the vault
and the site's reading ledger don't silently diverge. Silently no-ops if the
note does not exist — the vault is optional and absent in CI.

Usage: sync-vault-status.py NOTE_PATH NEW_STATUS
Prints "updated" only if it changed the file; otherwise prints nothing. Exits 0
either way (missing note or already-correct status are not errors).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: sync-vault-status.py NOTE_PATH NEW_STATUS", file=sys.stderr)
        return 2

    note_path = Path(argv[0])
    new_status = argv[1]
    if not note_path.is_file():
        return 0

    lines = note_path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return 0
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        return 0

    for i in range(1, end):
        m = re.match(r"^(status\s*:\s*)(.*)$", lines[i])
        if m:
            if m.group(2).strip() == new_status:
                return 0
            lines[i] = f"{m.group(1)}{new_status}"
            note_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            print("updated")
            return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
