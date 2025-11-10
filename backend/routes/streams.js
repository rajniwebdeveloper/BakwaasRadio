const express = require('express');
const router = express.Router();
const Stream = require('../models/Stream');

console.log('🛣️  Loading radio streams routes...');

// Helper function to generate player URL for streams
function generateStreamPlayerUrl(stream) {
  const baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  return `${baseUrl}/player/stream/${stream.id}`;
}

// Helper function to format stream response with player URL
function formatStreamWithPlayerUrl(stream, showOriginal = false) {
  const formatted = {
    ...stream.toObject ? stream.toObject() : stream,
    // Only include originalUrl when showing originals for admin purposes
    ...(showOriginal && { originalUrl: stream.url })
  };
  
  // If showOriginal is true, keep the original URL
  if (showOriginal) {
    formatted.audioUrl = stream.url || stream.audioUrl; // Keep original URL
    formatted.url = stream.url; // Keep original URL
    formatted.mp3Url = stream.url; // Keep original URL
    formatted.playerUrl = generateStreamPlayerUrl(stream); // Still include player URL for reference
  } else {
    formatted.url = generateStreamPlayerUrl(stream); // Replace with player URL
    formatted.mp3Url = generateStreamPlayerUrl(stream); // Replace with player URL
    formatted.audioUrl = generateStreamPlayerUrl(stream); // Replace with player URL
    formatted.playerUrl = generateStreamPlayerUrl(stream); // Add explicit player URL
  }
  
  return formatted;
}

// GET all streams
router.get('/', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/streams - Fetching all streams. ShowOriginal: ${showOriginal}`);
    const streams = await Stream.find();
    console.log(`✅ Found ${streams.length} radio streams`);
    
    // Format streams with player URLs
    const formattedStreams = streams.map(stream => formatStreamWithPlayerUrl(stream, showOriginal));
    res.json(formattedStreams);
  } catch (error) {
    console.error('❌ Error fetching streams:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET stream by ID
router.get('/:id', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/streams/${req.params.id} - Fetching stream by ID. ShowOriginal: ${showOriginal}`);
    const stream = await Stream.findOne({ id: req.params.id });
    
    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }
    
    console.log('✅ Stream found:', stream.name);
    
    // Format with player URL
    const formattedStream = formatStreamWithPlayerUrl(stream, showOriginal);
    res.json(formattedStream);
  } catch (error) {
    console.error('❌ Error fetching stream:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET streams by category
router.get('/category/:category', async (req, res) => {
  try {
    const category = req.params.category;
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/streams/category/${category} - Fetching streams by category. ShowOriginal: ${showOriginal}`);
    
    const streams = await Stream.find({ categories: { $in: [category] } });
    console.log(`✅ Found ${streams.length} streams in category ${category}`);
    
    // Format streams with player URLs
    const formattedStreams = streams.map(stream => formatStreamWithPlayerUrl(stream, showOriginal));
    res.json(formattedStreams);
  } catch (error) {
    console.error('❌ Error fetching streams by category:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// POST create a new stream
router.post('/', async (req, res) => {
  try {
    console.log('📡 POST /api/streams - Creating new stream');
    
    // Check if stream with same ID already exists
    const existingStream = await Stream.findOne({ id: req.body.id });
    if (existingStream) {
      return res.status(400).json({ message: 'Stream with this ID already exists' });
    }
    
    const stream = new Stream({
      id: req.body.id,
      name: req.body.name,
      url: req.body.url,
      image: req.body.image || '',
      description: req.body.description || '',
      categories: req.body.categories || [],
      language: req.body.language || 'English',
      country: req.body.country || '',
      featured: req.body.featured || false
    });
    
    const newStream = await stream.save();
    console.log('✅ Stream created successfully:', newStream.name);
    res.status(201).json(newStream);
  } catch (error) {
    console.error('❌ Error creating stream:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// PUT update a stream
router.put('/:id', async (req, res) => {
  try {
    console.log(`📡 PUT /api/streams/${req.params.id} - Updating stream`);
    
    const stream = await Stream.findOne({ id: req.params.id });
    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }
    
    // Update fields
    stream.name = req.body.name || stream.name;
    stream.url = req.body.url || stream.url;
    stream.image = req.body.image || stream.image;
    stream.description = req.body.description || stream.description;
    stream.categories = req.body.categories || stream.categories;
    stream.language = req.body.language || stream.language;
    stream.country = req.body.country || stream.country;
    stream.featured = req.body.featured !== undefined ? req.body.featured : stream.featured;
    
    const updatedStream = await stream.save();
    console.log('✅ Stream updated successfully:', updatedStream.name);
    res.json(updatedStream);
  } catch (error) {
    console.error('❌ Error updating stream:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// DELETE a stream
router.delete('/:id', async (req, res) => {
  try {
    console.log(`📡 DELETE /api/streams/${req.params.id} - Deleting stream`);
    
    const stream = await Stream.findOne({ id: req.params.id });
    if (!stream) {
      return res.status(404).json({ message: 'Stream not found' });
    }
    
    await Stream.deleteOne({ id: req.params.id });
    console.log('✅ Stream deleted successfully');
    res.json({ message: 'Stream deleted successfully' });
  } catch (error) {
    console.error('❌ Error deleting stream:', error.message);
    res.status(500).json({ message: error.message });
  }
});

console.log('✅ Radio streams routes loaded successfully');

module.exports = router;
