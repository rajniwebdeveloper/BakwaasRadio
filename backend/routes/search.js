const express = require('express');
const router = express.Router();
const Station = require('../models/Station');
const Series = require('../models/Series');
// Ensure the Episode model exists or adjust the filepath
const Episode = require('../models/Episode'); // Verify this filepath

// Helper function to generate player URL from request hostname
function generatePlayerUrl(item, type = 'station', req = null) {
  let baseUrl;
  if (req) {
    const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost:3222';
    baseUrl = `${protocol}://${host}`;
  } else {
    baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  }
  return `${baseUrl}/player/${type}/${item._id || item.id}`;
}

// Helper function to generate proxied image URL from request hostname
function generateProxyImageUrl(item, imageType = 'profilepic', entityType = 'station', req = null) {
  let baseUrl;
  if (req) {
    const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost:3222';
    baseUrl = `${protocol}://${host}`;
  } else {
    baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  }
  const itemId = item._id || item.id;
  return `${baseUrl}/proxy/${entityType}/${itemId}/${imageType}`;
}

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

    // Format stations with proxy URLs
    const formattedStations = stations.map(station => ({
      ...station.toObject(),
      mp3Url: generatePlayerUrl(station, 'station', req),
      playerUrl: generatePlayerUrl(station, 'station', req),
      profilepic: station.profilepic ? generateProxyImageUrl(station, 'profilepic', 'station', req) : '',
      banner: station.banner ? generateProxyImageUrl(station, 'banner', 'station', req) : ''
    }));

    // Format series with proxy URLs
    const formattedSeries = series.map(s => ({
      ...s.toObject(),
      profilepic: s.profilepic ? generateProxyImageUrl(s, 'profilepic', 'series', req) : '',
      banner: s.banner ? generateProxyImageUrl(s, 'banner', 'series', req) : ''
    }));

    // Format episodes with proxy URLs
    const formattedEpisodes = episodes.map(episode => ({
      ...episode.toObject(),
      mp3Url: generatePlayerUrl(episode, 'station', req),
      playerUrl: generatePlayerUrl(episode, 'station', req),
      profilepic: episode.profilepic ? generateProxyImageUrl(episode, 'profilepic', 'station', req) : '',
      banner: episode.banner ? generateProxyImageUrl(episode, 'banner', 'station', req) : ''
    }));

    res.json({
      success: true,
      results: {
        stations: formattedStations,
        series: formattedSeries,
        episodes: formattedEpisodes
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
