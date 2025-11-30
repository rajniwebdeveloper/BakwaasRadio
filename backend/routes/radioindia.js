const express = require('express');
const router = express.Router();
const fs = require('fs').promises;
const path = require('path');
const cheerio = require('cheerio');

const OUTPUT_HTML = path.join(__dirname, '..', 'output.html');

// In-memory cache to avoid re-parsing on every request (simple TTL)
let _cache = { ts: 0, data: null };
const CACHE_TTL_MS = 60 * 1000; // 1 minute

async function parsePage() {
  const now = Date.now();
  if (_cache.data && (now - _cache.ts) < CACHE_TTL_MS) return _cache.data;

  const html = await fs.readFile(OUTPUT_HTML, 'utf8');
  const $ = cheerio.load(html);

  // Try to parse JSON-LD ItemList first (more reliable)
  let itemList = [];
  $('script[type="application/ld+json"]').each((i, el) => {
    try {
      const txt = $(el).contents().text();
      if (!txt) return;
      const parsed = JSON.parse(txt);
      const arr = Array.isArray(parsed) ? parsed : [parsed];
      for (const obj of arr) {
        if (obj && (obj['@type'] === 'ItemList' || obj['@type'] === 'RadioStation' || obj.itemListElement)) {
          if (obj.itemListElement && Array.isArray(obj.itemListElement)) {
            itemList = obj.itemListElement.map((it) => {
              if (it && it.url) return { position: it.position || null, url: it.url };
              if (it && it['@type'] === 'ListItem' && it.item && it.item['@id']) return { position: it.position || null, url: it.item['@id'] };
              return null;
            }).filter(Boolean);
            break;
          }
        }
      }
    } catch (e) {
      // ignore JSON parse errors
    }
  });

  // Selector for station tiles
  const candidates = $('#radio_list_ul_1 li, .mdc-grid-list__tiles li');

  // Build a quick lookup of anchors by normalized href (pathname)
  const anchors = {};
  $('a').each((i, ael) => {
    const a = $(ael);
    const href = a.attr('href');
    if (!href) return;
    // Normalize: remove domain if present
    try {
      const urlObj = new URL(href, 'https://www.radioindia.in');
      const pathname = urlObj.pathname.replace(/\/+$/, '');
      anchors[pathname] = anchors[pathname] || [];
      anchors[pathname].push(ael);
    } catch (e) {
      // ignore
    }
  });

  const stations = [];

  // If JSON-LD itemList available, use that as ordering
  if (itemList.length > 0) {
    itemList.forEach((it, idx) => {
      let url = it.url;
      try {
        const u = new URL(url);
        const pathname = u.pathname.replace(/\/+$/, '');
        const matches = anchors[pathname] || [];
        let title = null, image = null, description = null, href = pathname;
        if (matches.length > 0) {
          const ael = matches[0];
          const $a = $(ael);
          title = $a.attr('title') || $a.find('h3').text().trim() || $a.find('.title').text().trim() || $a.text().trim();
          image = $a.find('img').attr('data-src') || $a.find('img').attr('src') || null;
          description = $a.closest('li').find('p').first().text().trim() || null;
        }
        stations.push({ position: it.position || (idx + 1), title: title || null, href: href, url, image: image || null, description });
      } catch (e) {
        // fallback
      }
    });
  } else {
    // Fallback: iterate candidate list items
    candidates.each((i, el) => {
      const $el = $(el);
      const a = $el.find('a').first();
      const href = a.attr('href') || '';
      let url = null;
      try { url = new URL(href, 'https://www.radioindia.in').toString(); } catch (e) { url = href; }
      const title = a.find('h3').text().trim() || a.find('.title').text().trim() || a.attr('title') || a.text().trim();
      const image = a.find('img').attr('data-src') || a.find('img').attr('src') || null;
      const desc = $el.find('p').first().text().trim() || null;
      if (!title && !href && !image) return;
      const pathname = (() => { try { return new URL(href, 'https://www.radioindia.in').pathname.replace(/\/+$/, ''); } catch (e) { return href; } })();
      stations.push({ position: stations.length + 1, title: title || null, href: pathname, url, image, description: desc });
    });
  }

  const out = { count: stations.length, stations };
  _cache = { ts: now, data: out };
  return out;
}

// Serve raw saved HTML
router.get('/raw', async (req, res) => {
  try {
    return res.sendFile(OUTPUT_HTML);
  } catch (e) {
    console.error('radioindia/raw error', e.message);
    return res.status(500).json({ error: e.message });
  }
});

// List stations (uses JSON-LD if present)
router.get('/stations', async (req, res) => {
  try {
    const parsed = await parsePage();
    return res.json(parsed);
  } catch (e) {
    console.error('radioindia/stations error', e.message);
    return res.status(500).json({ error: e.message });
  }
});

// Find stations by query (slug or title substring)
router.get('/stations/find', async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (!q) return res.status(400).json({ error: 'Missing query param `q`' });
    const parsed = await parsePage();
    const results = parsed.stations.filter(s => {
      if (!s) return false;
      const slug = s.href || '';
      const title = (s.title || '').toString();
      return slug.includes(q) || title.toLowerCase().includes(q.toLowerCase());
    });
    return res.json({ query: q, count: results.length, results });
  } catch (e) {
    console.error('radioindia/stations/find error', e.message);
    return res.status(500).json({ error: e.message });
  }
});

// Get station by slug (exact match) or by last path segment
router.get('/stations/:slug', async (req, res) => {
  try {
    const slug = req.params.slug;
    const parsed = await parsePage();
    // match exact slug or ending segment
    const found = parsed.stations.find(s => {
      if (!s) return false;
      const href = (s.href || '').replace(/^\//, '');
      const last = href.split('/').filter(Boolean).pop();
      return href === slug || last === slug;
    });
    if (!found) return res.status(404).json({ error: 'Station not found' });
    return res.json(found);
  } catch (e) {
    console.error('radioindia/stations/:slug error', e.message);
    return res.status(500).json({ error: e.message });
  }
});

module.exports = router;
