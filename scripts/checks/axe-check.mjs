#!/usr/bin/env node
import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, isAbsolute, join, relative, resolve } from 'node:path';
import AxeBuilder from '@axe-core/playwright';
import { chromium } from 'playwright';

const root = resolve(process.argv[2] || 'public');
const pages = [
  '/',
  '/articles/dennis-banks-fbi-file/',
  '/reviews/warrior-mckenzie-jones/',
  '/quotes/even-the-entertainment-was-traumatic/',
  '/courses/1493/',
  '/archives/',
  '/reading/',
  '/reading/2024/',
  '/sources/',
  '/sources/mckenziejones2015/',
  '/cv/',
  '/about/',
];

const mimeTypes = new Map([
  ['.avif', 'image/avif'],
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.jpg', 'image/jpeg'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.pdf', 'application/pdf'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.txt', 'text/plain; charset=utf-8'],
  ['.webmanifest', 'application/manifest+json; charset=utf-8'],
  ['.woff2', 'font/woff2'],
  ['.xml', 'application/xml; charset=utf-8'],
]);

function resolveRequest(urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0]);
  const relativePath = decoded === '/' ? 'index.html' : decoded.replace(/^\/+/, '');
  const candidate = resolve(root, relativePath);
  const candidateRel = relative(root, candidate);
  if (candidateRel.startsWith('..') || isAbsolute(candidateRel)) return null;
  if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  const index = join(candidate, 'index.html');
  const indexRel = relative(root, index);
  if (indexRel.startsWith('..') || isAbsolute(indexRel)) return null;
  if (existsSync(index) && statSync(index).isFile()) return index;
  return null;
}

const missingPages = [];
for (const pagePath of pages) {
  if (!resolveRequest(pagePath)) missingPages.push(pagePath);
}

if (missingPages.length > 0) {
  console.error('Axe target pages are missing from public/:');
  for (const pagePath of missingPages) {
    console.error(`  ${pagePath}`);
  }
  console.error('Build the site successfully before running axe, e.g. hugo --minify or scripts/preflight.sh --full.');
  process.exit(1);
}

// Serve public/_headers the way Cloudflare does: every block whose path
// pattern matches the request contributes its headers, later blocks winning.
// This is what makes the browser below enforce the real CSP and Trusted Types
// and fetch the Speculation-Rules set. A server that sends only content-type
// (as this one once did) lets a CSP violation through CI unseen.
function loadHeaderRules(file) {
  if (!existsSync(file)) return [];
  const rules = [];
  let current = null;
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    if (!line.trim() || line.trim().startsWith('#')) continue;
    if (!/^\s/.test(line)) {
      const source = line.trim().replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
      current = { pattern: new RegExp(`^${source}$`), headers: [] };
      rules.push(current);
    } else if (current) {
      const colon = line.indexOf(':');
      if (colon > 0) current.headers.push([line.slice(0, colon).trim().toLowerCase(), line.slice(colon + 1).trim()]);
    }
  }
  return rules;
}
const headerRules = loadHeaderRules(join(root, '_headers'));
if (headerRules.length === 0) {
  console.error('public/_headers is missing or empty; cannot check pages under the production CSP.');
  process.exit(1);
}

function responseHeaders(urlPath, file) {
  const headers = { 'content-type': mimeTypes.get(extname(file)) || 'application/octet-stream' };
  for (const rule of headerRules) {
    if (!rule.pattern.test(urlPath)) continue;
    for (const [name, value] of rule.headers) headers[name] = value;
  }
  return headers;
}

const server = createServer((req, res) => {
  const file = resolveRequest(req.url || '/');
  const fileRel = file && relative(root, file);
  if (!file || fileRel.startsWith('..') || isAbsolute(fileRel)) {
    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }
  res.writeHead(200, responseHeaders(decodeURIComponent((req.url || '/').split('?')[0]), file));
  createReadStream(file).pipe(res);
});

await new Promise((resolveServer) => server.listen(0, '127.0.0.1', resolveServer));
const { port } = server.address();
const baseURL = `http://127.0.0.1:${port}`;

let failures = 0;
const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();

// Chromium reports every speculation rule set it loads, with any parse or
// fetch error, through the DevTools Preload domain. Prerendering otherwise
// fails silently (b0afe31 shipped a rule set no browser ever loaded).
const cdp = await context.newCDPSession(page);
const ruleSets = [];
cdp.on('Preload.ruleSetUpdated', ({ ruleSet }) => ruleSets.push(ruleSet));
await cdp.send('Preload.enable');

// A CSP or Trusted Types violation doesn't fail page load or necessarily
// register as an axe rule — it just logs. Catching it here is the only
// automated net for a future regression like a reintroduced innerHTML write.
let pageErrors = [];
page.on('console', (msg) => {
  if (msg.type() === 'error') pageErrors.push(msg.text());
});
page.on('pageerror', (err) => {
  pageErrors.push(String(err));
});

try {
  for (const pagePath of pages) {
    pageErrors = [];
    const url = `${baseURL}${pagePath}`;
    const response = await page.goto(url, { waitUntil: 'networkidle' });
    if (!response || !response.ok()) {
      failures += 1;
      console.error(`\naxe target failed to load: ${pagePath} (${response?.status() ?? 'no response'})`);
      continue;
    }
    if (pageErrors.length > 0) {
      failures += pageErrors.length;
      console.error(`\nconsole/page errors on ${pagePath}:`);
      for (const err of pageErrors) {
        console.error(`- ${err}`);
      }
    }
    const result = await new AxeBuilder({ page }).analyze();
    if (result.violations.length === 0) {
      console.log(`axe clean: ${pagePath}`);
      continue;
    }

    failures += result.violations.length;
    console.error(`\naxe violations on ${pagePath}:`);
    for (const violation of result.violations) {
      console.error(`- ${violation.id}: ${violation.help}`);
      for (const node of violation.nodes.slice(0, 5)) {
        console.error(`  target: ${node.target.join(', ')}`);
        console.error(`  ${node.failureSummary?.replace(/\s+/g, ' ').trim() || 'No failure summary'}`);
      }
      if (violation.nodes.length > 5) {
        console.error(`  ...and ${violation.nodes.length - 5} more node(s)`);
      }
    }
  }

  if (ruleSets.length === 0) {
    failures += 1;
    console.error('\nspeculation rules: no rule set loaded (check the Speculation-Rules header and /speculationrules.json).');
  } else {
    for (const set of ruleSets.filter((s) => s.errorType)) {
      failures += 1;
      console.error(`\nspeculation rules: ${set.errorType}: ${set.errorMessage ?? ''} (${set.url ?? 'inline'})`);
    }
    if (!ruleSets.some((s) => s.errorType)) console.log(`speculation rules: ${ruleSets.length} load(s), no errors`);
  }
} finally {
  await context.close();
  await browser.close();
  server.close();
}

if (failures > 0) {
  console.error(`\naxe failed with ${failures} violation group(s).`);
  process.exit(1);
}

console.log('\naxe checks passed.');
