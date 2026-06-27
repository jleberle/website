<%*
const date = tp.date.now("YYYY-MM-DD");
const timestamp = tp.date.now("YYYY-MM-DDTHH:mm:ssZ");

const titleInput = await tp.system.prompt("Quote title");
const title = (titleInput || "Untitled").trim() || "Untitled";
const slug = title.toLowerCase()
  .normalize("NFKD")
  .replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/(^-|-$)/g, "") || "untitled";

const description = (await tp.system.prompt("Description (optional)")) || "";
const summary = (await tp.system.prompt("Summary override (optional)")) || "";
const series = (await tp.system.prompt('Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")')) || "";
const sourceTitle = (await tp.system.prompt("Source title (optional)")) || "";
const sourceAuthor = (await tp.system.prompt("Source author (optional)")) || "";
const sourceYear = (await tp.system.prompt("Source year (optional)")) || "";
const tags = (await tp.system.prompt("Tags, comma-separated (optional)")) || "";
const categories = (await tp.system.prompt("Categories, comma-separated (optional)")) || "";
const externalUrl = (await tp.system.prompt("External URL (optional)")) || "";

const q = (value) => JSON.stringify(String(value).trim());
const field = (key, value) => String(value).trim() ? `${key}: ${q(value)}\n` : "";
const listField = (key, value) => {
  const items = String(value).split(",").map((item) => item.trim()).filter(Boolean);
  if (!items.length) return "";
  return `${key}:\n${items.map((item) => `- ${q(item)}`).join("\n")}\n`;
};

await tp.file.move(`drafts/quotes/${date}-${slug}`);

tR += "---\n";
tR += `title: ${q(title)}\n`;
tR += `slug: ${slug}\n`;
tR += `date: ${q(timestamp)}\n`;
tR += "draft: true\n";
tR += field("description", description);
tR += field("summary", summary);
tR += field("series", series);
tR += field("source_title", sourceTitle);
tR += field("source_author", sourceAuthor);
tR += field("source_year", sourceYear);
tR += field("external_url", externalUrl);
tR += listField("categories", categories);
tR += listField("tags", tags);
tR += "---\n\n";
tR += "<!-- more -->\n";
-%>
