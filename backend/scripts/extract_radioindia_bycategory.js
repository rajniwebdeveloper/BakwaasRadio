#!/usr/bin/env node
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');

const DATA_JSON = path.join(__dirname, '..', 'data', 'radioindia.json');
const OUT_JSON = path.join(__dirname, '..', 'data', 'radioindia_stations.json');

function normalizeUrl(href) {
  if (!href) return null;
  href = href.trim();
  if (href.startsWith('//')) return `https:${href}`;
  if (href.startsWith('http://') || href.startsWith('https://')) return href;
  if (href.startsWith('/')) return `https://www.radioindia.in${href}`;
  return href;
}

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function fetchWithRetries(url, attempts = 3, baseDelay = 500, timeout = 30000) {
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const res = await axios.get(url, { timeout, headers: { 'User-Agent': 'Mozilla/5.0 (compatible; Node.js axios)' } });
      return res.data;
    } catch (e) {
      const msg = e && e.message ? e.message : String(e);
      console.error(`fetch error (attempt ${attempt}/${attempts})`, url, msg);
      if (attempt < attempts) {
        await sleep(baseDelay * Math.pow(2, attempt - 1));
      }
    }
  }
  return null;
}

async function extractStationsFromHtml(html, categoryName, categorySlug) {
  const $ = cheerio.load(html);
  const stations = [];
  const listSelectors = ['#radio_list_ul_1 li', '#radio_list_ul_2 li', '.mdc-grid-list__tiles li', '.mdc-grid-tile'];

  $(listSelectors.join(', ')).each((i, el) => {
    const $el = $(el);
    const a = $el.find('a').first();
    if (!a || a.length === 0) return;
    const href = (a.attr('href') || a.attr('data-href') || a.attr('data-url') || '').trim();
    const url = normalizeUrl(href);
    let title = a.find('.mdc-grid-tile__title, h3, .title').first().text().trim();
    if (!title) title = a.attr('title') || a.text().trim();
    const img = normalizeUrl($el.find('img').first().attr('data-src') || $el.find('img').first().attr('src') || '');
    // create record
    if (!title && !url) return;
    stations.push({ name: title || null, playerUrl: url || null, playerImage: img || null, categories: categorySlug ? [categorySlug] : [categoryName || null] });
  });

  return stations;
}

async function main() {
  try {
    if (!fsSync.existsSync(DATA_JSON)) {
      console.error('Missing', DATA_JSON, '- run the extractor first to generate categories');
      process.exit(2);
    }

    const src = JSON.parse(await fs.readFile(DATA_JSON, 'utf8'));
    const categories = src.categories || [];
    if (!Array.isArray(categories) || categories.length === 0) {
      console.error('No categories found in', DATA_JSON);
      process.exit(2);
    }

    // Clean output file first
    if (fsSync.existsSync(OUT_JSON)) await fs.unlink(OUT_JSON);

    const seen = new Set();
    const results = [];

    const map = {}; // key -> station record (merge categories)
    for (let i = 0; i < categories.length; i++) {
      const cat = categories[i];
      const catUrl = normalizeUrl(cat.url);
      const catSlug = (cat.slug || (cat.url || '').split('/').pop() || (cat.name || '').toLowerCase().replace(/\s+/g, '-'));
      if (!catUrl) continue;
      console.log(`Fetching category ${i+1}/${categories.length}: ${cat.name} -> ${catUrl}`);
      const html = await fetchWithRetries(catUrl, 4, 500, 30000);
      if (!html) {
        console.error('Failed to fetch category', catUrl);
        await sleep(500);
        continue;
      }

      const stations = await extractStationsFromHtml(html, cat.name, catSlug);
      for (const s of stations) {
        const key = (s.playerUrl || s.name || '').toLowerCase();
        if (!key) continue;
        if (!map[key]) {
          map[key] = s;
        } else {
          // merge categories
          const existing = map[key];
          const cats = new Set(existing.categories || []);
          (s.categories || []).forEach(c => { if (c) cats.add(c); });
          existing.categories = Array.from(cats);
        }
      }

      // polite delay
      await sleep(300);
    }

    // collect results
    for (const rec of Object.values(map)) results.push(rec);

    // write output
    const outObj = { generatedAt: new Date().toISOString(), count: results.length, stations: results };
    if (!fsSync.existsSync(path.dirname(OUT_JSON))) await fs.mkdir(path.dirname(OUT_JSON), { recursive: true });
    await fs.writeFile(OUT_JSON, JSON.stringify(outObj, null, 2), 'utf8');
    console.log(`Wrote ${results.length} unique stations to ${OUT_JSON}`);
    process.exit(0);
  } catch (e) {
    console.error('extract_bycategory error', e && e.message ? e.message : e);
    process.exit(1);
  }
}

if (require.main === module) main();
