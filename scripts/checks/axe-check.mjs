#!/usr/bin/env node
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
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
  const relative = decoded === '/' ? 'index.html' : decoded.replace(/^\/+/, '');
  const candidate = normalize(join(root, relative));
  if (!(candidate === root || candidate.startsWith(root + sep))) return null;
  if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  const index = join(candidate, 'index.html');
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

const server = createServer((req, res) => {
  const file = resolveRequest(req.url || '/');
  if (!file) {
    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }
  res.writeHead(200, { 'content-type': mimeTypes.get(extname(file)) || 'application/octet-stream' });
  createReadStream(file).pipe(res);
});

await new Promise((resolveServer) => server.listen(0, '127.0.0.1', resolveServer));
const { port } = server.address();
const baseURL = `http://127.0.0.1:${port}`;

let failures = 0;
const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();

try {
  for (const pagePath of pages) {
    const url = `${baseURL}${pagePath}`;
    const response = await page.goto(url, { waitUntil: 'networkidle' });
    if (!response || !response.ok()) {
      failures += 1;
      console.error(`\naxe target failed to load: ${pagePath} (${response?.status() ?? 'no response'})`);
      continue;
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
