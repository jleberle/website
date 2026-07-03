<%*
const date = tp.date.now("YYYY-MM-DD");
const timestamp = tp.date.now("YYYY-MM-DDTHH:mm:ssZ");

const titleInput = await tp.system.prompt("Review title");
const title = (titleInput || "Untitled").trim() || "Untitled";
const slug = title.toLowerCase()
  .normalize("NFKD")
  .replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/(^-|-$)/g, "") || "untitled";

const description = (await tp.system.prompt("Description (optional)")) || "";
const summary = (await tp.system.prompt("Summary override (optional)")) || "";
const series = (await tp.system.prompt('Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")')) || "";
const reviewedType = (await tp.system.prompt("Reviewed type, e.g. Book/Film (optional)")) || "";
const reviewedTitle = (await tp.system.prompt("Reviewed work title (optional)")) || "";
const reviewedAuthor = (await tp.system.prompt("Reviewed work author/creator (optional)")) || "";
const reviewedPublisher = (await tp.system.prompt("Reviewed work publisher/studio (optional)")) || "";
const reviewedYear = (await tp.system.prompt("Reviewed work year (optional)")) || "";
const citeKey = (await tp.system.prompt("Cite key, e.g. mckenziejones2015 (optional)")) || "";
const externalUrl = (await tp.system.prompt("Reviewed work URL (optional)")) || "";
const tags = (await tp.system.prompt("Tags, comma-separated (optional)")) || "";
const courses = (await tp.system.prompt("Course links, comma-separated course slugs such as 1493,3793 (optional)")) || "";
const people = (await tp.system.prompt("People links, comma-separated slugs such as theodore-roosevelt,clyde-warrior (optional)")) || "";
const categoriesInput = (await tp.system.prompt("Categories, comma-separated (optional; defaults to Reviews)")) || "";
const categories = categoriesInput.trim() ? categoriesInput : "Reviews";
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

await tp.file.move(`drafts/reviews/${date}-${slug}`);

tR += "---\n";
tR += `title: ${q(title)}\n`;
tR += `slug: ${slug}\n`;
tR += `date: ${q(timestamp)}\n`;
tR += "draft: true\n";
tR += field("description", description);
tR += field("summary", summary);
tR += field("series", series);
tR += field("reviewed_type", reviewedType);
tR += field("reviewed_title", reviewedTitle);
tR += field("reviewed_author", reviewedAuthor);
tR += field("reviewed_publisher", reviewedPublisher);
tR += field("reviewed_year", reviewedYear);
tR += field("cite_key", citeKey);
tR += field("external_url", externalUrl);
tR += listField("courses", courses);
tR += listField("people", people);
tR += listField("categories", categories);
tR += listField("tags", tags);
if (wantsCover) {
  tR += "cover:\n";
  tR += "  image: \"cover.avif\"\n";
  if (coverAlt.trim()) tR += `  alt: ${q(coverAlt)}\n`;
  tR += "  hiddenInList: true\n";
  tR += "  hiddenInSingle: false\n";
  if (coverCaption.trim()) tR += `  caption: ${q(coverCaption)}\n`;
  tR += "  relative: true\n";
}
tR += "---\n\n";
tR += "<!-- more -->\n";
-%>
