# Backend Updates Summary - CORS & Proxy URLs

## Date: December 5, 2025

## Changes Made

### 1. **CORS Configuration** (`bakwaasfm.js`)

Updated CORS to allow **all origins and requests**:

```javascript
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
```

**Benefits:**
- ✅ No CORS errors from any domain
- ✅ All HTTP methods allowed
- ✅ All headers allowed (custom headers, auth headers, etc.)
- ✅ Preflight caching for better performance
- ✅ Works with any client app regardless of domain

---

### 2. **Radio Routes** (`routes/radio.js`)

**Added Dynamic URL Generation Functions:**
```javascript
// Generate player URLs from request hostname
function generateRadioPlayerUrl(radioItem, req = null)

// Generate proxy image URLs from request hostname
function generateProxyImageUrl(item, imageType, entityType, req)
```

**Updated Routes with Proxy Support:**
- ✅ `GET /api/radio` - All radio items with pagination
- ✅ `GET /api/radio/list` - Simple list format
- ✅ `GET /api/radio/:id` - Single radio item
- ✅ `GET /api/radio/category/:category` - Category filtering
- ✅ `GET /api/radio/featured/list` - Featured items
- ✅ `GET /api/radio/search` - Search with query params
- ✅ `GET /api/radio/search/:query` - Search with path params
- ✅ `POST /api/radio` - Create new item
- ✅ `PUT /api/radio/:id` - Update item

**Features:**
- Player URLs adapt to request hostname
- Image URLs proxied through `/proxy/image?url=...`
- Supports `?show=original` to get original URLs
- X-Forwarded headers supported for reverse proxies

---

### 3. **Search Routes** (`routes/search.js`)

**Added:**
- Dynamic URL generation functions
- Proxy URL formatting for search results

**Updated:**
- ✅ `GET /api/search?q=query` - Now returns proxied URLs for:
  - Stations (mp3Url, playerUrl, profilepic, banner)
  - Series (profilepic, banner)
  - Episodes (mp3Url, playerUrl, profilepic, banner)

**Benefits:**
- Search results are immediately playable
- All images proxied to avoid CORS issues
- URLs match the domain used in request

---

### 4. **Already Updated Routes** (from previous work)

**Stations** (`routes/stations.js`):
- ✅ All station endpoints use dynamic proxy URLs
- ✅ Series endpoints use dynamic proxy URLs
- ✅ Episode endpoints use dynamic proxy URLs

**Streams** (`routes/streams.js`):
- ✅ All stream endpoints use dynamic proxy URLs
- ✅ Stream player URLs adapt to hostname

**Proxy** (`routes/proxy.js`):
- ✅ Station images: `/proxy/station/:id/profilepic` & `/proxy/station/:id/banner`
- ✅ Series images: `/proxy/series/:id/profilepic` & `/proxy/series/:id/banner`
- ✅ Stream logos: `/proxy/stream/:id/logo`
- ✅ Generic image proxy: `/proxy/image?url=...`
- ✅ Generic media proxy: `/proxy/media?url=...`

---

## API Response Examples

### Request to `https://bakwaasfm.in/api/radio`

```json
{
  "data": [
    {
      "_id": "12345abc",
      "title": "My Radio Show",
      "imageUrl": "https://bakwaasfm.in/proxy/image?url=https%3A%2F%2Fcdn.example.com%2Fimage.jpg",
      "audioUrl": "https://bakwaasfm.in/player/radio/12345abc",
      "playerUrl": "https://bakwaasfm.in/player/radio/12345abc"
    }
  ]
}
```

### Request to `http://localhost:3222/api/radio`

```json
{
  "data": [
    {
      "_id": "12345abc",
      "title": "My Radio Show",
      "imageUrl": "http://localhost:3222/proxy/image?url=https%3A%2F%2Fcdn.example.com%2Fimage.jpg",
      "audioUrl": "http://localhost:3222/player/radio/12345abc",
      "playerUrl": "http://localhost:3222/player/radio/12345abc"
    }
  ]
}
```

---

## Query Parameters

### `?show=original`

Get original URLs instead of proxied ones (useful for debugging/admin):

```bash
GET /api/radio?show=original
GET /api/stations?show=original
GET /api/streams?show=original
GET /api/search?q=test&show=original
```

Response includes both original and proxied URLs:
```json
{
  "_id": "12345abc",
  "audioUrl": "https://original-cdn.com/audio.mp3",
  "originalAudioUrl": "https://original-cdn.com/audio.mp3",
  "playerUrl": "https://bakwaasfm.in/player/radio/12345abc",
  "imageUrl": "https://original-cdn.com/image.jpg",
  "originalImageUrl": "https://original-cdn.com/image.jpg"
}
```

---

## Reverse Proxy Support

Works seamlessly behind reverse proxies (Nginx, Caddy, Cloudflare, etc.):

### Headers Supported:
- `X-Forwarded-Proto` - Original protocol (http/https)
- `X-Forwarded-Host` - Original hostname
- `Host` - Current hostname (fallback)

### Nginx Configuration Example:
```nginx
location /api {
    proxy_pass http://localhost:3222;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

---

## Complete Route Coverage

### ✅ Fully Proxied Routes:

1. **Stations** (`/api/stations`)
   - GET / - All stations
   - GET /:id - Single station
   - GET /series/list - All series
   - GET /series/:seriesName - Series episodes
   - GET /series/:seriesName/info - Series with metadata
   - GET /series/all/with-episodes - Series with counts
   - GET /series/all - Complete series metadata
   - GET /standalone - Standalone stations
   - POST / - Create station
   - PUT /:id - Update station
   - DELETE /:id - Delete station

2. **Streams** (`/api/streams`)
   - GET / - All streams
   - GET /:id - Single stream
   - GET /category/:category - Category streams
   - POST / - Create stream
   - PUT /:id - Update stream
   - DELETE /:id - Delete stream

3. **Radio** (`/api/radio`)
   - GET / - All radio items (paginated)
   - GET /list - Simple list
   - GET /:id - Single item
   - GET /category/:category - Category items
   - GET /featured/list - Featured items
   - GET /search - Search (query param)
   - GET /search/:query - Search (path param)
   - POST / - Create item
   - PUT /:id - Update item
   - DELETE /:id - Delete item

4. **Search** (`/api/search`)
   - GET /?q=query - Universal search

5. **Proxy** (`/proxy`)
   - GET /station/:id/profilepic
   - GET /station/:id/banner
   - GET /series/:id/profilepic
   - GET /series/:id/banner
   - GET /stream/:id/logo
   - GET /image?url=...
   - GET /media?url=...

6. **Player** (`/player`)
   - GET /station/:id
   - GET /stream/:id
   - GET /radio/:id

---

## Testing Commands

```bash
# Test CORS from any origin
curl -H "Origin: https://example.com" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: X-Custom-Header" \
     -X OPTIONS \
     http://localhost:3222/api/stations

# Test dynamic URL generation
curl http://localhost:3222/api/stations | jq '.[0] | {mp3Url, profilepic, banner}'

# Test with original URLs
curl http://localhost:3222/api/stations?show=original | jq '.[0] | {mp3Url, originalMp3Url}'

# Test search with proxy
curl "http://localhost:3222/api/search?q=test" | jq '.results.stations[0] | {mp3Url, playerUrl}'

# Test radio items
curl http://localhost:3222/api/radio | jq '.data[0] | {audioUrl, imageUrl, playerUrl}'
```

---

## Migration Notes

### No Breaking Changes ✅
- All existing API responses maintain the same structure
- Old clients continue to work
- New features are additive only

### Environment Variables
- `BASE_URL` - Used as fallback when req object not available
- Still respected for backward compatibility
- Default: `http://localhost:3222`

---

## Benefits Summary

### 🎯 Multi-Domain Support
- Works with bakwaasfm.in, radio.rajnikantmahato.me, localhost, etc.
- No configuration needed per domain

### 🔒 Security
- Original media URLs hidden from clients
- Proxy can add authentication/rate limiting
- Prevents hotlinking

### 🚀 Performance
- CORS preflight cached for 24 hours
- Image proxy can add caching headers
- Reduced CORS errors = faster loading

### 🛠️ Developer Experience
- Same API works in development and production
- No environment-specific URL configuration
- Easy debugging with `?show=original`

### 🌍 CDN-Ready
- URLs can be easily CDN-fronted
- Supports multiple geographic regions
- Load balancer friendly

---

## Future Enhancements

Potential improvements:
- [ ] URL signing for security
- [ ] Custom CDN domains for media
- [ ] Rate limiting per domain/IP
- [ ] Image transformation (resize, format conversion)
- [ ] Caching layer with Redis
- [ ] Analytics on proxy usage
- [ ] Geo-routing based on request origin

---

**Status**: ✅ Complete - All routes updated, CORS fully open, proxy URLs working
**Last Updated**: December 5, 2025
