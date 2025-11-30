#!/usr/bin/env node
const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');

const DATA_JSON = path.join(__dirname, '..', 'data', 'radioindia.json');

function slugFromUrl(url) {
  if (!url) return null;
  try {
    const u = new URL(url);
    const parts = u.pathname.split('/').filter(Boolean);
    if (parts.length === 0) return null;
    let slug = parts[parts.length - 1];
    // strip trailing -digits
    slug = slug.replace(/-\d+$/, '');
    return slug.toLowerCase();
  } catch (e) {
    // fallback simple
    let s = url.replace(/^\//, '').split(/[\/?#]/)[0];
    s = s.replace(/-\d+$/, '');
    return s.toLowerCase();
  }
}

function detectLanguageFromName(name) {
  if (!name) return null;
  // check scripts
  if (/[\u0900-\u097F]/.test(name)) return 'hi'; // Devanagari (Hindi/Marathi/Nepali)
  if (/[\u0B80-\u0BFF]/.test(name)) return 'ta'; // Tamil
  if (/[\u0C00-\u0C7F]/.test(name)) return 'te'; // Telugu
  if (/[\u0C80-\u0CFF]/.test(name)) return 'kn'; // Kannada
  if (/[\u0D00-\u0D7F]/.test(name)) return 'ml'; // Malayalam
  if (/[\u0980-\u09FF]/.test(name)) return 'bn'; // Bengali

  const lname = name.toLowerCase();
  if (lname.includes('hindi')) return 'hi';
  if (lname.includes('tamil')) return 'ta';
  if (lname.includes('telugu')) return 'te';
  if (lname.includes('marathi')) return 'mr';
  if (lname.includes('english')) return 'en';
  return null;
}

function detectCategoryType(name, slug) {
  const n = (name || '').toLowerCase();
  const s = (slug || '').toLowerCase();

  const genres = ['rock','pop','dance','electronic','metal','jazz','blues','classical','oldies','retro','bollywood','hits','chillout','lounge','rb','hip-hop','r&b','latin','dance-electronic','discover'];
  for (const g of genres) {
    if (n.includes(g) || s.includes(g)) return 'genre';
  }

  // states / locations common names
  const states = ['andaman','andhra','arunachal','assam','bihar','chandigarh','chhattisgarh','daman','goa','gujarat','haryana','himachal','jharkhand','karnataka','kerala','maharashtra','manipur','meghalaya','mizoram','nagaland','odisha','punjab','rajasthan','sikkim','tamil','tripura','uttar','uttarakhand','west-bengal','west bengal','odisha','kashmir','puducherry'];
  for (const st of states) {
    if (n.includes(st) || s.includes(st)) return 'location';
  }

  if (n.includes('podcast') || n.includes('podcasts')) return 'podcast';
  if (n.includes('country')) return 'country';

  return 'other';
}

async function main() {
  try {
    if (!fsSync.existsSync(DATA_JSON)) {
      console.error('Missing', DATA_JSON);
      process.exit(1);
    }

    const data = JSON.parse(await fs.readFile(DATA_JSON, 'utf8'));
    const cats = data.categories || [];
    const outCats = cats.map(c => {
      const url = c.url || null;
      const name = c.name || (url ? url.split('/').pop() : null);
      const slug = slugFromUrl(url) || (name ? name.toLowerCase().replace(/\s+/g,'-') : null);
      const type = detectCategoryType(name, slug);
      const language = detectLanguageFromName(name);
      return { name, url, slug, type, language };
    });

    data.categories = outCats;

    // backup original
    const backup = DATA_JSON + '.bak';
    if (!fsSync.existsSync(backup)) await fs.writeFile(backup, JSON.stringify(data, null, 2), 'utf8');

    await fs.writeFile(DATA_JSON, JSON.stringify(data, null, 2), 'utf8');
    console.log(`Updated ${outCats.length} categories in ${DATA_JSON}`);
  } catch (e) {
    console.error('augment error', e && e.message ? e.message : e);
    process.exit(1);
  }
}

if (require.main === module) main();
