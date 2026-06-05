let cachedConfig = null;

const getRealtimeKitConfig = () => {
  if (cachedConfig) return cachedConfig;

  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID?.trim();
  const appId = process.env.REALTIMEKIT_APP_ID?.trim();
  const apiToken = process.env.CLOUDFLARE_REALTIME_API_TOKEN?.trim();
  const teacherPreset =
    process.env.REALTIMEKIT_TEACHER_PRESET?.trim() || 'teacher';
  const studentPreset =
    process.env.REALTIMEKIT_STUDENT_PRESET?.trim() || 'student';
  const parentPreset =
    process.env.REALTIMEKIT_PARENT_PRESET?.trim() || studentPreset;
  const adminPreset =
    process.env.REALTIMEKIT_ADMIN_PRESET?.trim() || teacherPreset;
  const guestPreset =
    process.env.REALTIMEKIT_GUEST_PRESET?.trim() || studentPreset;
  // Recording-capable preset, handed to teachers/admins only when an admin has
  // enabled recording for the specific class.
  const teacherRecorderPreset =
    process.env.REALTIMEKIT_TEACHER_RECORDER_PRESET?.trim() || 'teacher_recorder';

  const missing = [];
  if (!accountId) missing.push('CLOUDFLARE_ACCOUNT_ID');
  if (!appId) missing.push('REALTIMEKIT_APP_ID');
  if (!apiToken) missing.push('CLOUDFLARE_REALTIME_API_TOKEN');
  if (missing.length > 0) {
    throw new Error(`RealtimeKit not configured. Missing: ${missing.join(', ')}`);
  }

  cachedConfig = {
    accountId,
    appId,
    apiToken,
    presets: {
      admin: adminPreset,
      teacher: teacherPreset,
      student: studentPreset,
      parent: parentPreset,
      guest: guestPreset,
      teacherRecorder: teacherRecorderPreset,
    },
  };
  return cachedConfig;
};

const isRealtimeKitConfigured = () => {
  try {
    getRealtimeKitConfig();
    return true;
  } catch (_) {
    return false;
  }
};

const clearConfigCache = () => {
  cachedConfig = null;
};

module.exports = {
  getRealtimeKitConfig,
  isRealtimeKitConfigured,
  clearConfigCache,
};
