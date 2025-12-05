# Dynamic Hostname-Based Proxy URL Generation

## Overview
The backend now automatically generates proxy URLs based on the incoming request's hostname instead of using a fixed `BASE_URL` from environment variables. This enables the API to work seamlessly across multiple domains without configuration changes.

## Benefits

1. **Multi-Domain Support**: Works automatically with:
   - `https://bakwaasfm.in`
   - `https://local.bakwaasfm.in`
   - `https://radio.rajnikantmahato.me`
   - `https://beta.bakwaasfm.in`
   - `http://localhost:3222` (development)
   - Any custom domain pointing to your server

2. **Reverse Proxy Compatible**: Supports standard headers:
   - `x-forwarded-proto`: Gets the original protocol (http/https)
   - `x-forwarded-host`: Gets the original hostname
   - Useful when behind Nginx, Caddy, Cloudflare, etc.

3. **No Configuration Required**: URLs adapt automatically to the domain used
4. **Development Friendly**: Works with localhost without special config

## How It Works

### URL Generation Functions

#### `generatePlayerUrl(item, type, req)`
Generates player URLs for audio streaming:
```javascript
// With request object
generatePlayerUrl(station, 'station', req)
// Output: https://bakwaasfm.in/player/station/12345abc

// Without request (fallback to BASE_URL)
generatePlayerUrl(station, 'station')
// Output: http://localhost:3222/player/station/12345abc
```

#### `generateProxyImageUrl(item, imageType, entityType, req)`
Generates proxy URLs for images (banners, profile pics):
```javascript
// Station profile picture
generateProxyImageUrl(station, 'profilepic', 'station', req)
// Output: https://bakwaasfm.in/proxy/station/12345abc/profilepic

// Series banner
generateProxyImageUrl(series, 'banner', 'series', req)
// Output: https://bakwaasfm.in/proxy/series/series123/banner
```

#### `generateGenericProxyUrl(url, type, req)`
Generates proxy URLs for any external resource:
```javascript
generateGenericProxyUrl('https://example.com/image.jpg', 'image', req)
// Output: https://bakwaasfm.in/proxy/image?url=https%3A%2F%2Fexample.com%2Fimage.jpg
```

## Updated Files

### `/routes/stations.js`
- ✅ `generatePlayerUrl()` - Now accepts `req` parameter
- ✅ `generateProxyImageUrl()` - Now accepts `req` parameter
- ✅ `generateGenericProxyUrl()` - Now accepts `req` parameter
- ✅ `formatStationWithPlayerUrl()` - Now accepts `req` parameter
- ✅ `formatSeriesWithProxyUrls()` - Now accepts `req` parameter
- ✅ All route handlers updated to pass `req` object

### `/routes/streams.js`
- ✅ `generateStreamPlayerUrl()` - Now accepts `req` parameter
- ✅ `formatStreamWithPlayerUrl()` - Now accepts `req` parameter
- ✅ All route handlers updated to pass `req` object

### `/routes/proxy.js`
- Already supports dynamic URLs by nature (proxies based on request)

## API Endpoints

All endpoints now return URLs matching the domain used in the request:

### Request to `https://bakwaasfm.in/api/stations`
```json
{
  "_id": "12345abc",
  "name": "My Station",
  "mp3Url": "https://bakwaasfm.in/player/station/12345abc",
  "profilepic": "https://bakwaasfm.in/proxy/station/12345abc/profilepic",
  "banner": "https://bakwaasfm.in/proxy/station/12345abc/banner"
}
```

### Request to `http://localhost:3222/api/stations`
```json
{
  "_id": "12345abc",
  "name": "My Station",
  "mp3Url": "http://localhost:3222/player/station/12345abc",
  "profilepic": "http://localhost:3222/proxy/station/12345abc/profilepic",
  "banner": "http://localhost:3222/proxy/station/12345abc/banner"
}
```

## Query Parameters

### `?show=original`
Get original URLs instead of proxied ones (useful for admin/debugging):
```
GET /api/stations?show=original
```

Response includes both original and proxied URLs:
```json
{
  "_id": "12345abc",
  "mp3Url": "https://original-cdn.com/audio.mp3",
  "originalMp3Url": "https://original-cdn.com/audio.mp3",
  "playerUrl": "https://bakwaasfm.in/player/station/12345abc",
  "profilepic": "https://original-cdn.com/image.jpg",
  "originalProfilepic": "https://original-cdn.com/image.jpg"
}
```

## Reverse Proxy Configuration

### Nginx Example
```nginx
location / {
    proxy_pass http://localhost:3222;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### Caddy Example
```caddy
bakwaasfm.in {
    reverse_proxy localhost:3222
}
```

Caddy automatically sets the forwarded headers.

## Testing

Run the test script to verify URL generation:
```bash
node test_hostname_urls.js
```

This tests:
- Fallback behavior (without request)
- Localhost requests
- Production domain requests
- X-Forwarded headers (reverse proxy)
- Different entity types (station, series, stream)

## Environment Variables

### `.env` file
```env
BASE_URL=https://radio.rajnikantmahato.me
```

The `BASE_URL` is now used as a **fallback only** when:
- No request object is available
- Building URLs outside of HTTP request context
- For backward compatibility

In normal API requests, the actual request hostname takes precedence.

## Flutter App Configuration

The Flutter app's `config.dart` already supports multiple domains:
```dart
final List<String> publicCandidates = [
  'https://bakwaasfm.in',           // Primary
  'https://local.bakwaasfm.in',     // Local DNS
  'https://radio.rajnikantmahato.me', // Fallback
  'https://beta.bakwaasfm.in',      // Beta
];
```

All domains will return correctly formatted URLs matching the domain used in the request.

## Migration Notes

### No Breaking Changes
- Existing API responses maintain the same structure
- Old clients continue to work
- `BASE_URL` environment variable still supported as fallback

### Benefits for Clients
- Clients can use any domain from their config list
- URLs in responses will match the domain they're using
- Better CDN and caching behavior
- Easier multi-region deployment

## Troubleshooting

### URLs still showing localhost in production
**Cause**: Reverse proxy not setting forwarded headers  
**Fix**: Add `X-Forwarded-Proto` and `X-Forwarded-Host` headers in your proxy config

### Mixed HTTP/HTTPS URLs
**Cause**: Protocol detection issue  
**Fix**: Ensure `X-Forwarded-Proto` header is set correctly by your reverse proxy

### URLs using wrong domain
**Cause**: Unexpected `Host` header value  
**Fix**: Check your load balancer / proxy settings

## Future Enhancements

Potential improvements:
- [ ] Add URL signing for security
- [ ] Support custom CDN domains for media
- [ ] Add rate limiting per domain
- [ ] Domain-specific caching strategies
- [ ] Geo-routing based on request origin

---

**Last Updated**: December 5, 2025  
**Author**: Bakwaas FM Development Team
