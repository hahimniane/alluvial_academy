const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const { createMeeting } = require('../zoom/client');
const { findAvailableHost } = require('../zoom/hosts');
const { getZoomConfig } = require('../zoom/config');

// Constants
const HUB_DURATION_MINUTES = 120; // 2 hour blocks
const MAX_PARTICIPANTS_PER_HUB = 100;
const BUFFER_MINUTES = 15; // Start meeting 15 mins before first shift

// Email validation regex
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Schedule Hub Meetings for upcoming shifts
 * 
 * Strategy:
 * 1. Find all scheduled shifts in next 24h needing a hub (hubMeetingId == null)
 * 2. Group them by 2-hour overlapping windows
 * 3. For each group:
 *    - Check capacity (split if > 100)
 *    - Create Zoom Meeting with Breakout Rooms
 *    - Save Hub Meeting doc
 *    - Update Shifts with hub details
 */
const scheduleHubMeetings = async () => {
    const db = admin.firestore();
    const now = DateTime.utc();
    const nextWindow = now.plus({ days: 7 }); // Look ahead 7 days

    // Step 1: Find candidate shifts
    const lookbackStart = now.minus({ hours: 1 });

    // Step 1: Find candidate shifts
    const shiftsSnapshot = await db.collection('teaching_shifts')
        .where('status', 'in', ['scheduled', 'active'])
        .where('shift_start', '>=', Timestamp.fromDate(lookbackStart.toJSDate()))
        .where('shift_start', '<=', Timestamp.fromDate(nextWindow.toJSDate()))
        .orderBy('shift_start', 'asc')
        .get();

    const candidates = [];
    shiftsSnapshot.forEach(doc => {
        const data = doc.data();
        if (!data.hubMeetingId) { // Only process shifts not yet assigned to a hub
            candidates.push({ id: doc.id, ...data });
        }
    });

    if (candidates.length === 0) {
        console.log('[HubScheduler] No pending shifts found.');
        return;
    }

    console.log(`[HubScheduler] Processing ${candidates.length} candidate shifts...`);

    // Step 2: Group by Time Blocks (Simple hourly buckets for now, or sliding window)
    // We will bucket by "Start Hour" floored to even numbers (e.g., 08:00, 10:00, 12:00)
    // to create consistent 2-hour slots. 
    const blocks = new Map(); // Key: "YYYY-MM-DDTWW:00" (Window Start), Value: [shifts]

    candidates.forEach(shift => {
        const start = DateTime.fromJSDate(shift.shift_start.toDate()).toUTC();

        // Logic: Floor to nearest even hour
        const hour = start.hour;
        const blockStartHour = hour - (hour % 2);
        const blockStart = start.set({ hour: blockStartHour, minute: 0, second: 0, millisecond: 0 });

        const key = blockStart.toISO();

        if (!blocks.has(key)) {
            blocks.set(key, []);
        }
        blocks.get(key).push(shift);
    });

    // Step 3: Process Blocks
    for (const [blockKey, bucketShifts] of blocks) {
        await processHubBlock(blockKey, bucketShifts);
    }
};

/**
 * Process a single time block of shifts
 */
const processHubBlock = async (blockKey, shifts) => {
    // 1. Calculate Capacity with full validation
    let totalParticipants = 0;
    const participantsByShift = [];

    for (const shift of shifts) {
        // Use enhanced validation that tracks routing risks
        const processed = await processShiftParticipants(shift, shifts);

        const count = 1 + processed.studentEmails.length; // Teacher + Students
        totalParticipants += count;

        participantsByShift.push({
            shift,
            teacherEmail: processed.teacherEmail,
            studentEmails: processed.studentEmails,
            validParticipants: processed.validParticipants,
            routingRiskParticipants: processed.routingRiskParticipants,
            hasRoutingRisk: processed.hasRoutingRisk,
            overlaps: processed.overlaps
        });
    }

    // Detect duplicate emails across all shifts in this block
    const duplicateCheck = detectDuplicateEmails(participantsByShift);
    if (duplicateCheck.hasDuplicates) {
        console.warn(`[HubScheduler] Block ${blockKey} has duplicate emails. Some participants may not auto-route correctly.`);
    }

    // 2. Split if Over Capacity
    if (totalParticipants > MAX_PARTICIPANTS_PER_HUB) {
        console.log(`[HubScheduler] Block ${blockKey} exceeds capacity (${totalParticipants}). Splitting...`);
        // Basic split logic: just slice the array. 
        // A more advanced one would try to keep "same teacher" shifts together if possible.
        // For now, simple chunking.

        const chunks = [];
        let currentChunk = [];
        let currentCount = 0;

        for (const p of participantsByShift) {
            const size = 1 + p.studentEmails.length;
            if (currentCount + size > MAX_PARTICIPANTS_PER_HUB) {
                chunks.push(currentChunk);
                currentChunk = [];
                currentCount = 0;
            }
            currentChunk.push(p);
            currentCount += size;
        }
        if (currentChunk.length > 0) chunks.push(currentChunk);

        // Process each chunk as a separate hub
        for (let i = 0; i < chunks.length; i++) {
            await createHubForShifts(blockKey, chunks[i], `Part ${i + 1}`);
        }
    } else {
        await createHubForShifts(blockKey, participantsByShift);
    }
};

const createHubForShifts = async (blockKey, participantsData, suffix = "") => {
    const db = admin.firestore();
    const blockStart = DateTime.fromISO(blockKey);
    const meetingStart = blockStart.minus({ minutes: BUFFER_MINUTES }); // Start early
    const duration = HUB_DURATION_MINUTES + BUFFER_MINUTES;

    const topic = `Alwal Academy Classes - ${blockStart.toFormat('MMM dB, h:mm a')} ${suffix}`;

    // Valid Shift IDs for this Hub
    const shiftIds = participantsData.map(p => p.shift.id);

    try {
        // CHECK FOR EXISTING HUB IN THIS BLOCK
        // We look for a scheduled/started hub with the same start time.
        // Note: Suffix handling is tricky if we have multiple parts. 
        // For simplicity, we'll try to add to any non-full hub in this slot.
        const existingHubQuery = await db.collection('hub_meetings')
            .where('startTime', '==', Timestamp.fromDate(meetingStart.toJSDate()))
            .where('status', 'in', ['scheduled', 'started']) // Active hubs
            .get();

        let existingHub = null;

        // Find one with capacity
        for (const doc of existingHubQuery.docs) {
            const data = doc.data();
            const currentCount = data.totalExpectedParticipants || 0;
            const newCount = participantsData.reduce((acc, p) => acc + 1 + p.studentEmails.length, 0);

            if (currentCount + newCount <= MAX_PARTICIPANTS_PER_HUB) {
                existingHub = { id: doc.id, ...data };
                break;
            }
        }

        if (existingHub) {
            console.log(`[HubScheduler] Adding ${shiftIds.length} shifts to existing Hub ${existingHub.id}`);

            // WE CANNOT UPDATE ZOOM BREAKOUT ROOMS VIA API IF MEETING STARTED
            // Only if status is 'scheduled' might we try, but Zoom API breakout updates are complex (often overwrites).
            // SAFE FALLBACK: Just add to Firestore. 
            // Users will join the Hub, see the "Navigator", and manually join their room.
            // This satisfies the "Late join" requirement.

            // Prepare Breakout Room Names (just for Firestore/UI)
            const breakoutRooms = participantsData.map((p, index) => {
                const s = p.shift;
                const time = DateTime.fromJSDate(s.shift_start.toDate()).toUTC().toFormat('h:mm a');
                const students = s.student_names ? s.student_names.join(', ') : 'Students';
                const name = `${s.teacher_name} | ${students} | ${time}`;
                return { name };
            });

            // Update Hub Doc (increment count, add shifts)
            await db.collection('hub_meetings').doc(existingHub.id).update({
                totalExpectedParticipants: FieldValue.increment(participantsData.reduce((acc, p) => acc + 1 + p.studentEmails.length, 0)),
                shifts: FieldValue.arrayUnion(...shiftIds)
            });

            // Update Shifts
            const batch = db.batch();
            participantsData.forEach((p, index) => {
                const shiftRef = db.collection('teaching_shifts').doc(p.shift.id);
                // For late joins to existing hub, we MUST force 'selfselect' or 'hybrid' (which falls back to selfselect)
                // because we aren't pre-assigning in Zoom (API limit).

                batch.update(shiftRef, {
                    hubMeetingId: existingHub.id,
                    breakoutRoomName: breakoutRooms[index].name,
                    breakoutRoomKey: p.shift.id,
                    zoomRoutingMode: 'selfselect', // Explicitly mark as self-select since not in pre-assign list
                    // Store routing risk information
                    routingRiskParticipants: p.routingRiskParticipants || [],
                    preAssignedParticipants: p.validParticipants?.map(vp => vp.email) || [],
                    hasRoutingRisk: p.hasRoutingRisk || false,
                });
            });
            await batch.commit();
            return;
        }

        // --- NEW HUB CREATION LOGIC (Previous Implementation) ---

        // Prepare Breakout Rooms
        const breakoutRooms = participantsData.map(p => {
            // Room Name: "{TeacherName} | {StudentName(s)} | {StartTime}"
            const s = p.shift;
            const time = DateTime.fromJSDate(s.shift_start.toDate()).toUTC().toFormat('h:mm a');
            const students = s.student_names ? s.student_names.join(', ') : 'Students';
            const name = `${s.teacher_name} | ${students} | ${time}`; // 50 char limit check? Zoom allows more usually.

            // Pre-assign list
            const emails = [];
            if (p.teacherEmail) emails.push(p.teacherEmail);
            if (p.studentEmails) emails.push(...p.studentEmails);

            return {
                name: name,
                participants: emails // API expects array of emails
            };
        });

        // Valid Shift IDs for this Hub
        // This was already defined above, so removing duplicate.
        // const shiftIds = participantsData.map(p => p.shift.id);

        // Find Host
        // We use the start of the BLOCK for availability check
        const { host, error } = await findAvailableHost(meetingStart.toJSDate(), meetingStart.plus({ minutes: duration }).toJSDate());

        if (!host) {
            console.error(`[HubScheduler] Failed to find host for hub ${topic}: ${JSON.stringify(error)}`);
            // TODO: Alert admin or retry logic
            return;
        }

        // Create Zoom Meeting
        const meeting = await createMeeting({
            topic,
            startTimeIso: meetingStart.toISO(),
            durationMinutes: duration,
            timezone: 'UTC',
            hostUser: host.email,
            breakoutRooms: breakoutRooms
        });

        // Save Hub Doc
        const hubRef = db.collection('hub_meetings').doc();
        const hubData = {
            id: hubRef.id,
            startTime: Timestamp.fromDate(meetingStart.toJSDate()),
            endTime: Timestamp.fromDate(meetingStart.plus({ minutes: duration }).toJSDate()),
            status: 'scheduled',
            hostZoomUserId: host.email,
            meetingId: meeting.id,
            meetingPasscode: meeting.passcode,
            joinUrl: meeting.joinUrl,
            totalExpectedParticipants: participantsData.reduce((acc, p) => acc + 1 + p.studentEmails.length, 0),
            shifts: shiftIds,
            createdAt: FieldValue.serverTimestamp()
        };

        await hubRef.set(hubData);

        // Update Shifts Batch
        const batch = db.batch();
        participantsData.forEach((p, index) => {
            const shiftRef = db.collection('teaching_shifts').doc(p.shift.id);
            const roomName = breakoutRooms[index].name;

            batch.update(shiftRef, {
                hubMeetingId: hubRef.id,
                breakoutRoomName: roomName,
                breakoutRoomKey: p.shift.id, // Using Shift ID as stable key if needed logic maps back
                zoomRoutingMode: p.hasRoutingRisk ? 'hybrid' : 'preassign', // Use preassign if all participants valid
                // Store routing risk information for client-side fallback handling
                routingRiskParticipants: p.routingRiskParticipants || [],
                preAssignedParticipants: p.validParticipants?.map(vp => vp.email) || [],
                hasRoutingRisk: p.hasRoutingRisk || false,
            });
        });

        await batch.commit();
        console.log(`[HubScheduler] Created Hub ${hubRef.id} with ${shiftIds.length} classes.`);

    } catch (e) {
        console.error(`[HubScheduler] Error creating hub ${topic}:`, e);
    }
};

/**
 * Validate participant email and return routing status
 * @param {string} userId - User ID to fetch and validate
 * @returns {Promise<{email: string|null, routingRisk: boolean, reason: string|null, userId: string}>}
 */
const validateParticipantEmail = async (userId) => {
    if (!userId) {
        return { email: null, routingRisk: true, reason: 'user_id_missing', userId };
    }

    try {
        const doc = await admin.firestore().collection('users').doc(userId).get();

        if (!doc.exists) {
            console.warn(`[HubScheduler] User ${userId} not found in users collection`);
            return { email: null, routingRisk: true, reason: 'user_not_found', userId };
        }

        const userData = doc.data();
        const email = userData.email || userData['e-mail'];

        // Check if email exists
        if (!email) {
            console.warn(`[HubScheduler] User ${userId} has no email`);
            return { email: null, routingRisk: true, reason: 'email_missing', userId };
        }

        // Validate email format
        if (!EMAIL_REGEX.test(email)) {
            console.warn(`[HubScheduler] User ${userId} has invalid email format: ${email}`);
            return { email: null, routingRisk: true, reason: 'email_invalid', userId };
        }

        // Check email verification status (optional - warn but still use)
        if (userData.email_verified === false) {
            console.warn(`[HubScheduler] User ${userId} email not verified: ${email}`);
            // Still return email but flag as routing risk
            return { email, routingRisk: true, reason: 'email_not_verified', userId };
        }

        return { email, routingRisk: false, reason: null, userId };
    } catch (e) {
        console.error(`[HubScheduler] Failed to fetch/validate email for user ${userId}:`, e);
        return { email: null, routingRisk: true, reason: 'fetch_error', userId };
    }
};

/**
 * Legacy helper: Get Email from User ID (for backward compatibility)
 * @deprecated Use validateParticipantEmail instead
 */
const getUserEmail = async (userId) => {
    const result = await validateParticipantEmail(userId);
    return result.email;
};

/**
 * Detect overlapping shifts for a user across all shifts in a block
 * @param {string} userId - User ID to check
 * @param {Array} allShifts - All shifts in the time block
 * @returns {{hasOverlap: boolean, shifts: Array, selectedShiftId: string|null}}
 */
const detectOverlappingShifts = (userId, allShifts) => {
    const userShifts = allShifts.filter(shift => {
        const isTeacher = shift.teacher_id === userId;
        const isStudent = (shift.student_ids || []).includes(userId);
        return isTeacher || isStudent;
    });

    if (userShifts.length <= 1) {
        return { hasOverlap: false, shifts: userShifts, selectedShiftId: userShifts[0]?.id || null };
    }

    // Sort by start time (earliest first)
    userShifts.sort((a, b) => {
        const aStart = a.shift_start?.toDate ? a.shift_start.toDate() : new Date(a.shift_start);
        const bStart = b.shift_start?.toDate ? b.shift_start.toDate() : new Date(b.shift_start);
        return aStart - bStart;
    });

    console.warn(`[HubScheduler] OVERLAP DETECTED: User ${userId} is in ${userShifts.length} shifts within the same time block. ` +
        `Shifts: ${userShifts.map(s => s.id).join(', ')}. Selected: ${userShifts[0].id} (closest start time)`);

    return {
        hasOverlap: true,
        shifts: userShifts,
        selectedShiftId: userShifts[0].id, // Deterministic: select shift with closest start time
        allShiftIds: userShifts.map(s => s.id)
    };
};

/**
 * Detect duplicate emails across all participants in a block
 * @param {Array} participantsData - Array of participant data with emails
 * @returns {{hasDuplicates: boolean, duplicates: Map}}
 */
const detectDuplicateEmails = (participantsData) => {
    const emailToShifts = new Map();

    for (const p of participantsData) {
        const emails = [p.teacherEmail, ...(p.studentEmails || [])].filter(Boolean);

        for (const email of emails) {
            if (!emailToShifts.has(email)) {
                emailToShifts.set(email, []);
            }
            emailToShifts.get(email).push(p.shift.id);
        }
    }

    const duplicates = new Map();
    for (const [email, shiftIds] of emailToShifts) {
        if (shiftIds.length > 1) {
            duplicates.set(email, shiftIds);
            console.warn(`[HubScheduler] DUPLICATE EMAIL: ${email} appears in ${shiftIds.length} shifts: ${shiftIds.join(', ')}`);
        }
    }

    return {
        hasDuplicates: duplicates.size > 0,
        duplicates
    };
};

/**
 * Process participants for a shift with full validation
 * @param {Object} shift - Shift data
 * @param {Array} allShiftsInBlock - All shifts in the time block (for overlap detection)
 * @returns {Promise<Object>} Processed participant data with routing risk info
 */
const processShiftParticipants = async (shift, allShiftsInBlock = []) => {
    const validParticipants = [];
    const routingRiskParticipants = [];

    // Validate teacher
    const teacherResult = await validateParticipantEmail(shift.teacher_id);
    if (teacherResult.email && !teacherResult.routingRisk) {
        validParticipants.push({ userId: shift.teacher_id, email: teacherResult.email, role: 'teacher' });
    } else {
        routingRiskParticipants.push({
            userId: shift.teacher_id,
            reason: teacherResult.reason,
            role: 'teacher'
        });
    }

    // Validate students
    const studentEmails = [];
    if (shift.student_ids && shift.student_ids.length > 0) {
        for (const studentId of shift.student_ids) {
            const studentResult = await validateParticipantEmail(studentId);

            if (studentResult.email && !studentResult.routingRisk) {
                validParticipants.push({ userId: studentId, email: studentResult.email, role: 'student' });
                studentEmails.push(studentResult.email);
            } else {
                routingRiskParticipants.push({
                    userId: studentId,
                    reason: studentResult.reason,
                    role: 'student'
                });
            }
        }
    }

    // Check for overlapping shifts
    const teacherOverlap = detectOverlappingShifts(shift.teacher_id, allShiftsInBlock);
    const studentOverlaps = (shift.student_ids || []).map(sid => detectOverlappingShifts(sid, allShiftsInBlock));

    return {
        shift,
        teacherEmail: teacherResult.email,
        studentEmails,
        validParticipants,
        routingRiskParticipants,
        hasRoutingRisk: routingRiskParticipants.length > 0,
        overlaps: {
            teacher: teacherOverlap,
            students: studentOverlaps.filter(o => o.hasOverlap)
        }
    };
};

module.exports = {
    scheduleHubMeetings,
    // Export helpers for testing
    validateParticipantEmail,
    detectOverlappingShifts,
    detectDuplicateEmails,
    processShiftParticipants,
    getUserEmail
};
