<%*
// Single front door for new website drafts — the Obsidian counterpart to
// `scripts/newpost.sh <article|review|quote>` in the website repo.
//
// This file used to reimplement that script: its own slugify, its own YAML
// field emitters, its own collision loop, kept aligned with the bash by
// comments in both asking the next editor to keep them aligned. Three copies
// of the slug rule existed (here, hugo-draft-from-note.md, and lib.sh), which
// is three chances for a published URL to come out different depending on
// which window the draft was started in.
//
// Now Obsidian does what Obsidian is better at — the suggester and the
// prompts — and the repo script does the generating. `--print-target` gives
// the path (collisions already resolved), `--print` gives the text. Nothing
// about the draft format is decided in this file any more, so it cannot drift
// from the script: there is nothing left here to drift.
//
// Desktop only, by design: this shells out, which Obsidian on iOS cannot do.

const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const REPO = process.env.WEBSITE_REPO || path.join(os.homedir(), "git", "website");
const SCRIPT = path.join(REPO, "scripts", "newpost.sh");
const DRAFTS_PREFIX = "07 Blog/Drafts";

const fail = (message) => {
  new Notice(message, 10000);
  throw new Error(message);
};

if (!require("fs").existsSync(SCRIPT)) {
  fail(`Website repo not found at ${REPO}. Set WEBSITE_REPO or clone it there.`);
}

const KIND_LABELS = ["Article", "Review", "Quote"];
const KIND_VALUES = ["article", "review", "quote"];
const kind = await tp.system.suggester(KIND_LABELS, KIND_VALUES, true, "New website draft — pick a kind");

const titleInput = await tp.system.prompt("Title");
const title = (titleInput || "Untitled").trim() || "Untitled";

// A review's slug names the reviewed work, not the review's own headline —
// the archive publishes "The Rise and Fall of Tucker Carlson" at
// /reviews/zengerle-tucker-carlson/, an author-plus-short-title form that
// keeps the URL stable no matter what the piece ends up being called. Nothing
// can derive that from the title, so ask. The script slugifies whatever comes
// back, so either "zengerle-tucker-carlson" or "Zengerle Tucker Carlson"
// works, and the default shown here is the script's own slug for the title.
let slug = "";
if (kind === "review") {
  const suggested = execFileSync(SCRIPT, [kind, "--batch", "--title", title, "--print-slug"], {
    encoding: "utf8",
    cwd: REPO,
  }).trim();
  slug = (await tp.system.prompt("Slug", suggested)) || suggested;
}

const description = (await tp.system.prompt("Description (optional)")) || "";
const summary = (await tp.system.prompt("Summary override (optional)")) || "";
const series = (await tp.system.prompt('Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")')) || "";
const tags = (await tp.system.prompt("Tags, comma-separated (optional; reuse existing tags; new tag only if a second post will share it)")) || "";
const eras = (await tp.system.prompt("Eras, comma-separated (optional; a decade like 1970s or a century like 19th Century — reuse existing eras)")) || "";
// The work a post is about is named once, by its source key — the directory
// name under content/sources/, a citation-style lastname+year. Its title,
// author, publisher and year live on that page, so nothing here re-types them.
const sources = (await tp.system.prompt("Source key(s), comma-separated, e.g. mckenziejones2015 (optional)")) || "";
// Must be a subset of `sources` — labels which of those links the piece is
// centrally about rather than merely cites.
const about = (await tp.system.prompt("About: which source key(s) this piece is centrally about, comma-separated, subset of the above (optional)")) || "";

let externalUrl = "";
if (kind === "review") {
  externalUrl = (await tp.system.prompt("Reviewed work URL (optional)")) || "";
} else if (kind === "quote") {
  externalUrl = (await tp.system.prompt("External URL for this passage (optional)")) || "";
}

// Quotes carry no cover — they publish as flat files, not page bundles.
let wantsCover = false, coverAlt = "", coverCaption = "";
if (kind !== "quote") {
  wantsCover = /^y(es)?$/i.test(((await tp.system.prompt("Add cover metadata? yes/no")) || "").trim());
  coverAlt = wantsCover ? ((await tp.system.prompt("Cover alt text (optional)")) || "") : "";
  coverCaption = wantsCover ? ((await tp.system.prompt("Cover caption (optional)")) || "") : "";
}

const args = [kind, "--batch", "--title", title];
if (slug) args.push("--slug", slug);
args.push("--description", description);
args.push("--summary", summary);
args.push("--series", series);
args.push("--tags", tags);
args.push("--eras", eras);
args.push("--sources", sources);
args.push("--about", about);
args.push("--url", externalUrl);
if (wantsCover) {
  args.push("--cover", "--cover-alt", coverAlt, "--cover-caption", coverCaption);
}

const run = (extra) =>
  execFileSync(SCRIPT, args.concat(extra), { encoding: "utf8", cwd: REPO });

let target, body;
try {
  // Path first: Templater has to place the note before it has anything to put
  // in it. The script resolves collisions against the drafts root, which is
  // this vault, so the answer is the same one the terminal would have given.
  target = run(["--print-target"]).trim();
  body = run(["--print"]);
} catch (error) {
  fail(`newpost.sh failed: ${error.message}`);
}

await tp.file.move(`${DRAFTS_PREFIX}/${target.replace(/\.md$/, "")}`);
tR += body;
-%>
