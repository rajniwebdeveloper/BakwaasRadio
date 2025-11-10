const mongoose = require('mongoose');

console.log('📝 Loading Station model...');

const stationSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true
  },
  profilepic: {
    type: String,
    default: ''
  },
  banner: {
    type: String,
    default: ''
  },
  description: {
    type: String,
    default: ''
  },
  mp3Url: {
    type: String,
    required: true
  },
  isPaid: {
    type: Boolean,
    default: false
  },
  // Series relationship - only for episodes
  seriesName: {
    type: String,
    default: null  // null means standalone
  },
  episodeNumber: {
    type: Number,
    default: null  // null for standalone content
  },
  episodeTitle: {
    type: String,
    default: ''
  },
  duration: {
    type: String,
    default: ''
  },
  isStandalone: {
    type: Boolean,
    default: true  // Default to standalone
  },
  audioCount: {
    type: Number,
    default: 1
  },
  genre: {
    type: String,
    default: 'General'
  },
  contentLanguage: {  // Rename to contentLanguage to avoid confusion with MongoDB's language field
    type: String,
    default: 'Hindi'
  },
  tags: [{
    type: String
  }],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Add pre-save middleware to map language to contentLanguage 
// for backward compatibility during the transition
stationSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  // Auto-set isStandalone based on seriesName
  this.isStandalone = !this.seriesName;

  // Handle language field - ensure backward compatibility
  if (this.language && !this.contentLanguage) {
    this.contentLanguage = this.language;
  }

  next();
});

// Add a virtual getter/setter for language field for backward compatibility
stationSchema.virtual('language')
  .get(function() {
    return this.contentLanguage;
  })
  .set(function(value) {
    this.contentLanguage = value;
  });

// Ensure virtuals are included when converting to JSON
stationSchema.set('toJSON', { 
  virtuals: true,
  transform: function(doc, ret) {
    // Prevent both fields from showing up in API responses
    delete ret.language; // Remove the duplicate field
    ret.language = ret.contentLanguage; // Map contentLanguage back to language
    return ret;
  }
});

const Station = mongoose.model('Station', stationSchema);

console.log('✅ Station model loaded successfully');

module.exports = Station;
