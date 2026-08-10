<%*
// Insert a Works Cited list (or just show the citation keys used) for the
// active draft, via scripts/cite-refs.sh. Run via "Templater: Insert
// Templater to the current active file" while sitting IN the draft you are
// writing — unlike hugo-source-from-note.md and hugo-draft-from-note.md,
// this one DOES insert into the active file; that is the point.
//
// Unlike newsource.sh, cite-refs.sh only reads (the draft body plus the
// Zotero-exported bibliography) and never writes anything, so there is no
// external side effect to gate behind a manual terminal review the way the
// source-lookup template does — worst case here is an insert you undo with
// Cmd+Z, same as any other edit. That is why this shells out and acts on the
// result directly instead of only prepping a command.
//
// Desktop only (uses child_process, unavailable on mobile Templater).
const REPO_PATH = "/Users/jaredeberle/git/website";

const { execFile } = require("child_process");
const path = require("path");

const scriptPath = path.join(REPO_PATH, "scripts", "cite-refs.sh");
const activeFilePath = tp.file.path();

const mode = await tp.system.suggester(
  ["Works Cited list (insert at cursor)", "List citation keys used (just show them)"],
  ["bibliography", "keys"],
  true,
  "cite-refs.sh — what do you want?"
);

// Obsidian is often launched by the GUI, not a shell, so it may not inherit
// Homebrew's PATH — cite-refs.sh shells out to python3 and pandoc, both
// installed there. Prepend explicitly rather than trust inherited PATH.
const env = Object.assign({}, process.env, {
  PATH: ["/opt/homebrew/bin", "/usr/local/bin", process.env.PATH || ""].join(":"),
});

const flag = mode === "bibliography" ? "--bibliography" : "--keys";

let output = "";
let failure = "";
try {
  output = await new Promise((resolve, reject) => {
    execFile(scriptPath, [flag, activeFilePath], { cwd: REPO_PATH, env }, (err, stdout, stderr) => {
      if (err) reject(new Error((stderr || err.message || "").trim()));
      else resolve(stdout);
    });
  });
} catch (e) {
  failure = e.message || String(e);
}

if (failure) {
  new Notice(`cite-refs.sh failed:\n${failure}`);
  tR = "";
} else if (mode === "keys") {
  const keys = output.trim();
  new Notice(keys ? `Citation keys used:\n${keys}` : "No citation keys found in this draft.");
  tR = "";
} else {
  const bib = output.trim();
  if (!bib) {
    new Notice("No citation keys found in this draft — nothing to render.");
    tR = "";
  } else {
    tR = `\n## Works Cited\n\n${bib}\n`;
  }
}

-%>
