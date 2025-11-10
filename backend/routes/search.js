const express = require('express');
const router = express.Router();
const Station = require('../models/Station');
const Series = require('../models/Series');
// Ensure the Episode model exists or adjust the filepath
const Episode = require('../models/Episode'); // Verify this filepath

// Search endpoint for stations, series and episodes
router.get('/', async (req, res) => {
  try {
    const query = req.query.q;

    if (!query || query.trim() === '') {
      return res.status(400).json({
        success: false,
        message: 'Search query is required'
      });
    }

    // Create case-insensitive search regex
    const searchRegex = new RegExp(query, 'i');

    // Search stations
    const stations = await Station.find({
      $or: [
        { name: searchRegex },
        { genre: searchRegex },
        { description: searchRegex }
      ]
    }).limit(10);

    // Search series
    const series = await Series.find({
      $or: [
        { name: searchRegex },
        { description: searchRegex }
      ]
    }).limit(10);

    // Ensure Episode model is correctly referenced
    const episodes = await Episode.find({
      $or: [
        { title: searchRegex },
        { description: searchRegex }
      ]
    }).populate('seriesId').limit(10);

    res.json({
      success: true,
      results: {
        stations: stations,
        series: series,
        episodes: episodes
      }
    });
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({
      success: false,
      message: 'Search failed',
      error: error.message
    });
  }
});

module.exports = router;
