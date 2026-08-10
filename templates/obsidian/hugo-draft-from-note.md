<%*
// Draft a Hugo post from an existing vault note — run via "Templater: Insert
// Templater to the current active file" while sitting IN the note to pull
// from (not "Create new note from template"). Reads that note only: takes the
// current selection if there is one, else the whole note body; pulls
// `citekey` (reading notes, matches content/sources/<key>/ 1:1) or `source`/
// `url` (web clippings) as defaults for sources/external_url if present. The
// source note is never edited or moved — this writes the new draft directly
// via the vault API and clears its own output (tR = "") so nothing lands back
// at the cursor.
//
// It no longer mirrors scripts/newpost.sh; it calls it. The slug rule, the
// field order and the collision behaviour used to be reimplemented here in
// JavaScript — a third copy, after hugo-new.md and lib.sh — and kept aligned
// by comments asking the next editor to keep them aligned. All this file
// decides now is the prompts and where the captured note body goes, which is
// the one part the script cannot know about. Desktop only: it shells out.
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
const kind = await tp.system.suggester(KIND_LABELS, KIND_VALUES, true, "Draft from this note — pick a kind");
const section = kind === "article" ? "articles" : kind === "review" ? "reviews" : "quotes";

const fm = tp.frontmatter || {};

// Selection first, whole note second — either way the source note is only
// ever read, never edited or moved. `tR` is set to "" at the very end so
// nothing gets inserted back at the cursor.
let captured = "";
try {
  captured = tp.file.selection();
} catch (e) {
  captured = "";
}
const stripFrontmatter = (content) => {
  const match = String(content).match(/^---\n[\s\S]*?\n---\n?/);
  return match ? content.slice(match[0].length) : content;
};
const body = (captured && captured.trim())
  ? captured.trim()
  : stripFrontmatter(tp.file.content || "").trim();

const date = tp.date.now("YYYY-MM-DD");
const timestamp = tp.date.now("YYYY-MM-DDTHH:mm:ssZ");

// Reading notes carry `citekey` (matches content/sources/<key>/ 1:1); web
// clippings carry `source` as the clipped page's URL. Neither is guaranteed —
// an unstructured note just falls back to blank prompts, same as hugo-new.md.
const defaultTitle = fm.title || tp.file.title || "";
const defaultDescription = fm.description || "";
const defaultSourceKey = fm.citekey || "";
const defaultExternalUrl = fm.source || fm.url || "";

const titleInput = await tp.system.prompt("Title", defaultTitle);
const title = (titleInput || "Untitled").trim() || "Untitled";

// The slug rule lives in scripts/newpost.sh and nowhere else. Ask it for the
// default rather than reimplementing it here; whatever the prompt returns is
// slugified by the script when the draft is generated.
let slug = "";
if (kind === "review") {
  const suggested = execFileSync(SCRIPT, [kind, "--batch", "--title", title, "--print-slug"], {
    encoding: "utf8",
    cwd: REPO,
  }).trim();
  slug = (await tp.system.prompt("Slug", suggested)) || suggested;
}

const description = (await tp.system.prompt("Description (optional)", defaultDescription)) || "";
const summary = (await tp.system.prompt("Summary override (optional)")) || "";
const series = (await tp.system.prompt('Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")')) || "";
const tags = (await tp.system.prompt("Tags, comma-separated (optional; reuse existing tags; new tag only if a second post will share it)")) || "";
const eras = (await tp.system.prompt("Eras, comma-separated (optional; a decade like 1970s or a century like 19th Century — reuse existing eras)")) || "";
const sources = (await tp.system.prompt("Source key(s), comma-separated, e.g. mckenziejones2015 (optional)", defaultSourceKey)) || "";
const about = (await tp.system.prompt("About: which source key(s) this piece is centrally about, comma-separated, subset of the above (optional)")) || "";

let externalUrl = "";
if (kind === "review") {
  externalUrl = (await tp.system.prompt("Reviewed work URL (optional)", defaultExternalUrl)) || "";
} else if (kind === "quote") {
  externalUrl = (await tp.system.prompt("External URL for this passage (optional)", defaultExternalUrl)) || "";
}

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

let target, frontMatter;
try {
  // The script resolves collisions against the drafts root, which is this
  // vault, so it lands on the same filename the terminal would have chosen.
  target = run(["--print-target"]).trim();
  frontMatter = run(["--print"]);
} catch (error) {
  fail(`newpost.sh failed: ${error.message}`);
}

const folder = `${DRAFTS_PREFIX}/${section}`;
if (!tp.app.vault.getAbstractFileByPath(folder)) {
  await tp.app.vault.createFolder(folder);
}

// The script's output ends at the `<!-- more -->` marker; the captured note
// body goes after it. That is the only part of the draft this template still
// decides, because it is the only part the script has no way to know about.
const out = `${frontMatter}\n${body}\n`;

const newFile = await tp.app.vault.create(`${DRAFTS_PREFIX}/${target}`, out);
tp.app.workspace.getLeaf(true).openFile(newFile);

tR = "";

-%>
