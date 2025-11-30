#!/usr/bin/env node
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const axios = require('axios');
const cheerio = require('cheerio');

const STATIONS_JSON = path.join(__dirname, '..', 'data', 'radioindia_stations.json');
const RADIO_JSON = path.join(__dirname, '..', 'data', 'radioindia.json');
const OUT_JSON = path.join(__dirname, '..', 'data', 'radioindia_full.json');
const CATEGORIES_DIR = path.join(__dirname, '..', 'data', 'categories');

function normalizeUrl(href) {
  if (!href) return null;
  href = href.trim();
  if (href.startsWith('//')) return `https:${href}`;
  if (href.startsWith('http://') || href.startsWith('https://')) return href;
  if (href.startsWith('/')) return `https://www.radioindia.in${href}`;
  return href;
}

async function fetchHtml(url) {
  try {
    const res = await axios.get(url, { timeout: 15000, headers: { 'User-Agent': 'Mozilla/5.0 (compatible; Node.js axios)' } });
    return res.data;
  } catch (e) {
    // return null on error
    return null;
  }
}

async function fetchWithRetries(url, attempts = 3, baseDelay = 500, timeout = 30000) {
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const res = await axios.get(url, { timeout, headers: { 'User-Agent': 'Mozilla/5.0 (compatible; Node.js axios)' } });
      return res.data;
    } catch (e) {
      const msg = e && e.message ? e.message : String(e);
      console.error(`fetch error (attempt ${attempt}/${attempts})`, url, msg);
      if (attempt < attempts) await new Promise(r => setTimeout(r, baseDelay * Math.pow(2, attempt - 1)));
    }
  }
  return null;
}

function findCandidateStreamUrls($) {
  const candidates = new Set();

  // look for audio tags
  $('audio source, audio').each((i, el) => {
    const src = $(el).attr('src') || $(el).attr('data-src') || $(el).attr('data');
    if (src) candidates.add(normalizeUrl(src));
  });

  // look for direct links to streams
  $('a[href]').each((i, el) => {
    const href = ($(el).attr('href') || '').trim();
    if (!href) return;
    const low = href.toLowerCase();
    if (low.endsWith('.mp3') || low.endsWith('.m4a') || low.endsWith('.aac') || low.endsWith('.m3u8') || low.includes('stream') || low.includes('audio')) {
      candidates.add(normalizeUrl(href));
    }
  });

  // meta tags
  const metaAudio = $('meta[property="og:audio"], meta[name="og:audio"], meta[property="og:video"], meta[name="og:video"]').attr('content');
  if (metaAudio) candidates.add(normalizeUrl(metaAudio));

  // search scripts for common patterns (simple regex)
  $('script').each((i, el) => {
    const txt = $(el).html() || '';
    // find urls ending with mp3/m3u8
    const m = txt.match(/https?:\/\/[^"'\s]+\.(mp3|m3u8|aac|m4a)/gi);
    if (m) m.forEach(u => candidates.add(u));
    const mm = txt.match(/https?:\/\/[^"'\s]+/gi);
    if (mm) mm.forEach(u => { if (u.includes('stream') || u.includes('audio')) candidates.add(u); });
  });

  return Array.from(candidates).filter(Boolean);
}

async function extractFromStationPage(url) {
  const html = await fetchWithRetries(url, 3, 500, 30000);
  if (!html) return null;
  const $ = cheerio.load(html);

  const title = $('meta[property="og:title"]').attr('content') || $('title').text().trim() || $('h1').first().text().trim();
  const description = $('meta[name="description"]').attr('content') || $('meta[property="og:description"]').attr('content') || $('p').first().text().trim();
  const image = normalizeUrl($('meta[property="og:image"]').attr('content') || $('img').first().attr('src') || $('img').first().attr('data-src'));
  const streams = findCandidateStreamUrls($);

  return { title: title || null, description: description || null, image: image || null, streams };
}

async function run() {
  if (!fsSync.existsSync(STATIONS_JSON)) {
    console.error('Missing stations file:', STATIONS_JSON, '- run category extractor first');
    process.exit(2);
  }

  const stationsSrc = JSON.parse(await fs.readFile(STATIONS_JSON, 'utf8'));
  const stationsList = stationsSrc.stations || stationsSrc.items || [];

  const radioData = fsSync.existsSync(RADIO_JSON) ? JSON.parse(await fs.readFile(RADIO_JSON, 'utf8')) : null;

  const out = [];
  const seen = new Set();

  // if resume is desired, load existing output to skip already-processed
  const resume = process.env.RESUME === 'true' || false;
  if (resume && fsSync.existsSync(OUT_JSON)) {
    try {
      const existing = JSON.parse(await fs.readFile(OUT_JSON, 'utf8'));
      const existingStations = existing.stations || [];
      for (const es of existingStations) {
        const k = (es.playerUrl || es.name || '').toLowerCase();
        if (k) seen.add(k);
        out.push(es);
      }
      console.log('Resuming: loaded', out.length, 'existing stations');
    } catch (e) {
      console.error('Failed to read existing output for resume', e && e.message ? e.message : e);
    }
  }

  // concurrency
  const CONC = 6;
  const queue = stationsList.slice();

  async function worker() {
    while (queue.length) {
      const s = queue.shift();
      const url = normalizeUrl(s.playerUrl || s.url || s.playerUrl);
      if (!url) continue;
      const key = (s.slug || s.name || s.playerUrl || s.playerImage || s.title || '').toLowerCase();
      if (!key) continue;
      if (seen.has(key)) continue;
      seen.add(key);

      console.log('Fetching station:', s.name || s.title || url);
      const details = await extractFromStationPage(url);
      let record = {
        name: s.name || details?.title || s.title || null,
        slug: s.slug || (s.playerUrl ? s.playerUrl.split('/').pop() : null),
        playerUrl: url,
        playerImage: s.playerImage || details?.image || null,
        description: details?.description || null,
        streams: details?.streams || [],
        categories: []
      };

      // try to find categories from radioJSON by matching url or category membership
      if (radioData && Array.isArray(radioData.categories)) {
        for (const c of radioData.categories) {
          if (c && c.url && s.playerUrl && (s.playerUrl.indexOf(c.slug || (c.url.split('/').pop())) !== -1)) {
            record.categories.push(c.slug || c.name);
          }
        }
      }

      out.push(record);
      // polite delay
      await new Promise(r => setTimeout(r, 200));
    }
  }

  // start workers
  const workers = [];
  for (let i = 0; i < CONC; i++) workers.push(worker());
  await Promise.all(workers);

  // write global full JSON
  if (!fsSync.existsSync(path.dirname(OUT_JSON))) await fs.mkdir(path.dirname(OUT_JSON), { recursive: true });
  await fs.writeFile(OUT_JSON, JSON.stringify({ generatedAt: new Date().toISOString(), count: out.length, stations: out }, null, 2), 'utf8');
  console.log(`Wrote ${out.length} stations to ${OUT_JSON}`);

  // write per-category files
  if (!fsSync.existsSync(CATEGORIES_DIR)) await fs.mkdir(CATEGORIES_DIR, { recursive: true });
  const byCat = {};
  out.forEach(s => {
    (s.categories.length ? s.categories : ['uncategorized']).forEach(cat => {
      if (!byCat[cat]) byCat[cat] = [];
      byCat[cat].push(s);
    });
  });
  for (const [cat, list] of Object.entries(byCat)) {
    const fn = path.join(CATEGORIES_DIR, `${cat}.json`);
    await fs.writeFile(fn, JSON.stringify({ generatedAt: new Date().toISOString(), category: cat, count: list.length, stations: list }, null, 2), 'utf8');
    console.log(`Wrote ${list.length} stations to ${fn}`);
  }
}

if (require.main === module) run().catch(e => { console.error(e); process.exit(1); });
