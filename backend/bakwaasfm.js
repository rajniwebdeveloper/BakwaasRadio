const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3222;

console.log('🚀 Starting BakwaasFM Server...');

// Middleware - Allow all CORS requests
const corsOptions = {
  origin: '*', // Allow all origins
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
  allowedHeaders: '*', // Allow all headers
  exposedHeaders: '*', // Expose all headers
  credentials: false, // Set to false when origin is '*'
  preflightContinue: false,
  optionsSuccessStatus: 204,
  maxAge: 86400 // Cache preflight for 24 hours
};

app.use(cors(corsOptions));

// Handle preflight requests for all routes
app.options('*', cors(corsOptions));

app.use(express.json());


app.use(express.static(path.join(__dirname, 'public')));

console.log('✅ Middleware configured');

// MongoDB connection
console.log('🔌 Connecting to MongoDB...');
mongoose.connect('mongodb://BakwaasFM:BakwaasFM@65.21.22.62:27017/bakwaasfm', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => {
  console.log('✅ MongoDB connected successfully');
})
.catch((error) => {
  console.error('❌ MongoDB connection error:', error.message);
  process.exit(1);
});

// MongoDB connection events
mongoose.connection.on('connected', () => {
  console.log('📊 Mongoose connected to MongoDB');
});

mongoose.connection.on('error', (err) => {
  console.error('❌ Mongoose connection error:', err);
});

mongoose.connection.on('disconnected', () => {
  console.log('⚠️  Mongoose disconnected');
});

// Routes
console.log('🛣️  Setting up routes...');
app.use('/api/stations', require('./routes/stations'));
app.use('/api/streams', require('./routes/streams'));
app.use('/api/radio', require('./routes/radio'));
app.use('/api', require('./routes/api')); // Add the main API routes
app.use('/api/search', require('./routes/search')); // Add the search route
app.use('/api/update', require('./routes/update'));


// Add player proxy route
app.use('/player', require('./routes/player'));

// Add proxy route for images and media
app.use('/proxy', require('./routes/proxy'));

// Add a test endpoint to verify API is working
app.get('/api/health', (req, res) => {
  console.log('🏥 Health check endpoint accessed');
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0'
  });
});

// Serve admin control panel
app.get('/admincp', (req, res) => {
  console.log('📋 Admin panel accessed');
  res.sendFile(path.join(__dirname, 'public', 'admincp.html'));
});

// Serve admin control panel
app.get('/admincp2', (req, res) => {
  console.log('📋 Admin panel accessed');
  res.sendFile(path.join(__dirname, 'public', 'admincp2.html'));
});

// Serve BakwaasFM website on root route
app.get('/', (req, res) => {
  console.log('🏠 Home page accessed');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Serve Privacy Policy
app.get('/privacy', (req, res) => {
  console.log('📋 Privacy Policy accessed');
  res.sendFile(path.join(__dirname, 'public', 'privacy.html'));
});

// Serve Terms & Conditions
app.get('/terms', (req, res) => {
  console.log('📋 Terms & Conditions accessed');
  res.sendFile(path.join(__dirname, 'public', 'terms.html'));
});

// Serve Contact Page (redirect to main site for now)
app.get('/contact', (req, res) => {
  console.log('📋 Contact page accessed - redirecting');
  res.redirect('/#contact');
});

// Serve app-ads.txt for ad verification
app.get('/app-ads.txt', (req, res) => {
  console.log('📋 app-ads.txt accessed');
  res.setHeader('Content-Type', 'text/plain');
  res.send('google.com, pub-5650183670072748, DIRECT, f08c47fec0942fa0');
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('❌ Server error:', err.stack);
  res.status(500).json({ message: 'Something went wrong!' });
});

// 404 handler
// app.use((req, res) => {
//   console.log(`⚠️  404 - Route not found: ${req.method} ${req.url}`);
//   res.status(404).json({ message: 'Route not found' });
// });

// Handle 404 errors
app.use((req, res, next) => {
  console.log(`⚠️ 404 Not Found: ${req.originalUrl}`);
  res.status(404).json({
    error: 'Not Found',
    message: `The requested resource '${req.originalUrl}' was not found on this server.`
  });
});
// Start server
app.listen(PORT, () => {
  console.log('');
  console.log('🎉 ========================================');
  console.log(`🚀 BakwaasFM Server is running!`);
  console.log(`📡 Port: ${PORT}`);
  console.log(`🌐 Website: http://localhost:${PORT}`);
  console.log(`⚙️  Admin Panel: http://localhost:${PORT}/admincp`);
  console.log(`📊 API Base: http://localhost:${PORT}/api`);
  console.log('🎉 ========================================');
  console.log('');
});

// Handle process termination
// process.on('SIGINT', () => {
//   console.log('\n🛑 Received SIGINT. Graceful shutdown...');
//   // mongoose.connection.close(() => {
//   //   console.log('📊 MongoDB connection closed.');
//   //   process.exit(0);
//   // });
// });

// process.on('SIGTERM', () => {
//   console.log('\n🛑 Received SIGTERM. Graceful shutdown...');
//   // mongoose.connection.close(() => {
//   //   console.log('📊 MongoDB connection closed.');
//   //   process.exit(0);
//   // });
// });

// Catch unhandled promise rejections
// process.on('unhandledRejection', (reason, promise) => {
//   console.error('⚠️ Unhandled Promise Rejection:', reason);
//   // Don't exit the process, just log the error
// });
