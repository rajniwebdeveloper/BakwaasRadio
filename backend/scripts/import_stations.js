#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const Station = require('../models/Station');

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&');
}

function logLine(action, name, url, extra) {
  const time = new Date().toISOString();
  const parts = [`[${time}]`, action];
  if (name) parts.push(`name="${name}"`);
  if (url) parts.push(`url="${url}"`);
  if (extra) parts.push(extra);
  console.log(parts.join(' | '));
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

  for (const [i, s] of stations.entries()) {
    const url = (s.streaming_url || s.stream || s.stream_url || s.url || '').toString().trim();
    const name = (s.name || s.title || s.station_name || s.station || '').toString().trim() || 'Unknown Station';

    if (!url) {
      skipped.no_stream++;
      logLine('SKIP_NO_STREAM', name, '', `index=${i}`);
      continue;
    }

    // If the path (before query) ends with .js => skip
    const urlPath = url.split('?')[0].toLowerCase();
    if (urlPath.endsWith('.js')) {
      skipped.js_urls++;
      logLine('SKIP_JS_URL', name, url, `index=${i}`);
      continue;
    }

    const mp3Url = url;

    // Duplicate check: existing by mp3Url or name (case-insensitive exact)
    const nameRegex = new RegExp('^' + escapeRegExp(name) + '$', 'i');
    const existingDoc = await Station.findOne({ $or: [ { mp3Url }, { name: { $regex: nameRegex } } ] }).lean();
    if (existingDoc) {
      skipped.duplicates++;
      const reason = existingDoc.mp3Url === mp3Url ? 'mp3Url' : 'name';
      logLine('SKIP_DUPLICATE', name, mp3Url, `index=${i} | matched_by=${reason}`);
      continue;
    }

    const doc = {
      name,
      mp3Url,
      profilepic: s.logo || s.image || s.icon || '',
      banner: s.banner || '',
      description: s.description || s.details || s.info || '',
      genre: s.genre || (Array.isArray(s.categories) ? s.categories[0] : '') || 'General',
      contentLanguage: s.language || s.lang || s.country || 'Hindi',
      tags: s.tags || s.categories || [],
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
