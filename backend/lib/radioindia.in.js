#!/usr/bin/env node
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

const URL = process.argv[2] || 'https://www.radioindia.in/';
const OUT = process.argv[3] || path.join(__dirname, '..', 'output.html');

async function main() {
	try {
		console.log(`Fetching ${URL} ...`);
		const res = await axios.get(URL, { responseType: 'text', timeout: 20000, headers: { 'User-Agent': 'Mozilla/5.0 (compatible; Node.js axios)'} });
		await fs.writeFile(OUT, res.data, 'utf8');
		console.log(`Saved response to ${OUT}`);
	} catch (err) {
		console.error('Fetch failed:', err && err.message ? err.message : err);
		process.exitCode = 1;
	}
}

main();

  