# The Writing Log

A public record of what got written and when, at [/writing-log](https://jaredeberle.org/writing-log/),
with the most recent writing day surfaced on the home page.

Every number on that page is a difference between two measurements. Nothing is
self-reported and nothing is typed in by hand.

## The one command

At the end of a writing session, from any machine that has this repo and the
vault:

```sh
scripts/log-writing.sh
```

It fetches, counts the vault, rebuilds the log, commits, and pushes.

**You do not have to run it on every machine.** Obsidian Sync converges all of
them on the same files, so a run anywhere sees everything Sync has delivered
there — including writing done at the office that morning. Three installs so it
is always to hand, not three obligations.

**You do not have to run it every day.** Words are dated by each file's mtime,
not by when the command ran. Write on Tuesday, run on Friday from a different
machine, and the words still land on Tuesday. Forgetting costs you publication
delay, not accuracy.

Set `NOTES_VAULT` if the vault is not at `~/Notes` on that machine.

## The two sources, and why they work differently

| Source | Mechanism | History |
|---|---|---|
| Blog | git history of this repo | Real, back to the first commit (2025-04-17) |
| Notes | census of `~/Notes` | Real from 2026-08-09 forward |

The blog is walked as **git history**: for every markdown file a commit touched,
subtract the word count before from the word count after.

The vault cannot be, and the reason is worth stating plainly because it is the
thing that shaped this whole design.

### Why the vault is not a git repo

It was, briefly. The vault has no history of its own — Obsidian keeps none, and
a file's mtime is its last touch, not a record of when its words were written —
so `~/Notes` was given a local git repo and a nightly launchd job to commit it.

That works for exactly one machine. The vault lives on three, and they share
files through **Obsidian Sync, which is a transport, not a history**. Give each
machine its own repo and each one commits the same synced content as its own
work: write 500 words at the office, and the office repo, the laptop repo and
the home repo each record +500. Add them up and the day reads 1,500. Worse, the
error is invisible — every repo is internally consistent.

And it is not fixable downstream. Once you have three sets of deltas there is no
way to tell "the same 500 words seen three times" from "500 words on each of
three machines."

### So the vault is a census

Each run records **how long each counted file is right now** — a state, not a
delta — into `data/observations/<machine>.json`. Deltas are derived afterwards
from the merged states.

That is what makes it safe. Three machines observing the same synced file all
report the same length for the same day, the timeline collapses to one entry,
and the words are counted once. The merge is over file states, never over
per-machine deltas.

Each machine writes **only its own** observation file, so two machines
cataloguing on the same day merge cleanly instead of colliding over one shared
file.

Where two machines disagree about a single day, the larger count wins. A machine
whose Obsidian Sync is behind reports a stale, shorter file, and reading that as
a deletion would invent negative days out of a sync lag. The cost is that a
genuine deletion stays invisible until every machine has caught up — and the
whole timeline is recomputed from scratch on every run, so the next run corrects
it. Nothing is ever baked in.

### Paths are hashed, deliberately

The observation files are committed to a **public** repo. A census keyed by path
would publish the name of every unpublished archival note — `04
Projects/Jonestown/01 Notes/…` — which is exactly the leak `writing-log.json`
was designed to avoid.

The merge only needs file *identity* to compute per-file deltas, never the name,
and the same path hashes identically on every machine. So paths are stored as
16 hex characters of salted SHA-256, and the leak never happens. Same for the
blog-draft slug list.

`HASH_SALT` in the script must never change. Changing it orphans every recorded
observation and re-counts the entire vault from scratch.

### The baseline

`census_start` in `writing-log.yaml` is 2026-08-09. Everything at or before that
date is the *starting position*, counted as zero: the vault held years of
writing before the first census ran, and crediting all of it to whatever mtime
each file happens to carry would bury every real writing day under a handful of
enormous ones. A file first seen after that date is genuinely new and counts in
full.

The one-time cost is that writing done **on** 2026-08-09 is part of the baseline
rather than the first day of the log. Moving the date later does not recover it;
it discards more.

## What runs when

| | When | What it reads |
|---|---|---|
| `scripts/log-writing.sh` | By hand, end of session | The vault, plus the repo |
| `scripts/preflight.sh` | Every push | Committed inputs only |

Preflight regenerates `data/writing-log.json` before the Hugo build, so the
numbers you publish are always current as of that push. It deliberately **does
not** census the vault. Rebuilding from committed inputs alone — git history and
`data/observations/` — means it produces the same answer on every machine and in
CI, and a routine push can never silently re-date vault writing to whatever
today's mtimes happen to say.

The consequence: a machine without the vault, including CI, still rebuilds the
log correctly and completely. Only `observe` needs the vault itself.

Nothing is scheduled. There is no launchd agent, no cron job, and no background
process — the nightly pair that used to exist (`notes-snapshot` at 22:30 and
`writing-log-sync` at 22:45) is gone, along with the vault's git repo. They were
replaced by one command you run on purpose, which removed the whole class of
problems that came with running unattended: a Touch ID prompt at 22:45 with
nobody awake to answer it, a gitleaks exemption committed with `--no-verify`,
and a `.gitignore` juggling 3.2 GB of scanned PDFs.

### What the command will not do

- **Commit anything but `data/writing-log.json` and `data/observations/`.**
  Never `git add -A`; whatever is half-finished in the working tree stays that
  way. That is `ship.sh`'s job, with its own confirmation prompt.
- **Push your unshipped work.** If the checkout is ahead of origin by more than
  its own commit, it stops, lists the commits, and tells you to run `ship.sh` —
  which publishes the log too.
- **Publish a broken build.** `hugo --minify` runs as a smoke test before the
  commit. The `pre-push` hook runs the full preflight gate on the push itself.
- **Leave a mess after a lost race.** If another machine published between the
  fetch and the push, the push is rejected; the command undoes its own commit
  and restores the two derived files, so the checkout is exactly as re-runnable
  as it was. Run it again.
- **Bypass the secret scan.** This repo is public, so the gitleaks pre-commit
  hook is left to run.

It fetches over **anonymous HTTPS** rather than the SSH origin. The repo is
public, so fetching needs no credential, and on machines where the GitHub key
lives in Secretive that means one Touch ID prompt for the push instead of two.
`origin` is left on SSH, so `ship.sh` is unaffected.

## What counts

Configured in [`writing-log.yaml`](../writing-log.yaml), not in code — tuning the
log should never mean editing the engine.

Included, and nothing else:

- **Blog:** `content/articles/` and `content/reviews/`. The only two sections
  holding composed prose — courses are syllabi, quotes are other people's words
  under a line of commentary, sources are bibliographic records, and the
  top-level pages are site furniture that gets edited rather than written.
- **Vault projects:** `04 Projects/*/01 Notes/`, `02 Analysis/`, and
  `04 Conferences/`. The `*` spans any project, so a new one counts from the day
  it is created with no config change. The rest of the skeleton is not writing:
  `03 Index` is navigation and `05 Sources` is Zotero material.
- **Blog drafts:** `07 Blog/`.

Excluded:

- **Front matter, fenced code, and blockquotes.** Quoted source material is not
  your writing.
- **Zotero highlights**, in both formats — see below.
- **Obsidian `%% comments %%`**, which are hidden in the rendered note, and are
  also how the importer brackets its own bookkeeping.
- **Dataview inline fields** (`page-no:: 14`) — body-dwelling metadata, never
  prose.

### Keeping Zotero highlights out

This is the defence that matters most: a source note is mostly the *source's*
words, and counting a big highlight file as writing would make the whole log a
lie. Four independent things have to fail before that happens.

1. **Scope.** Source notes live in `05 Sources` and `02 Notes/01 Reading Notes`,
   neither of which is included.
2. **The `zotero` tag.** Both importer templates hardcode it, so a source note is
   excluded wherever it gets filed — including into a counted project folder.
3. **The `citekey` front-matter field.** The same question asked a second way,
   independent of the tag list, which is editable. The importer writes `citekey`
   into every source note and the rest of the toolchain keys on it; nothing
   composed by hand has one.
4. **Annotation stripping in the counter itself**, for highlight text pasted into
   a file that is otherwise legitimately yours.

That last one needs care, because **the annotated notes in the vault are not in
the format the current templates produce.** Today's templates wrap each highlight
in a `> [!quote]` callout, which blockquote stripping removes. But every
annotated note actually in the vault predates that and stores the highlight as
*flat prose* with a trailing page link:

```
Ultimately, the reason for the reluctance of African Americans to embrace
socialism … [(p. 10)](zotero://open-pdf/library/items/AUEVL32W?page=10)
```

Blockquote stripping does nothing to that. So any line carrying a
`zotero://open-pdf` link is dropped whole — the link is machine-written and
cannot occur in composed prose, and the line *is* the highlight. Measured against
the real files, `timmerman2020` drops from 590 words to 8 and `hausmann2021` from
134 to 8; the remainder is bibliography and section headings, not prose.

The one hole no rule can close is a highlight pasted in by hand with its page
link removed. Nothing distinguishes that from your own sentence.

### Drafts counted once

Blog posts are drafted in the vault and then published here, which would count
the same words twice. **The vault wins** — it knows the day the words were
actually written. Every draft the census sees under `07 Blog/` contributes its
hashed slug to a skip list, and the commit that first publishes a matching post
is not counted. Later edits to the published post *are* counted; revision is
writing.

The slug list only grows, so a draft that is published and then deleted from the
vault keeps suppressing its own double count.

## Two things that were nearly wrong

Both were caught while building it, and both would have quietly inflated the
numbers rather than breaking anything:

- **Renames.** This repo has reorganised content wholesale — the 2026-05-20
  migration moved every review and quote to a date-prefixed path. Without `-M`
  git reports each move as a delete plus an add, and the engine reads that as
  writing the entire post over again. Rename detection is not optional.
- **Bulk imports.** Back catalogue arrived in git years after it was written; the
  quotes, some dated 2011, landed on 2026-06-03. Filed under their commit dates
  they produced 2026 writing days larger than everything else combined. So when a
  file is *added* and its front matter date is more than
  `backfill_threshold_days` older than the commit, the words are credited to the
  front matter date instead. Ordinary publishing is untouched.

## What it cannot see

Word-count deltas measure size, not effort. Rewriting a 500-word paragraph into a
better 500-word paragraph is a real day's work that registers as zero, and
deletion is invisible in the headline number (it is tracked as `net`). This is
the accepted trade: the alternative is counting diff churn, which rewards
thrashing a file over writing well.

The census adds two of its own:

- **mtime is last-touch.** A file edited Tuesday and again Thursday lands the
  whole week's growth on Thursday. Run the command more often and it sharpens.
- **Words written and deleted between two runs are never observed.** No census
  ever saw them.

A future mtime — clock skew, a restored backup — is clamped to today rather than
charting a row months ahead.

## Front-end notes

- `layouts/writing-log.html` renders every panel and row server-side.
  `assets/js/writing-log.js` only adds the period tabs and column sorting on top;
  with JS off the page is a stack of complete tables under their own headings.
- **Bar widths are classes, not inline styles.** The site ships `style-src 'self'`
  with no `'unsafe-inline'`, so a `style="width:42%"` attribute is blocked by the
  CSP and the bar renders at zero width — silently. `.wl-w-0` … `.wl-w-50` in
  `29-writing-log.css` are the 0–100% range in 2% steps; the template rounds onto
  that grid.
- `02-reset.css` sets `section { display: block }`, which beats the user agent's
  `[hidden] { display: none }`. `.wl-panel[hidden]` restores it — without that
  rule the tabs toggle correctly and every panel stays on screen anyway.
- Neither `writing-log.json` nor the observation files carry a filename. The page
  is public and says how much was written, not what the unpublished archival
  notes are called.

## Commands

```sh
scripts/log-writing.sh                    # the one you actually run

python3 scripts/writing-log.py observe    # census this machine's vault only
python3 scripts/writing-log.py            # rebuild data/writing-log.json
python3 scripts/writing-log.py --stats    # rebuild and print a summary
python3 scripts/writing-log.py --check    # non-zero exit if it would change
```

Needs PyYAML locally (`pip3 install --user pyyaml`); the deploy build only reads
the committed JSON.
