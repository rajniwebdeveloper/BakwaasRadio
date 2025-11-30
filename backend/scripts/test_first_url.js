#!/usr/bin/env node
const fs = require('fs').promises;
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');

// Try common locations for the saved HTML
const CANDIDATES = [
  path.join(__dirname, '..', 'output.html'),
  path.join(__dirname, '..', 'lib', 'output.html'),
  path.join(__dirname, '..', 'lib', 'output.htm')
];

let OUT = CANDIDATES.find(p => {
  try { return require('fs').existsSync(p); } catch (e) { return false; }
});

if (!OUT) {
  // default to backend/output.html (will error later if missing)
  OUT = path.join(__dirname, '..', 'output.html');
}

async function findFirstUrl(html) {
  const $ = cheerio.load(html);

  // Prefer explicit radio list anchors
  let a = $('#radio_list_ul_1 a, .mdc-grid-list__tiles a').first();
  let href = a.attr('href') || a.attr('data-href') || a.attr('data-url') || '';

  if (!href) {
    // fallback: look for first /radio/ link anywhere
    const fallback = $('a[href*="/radio/"]').first();
    href = fallback.attr('href') || '';
  }

  if (!href) return null;
  return href.startsWith('http') ? href : `https://www.radioindia.in${href}`;
}

async function main() {
  try {
    const html = await fs.readFile(OUT, 'utf8');
    const url = await findFirstUrl(html);
    if (!url) {
      console.error('No station URL found in', OUT);
      process.exit(2);
    }

    console.log('Testing URL:', url);

    // Use HEAD first, fall back to GET if HEAD not allowed
    let res;
    try {
      res = await axios.head(url, { timeout: 10000, maxRedirects: 5, validateStatus: () => true });
    } catch (headErr) {
      // fallback to GET
      res = await axios.get(url, { timeout: 10000, maxRedirects: 5, validateStatus: () => true });
    }

    const status = res && res.status ? res.status : null;
    if (status && status >= 200 && status < 400) {
      console.log(`OK - ${status}`);
      process.exit(0);
    } else if (status) {
      console.error(`FAIL - HTTP ${status}`);
      process.exit(3);
    } else {
      console.error('FAIL - No HTTP status received');
      process.exit(1);
    }
  } catch (e) {
    console.error('Error running test:', e && e.message ? e.message : e);
    process.exit(1);
  }
}

main();
