const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const ytdl = require('@distube/ytdl-core'); // Updated to @distube/ytdl-core
const { URL } = require('url');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-jwt-secret';
const JWT_EXPIRY = process.env.JWT_EXPIRY || '14d';
const JWT_LONG_EXPIRY = process.env.JWT_LONG_EXPIRY || '365d';

// Image encryption key (32 bytes for AES-256). Set via env var in production.
const IMAGE_SECRET = process.env.IMAGE_SECRET || '0123456789abcdef0123456789abcdef';

// Helper to compute an expiry Date from a jwt-style expiry string like '14d' or '365d' or '12h' or '1y'
function computeExpiryDate(expiryStr) {
    if (!expiryStr || typeof expiryStr !== 'string') return null;
    const now = Date.now();
    const num = parseInt(expiryStr, 10);
    if (expiryStr.endsWith('d')) {
        return new Date(now + (num * 24 * 60 * 60 * 1000));
    }
    if (expiryStr.endsWith('h')) {
        return new Date(now + (num * 60 * 60 * 1000));
    }
    if (expiryStr.endsWith('y')) {
        return new Date(now + (num * 365 * 24 * 60 * 60 * 1000));
    }
    // fallback: try parse as milliseconds
    const asNum = Number(expiryStr);
    if (!isNaN(asNum)) return new Date(now + asNum);
    return null;
}

// Return a proxied image URL for client consumption to avoid CORS issues.
function encryptUrl(url) {
    if (!url) return null;
    try {
        const key = Buffer.from(IMAGE_SECRET, 'utf8');
        // IV 12 bytes for GCM
        const iv = crypto.randomBytes(12);
        const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
        const encrypted = Buffer.concat([cipher.update(url, 'utf8'), cipher.final()]);
        const tag = cipher.getAuthTag();
        // concat iv + tag + encrypted
        const out = Buffer.concat([iv, tag, encrypted]).toString('base64');
        return out;
    } catch (e) {
        console.error('encryptUrl error', e.message);
        return null;
    }
}

function decryptUrl(token) {
    if (!token) return null;
    try {
        const key = Buffer.from(IMAGE_SECRET, 'utf8');
        const buf = Buffer.from(token, 'base64');
        // iv (12) + tag (16) + ciphertext
        const iv = buf.slice(0, 12);
        const tag = buf.slice(12, 28);
        const data = buf.slice(28);
        const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
        decipher.setAuthTag(tag);
        const decrypted = Buffer.concat([decipher.update(data), decipher.final()]);
        return decrypted.toString('utf8');
    } catch (e) {
        console.error('decryptUrl error', e.message);
        return null;
    }
}

// Return a proxied image URL tokenized with AES-GCM into `c` parameter
function proxiedImage(u) {
    if (!u) return null;
    try {
        if (typeof u !== 'string') return null;
        // If already proxied (legacy), return as-is
        if (u.startsWith('/api/image') || u.startsWith('/api/')) return u;
        const token = encryptUrl(u);
        if (!token) return null;
        return `/api/image?c=${encodeURIComponent(token)}`;
    } catch (_) { return u; }
}

/**
 * Process external URL to determine if it can be played or downloaded
 */
router.post('/process-url', async (req, res) => {
    try {
        const {url} = req.body;
        console.log(req.body)
        
        if (!url || typeof url !== 'string') {
            return res.status(200).json(createStandardResponse({
                error: 'Invalid URL provided',
                mediaName: "Invalid URL Format" 
            }));
        }
        
        console.log(`🔄 Processing URL: ${url}`);
        
        // Enhanced URL validation with better error handling
        let parsedUrl;
        try {
            parsedUrl = new URL(url);
        } catch (e) {
            return res.status(200).json(createStandardResponse({
                error: 'Invalid URL format',
                mediaName: "Invalid URL Format",
                url: url  // Return the original URL for debugging
            }));
        }
        
        // Process different URL types
        if (url.includes('youtube.com') || url.includes('youtu.be')) {
            // YouTube URL processing with improved error handling
            try {
                console.log('Processing YouTube URL...');
                
                // Extract video ID from URL with better validation
                const videoId = extractVideoId(url);
                if (!videoId) {
                    return res.status(200).json(createStandardResponse({
                        error: 'Could not extract valid YouTube video ID from URL',
                        mediaName: "Invalid YouTube URL",
                        url: url,
                        isYoutube: true
                    }));
                }
                
                console.log(`Extracted YouTube video ID: ${videoId}`);
                
                // Try to get video info - wrap in try/catch for better error handling
                try {
                    // Get high quality URLs using ytdl-core
                    const ytdlUrls = await getYtdlHighQualityUrls(videoId);
                    
                    if (!ytdlUrls.videoInfo) {
                        throw new Error('Failed to retrieve video information');
                    }
                    
                    const videoInfo = ytdlUrls.videoInfo;
                    const videoDetails = videoInfo.videoDetails;
                    
                    console.log(`Successfully retrieved info for: ${videoDetails.title}`);
                    
                    // Create media URLs array with different quality options
                    const mediaUrls = [];
                    
                    // Add best audio option with direct player URL
                    if (ytdlUrls.audioUrl) {
                        mediaUrls.push({
                            id: `audio-${videoId}`,
                            download: true,
                            playback: true,
                            isVideo: false,
                            isAudio: true,
                            videoUrl: null,
                            audioUrl: ytdlUrls.audioUrl,
                            name: `${videoDetails.title} (Audio)`,
                            quality: "High Quality Audio",
                            thumbnail: proxiedImage(videoDetails.thumbnails[0].url),
                            isPaid: false,
                            directPlayUrl: `/api/youtube/audio/${videoId}`
                        });
                    }
                    
                    // Add best video option
                    if (ytdlUrls.videoUrl) {
                        mediaUrls.push({
                            id: `video-${videoId}`,
                            download: true,
                            playback: true,
                            isVideo: true,
                            isAudio: false,
                            videoUrl: ytdlUrls.videoUrl,
                            audioUrl: null,
                            name: `${videoDetails.title} (Video)`,
                            quality: "High Quality Video",
                            thumbnail: proxiedImage(videoDetails.thumbnails[0].url),
                            isPaid: false
                        });
                    }
                    
                    // Add optimal combined format if available
                    if (ytdlUrls.optimalUrl) {
                        mediaUrls.push({
                            id: `optimal-${videoId}`,
                            download: true,
                            playback: true,
                            isVideo: true,
                            isAudio: true,
                            videoUrl: ytdlUrls.optimalUrl,
                            audioUrl: ytdlUrls.optimalUrl,
                            name: `${videoDetails.title} (Audio & Video)`,
                            quality: "Combined Audio & Video",
                            thumbnail: proxiedImage(videoDetails.thumbnails[0].url),
                            isPaid: false
                        });
                    }
                    
                    // If no media URLs were found, return error response
                    if (mediaUrls.length === 0) {
                        return res.status(200).json(createStandardResponse({
                            error: 'No playable formats found for this YouTube video',
                            mediaName: videoDetails.title || "YouTube Video",
                            youtubeId: videoId,
                            isYoutube: true,
                            url: url
                        }));
                    }
                    
                    // Create response with the best URL as primary and all options in mediaUrls
                    const bestUrl = ytdlUrls.optimalUrl || ytdlUrls.audioUrl || ytdlUrls.videoUrl;
                    
                    const result = {
                        download: true,
                        playback: true,
                        isVideo: !!ytdlUrls.videoUrl,
                        isAudio: !!ytdlUrls.audioUrl,
                        videoUrl: ytdlUrls.videoUrl || null,
                        audioUrl: ytdlUrls.audioUrl || null,
                        mediaUrl: bestUrl, // For backward compatibility
                        name: videoDetails.title,
                        mediaName: videoDetails.title, // For backward compatibility
                        thumbnail: proxiedImage(videoDetails.thumbnails[videoDetails.thumbnails.length - 1].url),
                        image: proxiedImage(videoDetails.thumbnails[videoDetails.thumbnails.length - 1].url),
                        isPaid: videoDetails.isPrivate || false,
                        description: videoDetails.description || '',
                        mediaUrls: mediaUrls,
                        // YouTube-specific fields for easier front-end handling
                        isYoutube: true,
                        youtubeId: videoId,
                        // Direct audio player endpoint - most important for automatic audio playback
                        directAudioUrl: `/api/youtube/audio/${videoId}`,
                        // Auto-play hint for front-end
                        autoPlay: true,
                        // Additional useful YouTube metadata
                        author: videoDetails.author ? videoDetails.author.name : '',
                        lengthSeconds: videoDetails.lengthSeconds,
                        viewCount: videoDetails.viewCount,
                        // Include original URL for reference
                        originalUrl: url
                    };
                    
                    console.log('YouTube processing success:', result.name);
                    console.log('Media URLs found:', mediaUrls.length);
                    
                    return res.status(200).json(result);
                } catch (videoError) {
                    // Video-specific error handling
                    console.error('❌ YouTube video info error:', videoError.message);
                    
                    // Return a user-friendly response with direct playback option
                    return res.status(200).json(createStandardResponse({
                        error: `Could not get video details: ${videoError.message}`,
                        mediaName: "YouTube Video",
                        mediaUrl: url,
                        isYoutube: true,
                        youtubeId: videoId,
                        // Always include direct play URL even if error occurs
                        directAudioUrl: `/api/youtube/audio/${videoId}`,
                        autoPlay: true,
                        // Include fallback thumbnail
                        thumbnail: proxiedImage(`https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`),
                        image: proxiedImage(`https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`)
                    }));
                }
            } catch (error) {
                console.error('❌ YouTube processing error:', error.message);
                // Extract video ID if possible even if processing failed
                const videoId = extractVideoId(url);
                
                // Return useful information even in error case
                return res.status(200).json(createStandardResponse({
                    error: `YouTube processing error: ${error.message}`,
                    mediaName: "YouTube Link",
                    mediaUrl: url,
                    isYoutube: true,
                    youtubeId: videoId,
                    // Include direct play URL if we have a video ID
                    ...(videoId && {
                        directAudioUrl: `/api/youtube/audio/${videoId}`,
                        autoPlay: true,
                        thumbnail: proxiedImage(`https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`),
                        image: proxiedImage(`https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`)
                    })
                }));
            }
        } else if (url.endsWith('.mp3') || url.endsWith('.m4a') || url.endsWith('.ogg') || url.endsWith('.wav')) {
            // Direct audio file URL
            const fileName = url.split('/').pop().split('?')[0];
            return res.status(200).json({
                download: true,
                playback: true,
                isVideo: false,
                isAudio: true,
                videoUrl: null,
                audioUrl: url,
                mediaUrl: url, // For backward compatibility
                name: fileName,
                mediaName: fileName, // For backward compatibility
                thumbnail: null,
                image: null,
                isPaid: false,
                mediaUrls: [{
                    id: `audio-${Date.now()}`,
                    download: true,
                    playback: true,
                    isVideo: false,
                    isAudio: true,
                    videoUrl: null,
                    audioUrl: url,
                    name: fileName,
                    quality: "Audio File",
                    thumbnail: null,
                    isPaid: false
                }]
            });
        } else if (url.endsWith('.mp4') || url.endsWith('.webm') || url.endsWith('.mkv') || url.endsWith('.mov')) {
            // Direct video file URL
            const fileName = url.split('/').pop().split('?')[0];
            return res.status(200).json({
                download: true,
                playback: true,
                isVideo: true,
                isAudio: false,
                videoUrl: url,
                audioUrl: null,
                mediaUrl: url, // For backward compatibility
                name: fileName,
                mediaName: fileName, // For backward compatibility
                thumbnail: null,
                image: null,
                isPaid: false,
                mediaUrls: [{
                    id: `video-${Date.now()}`,
                    download: true,
                    playback: true,
                    isVideo: true,
                    isAudio: false,
                    videoUrl: url,
                    audioUrl: null,
                    name: fileName,
                    quality: "Video File",
                    thumbnail: null,
                    isPaid: false
                }]
            });
        } else {
            // For other URLs, just check if they're audio/video by fetching headers
            try {
                const response = await axios.head(url, {
                    timeout: 5000,  // 5 second timeout
                    maxRedirects: 5  // Maximum of 5 redirects
                });
                
                const contentType = response.headers['content-type'] || '';
                const fileName = url.split('/').pop().split('?')[0] || 'Media File';
                
                const isAudio = contentType.includes('audio');
                const isVideo = contentType.includes('video');
                const isMedia = isAudio || isVideo || url.includes('stream') || url.includes('media');
                
                if (isMedia) {
                    return res.status(200).json({
                        download: true,
                        playback: true,
                        isVideo: isVideo,
                        isAudio: isAudio,
                        videoUrl: isVideo ? url : null,
                        audioUrl: isAudio ? url : null,
                        mediaUrl: url, // For backward compatibility
                        name: fileName,
                        mediaName: fileName, // For backward compatibility
                        thumbnail: null,
                        image: null,
                        isPaid: false,
                        contentType: contentType,
                        mediaUrls: [{
                            id: `media-${Date.now()}`,
                            download: true,
                            playback: true,
                            isVideo: isVideo,
                            isAudio: isAudio,
                            videoUrl: isVideo ? url : null,
                            audioUrl: isAudio ? url : null,
                            name: fileName,
                            quality: contentType,
                            thumbnail: null,
                            isPaid: false
                        }]
                    });
                } else {
                    // Return success but with flags set to false
                    return res.status(200).json(createStandardResponse({
                        mediaUrl: url,
                        mediaName: fileName,
                        message: "This URL doesn't appear to be a supported media file"
                    }));
                }
            } catch (error) {
                console.error('❌ Error checking URL:', error.message);
                return res.status(200).json(createStandardResponse({
                    mediaUrl: url,
                    mediaName: 'Unsupported Link',
                    error: `This link couldn't be analyzed: ${error.message}`
                }));
            }
        }
    } catch (error) {
        console.error('❌ URL processing error:', error);
        res.status(200).json(createStandardResponse({
            error: `Server error: ${error.message}`,
            mediaName: 'Error Processing URL',
            url: req.body
        }));
    }
});

/**
 * Direct URL processing endpoint - handles URLs directly through GET
 * This is useful for direct sharing of YouTube links
 */
router.get('/direct-url', async (req, res) => {
    try {
        const url = req.query.url;
        
        if (!url) {
            return res.status(400).json({
                error: 'Missing URL parameter',
                message: 'Please provide a URL in the query parameter'
            });
        }
        
        console.log(`🔄 Processing direct URL: ${url}`);
        
        // For YouTube URLs, redirect to the player directly
        if (url.includes('youtube.com') || url.includes('youtu.be')) {
            const videoId = extractVideoId(url);
            if (videoId) {
                // Redirect to audio player
                return res.redirect(`/api/youtube/audio/${videoId}`);
            }
        }
        
        // For other URLs, redirect to the main app with the URL as a parameter
        res.redirect(`/?url=${encodeURIComponent(url)}`);
        
    } catch (error) {
        console.error('❌ Direct URL processing error:', error);
        res.status(500).json({
            error: 'Failed to process URL',
            message: error.message
        });
    }
});

/**
 * New endpoint: Get direct YouTube audio stream
 * This allows immediate audio playback of YouTube videos
 */
router.get('/youtube/audio/:videoId', async (req, res) => {
    try {
        const videoId = req.params.videoId;
        console.log(`🎵 Streaming YouTube audio for video ID: ${videoId}`);
        
        if (!videoId || videoId.length !== 11) {
            return res.status(400).json({ error: 'Invalid YouTube video ID' });
        }
        
        // Get audio URL using ytdl-core with better error handling
        try {
            const info = await ytdl.getInfo(`https://www.youtube.com/watch?v=${videoId}`);
            
            // Get highest quality audio format
            const audioFormats = info.formats.filter(format => 
                format.mimeType?.includes('audio') && !format.hasVideo
            );
            
            if (!audioFormats || audioFormats.length === 0) {
                throw new Error('No audio formats found for this video');
            }
            
            // Sort by bitrate, highest first
            const bestAudio = audioFormats.sort((a, b) => b.audioBitrate - a.audioBitrate)[0];
            
            // Set appropriate headers for improved streaming
            if (bestAudio.mimeType) {
                const contentType = bestAudio.mimeType.split(';')[0];
                res.setHeader('Content-Type', contentType);
                console.log(`✅ Set Content-Type to: ${contentType}`);
            }
            
            // Set caching headers for better performance
            res.setHeader('Cache-Control', 'public, max-age=3600'); // 1 hour cache
            
            // Option 1: Redirect to the audio URL (simpler, less server load)
            console.log(`✅ Redirecting to audio URL for: ${info.videoDetails.title}`);
            console.log(`✅ Audio URL (first 100 chars): ${bestAudio.url.substring(0, 100)}...`);
            return res.redirect(bestAudio.url);
            
        } catch (error) {
            console.error('❌ Error getting audio info:', error.message);
            
            // Try fallback method: direct streaming
            console.log('🔄 Trying fallback method - direct streaming...');
            try {
                const audioStream = ytdl(`https://www.youtube.com/watch?v=${videoId}`, {
                    quality: 'highestaudio',
                    filter: 'audioonly',
                });
                
                res.setHeader('Content-Type', 'audio/mpeg');
                audioStream.pipe(res);
                return;
            } catch (fallbackError) {
                // If fallback also fails, then return error
                throw new Error(`Failed to stream audio: ${error.message}. Fallback also failed: ${fallbackError.message}`);
            }
        }
    } catch (error) {
        console.error('❌ Error streaming YouTube audio:', error.message);
        
        // Provide a user-friendly error page
        res.status(500).send(`
            <html>
                <head>
                    <title>Audio Streaming Error</title>
                    <style>
                        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
                        .error { color: #e74c3c; }
                        .back { margin-top: 20px; }
                    </style>
                </head>
                <body>
                    <h2 class="error">Failed to stream audio</h2>
                    <p>${error.message}</p>
                    <div class="back">
                        <a href="/">Go back to home</a>
                    </div>
                </body>
            </html>
        `);
    }
});

/**
 * Image endpoint that accepts an encrypted token and streams the underlying
 * image. Usage: GET /api/image?c=<base64-token>
 * For compatibility this also accepts `u=<plain-url>` but prefer `c`.
 */
router.get('/image', async (req, res) => {
    try {
        const code = req.query.c || req.query.code;
        let url = null;
        if (code && typeof code === 'string') {
            url = decryptUrl(code);
        }
        // Fallback to plain url if provided (legacy)
        if (!url) {
            const plain = req.query.u || req.query.url;
            if (plain && typeof plain === 'string') url = plain;
        }
        if (!url) return res.status(400).send('Missing url');
        const parsed = new URL(url);
        if (!['http:', 'https:'].includes(parsed.protocol)) return res.status(400).send('Invalid protocol');

        const resp = await axios.get(url, { responseType: 'stream', timeout: 8000, maxRedirects: 5 });
        const contentType = resp.headers['content-type'] || 'application/octet-stream';
        res.setHeader('Content-Type', contentType);
        res.setHeader('Cache-Control', 'public, max-age=3600');
        resp.data.pipe(res);
    } catch (e) {
        console.error('image endpoint error', e.message);
        res.status(502).send('Failed to fetch image');
    }
});

/**
 * Extract video ID from YouTube URL with improved validation
 */
function extractVideoId(url) {
    // Handle different YouTube URL formats
    const patterns = [
        /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/i, // Standard
        /(?:youtube\.com\/shorts\/)([^"&?\/\s]{11})/i, // Shorts
        /(?:music\.youtube\.com\/watch\?v=)([^"&?\/\s]{11})/i // YouTube Music
    ];
    
    for (const pattern of patterns) {
        const match = url.match(pattern);
        if (match && match[1]) {
            return match[1];
        }
    }
    
    return null;
}

/**
 * Helper function to get high quality URLs using ytdl-core
 */
async function getYtdlHighQualityUrls(videoId) {
    try {
        console.log(`Getting high quality URLs for video ID: ${videoId}`);
        
        // Get full video info including formats
        const info = await ytdl.getInfo(`https://www.youtube.com/watch?v=${videoId}`);
        
        // Filter for audio-only formats
        const audioFormats = info.formats.filter(format => 
            format.mimeType?.includes('audio') && !format.hasVideo
        );
        
        console.log(`Found ${audioFormats.length} audio formats`);
        
        // Filter for video formats with high quality
        const videoFormats = info.formats.filter(format => 
            format.hasVideo && format.quality
        );
        
        console.log(`Found ${videoFormats.length} video formats`);
        
        // Get best audio format (highest bitrate)
        const bestAudio = audioFormats.sort((a, b) => b.audioBitrate - a.audioBitrate)[0];
        
        // Get best video format (highest resolution)
        const bestVideo = videoFormats.sort((a, b) => b.height - a.height)[0];
        
        let optimalFormat = null;
        
        // Get optimal combined format for simple playback
        try {
            optimalFormat = ytdl.chooseFormat(info.formats, { 
                quality: 'highest',
                filter: 'audioandvideo' // Format with both audio and video
            });
            
            console.log(`Found optimal format: ${optimalFormat?.qualityLabel || 'None'}`);
        } catch (e) {
            console.log('No optimal format available:', e.message);
        }
        
        // Log the results for debugging
        if (bestAudio) {
            console.log(`Best audio: ${bestAudio.audioBitrate}kbps ${bestAudio.mimeType}`);
        }
        
        if (bestVideo) {
            console.log(`Best video: ${bestVideo.qualityLabel} ${bestVideo.mimeType}`);
        }
        
        return {
            audioUrl: bestAudio ? bestAudio.url : null,
            videoUrl: bestVideo ? bestVideo.url : null,
            optimalUrl: optimalFormat ? optimalFormat.url : null,
            videoInfo: info
        };
    } catch (error) {
        console.error('Error getting ytdl high quality URLs:', error.message);
        throw error; // Propagate error for better handling upstream
    }
}

/**
 * Helper function to create a standardized response
 * Ensures all responses follow the same format even on errors
 */
function createStandardResponse(options) {
    const proxy = (u) => {
        if (!u) return null;
        try {
            // If already proxied, return as-is
            if (u.startsWith('/api/image') || u.startsWith('/api/')) return u;
            const token = encryptUrl(u);
            if (!token) return u;
            return `/api/image?c=${encodeURIComponent(token)}`;
        } catch (_) { return u; }
    };
    return {
        download: options.download || false,
        playback: options.playback || false,
        isVideo: options.isVideo || false,
        isAudio: options.isAudio || false,
        videoUrl: options.videoUrl || null,
        audioUrl: options.audioUrl || null,
        mediaUrl: options.mediaUrl || null, // For backward compatibility
        name: options.mediaName || options.name || "Unknown Media",
        mediaName: options.mediaName || options.name || "Unknown Media", // For backward compatibility
        thumbnail: proxiedImage(options.thumbnail) || null,
        image: proxiedImage(options.image) || proxiedImage(options.thumbnail) || null,
        isPaid: options.isPaid || false,
        error: options.error || null,
        mediaUrls: (options.mediaUrls || []).map(m => {
            const out = Object.assign({}, m);
            if (out.thumbnail) out.thumbnail = proxiedImage(out.thumbnail);
            return out;
        })
    };
}

/**
 * General API endpoint info
 */
router.get('/', (req, res) => {
    res.json({
        name: "BakwaasFM API",
        version: "1.2.0",
        endpoints: [
            "/api/stations - Radio station endpoints",
            "/api/streams - Stream endpoints",
            "/api/radio - Radio items endpoints",
            "/api/health - Health check",
            "/api/process-url - Process media URLs",
            "/api/youtube/audio/:videoId - Stream YouTube audio",
            "/api/youtube/info/:videoId - Get YouTube video info",
            "/api/youtube/download/:videoId - Download YouTube audio",
            "/api/ui-config - UI labels and feature flags",
            "/api/direct-url - Direct URL processing"
        ],
        documentation: "Contact developer for API documentation"
    });
});

/**
 * UI configuration endpoint
 * Returns a small JSON payload containing UI labels and feature flags.
 * Keep downloads disabled by default for App Store safety; the app will
 * only show download UI when the backend sets `features.enable_downloads`
 * to true AND the user is logged in.
 */
router.get('/ui-config', (req, res) => {
    console.log('📣 ui-config requested');
    const payload = {
        labels: {
                menu_profile: 'Profile',
                menu_downloads: 'Downloads',
            menu_filters: 'Filters',
            menu_now_playing: 'Now Playing',
            menu_sleep_timer: 'Sleep Timer',
            filters_title: 'Library Filters',
            filter_liked: 'Liked Songs',
            filter_albums: 'Albums',
            filter_artists: 'Artists',
                filter_downloads: 'Downloads',
            filter_playlists: 'Playlists',
            filter_stations: 'Stations',
            filter_recent: 'Recently Played',
            filters_clear: 'Clear',
            filters_done: 'Done',
            import_title: 'Import link',
            import_play: 'Play Now',
                import_download: 'Download Now'
        },
            features: {
                // Default: downloads disabled. Set to `true` only if you
                // have a proper licensed download flow and user auth.
                enable_downloads: false,
                // Default: hide login/signup UI until explicitly enabled.
                // This prevents the app from advertising login when backend
                // operators want to keep the app in a non-auth state.
                show_login_button: false
            }
    };
    res.json(payload);
});

/**
 * Simple authentication endpoints (signup/login/me) for demo purposes.
 * This is a minimal implementation backed by `backend/users.json` and
 * should be replaced by a real auth flow for production.
 */

router.post('/auth/signup', async (req, res) => {
    try {
        const { email, password } = req.body || {};
        if (!email || !password) return res.status(400).json({ error: 'Missing email or password' });

        const existing = await User.findOne({ email: email.toLowerCase() }).exec();
        if (existing) return res.status(400).json({ error: 'User already exists' });

        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(password, saltRounds);
        const user = new User({ email: email.toLowerCase(), passwordHash });

        // Optional device info from signup payload
        const device = req.body.device;
        if (device && typeof device === 'object') {
            user.devices.push({
                deviceId: device.deviceId || device.id || null,
                deviceName: device.deviceName || device.name || null,
                userAgent: req.headers['user-agent'] || device.userAgent || null,
                ip: req.ip || req.connection?.remoteAddress || null,
                mode: device.mode || (req.headers['user-agent'] ? 'web' : null),
                lastSeen: new Date()
            });
        }

        await user.save();

        // Support optional long-lived (one-year) token when client requests it
        const oneYear = !!req.body.oneYear;
        const expiry = oneYear ? JWT_LONG_EXPIRY : JWT_EXPIRY;
        const token = jwt.sign({ email: user.email, id: user._id }, JWT_SECRET, { expiresIn: expiry });
        const expiresAt = computeExpiryDate(expiry);
        return res.json({ ok: true, user: { id: user._id.toString(), email: user.email }, token, tokenExpiresAt: expiresAt ? expiresAt.toISOString() : null });
    } catch (e) {
        console.error('Signup error:', e.message);
        return res.status(500).json({ error: 'Signup failed' });
    }
});

router.post('/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body || {};
        if (!email || !password) return res.status(400).json({ error: 'Missing email or password' });

        const user = await User.findOne({ email: email.toLowerCase() }).exec();
        if (!user) return res.status(400).json({ error: 'Invalid credentials' });

        const match = await bcrypt.compare(password, user.passwordHash);
        if (!match) return res.status(400).json({ error: 'Invalid credentials' });

        // Update or add device info if provided
        const device = req.body.device;
        if (device && typeof device === 'object') {
            const dId = device.deviceId || device.id || null;
            const existingIndex = user.devices.findIndex(d => d.deviceId === dId && d.deviceId != null);
            const deviceRecord = {
                deviceId: dId,
                deviceName: device.deviceName || device.name || null,
                userAgent: req.headers['user-agent'] || device.userAgent || null,
                ip: req.ip || req.connection?.remoteAddress || null,
                mode: device.mode || (req.headers['user-agent'] ? 'web' : null),
                lastSeen: new Date()
            };
            if (existingIndex >= 0) {
                user.devices[existingIndex] = Object.assign(user.devices[existingIndex].toObject ? user.devices[existingIndex].toObject() : user.devices[existingIndex], deviceRecord);
            } else {
                user.devices.push(deviceRecord);
            }
            // update device lastSeen but defer lastLogin update until after credential checks
            await user.save();
        }

        // set lastLogin as an object containing full datetime and device info
        const now = new Date();
        const lastLoginRecord = {
            dateTime: now,
            mode: (device && device.mode) ? device.mode : (req.headers['user-agent'] ? 'web' : null),
            deviceId: (device && (device.deviceId || device.id)) ? (device.deviceId || device.id) : null,
            deviceName: (device && (device.deviceName || device.name)) ? (device.deviceName || device.name) : null,
            ip: req.ip || req.connection?.remoteAddress || null
        };
        user.lastLogin = lastLoginRecord;
        await user.save();
        // Support optional long-lived (one-year) token when client requests it
        const oneYear = !!req.body.oneYear;
        const expiry = oneYear ? JWT_LONG_EXPIRY : JWT_EXPIRY;
        const token = jwt.sign({ email: user.email, id: user._id }, JWT_SECRET, { expiresIn: expiry });
        const expiresAt = computeExpiryDate(expiry);
        return res.json({ ok: true, user: { id: user._id.toString(), email: user.email, plan: user.plan, devices: user.devices, lastLogin: user.lastLogin }, token, tokenExpiresAt: expiresAt ? expiresAt.toISOString() : null });
    } catch (e) {
        console.error('Login error:', e.message);
        return res.status(500).json({ error: 'Login failed' });
    }
});

router.get('/auth/me', async (req, res) => {
    try {
        const auth = req.headers.authorization || '';
        if (!auth.startsWith('Bearer ')) return res.status(401).json({ error: 'Missing token' });
        const token = auth.substring(7);
        let payload;
        try {
            payload = jwt.verify(token, JWT_SECRET);
        } catch (e) {
            return res.status(401).json({ error: 'Invalid token' });
        }
        const user = await User.findOne({ email: payload.email.toLowerCase() }).exec();
        if (!user) return res.status(404).json({ error: 'User not found' });
        return res.json({ ok: true, user: { id: user._id.toString(), email: user.email, plan: user.plan, devices: user.devices, lastLogin: user.lastLogin } });
    } catch (e) {
        console.error('Me error:', e.message);
        return res.status(500).json({ error: 'Failed to verify token' });
    }
});

/**
 * Middleware to authenticate Bearer token and attach user object to req.user
 */
async function authMiddleware(req, res, next) {
    try {
        const auth = req.headers.authorization || '';
        if (!auth.startsWith('Bearer ')) return res.status(401).json({ error: 'Missing token' });
        const token = auth.substring(7);
        let payload;
        try {
            payload = jwt.verify(token, JWT_SECRET);
        } catch (e) {
            return res.status(401).json({ error: 'Invalid token' });
        }
        const user = await User.findOne({ email: payload.email.toLowerCase() }).exec();
        if (!user) return res.status(404).json({ error: 'User not found' });
        req.user = user;
        next();
    } catch (e) {
        console.error('authMiddleware error:', e.message);
        return res.status(500).json({ error: 'Auth error' });
    }
}

/**
 * Register or update a device for the authenticated user.
 * POST body: { device: { deviceId, deviceName, mode, userAgent } }
 */
router.post('/user/device', authMiddleware, async (req, res) => {
    try {
        const device = req.body.device;
        if (!device || typeof device !== 'object') return res.status(400).json({ error: 'Missing device object' });
        const user = req.user;
        const dId = device.deviceId || device.id || null;
        const existingIndex = user.devices.findIndex(d => d.deviceId === dId && d.deviceId != null);
        const deviceRecord = {
            deviceId: dId,
            deviceName: device.deviceName || device.name || null,
            userAgent: req.headers['user-agent'] || device.userAgent || null,
            ip: req.ip || req.connection?.remoteAddress || null,
            mode: device.mode || (req.headers['user-agent'] ? 'web' : null),
            lastSeen: new Date()
        };
        if (existingIndex >= 0) {
            user.devices[existingIndex] = Object.assign(user.devices[existingIndex].toObject ? user.devices[existingIndex].toObject() : user.devices[existingIndex], deviceRecord);
        } else {
            user.devices.push(deviceRecord);
        }
        await user.save();
        return res.json({ ok: true, devices: user.devices });
    } catch (e) {
        console.error('user/device error:', e.message);
        return res.status(500).json({ error: 'Failed to register device' });
    }
});

/**
 * Get or update the user's plan. POST requires body { plan: { name, planType, adsEnabled, expiresAt } }
 * This endpoint is intentionally permissive for testing — in production require admin rights.
 */
router.get('/user/plan', authMiddleware, async (req, res) => {
    try {
        const user = req.user;
        return res.json({ ok: true, plan: user.plan || {} });
    } catch (e) {
        console.error('user/plan get error:', e.message);
        return res.status(500).json({ error: 'Failed to fetch plan' });
    }
});

router.post('/user/plan', authMiddleware, async (req, res) => {
    try {
        const plan = req.body.plan;
        if (!plan || typeof plan !== 'object') return res.status(400).json({ error: 'Missing plan object' });
        const user = req.user;
        user.plan = {
            name: plan.name || user.plan.name || null,
            planType: plan.planType || user.plan.planType || null,
            adsEnabled: (typeof plan.adsEnabled === 'boolean') ? plan.adsEnabled : (user.plan.adsEnabled !== undefined ? user.plan.adsEnabled : true),
            expiresAt: plan.expiresAt ? new Date(plan.expiresAt) : user.plan.expiresAt || null
        };
        await user.save();
        return res.json({ ok: true, plan: user.plan });
    } catch (e) {
        console.error('user/plan post error:', e.message);
        return res.status(500).json({ error: 'Failed to update plan' });
    }
});

// Lightweight endpoint that returns the origin (protocol + host) as seen
// by the server for the incoming request. This is useful for clients to
// discover which domain/protocol the server will use when generating
// proxy/player URLs. It respects standard reverse-proxy headers.
router.get('/host', (req, res) => {
    try {
        const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
        const host = req.headers['x-forwarded-host'] || req.headers.host || `localhost:${process.env.PORT || '3222'}`;
        const origin = `${protocol}://${host}`;
        return res.json({ ok: true, origin, protocol, host });
    } catch (e) {
        console.error('/api/host error:', e && e.message);
        return res.status(500).json({ ok: false });
    }
});

module.exports = router;

