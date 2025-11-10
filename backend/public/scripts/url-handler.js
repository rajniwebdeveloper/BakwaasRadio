/**
 * URL Handler for Radio-Tube
 * Handles direct URL imports and sharing
 */

document.addEventListener('DOMContentLoaded', function() {
    // Check if URL has a 'url' parameter
    const urlParams = new URLSearchParams(window.location.search);
    const sharedUrl = urlParams.get('url');
    
    if (sharedUrl) {
        console.log('Detected shared URL:', sharedUrl);
        handleSharedUrl(sharedUrl);
    }
    
    // Setup URL import functionality
    setupUrlImport();
});

/**
 * Process a shared URL that was passed via query parameter
 */
function handleSharedUrl(url) {
    // Show loading indicator
    showMessage('Processing shared URL...', 'info');
    
    // Process the URL
    processUrl(url)
        .then(response => {
            if (response.error) {
                showMessage(`Error: ${response.error}`, 'error');
                return;
            }
            
            // Handle successful URL processing
            if (response.isYoutube && response.directAudioUrl) {
                // For YouTube, play directly using the audio URL
                playMedia({
                    title: response.name || 'YouTube Audio',
                    audioUrl: response.directAudioUrl,
                    thumbnail: response.thumbnail,
                    isYoutube: true,
                    youtubeId: response.youtubeId
                });
                showMessage(`Playing: ${response.name}`, 'success');
            } else if (response.audioUrl || response.videoUrl || response.mediaUrl) {
                // For other media, play using the best available URL
                playMedia({
                    title: response.name || 'Media',
                    audioUrl: response.audioUrl || response.mediaUrl,
                    videoUrl: response.videoUrl,
                    thumbnail: response.thumbnail
                });
                showMessage(`Playing: ${response.name}`, 'success');
            } else {
                showMessage('The shared URL does not contain playable media', 'error');
            }
        })
        .catch(error => {
            console.error('Error processing shared URL:', error);
            showMessage(`Failed to process URL: ${error.message}`, 'error');
        });
}

/**
 * Setup URL import functionality
 */
function setupUrlImport() {
    // Find import button and input if they exist
    const importButton = document.getElementById('import-url-btn');
    const urlInput = document.getElementById('url-input');
    
    if (importButton && urlInput) {
        importButton.addEventListener('click', function() {
            const url = urlInput.value.trim();
            if (url) {
                handleSharedUrl(url);
            } else {
                showMessage('Please enter a URL first', 'warning');
            }
        });
    }
    
    // Setup paste handler for the whole document
    document.addEventListener('paste', function(e) {
        // Only handle paste if we're not in an input element
        if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
            const pastedText = (e.clipboardData || window.clipboardData).getData('text');
            
            // Check if it looks like a URL
            if (pastedText.startsWith('http') && (
                pastedText.includes('youtube.com') || 
                pastedText.includes('youtu.be') || 
                pastedText.includes('.mp3') || 
                pastedText.includes('.mp4')
            )) {
                handleSharedUrl(pastedText);
            }
        }
    });
}

/**
 * Process a URL by sending it to the backend
 */
async function processUrl(url) {
    try {
        const response = await fetch('/api/process-url', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(url)
        });
        
        if (!response.ok) {
            throw new Error(`Server returned ${response.status}: ${response.statusText}`);
        }
        
        return await response.json();
    } catch (error) {
        console.error('Error processing URL:', error);
        return { error: error.message };
    }
}

/**
 * Show a message to the user
 */
function showMessage(message, type = 'info') {
    // Check if we have a message container
    let messageContainer = document.getElementById('message-container');
    
    // Create one if it doesn't exist
    if (!messageContainer) {
        messageContainer = document.createElement('div');
        messageContainer.id = 'message-container';
        messageContainer.style.position = 'fixed';
        messageContainer.style.top = '20px';
        messageContainer.style.right = '20px';
        messageContainer.style.zIndex = '9999';
        document.body.appendChild(messageContainer);
    }
    
    // Create message element
    const messageElement = document.createElement('div');
    messageElement.className = `message ${type}`;
    messageElement.style.padding = '10px 15px';
    messageElement.style.marginBottom = '10px';
    messageElement.style.borderRadius = '4px';
    messageElement.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
    
    // Set colors based on message type
    switch (type) {
        case 'error':
            messageElement.style.backgroundColor = '#f8d7da';
            messageElement.style.color = '#721c24';
            messageElement.style.borderLeft = '4px solid #dc3545';
            break;
        case 'success':
            messageElement.style.backgroundColor = '#d4edda';
            messageElement.style.color = '#155724';
            messageElement.style.borderLeft = '4px solid #28a745';
            break;
        case 'warning':
            messageElement.style.backgroundColor = '#fff3cd';
            messageElement.style.color = '#856404';
            messageElement.style.borderLeft = '4px solid #ffc107';
            break;
        default:
            messageElement.style.backgroundColor = '#d1ecf1';
            messageElement.style.color = '#0c5460';
            messageElement.style.borderLeft = '4px solid #17a2b8';
    }
    
    // Set message content
    messageElement.textContent = message;
    
    // Add to container
    messageContainer.appendChild(messageElement);
    
    // Remove after timeout
    setTimeout(() => {
        messageElement.style.opacity = '0';
        messageElement.style.transition = 'opacity 0.5s';
        setTimeout(() => messageElement.remove(), 500);
    }, 5000);
}

/**
 * Play media - this function should be implemented according to your app's media player
 * This is a placeholder that needs to be adapted to your specific implementation
 */
function playMedia(mediaInfo) {
    // Check if your app has a global player object
    if (window.player && typeof window.player.playMedia === 'function') {
        window.player.playMedia(mediaInfo);
    } else if (window.audioPlayer && typeof window.audioPlayer.play === 'function') {
        // Simple player fallback
        if (mediaInfo.audioUrl) {
            if (mediaInfo.isYoutube) {
                // For YouTube, use the direct audio URL
                window.audioPlayer.src = mediaInfo.audioUrl;
            } else {
                window.audioPlayer.src = mediaInfo.audioUrl;
            }
            window.audioPlayer.play();
        }
    } else {
        console.error('No player implementation found');
        alert(`Ready to play: ${mediaInfo.title}`);
    }
}

// Export functions for use in other scripts
window.urlHandler = {
    processUrl,
    handleSharedUrl,
    showMessage
};
