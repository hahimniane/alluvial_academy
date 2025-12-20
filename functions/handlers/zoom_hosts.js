/**
 * Zoom Host Management Cloud Functions
 *
 * Admin-only endpoints for managing Zoom host accounts.
 * These functions handle CRUD operations for the zoom_hosts collection.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');
const {
  ZOOM_HOSTS_COLLECTION,
  validateZoomHost,
  hasUpcomingMeetings,
  getHostUtilization,
  getActiveHosts,
} = require('../services/zoom/hosts');

/**
 * Check if the calling user is an admin.
 * @param {string} uid - User UID
 * @returns {Promise<boolean>}
 */
const isAdmin = async (uid) => {
  try {
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return false;

    const data = userDoc.data();
    return (
      data.role === 'admin' ||
      data.user_type === 'admin' ||
      data.userType === 'admin' ||
      data.is_admin === true ||
      data.isAdmin === true ||
      data.is_admin_teacher === true
    );
  } catch (error) {
    console.error('[ZoomHosts] Error checking admin status:', error);
    return false;
  }
};

/**
 * List all Zoom hosts with their utilization statistics.
 * Admin only.
 *
 * @returns {Promise<{hosts: Array, success: boolean}>}
 */
const listZoomHosts = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin status
  const adminStatus = await isAdmin(request.auth.uid);
  if (!adminStatus) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  try {
    const utilization = await getHostUtilization();
    return {
      success: true,
      hosts: utilization,
    };
  } catch (error) {
    console.error('[ZoomHosts] Error listing hosts:', error);
    throw new functions.https.HttpsError('internal', `Failed to list hosts: ${error.message}`);
  }
});

/**
 * Add a new Zoom host account.
 * Validates the account against Zoom API before adding.
 * Admin only.
 *
 * @param {Object} data
 * @param {string} data.email - Zoom user email
 * @param {string} [data.displayName] - Display name
 * @param {number} [data.maxConcurrentMeetings=1] - Max concurrent meetings
 * @param {number} [data.priority] - Priority (lower = used first)
 * @param {string} [data.notes] - Notes
 * @returns {Promise<{hostId: string, success: boolean}>}
 */
const addZoomHost = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin status
  const adminStatus = await isAdmin(request.auth.uid);
  if (!adminStatus) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { email, displayName, maxConcurrentMeetings, priority, notes } = request.data || {};

  if (!email || typeof email !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  try {
    const db = admin.firestore();

    // Check if host already exists
    const existingSnapshot = await db
      .collection(ZOOM_HOSTS_COLLECTION)
      .where('email', '==', email.toLowerCase().trim())
      .limit(1)
      .get();

    let reactivatingHostId = null;

    if (!existingSnapshot.empty) {
      const existingDoc = existingSnapshot.docs[0];
      const existingData = existingDoc.data();

      if (existingData.is_active) {
        throw new functions.https.HttpsError(
          'already-exists',
          `Zoom host with email "${email}" already exists`
        );
      }

      // Found inactive host - mark for reactivation
      console.log(`[ZoomHosts] Found inactive host to reactivate: ${email} (ID: ${existingDoc.id})`);
      reactivatingHostId = existingDoc.id;
    }

    // Validate the Zoom account
    console.log(`[ZoomHosts] Validating Zoom account: ${email}`);
    const validation = await validateZoomHost(email);

    if (!validation.valid) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        validation.error || 'Invalid Zoom account'
      );
    }

    // Get the next priority number if not provided
    let hostPriority = priority;
    if (hostPriority === undefined || hostPriority === null) {
      // If reactivating, we might want to keep old priority or reset? 
      // Let's treat it as new for priority sorting unless specified
      const allHosts = await db
        .collection(ZOOM_HOSTS_COLLECTION)
        .orderBy('priority', 'desc')
        .limit(1)
        .get();

      hostPriority = allHosts.empty ? 0 : (allHosts.docs[0].data().priority || 0) + 1;
    }

    // Create the host document
    const hostData = {
      email: email.toLowerCase().trim(),
      display_name: displayName || validation.userInfo?.firstName
        ? `${validation.userInfo.firstName} ${validation.userInfo.lastName || ''}`.trim()
        : email,
      max_concurrent_meetings: maxConcurrentMeetings || 1,
      priority: hostPriority,
      is_active: true,
      notes: notes || null,
      created_at: reactivatingHostId ? undefined : admin.firestore.FieldValue.serverTimestamp(), // Don't overwrite creation time
      created_by: request.auth.uid,
      last_validated_at: admin.firestore.FieldValue.serverTimestamp(),
      zoom_user_info: validation.userInfo || null,
    };

    // Remove undefined fields
    Object.keys(hostData).forEach(key => hostData[key] === undefined && delete hostData[key]);

    let docRef;
    if (reactivatingHostId) {
      // Update existing document
      await db.collection(ZOOM_HOSTS_COLLECTION).doc(reactivatingHostId).set(hostData, { merge: true });
      docRef = { id: reactivatingHostId };
      console.log(`[ZoomHosts] Reactivated host: ${email} (ID: ${reactivatingHostId})`);
    } else {
      // Create new document
      docRef = await db.collection(ZOOM_HOSTS_COLLECTION).add(hostData);
      console.log(`[ZoomHosts] Added new host: ${email} (ID: ${docRef.id})`);
    }

    return {
      success: true,
      hostId: docRef.id,
      host: {
        id: docRef.id,
        ...hostData,
        created_at: new Date().toISOString(),
        last_validated_at: new Date().toISOString(),
      },
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('[ZoomHosts] Error adding host:', error);
    throw new functions.https.HttpsError('internal', `Failed to add host: ${error.message}`);
  }
});

/**
 * Update an existing Zoom host's settings.
 * Admin only.
 *
 * @param {Object} data
 * @param {string} data.hostId - Host document ID
 * @param {string} [data.displayName] - Display name
 * @param {number} [data.maxConcurrentMeetings] - Max concurrent meetings
 * @param {number} [data.priority] - Priority
 * @param {boolean} [data.isActive] - Whether host is active
 * @param {string} [data.notes] - Notes
 * @returns {Promise<{success: boolean}>}
 */
const updateZoomHost = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin status
  const adminStatus = await isAdmin(request.auth.uid);
  if (!adminStatus) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { hostId, displayName, maxConcurrentMeetings, priority, isActive, notes } = request.data || {};

  if (!hostId || typeof hostId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'hostId is required');
  }

  try {
    const db = admin.firestore();
    const hostRef = db.collection(ZOOM_HOSTS_COLLECTION).doc(hostId);
    const hostDoc = await hostRef.get();

    if (!hostDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Host not found');
    }

    // Build update data (only include provided fields)
    const updateData = {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_by: request.auth.uid,
    };

    if (displayName !== undefined) {
      updateData.display_name = displayName;
    }
    if (maxConcurrentMeetings !== undefined) {
      updateData.max_concurrent_meetings = maxConcurrentMeetings;
    }
    if (priority !== undefined) {
      updateData.priority = priority;
    }
    if (isActive !== undefined) {
      updateData.is_active = isActive;
    }
    if (notes !== undefined) {
      updateData.notes = notes;
    }

    await hostRef.update(updateData);

    console.log(`[ZoomHosts] Updated host: ${hostId}`);

    return {
      success: true,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('[ZoomHosts] Error updating host:', error);
    throw new functions.https.HttpsError('internal', `Failed to update host: ${error.message}`);
  }
});

/**
 * Remove (deactivate) a Zoom host.
 * Fails if the host has upcoming meetings assigned to it.
 * Admin only.
 *
 * @param {Object} data
 * @param {string} data.hostId - Host document ID
 * @param {boolean} [data.forceDelete=false] - If true, delete instead of deactivate
 * @returns {Promise<{success: boolean}>}
 */
const removeZoomHost = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin status
  const adminStatus = await isAdmin(request.auth.uid);
  if (!adminStatus) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { hostId, forceDelete } = request.data || {};

  if (!hostId || typeof hostId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'hostId is required');
  }

  try {
    const db = admin.firestore();
    const hostRef = db.collection(ZOOM_HOSTS_COLLECTION).doc(hostId);
    const hostDoc = await hostRef.get();

    if (!hostDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Host not found');
    }

    const hostData = hostDoc.data();

    // Check for upcoming meetings
    const upcoming = await hasUpcomingMeetings(hostData.email);
    if (upcoming.hasUpcoming && !forceDelete) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cannot remove host: ${upcoming.count} upcoming meetings assigned. Next meeting: ${upcoming.nextMeeting?.toISOString()}`
      );
    }

    if (forceDelete) {
      // Actually delete the document
      await hostRef.delete();
      console.log(`[ZoomHosts] Deleted host: ${hostId} (${hostData.email})`);
    } else {
      // Deactivate instead of delete
      await hostRef.update({
        is_active: false,
        deactivated_at: admin.firestore.FieldValue.serverTimestamp(),
        deactivated_by: request.auth.uid,
      });
      console.log(`[ZoomHosts] Deactivated host: ${hostId} (${hostData.email})`);
    }

    return {
      success: true,
      deleted: forceDelete || false,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('[ZoomHosts] Error removing host:', error);
    throw new functions.https.HttpsError('internal', `Failed to remove host: ${error.message}`);
  }
});

/**
 * Revalidate a Zoom host's account status.
 * Checks if the account is still valid and licensed.
 * Admin only.
 *
 * @param {Object} data
 * @param {string} data.hostId - Host document ID
 * @returns {Promise<{success: boolean, valid: boolean, userInfo?: object}>}
 */
const revalidateZoomHost = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin status
  const adminStatus = await isAdmin(request.auth.uid);
  if (!adminStatus) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { hostId } = request.data || {};

  if (!hostId || typeof hostId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'hostId is required');
  }

  try {
    const db = admin.firestore();
    const hostRef = db.collection(ZOOM_HOSTS_COLLECTION).doc(hostId);
    const hostDoc = await hostRef.get();

    if (!hostDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Host not found');
    }

    const hostData = hostDoc.data();
    const validation = await validateZoomHost(hostData.email);

    // Update the host document with validation results
    await hostRef.update({
      last_validated_at: admin.firestore.FieldValue.serverTimestamp(),
      zoom_user_info: validation.userInfo || null,
      validation_error: validation.valid ? null : validation.error,
    });

    return {
      success: true,
      valid: validation.valid,
      userInfo: validation.userInfo,
      error: validation.error,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('[ZoomHosts] Error revalidating host:', error);
    throw new functions.https.HttpsError('internal', `Failed to revalidate host: ${error.message}`);
  }
});

/**
 * Get current host availability for a specific time slot.
 * Useful for checking before creating a shift.
 * Admin only.
 *
 * @param {Object} data
 * @param {string} data.startTime - ISO start time
 * @param {string} data.endTime - ISO end time
 * @returns {Promise<{available: boolean, hosts: Array, alternatives?: Array}>}
 */
const checkHostAvailability = onCall(async (request) => {
  // Check authentication
  if (!request.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  // Check admin status
  const adminStatus = await isAdmin(request.auth.uid);
  if (!adminStatus) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { startTime, endTime } = request.data || {};

  if (!startTime || !endTime) {
    throw new functions.https.HttpsError('invalid-argument', 'startTime and endTime are required');
  }

  try {
    const { findAvailableHost } = require('../services/zoom/hosts');
    const start = new Date(startTime);
    const end = new Date(endTime);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid date format');
    }

    const { host, error } = await findAvailableHost(start, end);

    if (host) {
      return {
        success: true,
        available: true,
        availableHost: {
          email: host.email,
          displayName: host.displayName,
        },
      };
    }

    return {
      success: true,
      available: false,
      error: error,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('[ZoomHosts] Error checking availability:', error);
    throw new functions.https.HttpsError('internal', `Failed to check availability: ${error.message}`);
  }
});

module.exports = {
  listZoomHosts,
  addZoomHost,
  updateZoomHost,
  removeZoomHost,
  revalidateZoomHost,
  checkHostAvailability,
};
