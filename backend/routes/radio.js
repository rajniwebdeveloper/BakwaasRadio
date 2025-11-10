const express = require('express');
const router = express.Router();
const Radio = require('../models/Radio');

console.log('🛣️  Loading radio routes...');

// Helper function to generate player URL for radio items
function generateRadioPlayerUrl(radioItem) {
  const baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  return `${baseUrl}/player/radio/${radioItem._id}`;
}

// Helper function to format radio response with player URL
function formatRadioWithPlayerUrl(radioItem, showOriginal = false) {
  const formatted = {
    ...radioItem.toObject ? radioItem.toObject() : radioItem,
    // Only include originalAudioUrl when showing originals for admin purposes
    ...(showOriginal && { originalAudioUrl: radioItem.audioUrl })
  };
  
  // If showOriginal is true, keep the original audioUrl
  if (showOriginal) {
    formatted.mp3Url = radioItem.audioUrl; // Keep original URL
    formatted.audioUrl = radioItem.audioUrl; // Keep original URL
    formatted.playerUrl = generateRadioPlayerUrl(radioItem); // Still include player URL for reference
  } else {
    formatted.mp3Url = generateRadioPlayerUrl(radioItem); // Keep original URL
    formatted.audioUrl = generateRadioPlayerUrl(radioItem); // Replace with player URL
    formatted.playerUrl = generateRadioPlayerUrl(radioItem); // Add explicit player URL
  }
  
  return formatted;
}

// GET all radio items with enhanced pagination and search
router.get('/', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    const search = req.query.search || '';
    const category = req.query.category || '';
    const featured = req.query.featured;
    const showOriginal = req.query.show === 'original';

    console.log(`📡 GET /api/radio - Page: ${page}, Limit: ${limit}, Search: "${search}", Category: "${category}", Featured: ${featured}, ShowOriginal: ${showOriginal}`);

    // Build search query
    let query = {};
    
    if (search) {
      query.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { tags: { $in: [new RegExp(search, 'i')] } },
        { category: { $regex: search, $options: 'i' } }
      ];
    }
    
    if (category) {
      query.category = category;
    }
    
    if (featured === 'true') {
      query.featured = true;
    }

    const total = await Radio.countDocuments(query);
    const radioItems = await Radio.find(query)
      .select('_id title description imageUrl audioUrl category language tags isPaid featured views duration createdAt updatedAt')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    console.log(`✅ Found ${radioItems.length} radio items (${total} total)`);
    
    // Format the items with complete data and player URLs
    const formattedItems = radioItems.map(item => {
      const baseFormatted = {
        _id: item._id,
        title: item.title || 'Untitled Radio',
        description: item.description || '',
        imageUrl: item.imageUrl || '',
        category: item.category || 'General',
        language: item.language || 'English',
        tags: Array.isArray(item.tags) ? item.tags : [],
        isPaid: item.isPaid || false,
        featured: item.featured || false,
        views: item.views || 0,
        duration: item.duration || '',
        createdAt: item.createdAt,
        updatedAt: item.updatedAt
      };

      // Add player URL if audioUrl exists
      if (item.audioUrl) {
        baseFormatted.originalAudioUrl = item.audioUrl;
        if (!showOriginal) {
          baseFormatted.audioUrl = generateRadioPlayerUrl(item);
          baseFormatted.playerUrl = generateRadioPlayerUrl(item);
        } else {
          baseFormatted.audioUrl = item.audioUrl; // Keep original
          baseFormatted.playerUrl = generateRadioPlayerUrl(item);
        }
      } else {
        baseFormatted.audioUrl = '';
        baseFormatted.playerUrl = '';
      }

      return baseFormatted;
    });
    
    res.json({
      data: formattedItems,
      pagination: {
        current: page,
        total: Math.ceil(total / limit),
        count: formattedItems.length,
        totalItems: total
      },
      meta: {
        timestamp: new Date().toISOString(),
        version: "1.0",
        developer: "Rajni Web Developer"
      }
    });
  } catch (error) {
    console.error('❌ Error fetching radio items:', error.message);
    res.status(500).json({
      data: [],
      pagination: {
        current: 1,
        total: 0,
        count: 0,
        totalItems: 0
      },
      error: error.message
    });
  }
});

// GET all radio items (simple list for compatibility)
router.get('/list', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/radio/list - Fetching complete radio items list. ShowOriginal: ${showOriginal}`);
    const items = await Radio.find()
      .select('_id title description imageUrl audioUrl category language tags isPaid featured views duration createdAt updatedAt')
      .sort({ createdAt: -1 });
    
    console.log(`✅ Found ${items.length} radio items`);
    
    // Ensure all fields are properly formatted
    const formattedItems = items.map(item => {
      const formatted = {
        _id: item._id,
        title: item.title || 'Untitled Radio',
        description: item.description || '',
        imageUrl: item.imageUrl || '',
        category: item.category || 'General',
        language: item.language || 'English',
        tags: Array.isArray(item.tags) ? item.tags : [],
        isPaid: item.isPaid || false,
        featured: item.featured || false,
        views: item.views || 0,
        duration: item.duration || '',
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        originalAudioUrl: item.audioUrl
      };
      
      if (showOriginal) {
        formatted.audioUrl = item.audioUrl; // Keep original URL
      } else {
        formatted.audioUrl = generateRadioPlayerUrl(item);
      }
      
      formatted.playerUrl = generateRadioPlayerUrl(item);
      return formatted;
    });
    
    res.json(formattedItems);
  } catch (error) {
    console.error('❌ Error fetching radio items list:', error.message);
    res.status(500).json({ message: error.message, data: [] });
  }
});

// GET radio item by ID
router.get('/:id', async (req, res) => {
  try {
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/radio/${req.params.id} - Fetching radio item by ID. ShowOriginal: ${showOriginal}`);
    const radioItem = await Radio.findById(req.params.id);
    
    if (!radioItem) {
      return res.status(404).json({ message: 'Radio item not found' });
    }
    
    // Increment views
    radioItem.views += 1;
    await radioItem.save();
    
    console.log('✅ Radio item found:', radioItem.title);
    res.json(formatRadioWithPlayerUrl(radioItem, showOriginal));
  } catch (error) {
    console.error('❌ Error fetching radio item:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET radio items by category
router.get('/category/:category', async (req, res) => {
  try {
    const category = req.params.category;
    const limit = parseInt(req.query.limit) || 20;
    const showOriginal = req.query.show === 'original';
    
    console.log(`📡 GET /api/radio/category/${category} - Fetching radio items by category. ShowOriginal: ${showOriginal}`);
    
    const radioItems = await Radio.find({ category: category })
      .sort({ createdAt: -1 })
      .limit(limit);
      
    console.log(`✅ Found ${radioItems.length} radio items in category ${category}`);
    res.json(radioItems.map(item => formatRadioWithPlayerUrl(item, showOriginal)));
  } catch (error) {
    console.error('❌ Error fetching radio items by category:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET featured radio items
router.get('/featured/list', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/radio/featured/list - Fetching featured radio items. ShowOriginal: ${showOriginal}`);
    
    const radioItems = await Radio.find({ featured: true })
      .sort({ createdAt: -1 })
      .limit(limit);
      
    console.log(`✅ Found ${radioItems.length} featured radio items`);
    res.json(radioItems.map(item => formatRadioWithPlayerUrl(item, showOriginal)));
  } catch (error) {
    console.error('❌ Error fetching featured radio items:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// Search radio items
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    const limit = parseInt(req.query.limit) || 20;
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/radio/search - Searching radio items: ${query}. ShowOriginal: ${showOriginal}`);
    
    const items = await Radio.find({
      $or: [
        { title: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { artist: { $regex: query, $options: 'i' } },
        { category: { $regex: query, $options: 'i' } }
      ]
    }).sort({ createdAt: -1 }).limit(limit);
    
    console.log(`✅ Found ${items.length} radio items matching query: ${query}`);
    res.json(items.map(item => formatRadioWithPlayerUrl(item, showOriginal)));
  } catch (error) {
    console.error('❌ Error searching radio items:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// Search radio items - fix the search endpoint
router.get('/search/:query', async (req, res) => {
  try {
    const query = req.params.query;
    const limit = parseInt(req.query.limit) || 20;
    const showOriginal = req.query.show === 'original';
    console.log(`📡 GET /api/radio/search/${query} - Searching radio items. ShowOriginal: ${showOriginal}`);
    
    const items = await Radio.find({
      $or: [
        { title: { $regex: query, $options: 'i' } },
        { description: { $regex: query, $options: 'i' } },
        { category: { $regex: query, $options: 'i' } },
        { tags: { $in: [new RegExp(query, 'i')] } }
      ]
    }).sort({ createdAt: -1 }).limit(limit);
    
    console.log(`✅ Found ${items.length} radio items matching query: ${query}`);
    res.json(items.map(item => formatRadioWithPlayerUrl(item, showOriginal)));
  } catch (error) {
    console.error('❌ Error searching radio items:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET radio statistics
router.get('/stats/overview', async (req, res) => {
  try {
    console.log('📡 GET /api/radio/stats/overview - Fetching radio statistics');
    
    const totalItems = await Radio.countDocuments();
    const premiumItems = await Radio.countDocuments({ isPaid: true });
    const featuredItems = await Radio.countDocuments({ featured: true });
    const categories = await Radio.distinct('category');
    
    const stats = {
      totalItems,
      premiumItems,
      freeItems: totalItems - premiumItems,
      featuredItems,
      totalCategories: categories.length,
      categories
    };
    
    console.log('✅ Radio statistics calculated:', stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Error fetching radio statistics:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// POST create new radio item
router.post('/', async (req, res) => {
  try {
    console.log('📡 POST /api/radio - Creating new radio item');
    
    const radioItem = new Radio({
      title: req.body.title,
      description: req.body.description || '',
      imageUrl: req.body.imageUrl || '',
      audioUrl: req.body.audioUrl,
      category: req.body.category || 'General',
      language: req.body.language || 'English',
      tags: req.body.tags || [],
      isPaid: req.body.isPaid || false,
      featured: req.body.featured || false
    });
    
    const newRadioItem = await radioItem.save();
    console.log('✅ Radio item created successfully:', newRadioItem.title);
    res.status(201).json(formatRadioWithPlayerUrl(newRadioItem));
  } catch (error) {
    console.error('❌ Error creating radio item:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// PUT update radio item
router.put('/:id', async (req, res) => {
  try {
    console.log(`📡 PUT /api/radio/${req.params.id} - Updating radio item`);
    const updatedRadioItem = await Radio.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!updatedRadioItem) {
      return res.status(404).json({ message: 'Radio item not found' });
    }
    console.log('✅ Radio item updated successfully:', updatedRadioItem.title);
    res.json(formatRadioWithPlayerUrl(updatedRadioItem));
  } catch (error) {
    console.error('❌ Error updating radio item:', error.message);
    res.status(400).json({ message: error.message });
  }
});

// DELETE radio item
router.delete('/:id', async (req, res) => {
  try {
    console.log(`📡 DELETE /api/radio/${req.params.id} - Deleting radio item`);
    
    const radioItem = await Radio.findById(req.params.id);
    if (!radioItem) {
      return res.status(404).json({ message: 'Radio item not found' });
    }
    
    await Radio.findByIdAndDelete(req.params.id);
    console.log('✅ Radio item deleted successfully');
    res.json({ message: 'Radio item deleted successfully' });
  } catch (error) {
    console.error('❌ Error deleting radio item:', error.message);
    res.status(500).json({ message: error.message });
  }
});

// GET categories
router.get('/meta/categories', async (req, res) => {
  try {
    console.log('📡 GET /api/radio/meta/categories - Fetching radio categories');
    const categories = await Radio.distinct('category');
    console.log(`✅ Found ${categories.length} categories`);
    res.json(categories);
  } catch (error) {
    console.error('❌ Error fetching categories:', error.message);
    res.status(500).json({ message: error.message });
  }
});

console.log('✅ Radio routes loaded successfully');

module.exports = router;
