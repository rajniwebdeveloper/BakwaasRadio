const { Innertube, UniversalCache } = require('youtubei.js');
const ytdl = require('@distube/ytdl-core'); // Add the ytdl-core library
const fs = require('fs');
const path = require('path');

// Test YouTube URL - update to use a reliable test URL
const testUrl = 'https://youtu.be/twgEUH9O_gM?si=9_GOkAG_ioN1Ja02';

// Extract video ID from URL
function extractVideoId(url) {
  const regex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/i;
  const match = url.match(regex);
  return match ? match[1] : null;
}

async function testYoutubeInfo() {
  console.log(`🔄 Testing YouTube URL: ${testUrl}`);
  
  try {
    // Extract video ID from URL
    const videoId = extractVideoId(testUrl);
    
    if (!videoId) {
      throw new Error('Could not extract video ID from URL');
    }
    
    console.log(`Video ID: ${videoId}`);
    
    // Create output folder if it doesn't exist
    const outputDir = path.join(__dirname, 'downloads');
    if (!fs.existsSync(outputDir)){
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    // Get high quality URLs using ytdl-core first (primary method)
    console.log('\n🔍 Getting high quality URLs using ytdl-core...');
    const ytdlUrls = await getYtdlHighQualityUrls(videoId);
    
    // Skip youtube.js which is causing errors and go straight to testing ytdl-core
    console.log('\n🔍 Testing @distube/ytdl-core method directly...');
    await testWithYtdl(videoId, outputDir);
    
    // Display API response format - more complete response to match api.js
    if (ytdlUrls.videoInfo) {
      const videoDetails = ytdlUrls.videoInfo.videoDetails;
      console.log('\nAPI would return:');
      const apiResponse = {
        // Keep existing fields for backward compatibility
        download: true,
        playback: true,
        isVideo: !!ytdlUrls.videoUrl,
        isAudio: !!ytdlUrls.audioUrl,
        videoUrl: ytdlUrls.videoUrl || null,
        audioUrl: ytdlUrls.audioUrl || null,
        mediaUrl: ytdlUrls.audioUrl || ytdlUrls.videoUrl || null, // For backward compatibility
        name: videoDetails.title,
        mediaName: videoDetails.title, // For backward compatibility
        thumbnail: videoDetails.thumbnails[0].url,
        image: videoDetails.thumbnails[0].url,
        isPaid: videoDetails.isPrivate || false,
        description: videoDetails.description || '',
        
        // Add new YouTube-specific fields
        youtubeId: videoId,
        isYoutube: true,
        directAudioUrl: `/api/youtube/audio/${videoId}`,
        autoPlay: true,
        
        // Add media URLs array with different options
        mediaUrls: [
          {
            id: `audio-${videoId}`,
            download: true,
            playback: true,
            isVideo: false,
            isAudio: true,
            videoUrl: null,
            audioUrl: ytdlUrls.audioUrl,
            name: `${videoDetails.title} (Audio)`,
            quality: "High Quality Audio",
            thumbnail: videoDetails.thumbnails[0].url,
            isPaid: false,
            directPlayUrl: `/api/youtube/audio/${videoId}`
          }
        ]
      };
      
      if (ytdlUrls.videoUrl) {
        apiResponse.mediaUrls.push({
          id: `video-${videoId}`,
          download: true,
          playback: true,
          isVideo: true,
          isAudio: false,
          videoUrl: ytdlUrls.videoUrl,
          audioUrl: null,
          name: `${videoDetails.title} (Video)`,
          quality: "High Quality Video",
          thumbnail: videoDetails.thumbnails[0].url,
          isPaid: false
        });
      }
      
      console.log(apiResponse);
    }
    
  } catch (error) {
    console.error('❌ Test failed with error:', error.message);
    console.error(error.stack);
    
    // Still try ytdl-core if the first method fails
    console.log('\n🔍 Attempting with @distube/ytdl-core as fallback...');
    const videoId = extractVideoId(testUrl);
    if (videoId) {
      const outputDir = path.join(__dirname, 'downloads');
      await testWithYtdl(videoId, outputDir);
      
      // Return API response with ytdl URLs only
      const ytdlUrls = await getYtdlHighQualityUrls(videoId);
      console.log('\nAPI would return:');
      const apiResponse = {
        download: true,
        playback: true,
        isVideo: true,
        mediaName: "YouTube Video", // Fallback title
        isPaid: false,
        thumbnail: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
        audioUrl: ytdlUrls.audioUrl,
        videoUrl: ytdlUrls.videoUrl,
        directAudioUrl: `/api/youtube/audio/${videoId}`,
        youtubeId: videoId,
        isYoutube: true,
        autoPlay: true
      };
      console.log(apiResponse);
    }
    
    console.log('\nTROUBLESHOOTING TIPS:');
    console.log('1. Make sure you have installed @distube/ytdl-core: npm install @distube/ytdl-core@latest');
    console.log('2. Check if the YouTube URL is accessible in your browser');
    console.log('3. Try using a different YouTube URL for testing');
    console.log('4. Check your internet connection');
  }
}

// Helper function to get high quality URLs using ytdl-core
async function getYtdlHighQualityUrls(videoId) {
  try {
    // Get full video info including formats
    const info = await ytdl.getInfo(`https://www.youtube.com/watch?v=${videoId}`);
    
    // Filter for audio-only formats
    const audioFormats = info.formats.filter(format => 
      format.mimeType?.includes('audio') && !format.hasVideo
    );
    
    // Filter for video formats with high quality
    const videoFormats = info.formats.filter(format => 
      format.hasVideo && format.quality
    );
    
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
    } catch (e) {
      console.log('No optimal format available:', e.message);
    }
    
    return {
      audioUrl: bestAudio ? bestAudio.url : null,
      videoUrl: bestVideo ? bestVideo.url : null,
      optimalUrl: optimalFormat ? optimalFormat.url : null,
      videoInfo: info
    };
  } catch (error) {
    console.error('Error getting ytdl high quality URLs:', error.message);
    return { audioUrl: null, videoUrl: null, optimalUrl: null };
  }
}

// Add new function to test with ytdl-core
async function testWithYtdl(videoId, outputDir) {
  try {
    console.log(`Getting video info with ytdl-core for ID: ${videoId}`);
    
    // Get full video info including formats
    const info = await ytdl.getInfo(`https://www.youtube.com/watch?v=${videoId}`);
    
    // Save ytdl response for inspection
    const ytdlOutputPath = path.join(outputDir, 'ytdl-response.json');
    fs.writeFileSync(ytdlOutputPath, JSON.stringify(info, null, 2));
    console.log(`\n💾 ytdl-core response saved to: ${ytdlOutputPath}`);
    
    console.log('\n✅ Video Information (ytdl-core):');
    console.log(`Title: ${info.videoDetails.title}`);
    console.log(`Author: ${info.videoDetails.author.name}`);
    console.log(`Duration: ${info.videoDetails.lengthSeconds} seconds`);
    
    // Get formats
    console.log('\n📋 Available Formats (ytdl-core):');
    
    // Filter for audio-only formats
    const audioFormats = info.formats.filter(format => 
      format.mimeType?.includes('audio') && !format.hasVideo
    );
    
    // Filter for video formats (may or may not include audio)
    const videoFormats = info.formats.filter(format => 
      format.hasVideo
    );
    
    console.log(`Audio formats: ${audioFormats.length}`);
    console.log(`Video formats: ${videoFormats.length}`);
    
    // Get best audio format - always highest quality
    if (audioFormats.length > 0) {
      // Sort by bitrate, highest first
      const bestAudio = audioFormats.sort((a, b) => b.audioBitrate - a.audioBitrate)[0];
      
      console.log('\n🔊 Best Audio Format (ytdl-core):');
      console.log(`Bitrate: ${bestAudio.audioBitrate}kbps`);
      console.log(`MIME Type: ${bestAudio.mimeType}`);
      
      // Save the audio URL to a file
      const audioUrlPath = path.join(outputDir, 'ytdl-audio-url.txt');
      fs.writeFileSync(audioUrlPath, bestAudio.url);
      console.log(`Audio URL saved to: ${audioUrlPath}`);
      console.log(`Audio URL (first 100 chars): ${bestAudio.url.substring(0, 100)}...`);
      
      // Save audio stream example
      console.log('\n💾 Downloading audio sample (5 seconds)...');
      const audioSamplePath = path.join(outputDir, 'audio-sample.mp3');
      
      // Example of downloading a small portion of the audio - using highest quality
      const audioStream = ytdl(`https://www.youtube.com/watch?v=${videoId}`, {
        quality: 'highestaudio',
        filter: 'audioonly',
        dlChunkSize: 0, // Set to 0 for streaming instead of chunking
      });
      
      // Create a write stream that we'll end after 5 seconds
      const writeStream = fs.createWriteStream(audioSamplePath);
      audioStream.pipe(writeStream);
      
      // Stop the download after 5 seconds
      setTimeout(() => {
        audioStream.destroy();
        writeStream.end();
        console.log(`Audio sample saved to: ${audioSamplePath}`);
      }, 5000);
    }
    
    // Get best video format - always highest quality
    if (videoFormats.length > 0) {
      // Sort by resolution (height), highest first
      const bestVideo = videoFormats.sort((a, b) => b.height - a.height)[0];
      
      console.log('\n🎬 Best Video Format (ytdl-core):');
      console.log(`Resolution: ${bestVideo.width}x${bestVideo.height}`);
      console.log(`MIME Type: ${bestVideo.mimeType}`);
      
      // Save the video URL to a file
      const videoUrlPath = path.join(outputDir, 'ytdl-video-url.txt');
      fs.writeFileSync(videoUrlPath, bestVideo.url);
      console.log(`Video URL saved to: ${videoUrlPath}`);
      console.log(`Video URL (first 100 chars): ${bestVideo.url.substring(0, 100)}...`);
    }
    
    // Create a function to get an optimal format for streaming
    console.log('\n🎯 Getting optimal streaming format...');
    try {
      const optimalFormat = ytdl.chooseFormat(info.formats, { 
        quality: 'highest',
        filter: 'audioandvideo' // Prefer formats with both audio and video
      });
      
      if (optimalFormat) {
        console.log(`Optimal format: ${optimalFormat.qualityLabel} - ${optimalFormat.mimeType}`);
        
        // Save the optimal URL to a file
        const optimalUrlPath = path.join(outputDir, 'ytdl-optimal-url.txt');
        fs.writeFileSync(optimalUrlPath, optimalFormat.url);
        console.log(`Optimal streaming URL saved to: ${optimalUrlPath}`);
      }
    } catch (error) {
      console.log('No optimal format found with both audio and video:', error.message);
    }
    
  } catch (error) {
    console.error('❌ ytdl-core test failed:', error.message);
  }
}

// Run the test
testYoutubeInfo();

console.log('\nTo use this script:');
console.log('1. Run with: node test.js');
console.log('2. Review console output for successful processing');
console.log('3. Check the downloads folder for extracted URLs and samples');
console.log('4. Use ytdl-core URLs for reliable high-quality streaming');
