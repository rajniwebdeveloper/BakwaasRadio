const mongoose = require('mongoose');

const radioSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true
  },
  description: {
    type: String,
    default: ''
  },
  imageUrl: {
    type: String,
    default: ''
  },
  audioUrl: {
    type: String,
    required: true
  },
  category: {
    type: String,
    default: 'General'
  },
  language: {
    type: String,
    default: 'English'
  },
  tags: {
    type: [String],
    default: []
  },
  isPaid: {
    type: Boolean,
    default: false
  },
  featured: {
    type: Boolean,
    default: false
  },
  views: {
    type: Number,
    default: 0
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

// Update the 'updatedAt' field on save
radioSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('Radio', radioSchema);
