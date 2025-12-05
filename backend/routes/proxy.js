const express = require('express');
const axios = require('axios');
const router = express.Router();
const Station = require('../models/Station');
const Series = require('../models/Series');
const Stream = require('../models/Stream');

console.log('🛣️  Loading proxy routes for images and media...');

// Helper function to proxy any resource
async function proxyResource(url, req, res, options = {}) {
  try {
    console.log(`🔄 Proxying resource: ${url}`);
    
    // Make request to the original URL
    const response = await axios({
      method: 'GET',
      url: url,
      responseType: 'stream',
      headers: {
        'User-Agent': req.headers['user-agent'] || 'BakwaasFM-Proxy/1.0',
        'Referer': options.referer || '',
        'Accept': req.headers['accept'] || '*/*'
      },
      timeout: 30000,
      maxRedirects: 5
    });

    // Set appropriate headers
    res.setHeader('Content-Type', response.headers['content-type'] || options.contentType || 'application/octet-stream');
    
    if (response.headers['content-length']) {
      res.setHeader('Content-Length', response.headers['content-length']);
    }
    
    // Cache headers for images
    if (options.cache !== false) {
      res.setHeader('Cache-Control', 'public, max-age=86400'); // 24 hours
    }
    
    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    
    // Pipe the response
    response.data.pipe(res);
    
    response.data.on('error', (err) => {
      console.error('❌ Stream error:', err.message);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to proxy resource' });
      }
    });

  } catch (error) {
    console.error('❌ Proxy error:', error.message);
    if (!res.headersSent) {
      res.status(error.response?.status || 500).json({ 
        error: 'Failed to fetch resource',
        message: error.message 
      });
    }
  }
}

// Proxy station profile picture
router.get('/station/:id/profilepic', async (req, res) => {
  try {
    const station = await Station.findById(req.params.id).select('profilepic name');
    if (!station) {
      return res.status(404).json({ error: 'Station not found' });
    }
    
    if (!station.profilepic) {
      return res.status(404).json({ error: 'No profile picture available' });
    }

    await proxyResource(station.profilepic, req, res, {
      contentType: 'image/jpeg',
      cache: true,
      referer: station.profilepic
    });
  } catch (error) {
    console.error('❌ Error proxying station profile picture:', error.message);
    res.status(500).json({ error: 'Failed to load profile picture' });
  }
});

// Proxy station banner
router.get('/station/:id/banner', async (req, res) => {
  try {
    const station = await Station.findById(req.params.id).select('banner name');
    if (!station) {
      return res.status(404).json({ error: 'Station not found' });
    }
    
    if (!station.banner) {
      return res.status(404).json({ error: 'No banner available' });
    }

    await proxyResource(station.banner, req, res, {
      contentType: 'image/jpeg',
      cache: true,
      referer: station.banner
    });
  } catch (error) {
    console.error('❌ Error proxying station banner:', error.message);
    res.status(500).json({ error: 'Failed to load banner' });
  }
});

// Proxy series profile picture
router.get('/series/:id/profilepic', async (req, res) => {
  try {
    const series = await Series.findById(req.params.id).select('profilepic name');
    if (!series) {
      return res.status(404).json({ error: 'Series not found' });
    }
    
    if (!series.profilepic) {
      return res.status(404).json({ error: 'No profile picture available' });
    }

    await proxyResource(series.profilepic, req, res, {
      contentType: 'image/jpeg',
      cache: true,
      referer: series.profilepic
    });
  } catch (error) {
    console.error('❌ Error proxying series profile picture:', error.message);
    res.status(500).json({ error: 'Failed to load profile picture' });
  }
});

// Proxy series banner
router.get('/series/:id/banner', async (req, res) => {
  try {
    const series = await Series.findById(req.params.id).select('banner name');
    if (!series) {
      return res.status(404).json({ error: 'Series not found' });
    }
    
    if (!series.banner) {
      return res.status(404).json({ error: 'No banner available' });
    }

    await proxyResource(series.banner, req, res, {
      contentType: 'image/jpeg',
      cache: true,
      referer: series.banner
    });
  } catch (error) {
    console.error('❌ Error proxying series banner:', error.message);
    res.status(500).json({ error: 'Failed to load banner' });
  }
});

// Proxy stream logo/icon
router.get('/stream/:id/logo', async (req, res) => {
  try {
    const stream = await Stream.findOne({ id: req.params.id }).select('favicon name');
    if (!stream) {
      const streamByObjectId = await Stream.findById(req.params.id).select('favicon name');
      if (!streamByObjectId) {
        return res.status(404).json({ error: 'Stream not found' });
      }
      stream = streamByObjectId;
    }
    
    if (!stream.favicon) {
      return res.status(404).json({ error: 'No logo available' });
    }

    await proxyResource(stream.favicon, req, res, {
      contentType: 'image/png',
      cache: true,
      referer: stream.favicon
    });
  } catch (error) {
    console.error('❌ Error proxying stream logo:', error.message);
    res.status(500).json({ error: 'Failed to load logo' });
  }
});

// Generic image proxy with URL encoding
router.get('/image', async (req, res) => {
  try {
    const imageUrl = req.query.url;
    if (!imageUrl) {
      return res.status(400).json({ error: 'URL parameter is required' });
    }

    // Decode the URL if it's encoded
    const decodedUrl = decodeURIComponent(imageUrl);
    
    await proxyResource(decodedUrl, req, res, {
      contentType: 'image/jpeg',
      cache: true,
      referer: decodedUrl
    });
  } catch (error) {
    console.error('❌ Error proxying generic image:', error.message);
    res.status(500).json({ error: 'Failed to load image' });
  }
});

// Generic media proxy with URL encoding (for audio/video)
router.get('/media', async (req, res) => {
  try {
    const mediaUrl = req.query.url;
    if (!mediaUrl) {
      return res.status(400).json({ error: 'URL parameter is required' });
    }

    // Decode the URL if it's encoded
    const decodedUrl = decodeURIComponent(mediaUrl);
    
    await proxyResource(decodedUrl, req, res, {
      contentType: 'audio/mpeg',
      cache: false,
      referer: decodedUrl
    });
  } catch (error) {
    console.error('❌ Error proxying generic media:', error.message);
    res.status(500).json({ error: 'Failed to load media' });
  }
});

console.log('✅ Proxy routes loaded successfully');

module.exports = router;
