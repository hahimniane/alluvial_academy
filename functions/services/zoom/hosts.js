/**
 * Zoom Host Management Service
 *
 * Manages multiple Zoom host accounts for meeting distribution.
 * Uses a "fill-first" strategy: exhaust Host 1 capacity before using Host 2.
 * Falls back to ZOOM_HOST_USER env var if no hosts are configured in Firestore.
 *
 * Firestore Collection: zoom_hosts
 * Document fields:
 *   - email: string (required) - Zoom host email/user ID
 *   - is_active: boolean (required, default true)
 *   - max_concurrent_meetings: number (required, default 1)
 *   - priority: number (required, lower = used first)
 *   - created_at: timestamp
 *   - created_by: string (admin UID)
 *   - display_name: string (optional)
 *   - notes: string (optional)
 *   - last_used_at: timestamp (optional)
 *   - last_validated_at: timestamp (optional)
 */

const admin = require('firebase-admin');
const { getZoomConfig } = require('./config');

const ZOOM_HOSTS_COLLECTION = 'zoom_hosts';

const shiftHasZoomMeeting = (shiftData) => {
  if (!shiftData || typeof shiftData !== 'object') return false;
  return Boolean(shiftData.zoom_meeting_id && shiftData.zoom_encrypted_join_url);
};

/**
 * Get all active Zoom hosts from Firestore, ordered by priority.
 * Falls back to ZOOM_HOST_USER environment variable if no hosts exist.
 *
 * @returns {Promise<Array<{email: string, maxConcurrentMeetings: number, priority: number, displayName?: string}>>}
 */
const getActiveHosts = async () => {
  try {
    const db = admin.firestore();
    const snapshot = await db
      .collection(ZOOM_HOSTS_COLLECTION)
      .where('is_active', '==', true)
      .orderBy('priority', 'asc')
      .get();

    if (snapshot.empty) {
      // Fall back to environment variable and hardcoded second host
      console.log('[ZoomHosts] No hosts in Firestore, falling back to environment defaults');
      const hosts = [];
      try {
        const { hostUser } = getZoomConfig();
        if (hostUser) {
          hosts.push({
            email: hostUser,
            maxConcurrentMeetings: 2, // Allow a few concurrent meetings for main host
            priority: 0,
            displayName: 'Primary Host (env)',
            isEnvFallback: true,
          });
        }

        // Add support host as secondary fallback
        hosts.push({
          email: 'support@alluwaleducationhub.org',
          maxConcurrentMeetings: 5,
          priority: 1,
          displayName: 'Secondary Host (support)',
          isEnvFallback: true,
        });
      } catch (configError) {
        console.warn('[ZoomHosts] Error configuring fallback hosts:', configError.message);
      }
      return hosts;
    }

    return snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        email: data.email,
        maxConcurrentMeetings: data.max_concurrent_meetings || 1,
        priority: data.priority || 0,
        displayName: data.display_name || data.email,
        notes: data.notes || null,
        lastUsedAt: data.last_used_at?.toDate() || null,
        lastValidatedAt: data.last_validated_at?.toDate() || null,
        isEnvFallback: false,
      };
    });
  } catch (error) {
    console.error('[ZoomHosts] Error fetching active hosts:', error);

    // On error, try to fall back to env var
    try {
      const { hostUser } = getZoomConfig();
      if (hostUser) {
        console.log('[ZoomHosts] Falling back to ZOOM_HOST_USER due to Firestore error');
        return [{
          email: hostUser,
          maxConcurrentMeetings: 1,
          priority: 0,
          displayName: 'Default Host (from env)',
          isEnvFallback: true,
        }];
      }
    } catch (configError) {
      // Both Firestore and env var failed
    }

    throw error;
  }
};

/**
 * Count how many meetings overlap with a given time slot for a specific host.
 *
 * Overlap detection: Two time ranges overlap if and only if:
 * start1 < end2 AND end1 > start2
 *
 * @param {string} hostEmail - The Zoom host email
 * @param {Date} requestedStart - Start time of the requested slot
 * @param {Date} requestedEnd - End time of the requested slot
 * @param {string} [excludeShiftId] - Optional shift ID to exclude (for updates)
 * @param {boolean} [includeUnassigned=false] - If true, also count shifts missing zoom_host_email (treated as default host)
 * @returns {Promise<number>} - Number of overlapping meetings
 */
const countOverlappingMeetings = async (
  hostEmail,
  requestedStart,
  requestedEnd,
  excludeShiftId = null,
  includeUnassigned = false
) => {
  try {
    const db = admin.firestore();

    // Firestore cannot do inequality filters on two different fields.
    // Query shifts where shift_start < requestedEnd (gets all shifts that START before our slot ends),
    // then filter in memory to check shift_end > requestedStart.
    //
    // Backward compatibility: existing shifts may not have zoom_host_email. For capacity checks, we
    // treat these as belonging to the first active host (fill-first default host).
    const snapshots = [];

    snapshots.push(
      db
        .collection('teaching_shifts')
        .where('zoom_host_email', '==', hostEmail)
        .where('shift_start', '<', admin.firestore.Timestamp.fromDate(requestedEnd))
        .where('status', 'in', ['scheduled', 'active'])
        .get()
    );

    if (includeUnassigned) {
      snapshots.push(
        db
          .collection('teaching_shifts')
          .where('zoom_host_email', '==', null)
          .where('shift_start', '<', admin.firestore.Timestamp.fromDate(requestedEnd))
          .where('status', 'in', ['scheduled', 'active'])
          .get()
      );
    }

    const results = await Promise.all(snapshots);
    const docs = results.flatMap(r => r.docs);

    let count = 0;
    for (const doc of docs) {
      // Skip the shift we're updating
      if (excludeShiftId && doc.id === excludeShiftId) {
        continue;
      }

      const data = doc.data();
      // Only count shifts that actually have a Zoom meeting created.
      if (!shiftHasZoomMeeting(data)) {
        continue;
      }
      const shiftEnd = data.shift_end?.toDate();

      // Check if the existing meeting ends after our requested start (completing overlap check)
      if (shiftEnd && shiftEnd > requestedStart) {
        count++;
      }
    }

    return count;
  } catch (error) {
    console.error(`[ZoomHosts] Error counting overlapping meetings for ${hostEmail}:`, error);
    throw error;
  }
};

/**
 * Find an available host for a requested time slot using fill-first strategy.
 *
 * Fill-first: Exhaust Host 1 capacity before using Host 2, etc.
 *
 * @param {Date} requestedStart - Start time of the requested slot
 * @param {Date} requestedEnd - End time of the requested slot
 * @param {string} [excludeShiftId] - Optional shift ID to exclude (for updates)
 * @returns {Promise<{host: object|null, error: object|null}>}
 */
const findAvailableHost = async (requestedStart, requestedEnd, excludeShiftId = null) => {
  try {
    const hosts = await getActiveHosts();

    if (hosts.length === 0) {
      return {
        host: null,
        error: {
          code: 'NO_HOSTS_CONFIGURED',
          message: 'No Zoom host accounts are configured. Please add a Zoom host or configure ZOOM_HOST_USER.',
          suggestion: 'Configure at least one Zoom host account in settings.',
        },
      };
    }

    // Check each host in priority order (fill-first strategy)
    for (let index = 0; index < hosts.length; index++) {
      const host = hosts[index];
      const includeUnassigned = index === 0; // existing shifts without zoom_host_email default to first host
      const overlappingCount = await countOverlappingMeetings(
        host.email,
        requestedStart,
        requestedEnd,
        excludeShiftId,
        includeUnassigned
      );

      console.log(`[ZoomHosts] Host ${host.email}: ${overlappingCount}/${host.maxConcurrentMeetings} meetings during requested slot`);

      if (overlappingCount < host.maxConcurrentMeetings) {
        // This host has capacity
        return {
          host,
          error: null,
        };
      }
    }

    // No host has capacity - find alternative times
    const alternatives = await findAlternativeTimes(requestedStart, requestedEnd, hosts);

    return {
      host: null,
      error: {
        code: 'NO_AVAILABLE_HOST',
        message: 'All Zoom hosts are at capacity for this time slot.',
        alternatives,
        suggestion: hosts.length < 3
          ? 'Consider purchasing additional Zoom licenses.'
          : 'Try one of the suggested alternative times.',
      },
    };
  } catch (error) {
    console.error('[ZoomHosts] Error finding available host:', error);
    throw error;
  }
};

/**
 * Find alternative available times when all hosts are busy.
 * Searches from requested time to 3 days out in 30-minute increments.
 * Only includes slots during reasonable hours (8am-9pm).
 *
 * @param {Date} requestedStart - Original requested start time
 * @param {Date} requestedEnd - Original requested end time
 * @param {Array} hosts - List of active hosts
 * @returns {Promise<Array<{start: string, end: string}>>} - First 5 available slots
 */
const findAlternativeTimes = async (requestedStart, requestedEnd, hosts) => {
  const alternatives = [];
  const durationMs = requestedEnd.getTime() - requestedStart.getTime();
  const maxAlternatives = 5;
  const maxDaysAhead = 3;
  const slotIncrementMs = 30 * 60 * 1000; // 30 minutes

  // Reasonable hours: 8am to 9pm
  const minHour = 8;
  const maxHour = 21; // 9pm

  // Start from the next 30-minute slot after the requested time
  let currentSlot = new Date(requestedStart);
  currentSlot.setMinutes(Math.ceil(currentSlot.getMinutes() / 30) * 30, 0, 0);
  currentSlot = new Date(currentSlot.getTime() + slotIncrementMs);

  const maxTime = new Date(requestedStart);
  maxTime.setDate(maxTime.getDate() + maxDaysAhead);

  // Pre-fetch all meetings in the search window for efficiency
  const meetingsByHost = new Map();
  for (let index = 0; index < hosts.length; index++) {
    const host = hosts[index];
    const includeUnassigned = index === 0;
    try {
      const db = admin.firestore();
      const snapshots = [];
      snapshots.push(
        db
          .collection('teaching_shifts')
          .where('zoom_host_email', '==', host.email)
          .where('shift_start', '<', admin.firestore.Timestamp.fromDate(maxTime))
          .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(new Date()))
          .where('status', 'in', ['scheduled', 'active'])
          .get()
      );
      if (includeUnassigned) {
        snapshots.push(
          db
            .collection('teaching_shifts')
            .where('zoom_host_email', '==', null)
            .where('shift_start', '<', admin.firestore.Timestamp.fromDate(maxTime))
            .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(new Date()))
            .where('status', 'in', ['scheduled', 'active'])
            .get()
        );
      }

      const results = await Promise.all(snapshots);
      const docs = results.flatMap(r => r.docs);
      meetingsByHost.set(
        host.email,
        docs
          .map(doc => doc.data())
          .filter(shiftHasZoomMeeting)
          .map(data => ({
            start: data.shift_start.toDate(),
            end: data.shift_end.toDate(),
          }))
      );
    } catch (error) {
      console.warn(`[ZoomHosts] Error fetching meetings for ${host.email}:`, error);
      meetingsByHost.set(host.email, []);
    }
  }

  while (currentSlot < maxTime && alternatives.length < maxAlternatives) {
    const slotEnd = new Date(currentSlot.getTime() + durationMs);
    const slotHour = currentSlot.getHours();
    const endHour = slotEnd.getHours();

    // Check if slot is during reasonable hours
    if (slotHour >= minHour && slotHour < maxHour && endHour <= maxHour) {
      // Check if any host has capacity for this slot
      for (const host of hosts) {
        const meetings = meetingsByHost.get(host.email) || [];
        const overlaps = meetings.filter(m =>
          currentSlot < m.end && slotEnd > m.start
        ).length;

        if (overlaps < host.maxConcurrentMeetings) {
          alternatives.push({
            start: currentSlot.toISOString(),
            end: slotEnd.toISOString(),
            hostEmail: host.email, // Include for debugging, can be removed in production
          });
          break; // Found a host for this slot, move to next slot
        }
      }
    }

    currentSlot = new Date(currentSlot.getTime() + slotIncrementMs);
  }

  // Remove hostEmail from final output (don't expose to frontend)
  return alternatives.map(({ start, end }) => ({ start, end }));
};

/**
 * Validate a Zoom host by checking if the account exists and is licensed.
 * Uses Zoom API to verify the account.
 *
 * @param {string} email - Zoom email/user ID to validate
 * @returns {Promise<{valid: boolean, error?: string, userInfo?: object}>}
 */
const validateZoomHost = async (email) => {
  try {
    // Get Zoom config for API access
    const { accountId, clientId, clientSecret, hostUser } = getZoomConfig();

    // Get access token
    const tokenUrl = new URL('https://zoom.us/oauth/token');
    tokenUrl.searchParams.set('grant_type', 'account_credentials');
    tokenUrl.searchParams.set('account_id', accountId);

    const basic = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const tokenResp = await fetch(tokenUrl.toString(), {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
      },
    });

    if (!tokenResp.ok) {
      return {
        valid: false,
        error: 'Failed to authenticate with Zoom API',
      };
    }

    const tokenJson = await tokenResp.json();
    const accessToken = tokenJson.access_token;

    // Try to get user info from Zoom
    // Zoom API accepts email or user ID in the path
    const userResp = await fetch(`https://api.zoom.us/v2/users/${encodeURIComponent(email)}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    });

    if (!userResp.ok) {
      const errorText = await userResp.text().catch(() => '');

      // If this is the same email as ZOOM_HOST_USER (which we know works), allow it anyway
      // This handles cases where the OAuth app can create meetings but can't read user info
      if (hostUser && email.toLowerCase().trim() === hostUser.toLowerCase().trim()) {
        console.warn(`[ZoomHosts] Cannot read user info for "${email}" (${userResp.status}), but this matches ZOOM_HOST_USER. Allowing since meetings can be created.`);
        return {
          valid: true,
          userInfo: {
            email: email,
            firstName: null,
            lastName: null,
            type: 2, // Assume Licensed since meetings work
            typeName: 'Licensed (assumed)',
            status: 'active',
            note: 'Validated by matching ZOOM_HOST_USER (user info read not available)',
          },
        };
      }

      let errorMessage;
      if (userResp.status === 400) {
        // 400 usually means invalid format or user doesn't exist, or OAuth app lacks user:read scope
        errorMessage = `Cannot validate Zoom user "${email}". The OAuth app may not have permission to read user information.\n\n` +
          `If this email is the same as ZOOM_HOST_USER (which is working for meetings), you can:\n` +
          `1. Add the "user:read:admin" scope to your Zoom OAuth app in Zoom Marketplace\n` +
          `2. Or use the email that matches your ZOOM_HOST_USER environment variable\n` +
          `3. Or verify the email is correct and the user exists in your Zoom account`;
      } else if (userResp.status === 404) {
        errorMessage = `Zoom user "${email}" not found in your Zoom account. Make sure the email is correct and the user exists in your Zoom organization.`;
      } else {
        errorMessage = `Failed to fetch Zoom user info (${userResp.status}): ${errorText || 'Unknown error'}`;
      }

      console.error(`[ZoomHosts] Failed to validate user "${email}": ${userResp.status} - ${errorText}`);
      return {
        valid: false,
        error: errorMessage,
      };
    }

    const userInfo = await userResp.json();

    // Check if user has a Pro license (type 2 = Licensed, type 1 = Basic/Free)
    // Type values: 1 = Basic, 2 = Licensed, 3 = On-prem
    if (userInfo.type < 2) {
      return {
        valid: false,
        error: `Zoom user "${email}" has a Basic (free) account. A Pro license is required for hosting meetings.`,
        userInfo: {
          email: userInfo.email,
          firstName: userInfo.first_name,
          lastName: userInfo.last_name,
          type: userInfo.type,
          typeName: userInfo.type === 1 ? 'Basic' : 'Unknown',
        },
      };
    }

    return {
      valid: true,
      userInfo: {
        email: userInfo.email,
        firstName: userInfo.first_name,
        lastName: userInfo.last_name,
        type: userInfo.type,
        typeName: userInfo.type === 2 ? 'Licensed' : 'On-prem',
        status: userInfo.status,
      },
    };
  } catch (error) {
    console.error('[ZoomHosts] Error validating Zoom host:', error);
    return {
      valid: false,
      error: `Failed to validate Zoom host: ${error.message}`,
    };
  }
};

/**
 * Update the last_used_at timestamp for a host after creating a meeting.
 *
 * @param {string} hostEmail - The host email that was used
 * @returns {Promise<void>}
 */
const updateHostLastUsed = async (hostEmail) => {
  try {
    const db = admin.firestore();
    const snapshot = await db
      .collection(ZOOM_HOSTS_COLLECTION)
      .where('email', '==', hostEmail)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      await snapshot.docs[0].ref.update({
        last_used_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    // Non-critical error, log but don't throw
    console.warn('[ZoomHosts] Failed to update last_used_at:', error);
  }
};

/**
 * Check if a host has upcoming meetings (for preventing removal).
 *
 * @param {string} hostEmail - The host email to check
 * @returns {Promise<{hasUpcoming: boolean, count: number, nextMeeting: Date|null}>}
 */
const hasUpcomingMeetings = async (hostEmail) => {
  try {
    const db = admin.firestore();
    const now = new Date();

    const snapshot = await db
      .collection('teaching_shifts')
      .where('zoom_host_email', '==', hostEmail)
      .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now))
      .where('status', 'in', ['scheduled', 'active'])
      .orderBy('shift_start', 'asc')
      .limit(10)
      .get();

    if (snapshot.empty) {
      return {
        hasUpcoming: false,
        count: 0,
        nextMeeting: null,
      };
    }

    return {
      hasUpcoming: true,
      count: snapshot.size,
      nextMeeting: snapshot.docs[0].data().shift_start.toDate(),
    };
  } catch (error) {
    console.error('[ZoomHosts] Error checking upcoming meetings:', error);
    throw error;
  }
};

/**
 * Get host utilization statistics for admin view.
 *
 * @returns {Promise<Array<{host: object, currentMeetings: number, upcomingMeetings: number}>>}
 */
const getHostUtilization = async () => {
  try {
    const hosts = await getActiveHosts();
    const now = new Date();
    const db = admin.firestore();

    const utilization = await Promise.all(hosts.map(async (host) => {
      // Count current (active) meetings
      const currentSnapshot = await db
        .collection('teaching_shifts')
        .where('zoom_host_email', '==', host.email)
        .where('status', '==', 'active')
        .get();

      // Count upcoming meetings (next 7 days)
      const weekFromNow = new Date(now);
      weekFromNow.setDate(weekFromNow.getDate() + 7);

      const upcomingSnapshot = await db
        .collection('teaching_shifts')
        .where('zoom_host_email', '==', host.email)
        .where('shift_start', '>=', admin.firestore.Timestamp.fromDate(now))
        .where('shift_start', '<', admin.firestore.Timestamp.fromDate(weekFromNow))
        .where('status', '==', 'scheduled')
        .get();

      return {
        ...host,
        currentMeetings: currentSnapshot.size,
        upcomingMeetings: upcomingSnapshot.size,
      };
    }));

    return utilization;
  } catch (error) {
    console.error('[ZoomHosts] Error getting host utilization:', error);
    throw error;
  }
};

module.exports = {
  ZOOM_HOSTS_COLLECTION,
  getActiveHosts,
  countOverlappingMeetings,
  findAvailableHost,
  findAlternativeTimes,
  validateZoomHost,
  updateHostLastUsed,
  hasUpcomingMeetings,
  getHostUtilization,
};
