#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const Station = require('../models/Station');

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&');
}

function logLine(action, name, url, extra) {
  const time = new Date().toISOString();
  const parts = [`[${time}]`, action];
  if (name) parts.push(`name="${name}"`);
  if (url) parts.push(`url="${url}"`);
  if (extra) parts.push(extra);
  console.log(parts.join(' | '));
}

function normalizeUrl(u) {
  if (!u) return '';
  try {
    const urlObj = new URL(u);
    // remove trailing slashes from pathname but keep single leading slash
    const pathname = urlObj.pathname.replace(/\/+$/g, '');
    return urlObj.origin + pathname;
  } catch (e) {
    // fallback: strip query and trailing slashes
    return u.toString().replace(/\?.*$/, '').replace(/\/+$/g, '');
  }
}

async function main() {
  const apply = process.argv.includes('--apply');
  const dataPath = path.resolve(__dirname, '..', 'data', 'radioindia_full_with_streams.json');
  if (!fs.existsSync(dataPath)) {
    console.error('Data file not found:', dataPath);
    process.exit(1);
  }

  const raw = fs.readFileSync(dataPath, 'utf8');
  let json;
  try {
    json = JSON.parse(raw);
  } catch (err) {
    console.error('Failed to parse JSON:', err.message);
    process.exit(1);
  }

  const stations = Array.isArray(json.stations) ? json.stations : [];

  const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URL || 'mongodb://BakwaasFM:BakwaasFM@65.21.22.62:27017/bakwaasfm';
  console.log('Connecting to MongoDB at', mongoUri);

  await mongoose.connect(mongoUri, { useNewUrlParser: true, useUnifiedTopology: true });

  // Detect replace flag early
  const replaceAll = process.argv.includes('--replace');

  // Backup existing stations collection
  const backupDir = path.resolve(__dirname, '..', 'backups');
  if (!fs.existsSync(backupDir)) fs.mkdirSync(backupDir, { recursive: true });
  const existing = await Station.find({}).lean();
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFile = path.join(backupDir, `stations_backup_${timestamp}.json`);
  fs.writeFileSync(backupFile, JSON.stringify(existing, null, 2));
  console.log(`Backed up ${existing.length} stations to ${backupFile}`);

  const toCreate = [];
  const skipped = { duplicates: 0, no_stream: 0, js_urls: 0 };

  // If replaceAll requested, delete existing docs after backup and before duplicate checks
  if (replaceAll) {
    try {
      const delRes = await Station.deleteMany({});
      console.log(`Replaced mode: deleted ${delRes.deletedCount} existing stations from DB (after backup)`);
    } catch (err) {
      console.error('Failed to delete existing stations:', err.message);
      await mongoose.disconnect();
      process.exit(1);
    }
  }

  for (const [i, s] of stations.entries()) {
    // Prefer explicit streaming_url, then streams array, then common fallbacks
    let url = '';
    if (s.streaming_url) url = s.streaming_url;
    else if (Array.isArray(s.streams) && s.streams.length) url = s.streams[0];
    else if (s.stream) url = s.stream;
    else if (s.stream_url) url = s.stream_url;
    else if (s.url) url = s.url;
    url = (url || '').toString().trim();

    const name = ((s.name || s.title || s.station_name || s.station) || 'Unknown Station').toString().trim();

    if (!url) {
      skipped.no_stream++;
      logLine('SKIP_NO_STREAM', name, '', `index=${i}`);
      continue;
    }

    // If the path (before query) ends with .js => skip
    const urlPathLower = url.split('?')[0].toLowerCase();
    if (urlPathLower.endsWith('.js')) {
      skipped.js_urls++;
      logLine('SKIP_JS_URL', name, url, `index=${i}`);
      continue;
    }

    // Normalize mp3/stream URL for duplicate detection
    const mp3Url = normalizeUrl(url);

    // Duplicate check: existing by normalized mp3Url or name (case-insensitive exact)
    const nameRegex = new RegExp('^' + escapeRegExp(name) + '$', 'i');
    const existingDoc = await Station.findOne({ $or: [ { mp3Url }, { name: { $regex: nameRegex } } ] }).lean();
    if (existingDoc) {
      skipped.duplicates++;
      const reason = existingDoc.mp3Url === mp3Url ? 'mp3Url' : 'name';
      logLine('SKIP_DUPLICATE', name, mp3Url, `index=${i} | matched_by=${reason}`);
      continue;
    }

    // Extract profile image: prefer `playerImage`, then `banner`, then other fallbacks
    const profilepic = (s.playerImage || s.banner || s.player_image || s.playerImg || s.image || s.logo || s.icon || '').toString().trim();

    // Description and extras
    const description = (s.description || s.details || s.info || s.summary || '').toString().trim();

    // Genre: prefer explicit genre, else categories (join if multiple)
    let genre = 'General';
    if (s.genre) genre = s.genre;
    else if (Array.isArray(s.categories) && s.categories.length) {
      // categories may be strings or objects
      const parts = s.categories.map(c => (typeof c === 'string' ? c : (c.name || c.title || '') )).filter(Boolean);
      if (parts.length) genre = parts.join(', ');
    }

    // Tags: categories if strings, else tags field
    let tags = [];
    if (Array.isArray(s.categories) && s.categories.every(c => typeof c === 'string')) tags = s.categories;
    else if (Array.isArray(s.tags)) tags = s.tags;

    const doc = {
      name,
      mp3Url,
      profilepic,
      // Banner: prefer explicit `banner`, else fall back to `playerImage` or empty
      banner: (s.banner || s.playerImage || s.player_image || '').toString().trim(),
      description,
      genre: genre || 'General',
      contentLanguage: s.language || s.lang || s.country || 'Hindi',
      tags,
      isStandalone: true,
    };

    toCreate.push(doc);
    logLine('WILL_CREATE', doc.name, doc.mp3Url, `index=${i}`);
  }

  console.log(`Parsed ${stations.length} entries -> ${toCreate.length} new stations to create`);
  console.log(`Skipped: no_stream=${skipped.no_stream}, js_urls=${skipped.js_urls}, duplicates=${skipped.duplicates}`);

  if (!apply) {
    console.log('Dry-run mode (no changes saved). To persist, re-run with `--apply` flag.');
    await mongoose.disconnect();
    return;
  }

  // (deletion handled earlier)

  let imported = 0;
  let errors = 0;
  for (let i = 0; i < toCreate.length; i++) {
    const doc = toCreate[i];
    try {
      const created = new Station(doc);
      await created.save();
      imported++;
      logLine('CREATED', doc.name, doc.mp3Url, `index=${i} | id=${created._id}`);
    } catch (err) {
      errors++;
      logLine('ERROR_SAVE', doc.name, doc.mp3Url, `index=${i} | error=${err.message}`);
    }
  }

  console.log(`Imported ${imported} stations into database. Errors: ${errors}`);

  await mongoose.disconnect();
}

main().catch(err => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
