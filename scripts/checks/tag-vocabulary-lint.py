#!/usr/bin/env python3
"""Hold `tags` to a closed, approved subject vocabulary.

The period facet is closed by construction — a decade or a named century — so
taxonomy-facet-lint.py can check it with a regex. Subjects have no such shape,
and that asymmetry is the whole problem: a misspelled or improvised tag is
indistinguishable from a real one, so it silently publishes a single-member
/tags/<typo>/ hub that nothing links to and no one notices. "Rodeo" and
"rodeo", "Right-Wing Movements" and "Right Wing Movements", all valid, all
different pages.

The fix is to make the vocabulary a list rather than a convention. Adding a
subject is then a deliberate two-line commit — the term here, the term in the
front matter — which is the point: a new hub should be a decision, not a
side effect of typing.

Guidance for the list, applied 2026-07-31 and not enforceable here:

  - A term wants three or more members. Fewer and the hub returns roughly what
    the page linking to it already showed. Two exceptions currently stand:
    `AI`, which is the first part of a running series, and terms held for a
    cluster that is still arriving.
  - A term must not be a restatement of its neighbours. `Digital Humanities`
    and `Drinking` were retired into `Historiography` and `Folklore` because
    every member already carried the broader term; the narrow page added a
    second name for the same shelf.
  - `Native American History` is the field, not a subject. It runs to roughly a
    third of everything tagged, so it is a parent term: it should travel with a
    narrower tag wherever one fits. Two sources currently carry it alone
    because nothing in the vocabulary is narrower for them, which is the
    correct outcome — inventing a term to satisfy the rule is the sprawl the
    rule exists to prevent.

A few terms name a work's FORM rather than its subject — `Fiction`,
`Life Writing` — which the "what is this about" rule does not strictly cover.
They are kept deliberately, and only for the reading log: `/reading/` is a
record of what was read, and "what kind of book was it" is a real question to
ask of a reading list even though it is not a research subject. Keep this
subset small and obvious. A form term that starts collecting writing as well as
works is a sign it has drifted into being a subject and should be re-examined.

Prefer the term that covers the shelf over the term that names its commonest
member. `Life Writing` started as `Autobiography` and was renamed within the
day: the work that prompted it, Roosevelt's `roosevelt1928`, is a
contemporaneous diary rather than retrospective autobiography, so the narrower
word excluded its own founding case. The umbrella takes diaries, letters,
journals and oral histories without that mismatch.

Place terms (`Oklahoma`, `Connecticut`, `Europe`) live here rather than in a
`places` facet. Regional history is a subject, and a facet with three members is
still thinner than the vocabulary it would be carved out of. Note that `Europe`
is coarser than the other two, so if an `England` term ever appears — three of
the seven European works are English — the facet inherits the granularity
problem era_rollup.html solves for centuries, and should be solved the same way
rather than by storing both terms. See docs/workflow.md 'Tags and eras'.
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

from _frontmatter import front_matter, values

VOCABULARY = {
    "AI",
    "American Indian Movement",
    "Connecticut",
    "Disaster",
    "Environment",
    "Europe",
    "Federal Law Enforcement",
    "Fiction",
    "Folklore",
    "Historiography",
    "Journalism",
    "Labor",
    "Life Writing",
    "Media",
    "Music",
    "Native American History",
    "Oklahoma",
    "Populism",
    "Right-Wing Movements",
    "Rodeo",
    "Sports",
    "Tribal Recognition",
}

def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "content")
    unknown: list[tuple[Path, str]] = []
    used: Counter[str] = Counter()

    for path in sorted(root.rglob("*.md")):
        for value in values(front_matter(path), "tags"):
            used[value] += 1
            if value not in VOCABULARY:
                unknown.append((path, value))

    failed = False

    if unknown:
        failed = True
        print("Tags outside the approved subject vocabulary:")
        for path, value in unknown:
            near = [t for t in sorted(VOCABULARY) if t.lower() == value.lower()]
            hint = f" — did you mean {near[0]!r}?" if near else ""
            print(f"  {path}: {value!r}{hint}")
        print(
            "Fix the spelling, or add the term to VOCABULARY in "
            "scripts/checks/tag-vocabulary-lint.py if it is a real new subject."
        )

    # A term left in the list after its last use publishes nothing and quietly
    # stops describing the site. Retiring a tag should mean retiring it here
    # too, in the same commit that empties it.
    orphans = sorted(VOCABULARY - set(used))
    if orphans:
        failed = True
        if unknown:
            print()
        print("Approved tags no longer used by any page:")
        for value in orphans:
            print(f"  {value!r}")
        print("Remove them from VOCABULARY, or restore the tag on the pages that lost it.")

    if failed:
        return 1

    print(
        f"Tag vocabulary lint clean ({len(VOCABULARY)} approved terms, "
        f"{sum(used.values())} assignments)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
