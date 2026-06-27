<%*
const date = tp.date.now("YYYY-MM-DD");
const timestamp = tp.date.now("YYYY-MM-DDTHH:mm:ssZ");

const titleInput = await tp.system.prompt("Post title");
const title = (titleInput || "Untitled").trim() || "Untitled";
const slug = title.toLowerCase()
  .normalize("NFKD")
  .replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/(^-|-$)/g, "") || "untitled";

const description = (await tp.system.prompt("Description (optional)")) || "";
const summary = (await tp.system.prompt("Summary override (optional)")) || "";
const series = (await tp.system.prompt('Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")')) || "";
const tags = (await tp.system.prompt("Tags, comma-separated (optional)")) || "";
const categories = (await tp.system.prompt("Categories, comma-separated (optional)")) || "";
const wantsCover = /^y(es)?$/i.test(((await tp.system.prompt("Add cover metadata? yes/no")) || "").trim());
const coverAlt = wantsCover ? ((await tp.system.prompt("Cover alt text (optional)")) || "") : "";
const coverCaption = wantsCover ? ((await tp.system.prompt("Cover caption (optional)")) || "") : "";

const q = (value) => JSON.stringify(String(value).trim());
const field = (key, value) => String(value).trim() ? `${key}: ${q(value)}\n` : "";
const listField = (key, value) => {
  const items = String(value).split(",").map((item) => item.trim()).filter(Boolean);
  if (!items.length) return "";
  return `${key}:\n${items.map((item) => `- ${q(item)}`).join("\n")}\n`;
};

await tp.file.move(`drafts/articles/${date}-${slug}`);

tR += "---\n";
tR += `title: ${q(title)}\n`;
tR += `slug: ${slug}\n`;
tR += `date: ${q(timestamp)}\n`;
tR += "draft: true\n";
tR += field("description", description);
tR += field("summary", summary);
tR += field("series", series);
tR += listField("categories", categories);
tR += listField("tags", tags);
if (wantsCover) {
  tR += "cover:\n";
  tR += "  image: \"cover.avif\"\n";
  if (coverAlt.trim()) tR += `  alt: ${q(coverAlt)}\n`;
  tR += "  hiddenInList: false\n";
  tR += "  hiddenInSingle: false\n";
  if (coverCaption.trim()) tR += `  caption: ${q(coverCaption)}\n`;
  tR += "  relative: true\n";
}
tR += "---\n\n";
tR += "<!-- more -->\n";
-%>
