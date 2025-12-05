#!/bin/bash

# Test Script for CORS and Proxy URL Updates
# Run this after installing dependencies: npm install

echo "🧪 Testing Backend CORS and Proxy URL Updates"
echo "=============================================="
echo ""

BASE_URL="http://localhost:3222"

echo "1️⃣  Testing CORS Preflight (OPTIONS)"
echo "------------------------------------"
curl -s -X OPTIONS "${BASE_URL}/api/stations" \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: X-Custom-Header" \
  -i | head -n 20
echo ""

echo "2️⃣  Testing Station API with Proxy URLs"
echo "---------------------------------------"
curl -s "${BASE_URL}/api/stations" | head -n 50
echo ""

echo "3️⃣  Testing Station with Original URLs (?show=original)"
echo "-------------------------------------------------------"
curl -s "${BASE_URL}/api/stations?show=original" | head -n 50
echo ""

echo "4️⃣  Testing Search API"
echo "---------------------"
curl -s "${BASE_URL}/api/search?q=test" | head -n 50
echo ""

echo "5️⃣  Testing Radio API"
echo "--------------------"
curl -s "${BASE_URL}/api/radio" | head -n 50
echo ""

echo "6️⃣  Testing with X-Forwarded Headers (Simulating Reverse Proxy)"
echo "---------------------------------------------------------------"
curl -s "${BASE_URL}/api/stations" \
  -H "X-Forwarded-Proto: https" \
  -H "X-Forwarded-Host: bakwaasfm.in" | head -n 50
echo ""

echo "✅ Tests Complete!"
echo ""
echo "Expected Results:"
echo "- All OPTIONS requests should return 204"
echo "- Access-Control-Allow-Origin: * in all responses"
echo "- URLs should match the hostname used (localhost or forwarded host)"
echo "- ?show=original should include originalMp3Url fields"
