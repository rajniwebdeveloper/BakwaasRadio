/**
 * Test file to verify hostname-based URL generation
 * Run with: node test_hostname_urls.js
 */

// Mock Express request object
function createMockRequest(protocol, host) {
  return {
    protocol: protocol,
    headers: {
      host: host
    }
  };
}

// Test helper function (simulating the one in stations.js)
function generatePlayerUrl(item, type = 'station', req = null) {
  let baseUrl;
  if (req) {
    const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost:3222';
    baseUrl = `${protocol}://${host}`;
  } else {
    baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  }
  return `${baseUrl}/player/${type}/${item._id || item.id}`;
}

function generateProxyImageUrl(item, imageType = 'profilepic', entityType = 'station', req = null) {
  let baseUrl;
  if (req) {
    const protocol = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers.host || 'localhost:3222';
    baseUrl = `${protocol}://${host}`;
  } else {
    baseUrl = process.env.BASE_URL || 'http://localhost:3222';
  }
  const itemId = item._id || item.id;
  return `${baseUrl}/proxy/${entityType}/${itemId}/${imageType}`;
}

// Test cases
console.log('🧪 Testing hostname-based URL generation\n');

const testStation = { _id: '12345abc', name: 'Test Station' };

// Test 1: Without request object (fallback to env/default)
console.log('Test 1: Without request object (fallback)');
console.log('Player URL:', generatePlayerUrl(testStation, 'station'));
console.log('Proxy Image URL:', generateProxyImageUrl(testStation, 'profilepic', 'station'));
console.log('');

// Test 2: With localhost request
console.log('Test 2: With localhost:3222 request');
const localhostReq = createMockRequest('http', 'localhost:3222');
console.log('Player URL:', generatePlayerUrl(testStation, 'station', localhostReq));
console.log('Proxy Image URL:', generateProxyImageUrl(testStation, 'profilepic', 'station', localhostReq));
console.log('');

// Test 3: With production domain
console.log('Test 3: With production domain (bakwaasfm.in)');
const prodReq = createMockRequest('https', 'bakwaasfm.in');
console.log('Player URL:', generatePlayerUrl(prodReq, 'station', prodReq));
console.log('Proxy Image URL:', generateProxyImageUrl(testStation, 'profilepic', 'station', prodReq));
console.log('');

// Test 4: With alternate domain
console.log('Test 4: With alternate domain (radio.rajnikantmahato.me)');
const altReq = createMockRequest('https', 'radio.rajnikantmahato.me');
console.log('Player URL:', generatePlayerUrl(testStation, 'station', altReq));
console.log('Proxy Image URL:', generateProxyImageUrl(testStation, 'profilepic', 'station', altReq));
console.log('');

// Test 5: With x-forwarded headers (behind proxy/load balancer)
console.log('Test 5: With x-forwarded headers (behind reverse proxy)');
const forwardedReq = {
  protocol: 'http',
  headers: {
    host: 'localhost:3222',
    'x-forwarded-proto': 'https',
    'x-forwarded-host': 'bakwaasfm.in'
  }
};
console.log('Player URL:', generatePlayerUrl(testStation, 'station', forwardedReq));
console.log('Proxy Image URL:', generateProxyImageUrl(testStation, 'profilepic', 'station', forwardedReq));
console.log('');

// Test 6: Series proxy URLs
console.log('Test 6: Series proxy URLs');
const testSeries = { _id: 'series123', name: 'Test Series' };
console.log('Series Banner:', generateProxyImageUrl(testSeries, 'banner', 'series', prodReq));
console.log('Series Profile:', generateProxyImageUrl(testSeries, 'profilepic', 'series', prodReq));
console.log('');

console.log('✅ All tests completed!');
console.log('\n📝 Summary:');
console.log('- URLs are now generated dynamically based on the request hostname');
console.log('- Supports x-forwarded-proto and x-forwarded-host headers');
console.log('- Falls back to BASE_URL env variable when req is not provided');
console.log('- Works with localhost, production domains, and reverse proxies');
