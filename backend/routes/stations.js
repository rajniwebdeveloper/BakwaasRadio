const express = require('express');
const router = express.Router();
const Station = require('../models/Station');
const Series = require('../models/Series');

console.log('🛣️  Loading station routes...');

// Helper function to generate player URL
function generatePlayerUrl(item, type = 'station') {
  const baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  return `${baseUrl}/player/${type}/${item._id || item.id}`;
}

// Helper function to format station response with player URL
function formatStationWithPlayerUrl(station, showOriginal = false) {
  const formatted = {
    ...station.toObject ? station.toObject() : station,
    // Only include originalMp3Url when showing originals for admin purposes
    ...(showOriginal && { originalMp3Url: station.mp3Url })
  };
  
  // If showOriginal is true, keep the original URL
  if (showOriginal) {
    formatted.mp3Url = station.mp3Url; // Keep original URL
    formatted.audioUrl = station.audioUrl; // Keep original URL (fixed: was radioItem.audioUrl)
    formatted.playerUrl = generatePlayerUrl(station, 'station'); // Still include player URL for reference
  } else {
    formatted.mp3Url = generatePlayerUrl(station, 'station'); // Replace with player URL
    formatted.audioUrl = generatePlayerUrl(station, 'station'); // Replace with player URL
    formatted.playerUrl = generatePlayerUrl(station, 'station'); // Add explicit player URL
  }
  
  return formatted;
}

// GET all stations
router.get('/', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/stations - Fetching all stations. ShowOriginal: ${showOriginal}`);
    const stations = await Station.find()
      .select('_id name description profilepic banner mp3Url streamURL seriesName episodeNumber episodeTitle isStandalone isPaid audioCount duration genre contentLanguage tags createdAt updatedAt')
      .sort({ createdAt: -1 });
    
    console.log(`✅ Found ${stations.length} stations`);
    
    // Ensure all fields are properly formatted with player URLs
    const formattedStations = stations.map(station => {
      const baseFormatted = {
        _id: station._id,
        name: station.name || 'Untitled Station',
        description: station.description || '',
        profilepic: station.profilepic || '',
        banner: station.banner || '',
        streamURL: station.streamURL || '',
        seriesName: station.seriesName || null,
        episodeNumber: station.episodeNumber || null,
        episodeTitle: station.episodeTitle || '',
        isStandalone: station.isStandalone !== false,
        isPaid: station.isPaid || false,
        audioCount: station.audioCount || 1,
        duration: station.duration || '',
        genre: station.genre || 'General',
        contentLanguage: station.contentLanguage || 'Hindi',
        tags: station.tags || [],
        createdAt: station.createdAt,
        updatedAt: station.updatedAt
      };

      // Add player URL if mp3Url exists
      if (station.mp3Url) {
        if (showOriginal) {
          baseFormatted.mp3Url = station.mp3Url; // Keep original URL
          baseFormatted.originalMp3Url = station.mp3Url; // Include original for admins
        } else {
          baseFormatted.mp3Url = generatePlayerUrl(station, 'station');
        }
        baseFormatted.playerUrl = generatePlayerUrl(station, 'station');
      } else {
        baseFormatted.mp3Url = '';
        baseFormatted.playerUrl = '';
      }

      return baseFormatted;
    });
    
    res.json(formattedStations);
  } catch (error) {
    console.error('❌ Error fetching stations:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET all series
router.get('/series/list', async (req, res) => {
  try {
    console.log('📡 GET /api/stations/series/list - Fetching all series');
    const series = await Series.find({ isActive: true }).sort({ name: 1 });
    console.log(`✅ Found ${series.length} series`);
    res.json(series);
  } catch (error) {
    console.error('❌ Error fetching series:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET stations by series
router.get('/series/:seriesName', async (req, res) => {
  try {
    console.log(`📡 GET /api/stations/series/${req.params.seriesName} - Fetching stations by series`);
    const stations = await Station.find({ 
      seriesName: req.params.seriesName,
      isStandalone: false 
    }).sort({ episodeNumber: 1 });
    console.log(`✅ Found ${stations.length} stations in series ${req.params.seriesName}`);
    res.json(stations);
  } catch (error) {
    console.error('❌ Error fetching stations by series:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET series metadata with episodes
router.get('/series/:seriesName/info', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/stations/series/${req.params.seriesName}/info - Fetching series metadata. ShowOriginal: ${showOriginal}`);
    const seriesName = req.params.seriesName;
    
    // Get series info
    const seriesData = await Series.findOne({ name: seriesName });
    if (!seriesData) {
      return res.status(404).json({ message: 'Series not found' });
    }
    
    // Get episodes
    const episodes = await Station.find({ 
      seriesName: seriesName,
      isStandalone: false 
    }).sort({ episodeNumber: 1 });
    
    // Format episodes with player URLs
    const formattedEpisodes = episodes.map(episode => formatStationWithPlayerUrl(episode, showOriginal));
    
    // Return combined data
    res.json({
      series: seriesData,
      episodes: formattedEpisodes,
      totalEpisodes: episodes.length
    });
    
    console.log(`✅ Found ${episodes.length} episodes for series ${seriesName}`);
  } catch (error) {
    console.error('❌ Error fetching series metadata:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// Add a new endpoint to get all series with their episodes counts
router.get('/series/all/with-episodes', async (req, res) => {
  try {
    console.log('📡 GET /api/stations/series/all/with-episodes - Fetching all series with episode counts');
    
    // Get all series
    const allSeries = await Series.find({ isActive: true }).sort({ name: 1 });
    
    // Get episode counts for each series
    const seriesWithEpisodes = await Promise.all(allSeries.map(async (series) => {
      const episodeCount = await Station.countDocuments({ 
        seriesName: series.name,
        isStandalone: false 
      });
      
      return {
        ...series.toObject(),
        episodeCount,
      };
    }));
    
    console.log(`✅ Found ${seriesWithEpisodes.length} series with episode information`);
    res.json(seriesWithEpisodes);
  } catch (error) {
    console.error('❌ Error fetching series with episodes:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET standalone stations (not part of series)
router.get('/standalone', async (req, res) => {
  try {
    console.log('📡 GET /api/stations/standalone - Fetching standalone stations');
    const stations = await Station.find({ isStandalone: true }).sort({ createdAt: -1 });
    console.log(`✅ Found ${stations.length} standalone stations`);
    res.json(stations);
  } catch (error) {
    console.error('❌ Error fetching standalone stations:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET station by ID
router.get('/:id', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/stations/${req.params.id} - Fetching station by ID. ShowOriginal: ${showOriginal}`);
    const station = await Station.findById(req.params.id);
    if (!station) {
      return res.status(404).json({ message: 'Station not found' });
    }
    console.log(`✅ Found station: ${station.name}`);
    
    // Format with player URL
    const formattedStation = formatStationWithPlayerUrl(station, showOriginal);
    res.json(formattedStation);
  } catch (error) {
    console.error('❌ Error fetching station by ID:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET all series with complete metadata
router.get('/series/all', async (req, res) => {
  try {
    console.log('📡 GET /api/stations/series/all - Fetching all series with complete metadata');
    const series = await Series.find({ isActive: true })
      .select('_id name description profilepic banner genre language tags isActive createdAt updatedAt')
      .sort({ name: 1 });
    
    console.log(`📊 Found ${series.length} series from database`);
    
    if (!series || series.length === 0) {
      console.log('📊 No series found in database - returning empty array');
      return res.json([]);
    }
    
    // Get detailed statistics for each series
    const seriesWithCompleteStats = await Promise.all(series.map(async (s) => {
      try {
        const episodes = await Station.find({ 
          seriesName: s.name, 
          isStandalone: false 
        }).select('_id episodeNumber isPaid duration createdAt').lean();
        
        console.log(`📝 Series "${s.name}" has ${episodes.length} episodes`);
        
        return {
          _id: s._id,
          seriesName: s.name,
          name: s.name,
          seriesDescription: s.description || '',
          description: s.description || '',
          banner: s.banner || '',
          profilepic: s.profilepic || '',
          genre: s.genre || 'General',
          language: s.language || 'Hindi',
          tags: Array.isArray(s.tags) ? s.tags : [],
          isActive: s.isActive !== false,
          totalEpisodes: episodes.length,
          paidCount: episodes.filter(ep => ep.isPaid).length,
          freeCount: episodes.filter(ep => !ep.isPaid).length,
          latestEpisode: episodes.length > 0 ? 
            Math.max(...episodes.map(ep => ep.episodeNumber || 0).filter(n => !isNaN(n))) : 0,
          firstEpisodeDate: episodes.length > 0 ? 
            episodes.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))[0].createdAt : null,
          lastEpisodeDate: episodes.length > 0 ? 
            episodes.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))[0].createdAt : null,
          averageDuration: episodes.length > 0 ? 
            episodes.filter(ep => ep.duration).map(ep => ep.duration).join(', ') : '',
          createdAt: s.createdAt,
          updatedAt: s.updatedAt
        };
      } catch (error) {
        console.error(`❌ Error processing series "${s.name}":`, error.message);
        return {
          _id: s._id,
          seriesName: s.name,
          name: s.name,
          seriesDescription: s.description || '',
          description: s.description || '',
          banner: s.banner || '',
          profilepic: s.profilepic || '',
          genre: s.genre || 'General',
          language: s.language || 'Hindi',
          tags: Array.isArray(s.tags) ? s.tags : [],
          isActive: s.isActive !== false,
          totalEpisodes: 0,
          paidCount: 0,
          freeCount: 0,
          latestEpisode: 0,
          firstEpisodeDate: null,
          lastEpisodeDate: null,
          averageDuration: '',
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
          error: error.message
        };
      }
    }));

    console.log('✅ Series metadata with complete stats fetched successfully:', seriesWithCompleteStats.length);
    res.json(seriesWithCompleteStats);
  } catch (error) {
    console.error('❌ Error fetching series metadata:', error.message);
    res.status(500).json({ message: error.message, data: [] });
  }
});

// POST create new series
router.post('/series', async (req, res) => {
  console.log('📡 POST /api/stations/series - Creating new series');
  console.log('📦 Request body:', req.body);
  
  try {
    // Check if a series with the same name already exists
    const existingSeries = await Series.findOne({ name: req.body.name });
    if (existingSeries) {
      console.log('⚠️ Series with this name already exists');
      return res.status(400).json({ message: 'A series with this name already exists' });
    }
    
    const series = new Series({
      name: req.body.name,
      description: req.body.description || '',
      profilepic: req.body.profilepic || '',
      banner: req.body.banner || '',
      genre: req.body.genre || 'General',
      language: req.body.language || 'Hindi',
      tags: req.body.tags || []
    });

    const newSeries = await series.save();
    console.log('✅ Series created successfully:', newSeries);
    res.status(201).json(newSeries);
  } catch (error) {
    console.error('❌ Error creating series:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// PUT update series
router.put('/series/:id', async (req, res) => {
  try {
    console.log(`📡 PUT /api/stations/series/${req.params.id} - Updating series`);
    const series = await Series.findById(req.params.id);
    if (!series) {
      console.log('❌ Series not found');
      return res.status(404).json({ message: 'Series not found' });
    }

    // Update fields - name is kept as is since it's the identifier
    // series.name = req.body.name;  // We don't update the name as it's used as an identifier
    series.description = req.body.description || series.description;
    series.profilepic = req.body.profilepic || series.profilepic;
    series.banner = req.body.banner || series.banner;
    series.genre = req.body.genre || series.genre;
    series.language = req.body.language || series.language;
    series.tags = req.body.tags || series.tags;
    series.updatedAt = Date.now();

    const updatedSeries = await series.save();
    console.log('✅ Series updated successfully:', updatedSeries);
    res.json(updatedSeries);
  } catch (error) {
    console.error('❌ Error updating series:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// DELETE series
router.delete('/series/:id', async (req, res) => {
  try {
    console.log(`📡 DELETE /api/stations/series/${req.params.id} - Deleting series`);
    
    // First find the series to get its name
    const series = await Series.findById(req.params.id);
    if (!series) {
      console.log('❌ Series not found');
      return res.status(404).json({ message: 'Series not found' });
    }
    
    const seriesName = series.name;
    
    // Find all episodes associated with this series
    const associatedStations = await Station.find({ seriesName: seriesName });
    console.log(`📊 Found ${associatedStations.length} stations associated with series "${seriesName}"`);
    
    // Delete the series
    await Series.findByIdAndDelete(req.params.id);
    
    // Either update or delete associated episodes based on your business logic
    // Option 1: Make episodes standalone (uncomment this if you want to keep episodes)
    /*
    if (associatedStations.length > 0) {
      const updateResult = await Station.updateMany(
        { seriesName: seriesName },
        { $set: { seriesName: null, isStandalone: true, episodeNumber: null, episodeTitle: '' } }
      );
      console.log(`✅ Updated ${updateResult.modifiedCount} stations to standalone`);
    }
    */
    
    // Option 2: Delete all associated episodes (uncomment this if you want to delete episodes)
    if (associatedStations.length > 0) {
      const deleteResult = await Station.deleteMany({ seriesName: seriesName });
      console.log(`✅ Deleted ${deleteResult.deletedCount} stations associated with the series`);
    }
    
    console.log(`✅ Series "${seriesName}" deleted successfully`);
    res.json({ 
      message: `Series "${seriesName}" deleted successfully`,
      associatedStationsCount: associatedStations.length
    });
  } catch (error) {
    console.error('❌ Error deleting series:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// POST create new station/episode
router.post('/', async (req, res) => {
  console.log('📡 POST /api/stations - Creating new station/episode');
  
  const stationData = {
    name: req.body.name,
    profilepic: req.body.profilepic || '',
    banner: req.body.banner || '',
    description: req.body.description || '',
    mp3Url: req.body.mp3Url,
    isPaid: req.body.isPaid || false,
    duration: req.body.duration || '',
    audioCount: req.body.audioCount || 1,
    genre: req.body.genre || 'General',
    contentLanguage: req.body.language || 'Hindi', // Use contentLanguage instead of language
    tags: req.body.tags || []
  };

  // Handle series vs standalone
  if (req.body.seriesName && req.body.seriesName.trim() !== '') {
    stationData.seriesName = req.body.seriesName;
    stationData.episodeNumber = req.body.episodeNumber || 1;
    stationData.episodeTitle = req.body.episodeTitle || '';
    stationData.isStandalone = false;
  } else {
    stationData.seriesName = null;
    stationData.episodeNumber = null;
    stationData.episodeTitle = '';
    stationData.isStandalone = true;
  }

  const station = new Station(stationData);

  try {
    const newStation = await station.save();
    console.log('✅ Station/episode created successfully:', newStation);
    res.status(201).json(newStation);
  } catch (error) {
    console.error('❌ Error creating station/episode:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// PUT update station
router.put('/:id', async (req, res) => {
  try {
    console.log(`📡 PUT /api/stations/${req.params.id} - Updating station`);
    const station = await Station.findById(req.params.id);
    if (!station) {
      console.log('❌ Station not found');
      return res.status(404).json({ message: 'Station not found' });
    }

    // Update basic fields
    station.name = req.body.name || station.name;
    station.profilepic = req.body.profilepic || station.profilepic;
    station.banner = req.body.banner || station.banner;
    station.description = req.body.description || station.description;
    station.mp3Url = req.body.mp3Url || station.mp3Url;
    station.isPaid = req.body.isPaid !== undefined ? req.body.isPaid : station.isPaid;
    station.duration = req.body.duration || station.duration;
    station.audioCount = req.body.audioCount || station.audioCount;
    station.genre = req.body.genre || station.genre;
    station.contentLanguage = req.body.language || station.contentLanguage; // Update contentLanguage field
    station.tags = req.body.tags || station.tags;

    // Handle series relationship
    if (req.body.seriesName && req.body.seriesName.trim() !== '') {
      station.seriesName = req.body.seriesName;
      station.episodeNumber = req.body.episodeNumber || station.episodeNumber;
      station.episodeTitle = req.body.episodeTitle || station.episodeTitle;
      station.isStandalone = false;
    } else {
      station.seriesName = null;
      station.episodeNumber = null;
      station.episodeTitle = '';
      station.isStandalone = true;
    }

    const updatedStation = await station.save();
    console.log('✅ Station updated successfully:', updatedStation);
    res.json(updatedStation);
  } catch (error) {
    console.error('❌ Error updating station:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// DELETE station
router.delete('/:id', async (req, res) => {
  try {
    console.log(`📡 DELETE /api/stations/${req.params.id} - Deleting station`);
    const station = await Station.findById(req.params.id);
    if (!station) {
      console.log('❌ Station not found');
      return res.status(404).json({ message: 'Station not found' });
    }

    await Station.findByIdAndDelete(req.params.id);
    console.log('✅ Station deleted successfully');
    res.json({ message: 'Station deleted successfully' });
  } catch (error) {
    console.error('❌ Error deleting station:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET stations count by series
router.get('/stats/series', async (req, res) => {
  try {
    console.log('📡 GET /api/stations/stats/series - Fetching stations count by series');
    const stats = await Station.aggregate([
      {
        $match: { 
          seriesName: { $ne: null, $ne: '', $exists: true },
          isStandalone: { $ne: true }
        }
      },
      {
        $group: {
          _id: '$seriesName',
          seriesName: { $first: '$seriesName' },
          count: { $sum: 1 },
          paidCount: { $sum: { $cond: ['$isPaid', 1, 0] } },
          freeCount: { $sum: { $cond: ['$isPaid', 0, 1] } }
        }
      },
      { $sort: { seriesName: 1 } }
    ]);
    console.log('✅ Stations count by series fetched successfully:', stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Error fetching stations count by series:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET search stations
router.get('/search/:query', async (req, res) => {
  try {
    console.log(`📡 GET /api/stations/search/${req.params.query} - Searching stations`);
    const query = req.params.query;
    const stations = await Station.find({
      $or: [
        { name: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { seriesName: { $regex: query, $options: 'i' } },
        { episodeTitle: { $regex: query, $options: 'i' } },
        { genre: { $regex: query, $options: 'i' } },
        { tags: { $in: [new RegExp(query, 'i')] } }
      ]
    }).sort({ createdAt: -1 });
    
    console.log(`✅ Found ${stations.length} stations matching query "${query}"`);
    res.json(stations);
  } catch (error) {
    console.error('❌ Error searching stations:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// Add a unified search endpoint that combines stations, series, and episodes
router.get('/unified-search/:query', async (req, res) => {
  try {
    console.log(`📡 GET /api/stations/unified-search/${req.params.query} - Unified search`);
    const query = req.params.query;
    
    // Search stations
    const stations = await Station.find({
      $or: [
        { name: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { genre: { $regex: query, $options: 'i' } }
      ]
    }).limit(10);
    
    // Search series
    const series = await Series.find({
      $or: [
        { name: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { genre: { $regex: query, $options: 'i' } }
      ]
    }).limit(5);
    
    // Group results with type indicators
    const results = {
      stations: stations.map(s => ({...s._doc, type: 'station'})),
      series: series.map(s => ({...s._doc, type: 'series'}))
    };
    
    console.log(`✅ Found ${stations.length} stations and ${series.length} series matching query "${query}"`);
    res.json(results);
  } catch (error) {
    console.error('❌ Error with unified search:', error.message);
    res.status(500).json({ message: error.message });
  }
});

console.log('✅ Station routes loaded successfully');

module.exports = router;
