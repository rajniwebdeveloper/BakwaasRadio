const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 4000;

app.use('/api/radioindia', require('./routes/radioindia'));

app.get('/', (req, res) => res.send('RadioIndia dev server (no DB)'));

app.listen(PORT, () => {
  console.log(`RadioIndia dev server listening on http://localhost:${PORT}`);
  console.log(`Endpoints:`);
  console.log(`  GET /api/radioindia/raw`);
  console.log(`  GET /api/radioindia/stations`);
  console.log(`  GET /api/radioindia/stations/find?q=<term>`);
});
