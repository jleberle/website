<%*
// Prep a `newsource.sh zotero` run for the active reading note — run via
// "Templater: Insert Templater to the current active file" while sitting IN
// the reading note (not "Create new note from template"), same trigger shape
// as hugo-draft-from-note.md.
//
// This does NOT write content/sources/ itself. newsource.sh's zotero path is
// interactive by design — every field, even the ones Zotero prefills, still
// goes through a confirm-or-override prompt ("a prefill, never a
// requirement", scripts/newsource.sh). Automating past that review would
// defeat the point of the script, so this only removes the friction of
// getting to a terminal in the right place with the right command: it reads
// `citekey` from the note's frontmatter (set on every reading note by the
// Zotero connector), copies `scripts/newsource.sh zotero "<citekey>"` to the
// clipboard, and opens a lean-terminal tab already cd'd into the website
// repo via its obsidian://lean-terminal?cwd= URI. Paste, enter, and the
// review step is exactly what running it by hand looks like today.
const REPO_PATH = "/Users/jaredeberle/git/website";

const fm = tp.frontmatter || {};
const citekey = (fm.citekey || "").trim();

if (!citekey) {
  new Notice("This note has no `citekey` in its frontmatter — nothing to look up in Zotero.");
} else {
  const command = `scripts/newsource.sh zotero "${citekey}"`;
  await navigator.clipboard.writeText(command);

  const uri = `obsidian://lean-terminal?cwd=${encodeURIComponent(REPO_PATH)}`;
  window.open(uri);

  new Notice(`Copied to clipboard: ${command}\nPaste into the terminal tab that just opened.`);
}

tR = "";

-%>
