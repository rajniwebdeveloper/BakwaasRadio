const mongoose = require('mongoose');

const DeviceSchema = new mongoose.Schema({
  deviceId: { type: String },
  deviceName: { type: String },
  userAgent: { type: String },
  ip: { type: String },
  mode: { type: String }, // e.g. 'web', 'android', 'ios', 'desktop'
  lastSeen: { type: Date, default: Date.now }
}, { _id: false });

const PlanSchema = new mongoose.Schema({
  name: { type: String },
  planType: { type: String },
  adsEnabled: { type: Boolean, default: true },
  expiresAt: { type: Date }
}, { _id: false });

const UserSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true },
  devices: { type: [DeviceSchema], default: [] },
  plan: { type: PlanSchema, default: {} },
  // Store last login as a small object with datetime and device info
  lastLogin: {
    dateTime: { type: Date },
    mode: { type: String },
    deviceId: { type: String },
    deviceName: { type: String },
    ip: { type: String }
  },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('User', UserSchema);
