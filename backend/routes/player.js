const express = require('express');
const https = require('https');
const http = require('http');
const url = require('url');
const router = express.Router();
const Station = require('../models/Station');
const Stream = require('../models/Stream');
const axios = require('axios');
const ffmpeg = require('fluent-ffmpeg'); // Add this import for HLS transcoding

console.log('🛣️  Loading player proxy routes...');

// Player endpoint for stations
router.get('/station/:id', async (req, res) => {
  try {
    console.log(`🎵 Player request for station: ${req.params.id}`);
    
    // Find the station
    const station = await Station.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ error: 'Station not found' });
    }

    if (!station.mp3Url) {
      return res.status(404).json({ error: 'No audio URL available' });
    }

    console.log(`🎵 Streaming: ${station.name} from ${station.mp3Url}`);
    
    // Update play count (optional analytics)
    await Station.findByIdAndUpdate(req.params.id, { $inc: { playCount: 1 } });
    
    // Proxy the stream

    let playerurl = station.mp3Url;
    try {
      const response = await axios.get(playerurl, { maxRedirects: 0, validateStatus: status => status < 400 || status === 302 });
      if (response.status === 302 && response.headers.location) {
        playerurl = response.headers.location;
        console.log(`🔄 Redirected to: ${playerurl}`);
      }
    } catch (error) {
      console.error(`❌ Error accessing station URL: ${playerurl}`, error.message);
    
    }

    proxyStream(playerurl, req, res, {
      title: station.name,
      type: 'station',
      id: station._id
    });

  } catch (error) {
    console.error('❌ Error in station player:', error.message);
    res.status(500).json({ error: 'Failed to load station' });
  }
});

// Player endpoint for streams
router.get('/stream/:id', async (req, res) => {
  try {
    const streamId = req.params.id;
    console.log(`📡 Player request for stream: ${streamId}`);
    
    // Find the stream
    let stream = await Stream.findOne({ id: streamId });
    if (!stream) {
      // Try to find by _id in case it was passed instead of id
      const streamByObjectId = await Stream.findById(streamId);
      if (!streamByObjectId) {
        console.error(`❌ Stream not found with id: ${streamId}`);
        return res.status(404).json({ error: 'Stream not found' });
      }
      stream = streamByObjectId;
    }

    if (!stream.url) {
      console.error(`❌ No stream URL available for: ${stream.name || streamId}`);
      return res.status(404).json({ error: 'No stream URL available' });
    }

    console.log(`📡 Streaming: ${stream.name} from ${stream.url}`);
    
    // Increment stream play count if tracking enabled
    if (stream.playCount !== undefined) {
      await Stream.findByIdAndUpdate(stream._id, { $inc: { playCount: 1 } });
    }
    
    // Proxy the stream
    proxyStream(stream.url, req, res, {
      title: stream.name || 'Radio Stream',
      type: 'stream',
      id: stream.id || stream._id
    });

  } catch (error) {
    console.error(`❌ Error in stream player: ${error.message}`, error);
    res.status(500).json({ error: 'Failed to load stream' });
  }
});

// Player endpoint for radio items
router.get('/radio/:id', async (req, res) => {
  try {
    console.log(`📻 Player request for radio: ${req.params.id}`);
    
    // Find the radio item
    const Radio = require('../models/Radio');
    const radioItem = await Radio.findById(req.params.id);
    if (!radioItem) {
      return res.status(404).json({ error: 'Radio item not found' });
    }

    if (!radioItem.audioUrl) {
      return res.status(404).json({ error: 'No audio URL available' });
    }

    console.log(`📻 Streaming: ${radioItem.title} from ${radioItem.audioUrl}`);
    
    // Update views count
    await Radio.findByIdAndUpdate(req.params.id, { $inc: { views: 1 } });
    
    // Proxy the stream
    proxyStream(radioItem.audioUrl, req, res, {
      title: radioItem.title,
      type: 'radio',
      id: radioItem._id
    });

  } catch (error) {
    console.error('❌ Error in radio player:', error.message);
    res.status(500).json({ error: 'Failed to load radio item' });
  }
});

// Generic URL player (for direct URLs)
router.get('/url/:encodedUrl', async (req, res) => {
  try {
    const decodedUrl = decodeURIComponent(req.params.encodedUrl);
    console.log(`🔗 Player request for URL: ${decodedUrl}`);
    
    // Basic URL validation
    if (!decodedUrl.startsWith('http://') && !decodedUrl.startsWith('https://')) {
      return res.status(400).json({ error: 'Invalid URL format' });
    }
    
    // Proxy the stream
    proxyStream(decodedUrl, req, res, {
      title: 'Direct Stream',
      type: 'url',
      url: decodedUrl
    });

  } catch (error) {
    console.error('❌ Error in URL player:', error.message);
    res.status(500).json({ error: 'Failed to load stream' });
  }
});

// Function to proxy stream with live data transfer
function proxyStream(sourceUrl, req, res, metadata = {}) {
  const parsedUrl = url.parse(sourceUrl);
  const isHttps = parsedUrl.protocol === 'https:';
  const httpModule = isHttps ? https : http;

  console.log(`🔄 Proxying ${metadata.type || 'stream'}: ${metadata.title || 'Unknown'}`);

  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Range, Content-Type');

  // Handle OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Check if the URL is an HLS stream (.m3u8)
  if (sourceUrl.endsWith('.m3u8')) {
    console.log(`🎥 Transcoding HLS stream: ${metadata.title || 'Unknown'}`);
    ffmpeg(sourceUrl)
      .inputOptions('-re') // Read input in real-time
      .outputFormat('mp3') // Transcode to MP3 format
      .on('start', () => {
        console.log(`▶️  Started transcoding: ${metadata.title || 'Unknown'} (HLS)`);
      })
      .on('error', (error) => {
        console.error(`❌ Transcoding error for ${metadata.title || 'stream'}:`, error.message);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Failed to transcode stream' });
        }
      })
      .on('end', () => {
        console.log(`🏁 Transcoding ended: ${metadata.title || 'Unknown'}`);
        res.end();
      })
      .pipe(res, { end: true }); // Pipe the transcoded stream to the response
    return;
  }

  const options = {
    hostname: parsedUrl.hostname,
    port: parsedUrl.port || (isHttps ? 443 : 80),
    path: parsedUrl.path,
    method: 'GET',
    headers: {
      'User-Agent': 'BakwaasFM-Player/1.0',
      'Accept': '*/*',
      'Connection': 'keep-alive'
    }
  };

  // Forward range header if present (for seeking support)
  if (req.headers.range) {
    options.headers.Range = req.headers.range;
  }

  // Forward other relevant headers
  if (req.headers['accept-encoding']) {
    options.headers['Accept-Encoding'] = req.headers['accept-encoding'];
  }

  const proxyReq = httpModule.request(options, (proxyRes) => {
    console.log(`📊 Proxy response: ${proxyRes.statusCode} for ${metadata.title || 'stream'}`);

    // Set response headers
    res.status(proxyRes.statusCode);

    // Forward relevant headers
    const headersToForward = [
      'content-type',
      'content-length',
      'content-range',
      'accept-ranges',
      'cache-control',
      'last-modified',
      'etag'
    ];

    headersToForward.forEach(header => {
      if (proxyRes.headers[header]) {
        res.setHeader(header, proxyRes.headers[header]);
      }
    });

    // Add custom headers for identification
    res.setHeader('X-BakwaasFM-Player', 'true');
    res.setHeader('X-Stream-Type', metadata.type || 'unknown');
    if (metadata.title) {
      res.setHeader('X-Stream-Title', encodeURIComponent(metadata.title));
    }

    // Log stream start
    console.log(`▶️  Started streaming: ${metadata.title || 'Unknown'} (${metadata.type || 'stream'})`);

    // Track active connections (optional)
    let bytesTransferred = 0;

    // Pipe the response with data tracking
    proxyRes.on('data', (chunk) => {
      bytesTransferred += chunk.length;
      res.write(chunk);
    });

    proxyRes.on('end', () => {
      console.log(`🏁 Stream ended: ${metadata.title || 'Unknown'} (${formatBytes(bytesTransferred)} transferred)`);
      res.end();
    });

    proxyRes.on('error', (error) => {
      console.error(`❌ Proxy response error for ${metadata.title || 'stream'}:`, error.message);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Stream error' });
      }
    });
  });

  proxyReq.on('error', (error) => {
    console.error(`❌ Proxy request error for ${metadata.title || 'stream'}:`, error.message);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to connect to stream' });
    }
  });

  // Handle client disconnect
  req.on('close', () => {
    console.log(`🔌 Client disconnected from: ${metadata.title || 'stream'}`);
    proxyReq.destroy();
  });

  // Set timeout
  proxyReq.setTimeout(30000, () => {
    console.error(`⏰ Timeout for stream: ${metadata.title || 'stream'}`);
    proxyReq.destroy();
  });

  proxyReq.end();
}

// Utility function to format bytes
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Health check endpoint
router.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'BakwaasFM Player Proxy',
    timestamp: new Date().toISOString()
  });
});

// Player proxy to handle streaming content
// This helps bypass CORS issues when playing media
router.get('/:streamId', async (req, res) => {
    const streamId = req.params.streamId;
    if (!streamId) {
        return res.status(400).json({ error: 'Stream ID is required' });
    }

    try {
        // Get the stream URL from our database
        const stream = await getStreamUrl(streamId);
        
        if (!stream || !stream.url) {
            return res.status(404).json({ error: 'Stream not found' });
        }

        console.log(`🎵 Proxying stream: ${stream.url}`);
        
        // Proxy the media stream
        const response = await axios({
            method: 'get',
            url: stream.url,
            responseType: 'stream'
        });

        // Set appropriate headers
        Object.keys(response.headers).forEach(key => {
            res.setHeader(key, response.headers[key]);
        });
        
        // Stream the content
        response.data.pipe(res);
    } catch (error) {
        console.error('Player proxy error:', error);
        res.status(500).json({ 
            error: 'Failed to proxy stream',
            message: error.message 
        });
    }
});

// Helper function to get stream URL from database
// In a real app, this would query MongoDB, but for simplicity we're mocking it
async function getStreamUrl(streamId) {
    // Mock implementation - in production this would query MongoDB
    return {
        id: streamId,
        url: `https://example.com/streams/${streamId}.mp3`
    };
}

// Detailed player page route
router.get('/view/:streamId', (req, res) => {
    const streamId = req.params.streamId;
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>BakwaasFM Player</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                .player { max-width: 500px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                audio { width: 100%; margin-top: 20px; }
                h1 { color: #6200ea; }
                .loading { text-align: center; color: #6200ea; }
            </style>
        </head>
        <body>
            <div class="player">
                <h1>BakwaasFM Player</h1>
                <p>Now playing stream: ${streamId}</p>
                <audio controls autoplay>
                    <source src="/player/${streamId}" type="audio/mpeg">
                    Your browser does not support the audio element.
                </audio>
            </div>
            <script>
                const audio = document.querySelector('audio');
                audio.addEventListener('error', () => {
                    document.querySelector('.player').innerHTML += '<p class="error">Error loading audio. The stream may be unavailable.</p>';
                });
            </script>
        </body>
        </html>
    `);
});

console.log('✅ Player proxy routes loaded successfully');

module.exports = router;
