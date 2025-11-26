const express = require('express');
const axios = require('axios');
const router = express.Router();

// Basic update endpoint
// Response structure:
// {
//   iso: { version: '1.2.3', build: '123', releaseNotes: '', url: 'https://apps.apple.com/..', force: false },
//   android: { version: '1.2.3', code: 45, releaseNotes: '', url: 'https://play.google.com/..', force: false },
//   web: { version: '1.0.0', url: 'https://example.com/app', releaseNotes: '' },
//   windows: { ... },
//   macos: { ... }
// }

// You can later change these values to read from DB or environment variables
const updateMetadata = {
  iso: {
    version: '1.4.0',
    build: '140',
    releaseNotes: 'Bug fixes and performance improvements',
    url: 'https://apps.apple.com/app/idYOUR_APP_ID',
    force: false
  },
  android: {
    version: '1.4.2',
    code: 142,
    releaseNotes: 'Small fixes, improved playback',
    url: 'https://play.google.com/store/apps/details?id=your.package.name',
    force: false
  },
  web: {
    version: '1.0.5',
    releaseNotes: 'Web UI improvements',
    url: 'https://radio.rajnikantmahato.me',
    force: false
  },
  windows: {
    version: '1.0.0',
    releaseNotes: 'Initial desktop build',
    url: '',
    force: false
  },
  macos: {
    version: '1.0.0',
    releaseNotes: 'Initial desktop build',
    url: '',
    force: false
  }
};

// GET /api/update
// Optional query params:
//  - platform: iso, android, web, macos, windows
//  - v: client version string (e.g. "6.0.0")
//  - ts: timestamp sent by the client
router.get('/', async (req, res) => {
  try {
    const platform = (req.query.platform || '').toString().toLowerCase();
    const clientVersion = req.query.v ? req.query.v.toString() : null;
    const clientTs = req.query.ts ? req.query.ts.toString() : null;

    // Helper: create per-platform response that also compares versions
    function platformPayload(key) {
      const meta = updateMetadata[key];
      if (!meta) return null;
      const serverVersion = (meta.version || '').toString();
      const serverBuild = (meta.build || meta.code || null);
      let upToDate = null;
      if (clientVersion) {
        upToDate = clientVersion === serverVersion;
      }
      return Object.assign({}, meta, {
        serverVersion,
        serverBuild,
        clientVersion: clientVersion || null,
        clientTs: clientTs || null,
        upToDate,
        activated: upToDate === true
      });
    }

    const allKeys = Object.keys(updateMetadata);

    if (platform) {
      if (!allKeys.includes(platform)) {
        return res.status(200).json({ error: 'Unknown platform', platformRequested: platform });
      }
      const payload = platformPayload(platform);
      return res.json({ [platform]: payload });
    }

    // If no platform specified, validate URLs for all platforms in parallel
    const out = {};
    await Promise.all(allKeys.map(async (k) => {
      const basePayload = platformPayload(k);
      // Validate URL reachability for http(s) URLs
      let urlValid = false;
      try {
        const u = (basePayload && basePayload.url) ? basePayload.url.toString() : '';
        if (u && (u.startsWith('http://') || u.startsWith('https://'))) {
          try {
            const head = await axios.head(u, { timeout: 3000, maxRedirects: 3 });
            if (head.status >= 200 && head.status < 400) urlValid = true;
            else urlValid = false;
          } catch (e) {
            // HEAD failed - mark invalid
            urlValid = false;
          }
        } else if (u) {
          // non-http(s) scheme (market:, itms-apps:, etc.) assume valid
          urlValid = true;
        } else {
          // no URL provided -> invalid
          urlValid = false;
        }
      } catch (e) {
        urlValid = false;
      }

      // Attach validation flags; available = urlValid && (serverVersion > 0)
      basePayload.urlValid = urlValid;
      basePayload.available = urlValid;
      out[k] = basePayload;
    }));

    return res.json(out);
  } catch (err) {
    console.error('❌ Update endpoint error:', err.message);
    return res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
