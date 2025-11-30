#!/usr/bin/env node
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const cheerio = require('cheerio');

// Candidate locations for saved HTML
const CANDIDATES = [
  path.join(__dirname, '..', 'output.html'),
  path.join(__dirname, '..', 'lib', 'output.html')
];

let OUT_HTML = CANDIDATES.find(p => fsSync.existsSync(p));
if (!OUT_HTML) OUT_HTML = CANDIDATES[0];

const DATA_DIR = path.join(__dirname, '..', 'data');
const OUT_JSON = path.join(DATA_DIR, 'radioindia.json');

function normalizeUrl(href) {
  if (!href) return null;
  href = href.trim();
  if (href.startsWith('//')) return `https:${href}`;
  if (href.startsWith('http://') || href.startsWith('https://')) return href;
  if (href.startsWith('/')) return `https://www.radioindia.in${href}`;
  return href;
}

async function extract() {
  try {
    const html = await fs.readFile(OUT_HTML, 'utf8');
    const $ = cheerio.load(html);

    const items = [];
    const urlsSet = new Set();

    // Select list items that likely contain stations
    const listSelectors = ['#radio_list_ul_1 li', '#radio_list_ul_2 li', '.mdc-grid-list__tiles li', '.radio-tile', '.tile'];

    let seen = new Set();

    $(listSelectors.join(', ')).each((i, el) => {
      const $el = $(el);
      const a = $el.find('a').first();
      const href = (a.attr('href') || a.attr('data-href') || a.attr('data-url') || '').trim();
      const url = normalizeUrl(href);

      if (url) urlsSet.add(url);

      // Title heuristics
      let title = a.find('.title, h3, .mdc-typography--subtitle1, .mdc-grid-tile__title').first().text().trim();
      if (!title) title = a.attr('title') || $el.find('h3').first().text().trim() || a.text().trim();

      // Image heuristics
      const imgTag = $el.find('img').first();
      let img = imgTag.attr('src') || imgTag.attr('data-src') || imgTag.attr('data-lazy') || '';
      img = normalizeUrl(img);
      if (img) urlsSet.add(img);

      // slug from href
      let slug = null;
      if (href) {
        const m = href.match(/\/([^\/?#]+)(?:[\/?#]|$)/);
        if (m && m[1]) slug = m[1];
      }

      // Avoid duplicates by url or slug
      const uniqueKey = url || slug || title;
      if (!uniqueKey) return;
      if (seen.has(uniqueKey)) return;
      seen.add(uniqueKey);

      items.push({
        position: items.length + 1,
        title: title || null,
        slug: slug || null,
        playerUrl: url || null,
        playerImage: img || null
      });
    });

    // Extract categories and filters (genres / locations)
    const categories = [];
    const locations = [];
    const categorySet = new Set();
    const locationSet = new Set();

    // Genre filters often live in collapse_1 and collapse_2
    $('#collapse_1 a, #collapse_2 a, .filter-column a, .radio-filter-button, .mdc-button--primary a').each((i, el) => {
      const $a = $(el);
      const href = ($a.attr('href') || '').trim();
      const text = $a.text().trim();
      const url = normalizeUrl(href);
      if (!href) return;
      if (href.startsWith('/radio/')) {
        if (!categorySet.has(url)) {
          categorySet.add(url);
          categories.push({ name: text || url.split('/').pop(), url });
          urlsSet.add(url);
        }
      } else if (href.startsWith('/')) {
        if (!locationSet.has(url)) {
          locationSet.add(url);
          locations.push({ name: text || url.split('/').pop(), url });
          urlsSet.add(url);
        }
      }
    });

    // Fallback: collect all radio-related links across page and include in urls set
    $('a[href]').each((i, el) => {
      const href = ($(el).attr('href') || '').trim();
      if (!href) return;
      if (href.startsWith('mailto:') || href.startsWith('javascript:')) return;
      const url = normalizeUrl(href);
      if (url) urlsSet.add(url);
    });

    // Fallback: if no items found, try to extract from JSON-LD
    if (items.length === 0) {
      const ld = $('script[type="application/ld+json"]').first().html();
      if (ld) {
        try {
          const data = JSON.parse(ld);
          if (Array.isArray(data)) {
            data.forEach(d => {
              if (d['@type'] === 'ListItem' && d.url) {
                const url = normalizeUrl(d.url);
                const slug = url.split('/').pop();
                items.push({ position: items.length + 1, title: d.name || null, slug, playerUrl: url, playerImage: null });
                urlsSet.add(url);
              }
            });
          }
        } catch (e) {
          // ignore json-ld parse errors
        }
      }
    }

    // Ensure data dir exists
    if (!fsSync.existsSync(DATA_DIR)) {
      await fs.mkdir(DATA_DIR, { recursive: true });
    }

    const allUrls = Array.from(urlsSet).sort();
    const outObj = {
      generatedAt: new Date().toISOString(),
      counts: { stations: items.length, categories: categories.length, locations: locations.length, urls: allUrls.length },
      items,
      categories,
      locations,
      urls: allUrls
    };

    await fs.writeFile(OUT_JSON, JSON.stringify(outObj, null, 2), 'utf8');
    console.log(`Wrote ${items.length} stations, ${categories.length} categories, ${locations.length} locations, ${allUrls.length} unique URLs to ${OUT_JSON}`);
    return 0;
  } catch (e) {
    console.error('extract error', e && e.message ? e.message : e);
    return 1;
  }
}

if (require.main === module) {
  extract().then(code => process.exit(code));
}
