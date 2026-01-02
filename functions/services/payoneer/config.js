const getConfigValue = (envKey) => {
  return process.env[envKey] || undefined;
};

const getPayoneerConfig = () => {
  const clientId = getConfigValue('PAYONEER_CLIENT_ID');
  const clientSecret = getConfigValue('PAYONEER_CLIENT_SECRET');
  const programId = getConfigValue('PAYONEER_PROGRAM_ID');
  const environment = (getConfigValue('PAYONEER_ENVIRONMENT') || 'sandbox').toLowerCase();
  const apiBaseUrl = getConfigValue('PAYONEER_API_BASE_URL');

  const isConfigured = Boolean(clientId && clientSecret && programId);

  return {
    clientId,
    clientSecret,
    programId,
    environment,
    apiBaseUrl,
    isMock: !isConfigured,
  };
};

module.exports = {
  getPayoneerConfig,
};

