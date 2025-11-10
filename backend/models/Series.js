const mongoose = require('mongoose');

console.log('📝 Loading Series model...');

const seriesSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true
  },
  description: {
    type: String,
    default: ''
  },
  profilepic: {
    type: String,
    default: ''
  },
  banner: {
    type: String,
    default: ''
  },
  genre: {
    type: String,
    default: 'General'
  },
  language: {
    type: String,
    default: 'Hindi'
  },
  tags: [{
    type: String
  }],
  isActive: {
    type: Boolean,
    default: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

seriesSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

const Series = mongoose.model('Series', seriesSchema);

console.log('✅ Series model loaded successfully');

module.exports = Series;
