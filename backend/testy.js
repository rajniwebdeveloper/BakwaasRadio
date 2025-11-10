/**
 * Function to test if a stream URL is working
 * @param {string} url - The stream URL to test
 */
async function testStream(url) {
  try {
    console.log(`🔗 Testing stream URL: ${url}`);
    
    // Validate URL format
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      console.error('❌ Invalid URL format');
      return { success: false, message: 'Invalid URL format' };
    }

    // Send a GET request to the URL using fetch
    const response = await fetch(url, { method: 'GET' });

    if (response.ok) {
      console.log(`✅ Stream is working: ${url}`);
      return { success: true, status: response.status, message: 'Stream is working' };
    } else {
      console.error(`❌ Stream test failed for ${url}: HTTP ${response.status}`);
      return { success: false, message: `HTTP ${response.status}` };
    }
  } catch (error) {
    console.error(`❌ Stream test failed for ${url}:`, error.message);
    return { success: false, message: error.message };
  }
}

// Example usage
const streamUrl = 'https://audio.streamcast.xyz/listen/radiogoongoon/radio.mp3';
testStream(streamUrl).then(result => console.log(result));

const express = require('express');
const { Readable } = require('stream'); // Import Readable stream from Node.js
// Ensure node-fetch is installed
const app = express();
const PORT = 3002;

// Endpoint to stream data from the URL to the frontend
app.get('/stream', async (req, res) => {
  const url = req.query.url; // URL passed as a query parameter

  if (!url || (!url.startsWith('http://') && !url.startsWith('https://'))) {
    return res.status(400).send('Invalid URL format');
  }

  try {
    const response = await fetch(url);

    if (!response.ok) {
      return res.status(response.status).send(`Failed to fetch stream: HTTP ${response.status}`);
    }

    // Convert response body to a buffer and create a readable stream
    const buffer = await response.arrayBuffer();
    const readableStream = Readable.from(Buffer.from(buffer));

    // Set headers for MP3 audio streaming
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Transfer-Encoding', 'chunked');

    // Pipe the readable stream to the client
    readableStream.pipe(res);
  } catch (error) {
    console.error(`Error streaming MP3 audio from ${url}:`, error.message);
    res.status(500).send(`Error: ${error.message}`);
  }
});

// Start the Express server
app.listen(PORT, () => {
  console.log(`🚀 Server is running on http://localhost:${PORT}`);
});
