/**
 * Cloudflare Worker - HTTPS Tafsir API Proxy
 *
 * This worker provides a secure HTTPS endpoint that proxies requests
 * to the HTTP tafsir API, ensuring Google Play Store compliance.
 *
 * Deployment: wrangler deploy tafsir-proxy.js
 *
 * Usage:
 *   GET /{translationId}/{surah}/{ayah}
 *   Example: /4/1/1 (Ibn Kathir, Surah 1, Ayah 1)
 */

export default {
  async fetch(request) {
    // CORS headers for Flutter app
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Accept',
      'Access-Control-Max-Age': '86400', // 24 hours
    };

    // Handle CORS preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders
      });
    }

    // Only allow GET requests
    if (request.method !== 'GET') {
      return new Response(
        JSON.stringify({
          error: 'Method not allowed',
          message: 'Only GET requests are supported'
        }),
        {
          status: 405,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      );
    }

    try {
      const url = new URL(request.url);
      const pathParts = url.pathname.split('/').filter(p => p);

      // Expected format: /{translationId}/{surah}/{ayah}
      const [translationId, surah, ayah] = pathParts;

      // Validate parameters
      if (!translationId || !surah || !ayah) {
        return new Response(
          JSON.stringify({
            error: 'Invalid path format',
            message: 'Expected format: /{translationId}/{surah}/{ayah}',
            example: '/4/1/1 (Ibn Kathir, Surah 1, Ayah 1)',
            received: url.pathname
          }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          }
        );
      }

      // Validate that parameters are numbers
      if (isNaN(translationId) || isNaN(surah) || isNaN(ayah)) {
        return new Response(
          JSON.stringify({
            error: 'Invalid parameters',
            message: 'All parameters must be numbers',
            received: { translationId, surah, ayah }
          }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          }
        );
      }

      // Build the HTTP API URL
      const apiUrl = `http://api.quran-tafseer.com/tafseer/${translationId}/${surah}/${ayah}`;

      console.log(`Proxying request: ${url.pathname} -> ${apiUrl}`);

      // Make request to the HTTP API
      const apiResponse = await fetch(apiUrl, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Quran-App-Cloudflare-Worker/1.0'
        },
        // Cloudflare Worker timeout is 50 seconds on free tier
        signal: AbortSignal.timeout(15000) // 15 second timeout
      });

      // Get response body
      const responseText = await apiResponse.text();

      // Validate JSON response
      let responseData;
      try {
        responseData = JSON.parse(responseText);
      } catch (parseError) {
        console.error('Failed to parse API response as JSON:', parseError);
        return new Response(
          JSON.stringify({
            error: 'Invalid API response',
            message: 'The tafsir API returned invalid JSON'
          }),
          {
            status: 502,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          }
        );
      }

      // Return successful response with caching
      return new Response(
        JSON.stringify(responseData),
        {
          status: apiResponse.status,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'Cache-Control': 'public, max-age=3600, s-maxage=3600', // Cache for 1 hour
            'X-Proxy-Status': 'success',
            'X-Translation-Id': translationId,
            'X-Surah': surah,
            'X-Ayah': ayah
          }
        }
      );

    } catch (error) {
      console.error('Proxy error:', error);

      // Handle timeout errors
      if (error.name === 'TimeoutError' || error.name === 'AbortError') {
        return new Response(
          JSON.stringify({
            error: 'Request timeout',
            message: 'The tafsir API took too long to respond (>15 seconds)',
            suggestion: 'Please try again'
          }),
          {
            status: 504,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          }
        );
      }

      // Handle network errors
      if (error.message.includes('fetch')) {
        return new Response(
          JSON.stringify({
            error: 'Network error',
            message: 'Failed to connect to tafsir API',
            suggestion: 'Please check your internet connection and try again'
          }),
          {
            status: 502,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          }
        );
      }

      // Generic error response
      return new Response(
        JSON.stringify({
          error: 'Proxy error',
          message: error.message || 'An unexpected error occurred',
          type: error.name
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        }
      );
    }
  }
};
