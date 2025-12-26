/**
 * LiveKit Configuration
 * 
 * Reads LiveKit credentials from environment variables.
 * Do not hardcode credentials in this file.
 * 
 * Required environment variables:
 * - LIVEKIT_URL: WebSocket URL for LiveKit Cloud (e.g., wss://your-app.livekit.cloud)
 * - LIVEKIT_API_KEY: API key from LiveKit Cloud dashboard
 * - LIVEKIT_API_SECRET: API secret from LiveKit Cloud dashboard
 */

let cachedConfig = null;

/**
 * Get LiveKit configuration from environment variables.
 * Throws an error if required variables are not set.
 * 
 * @returns {{ url: string, apiKey: string, apiSecret: string }}
 */
const getLiveKitConfig = () => {
  if (cachedConfig) {
    return cachedConfig;
  }

  const url = process.env.LIVEKIT_URL?.trim();
  const apiKey = process.env.LIVEKIT_API_KEY?.trim();
  const apiSecret = process.env.LIVEKIT_API_SECRET?.trim();

  if (!url || !apiKey || !apiSecret) {
    const missing = [];
    if (!url) missing.push('LIVEKIT_URL');
    if (!apiKey) missing.push('LIVEKIT_API_KEY');
    if (!apiSecret) missing.push('LIVEKIT_API_SECRET');
    throw new Error(`LiveKit not configured. Missing: ${missing.join(', ')}`);
  }

  cachedConfig = { url, apiKey, apiSecret };
  return cachedConfig;
};

/**
 * Check if LiveKit is configured.
 * 
 * @returns {boolean}
 */
const isLiveKitConfigured = () => {
  try {
    getLiveKitConfig();
    return true;
  } catch (_) {
    return false;
  }
};

/**
 * Clear cached config (useful for testing).
 */
const clearConfigCache = () => {
  cachedConfig = null;
};

module.exports = {
  getLiveKitConfig,
  isLiveKitConfigured,
  clearConfigCache,
};

