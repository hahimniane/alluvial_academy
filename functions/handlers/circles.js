const admin = require('firebase-admin');
const {onDocumentUpdated, onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {sendCircleInviteEmail} = require('../services/email/senders');
const {twilioSecrets, sendCircleInviteMessage, sendCircleInviteReminderMessage} = require('../services/sms/sender');

const db = () => admin.firestore();

const _toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const _toDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const _addMonths = (value, months) => {
  const date = value ? new Date(value) : new Date();
  date.setMonth(date.getMonth() + months);
  return date;
};

const _readString = (data, keys, fallback = '') => {
  for (const key of keys) {
    const value = data?.[key];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return fallback;
};

const _getCircleMembers = async (circleId) => {
  const snapshot = await db()
    .collection('circle_members')
    .where('circle_id', '==', circleId)
    .orderBy('payout_position')
    .get();

  return snapshot.docs.map((doc) => ({id: doc.id, ref: doc.ref, ...doc.data()}));
};

const _getActiveMembers = (members) =>
  members.filter((member) => _readString(member, ['status']) === 'active');

const _getHeadMember = (members) =>
  members.find((member) => member.is_tontine_head === true || member.isTontineHead === true);

const _recipientForCycle = (members, cycleIndex) => {
  const targetPosition = cycleIndex + 1;
  return (
    members.find(
      (member) => _toNumber(member.payout_position ?? member.payoutPosition) === targetPosition,
    ) || members[cycleIndex % Math.max(1, members.length)]
  );
};

const _sendNotifications = async (userIds, title, body, data = {}) => {
  const uniqueIds = [...new Set(userIds.filter(Boolean))];
  if (uniqueIds.length === 0) return;

  for (const userId of uniqueIds) {
    try {
      const userDoc = await db().collection('users').doc(userId).get();
      if (!userDoc.exists) continue;
      const userData = userDoc.data() || {};
      const fcmTokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
      const tokens = [
        ...fcmTokens
          .map((entry) => (entry && entry.token ? entry.token : null))
          .filter(Boolean),
        ...(userData.fcmToken ? [userData.fcmToken] : []),
      ];

      if (tokens.length === 0) continue;

      await admin.messaging().sendEachForMulticast({
        tokens: [...new Set(tokens)],
        notification: {title, body},
        data: {
          ...Object.entries(data).reduce((acc, [key, value]) => {
            acc[key] = value == null ? '' : String(value);
            return acc;
          }, {}),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
    } catch (error) {
      console.error('[CIRCLES] Failed to send notification', {userId, error: error.message});
    }
  }
};

const _createCycleAndContributions = async (circleId, circleData, cycleIndex, members) => {
  const activeMembers = _getActiveMembers(members);
  if (activeMembers.length === 0) return null;

  const contributionAmount = _toNumber(
    circleData.contribution_amount ?? circleData.contributionAmount,
  );
  const payoutAmount = contributionAmount * activeMembers.length;
  const recipient = _recipientForCycle(activeMembers, cycleIndex);
  if (!recipient) return null;

  const startDate = _toDate(circleData.start_date ?? circleData.startDate) || new Date();
  const dueDate = _addMonths(startDate, cycleIndex);
  const cycleRef = db().collection('circle_cycles').doc();
  const batch = db().batch();

  batch.set(cycleRef, {
    circle_id: circleId,
    cycle_number: cycleIndex + 1,
    due_date: admin.firestore.Timestamp.fromDate(dueDate),
    payout_recipient_user_id: _readString(recipient, ['user_id', 'userId']),
    payout_amount: payoutAmount,
    status: 'in_progress',
    total_expected: payoutAmount,
    total_collected: 0,
  });

  for (const member of activeMembers) {
    const contributionRef = db().collection('circle_contributions').doc();
    batch.set(contributionRef, {
      circle_id: circleId,
      cycle_id: cycleRef.id,
      user_id: _readString(member, ['user_id', 'userId']),
      display_name: _readString(member, ['display_name', 'displayName'], 'Member'),
      expected_amount: contributionAmount,
      status: 'pending',
      payment_method: 'manual',
    });
  }

  await batch.commit();

  return {
    cycleId: cycleRef.id,
    recipientUserId: _readString(recipient, ['user_id', 'userId']),
    recipientName: _readString(recipient, ['display_name', 'displayName'], 'Member'),
    activeMembers,
    payoutAmount,
  };
};

const onCircleActivated = onDocumentUpdated('circles/{circleId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return null;

  const beforeStatus = _readString(before, ['status']);
  const afterStatus = _readString(after, ['status']);
  if (beforeStatus === afterStatus || afterStatus !== 'active') {
    return null;
  }

  const {circleId} = event.params;
  const members = await _getCircleMembers(circleId);
  const cycleIndex = _toNumber(after.current_cycle_index ?? after.currentCycleIndex);
  const result = await _createCycleAndContributions(circleId, after, cycleIndex, members);
  if (!result) return null;

  await _sendNotifications(
    result.activeMembers.map((member) => _readString(member, ['user_id', 'userId'])),
    'Savings circle activated',
    `${_readString(after, ['title'], 'Your circle')} is now active. ${result.recipientName} receives the first payout.`,
    {
      type: 'circle_activated',
      circleId,
      cycleId: result.cycleId,
    },
  );

  return null;
});

const onContributionStatusChanged = onDocumentUpdated(
  'circle_contributions/{contributionId}',
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return null;

    const beforeStatus = _readString(before, ['status']);
    const afterStatus = _readString(after, ['status']);
    if (beforeStatus === afterStatus) {
      return null;
    }

    const circleId = _readString(after, ['circle_id', 'circleId']);
    const cycleId = _readString(after, ['cycle_id', 'cycleId']);
    if (!circleId || !cycleId) return null;

    const members = await _getCircleMembers(circleId);
    const head = _getHeadMember(members);
    const memberIds = _getActiveMembers(members).map((member) =>
      _readString(member, ['user_id', 'userId']),
    );

    const contributionsSnapshot = await db()
      .collection('circle_contributions')
      .where('cycle_id', '==', cycleId)
      .get();
    const contributions = contributionsSnapshot.docs.map((doc) => doc.data());
    const totalCollected = contributions
      .filter((item) => _readString(item, ['status']) === 'confirmed')
      .reduce(
        (sum, item) => sum + _toNumber(item.submitted_amount ?? item.submittedAmount),
        0,
      );

    await db().collection('circle_cycles').doc(cycleId).set(
      {
        total_collected: totalCollected,
      },
      {merge: true},
    );

    if (afterStatus === 'confirmed' && beforeStatus !== 'confirmed') {
      const member = members.find(
        (item) =>
          _readString(item, ['user_id', 'userId']) === _readString(after, ['user_id', 'userId']),
      );
      if (member) {
        await member.ref.update({
          total_contributed: admin.firestore.FieldValue.increment(
            _toNumber(after.submitted_amount ?? after.submittedAmount),
          ),
        });
      }
    }

    if (afterStatus === 'submitted') {
      const submitterName = _readString(after, ['display_name', 'displayName'], 'A member');
      await _sendNotifications(
        [
          ...(head ? [_readString(head, ['user_id', 'userId'])] : []),
          ...memberIds,
        ],
        'Contribution submitted',
        `${submitterName} submitted a payment for this cycle.`,
        {
          type: 'circle_contribution_submitted',
          circleId,
          cycleId,
        },
      );
      return null;
    }

    if (afterStatus === 'confirmed') {
      const activeMembers = _getActiveMembers(members);
      const contributionByUserId = new Map(
        contributions.map((item) => [_readString(item, ['user_id', 'userId']), item]),
      );
      const allConfirmed =
        activeMembers.length > 0 &&
        activeMembers.every(
          (member) =>
            _readString(contributionByUserId.get(_readString(member, ['user_id', 'userId'])), [
              'status',
            ]) === 'confirmed',
        );

      if (allConfirmed && head) {
        await _sendNotifications(
          [_readString(head, ['user_id', 'userId'])],
          'All contributions confirmed',
          'Every member contribution is confirmed. You can mark the payout as sent.',
          {
            type: 'circle_cycle_ready_for_payout',
            circleId,
            cycleId,
          },
        );
      }
    }

    return null;
  },
);

const onCycleCompleted = onDocumentUpdated('circle_cycles/{cycleId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return null;

  const beforeStatus = _readString(before, ['status']);
  const afterStatus = _readString(after, ['status']);
  if (beforeStatus === afterStatus || afterStatus !== 'completed') {
    return null;
  }

  const circleId = _readString(after, ['circle_id', 'circleId']);
  if (!circleId) return null;

  const circleRef = db().collection('circles').doc(circleId);
  const circleSnap = await circleRef.get();
  if (!circleSnap.exists) return null;
  const circleData = circleSnap.data() || {};
  const members = await _getCircleMembers(circleId);
  const recipient = members.find(
    (member) =>
      _readString(member, ['user_id', 'userId']) ===
      _readString(after, ['payout_recipient_user_id', 'payoutRecipientUserId']),
  );
  const nextCycleIndex =
    _toNumber(circleData.current_cycle_index ?? circleData.currentCycleIndex) + 1;
  const totalMembers = _toNumber(circleData.total_members ?? circleData.totalMembers) || members.length;
  const payoutAmount = _toNumber(after.payout_amount ?? after.payoutAmount);
  const batch = db().batch();

  if (recipient) {
    batch.update(recipient.ref, {
      total_received: admin.firestore.FieldValue.increment(payoutAmount),
      has_received_payout: true,
    });
  }

  if (nextCycleIndex >= totalMembers) {
    batch.update(circleRef, {
      current_cycle_index: nextCycleIndex,
      status: 'completed',
    });

    for (const member of members) {
      batch.update(member.ref, {status: 'completed'});
    }

    await batch.commit();
    await _sendNotifications(
      members.map((member) => _readString(member, ['user_id', 'userId'])),
      'Savings circle completed',
      `${_readString(circleData, ['title'], 'Your circle')} has completed all payout cycles.`,
      {
        type: 'circle_completed',
        circleId,
      },
    );
    return null;
  }

  batch.update(circleRef, {
    current_cycle_index: nextCycleIndex,
  });
  await batch.commit();

  const result = await _createCycleAndContributions(circleId, circleData, nextCycleIndex, members);
  if (!result) return null;

  await _sendNotifications(
    result.activeMembers.map((member) => _readString(member, ['user_id', 'userId'])),
    'New savings cycle started',
    `${result.recipientName} is the next payout recipient for ${_readString(
      circleData,
      ['title'],
      'your circle',
    )}.`,
    {
      type: 'circle_next_cycle_started',
      circleId,
      cycleId: result.cycleId,
    },
  );

  return null;
});

const onMemberJoined = onDocumentUpdated('circle_members/{memberId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return null;

  const beforeStatus = _readString(before, ['status']);
  const afterStatus = _readString(after, ['status']);
  if (beforeStatus === afterStatus || beforeStatus !== 'invited' || afterStatus !== 'active') {
    return null;
  }

  const circleId = _readString(after, ['circle_id', 'circleId']);
  if (!circleId) return null;
  const members = await _getCircleMembers(circleId);
  const head = _getHeadMember(members);
  if (!head) return null;

  const memberName = _readString(after, ['display_name', 'displayName'], 'A member');

  await _sendNotifications(
    [_readString(head, ['user_id', 'userId'])],
    'Member joined your circle',
    `${memberName} joined your savings circle.`,
    {
      type: 'circle_member_joined',
      circleId,
    },
  );

  const circleRef = db().collection('circles').doc(circleId);
  const circleSnap = await circleRef.get();
  if (!circleSnap.exists) return null;
  const circleData = circleSnap.data() || {};
  const circleStatus = _readString(circleData, ['status']);
  if (circleStatus !== 'forming') return null;

  const totalMembers = _toNumber(circleData.total_members ?? circleData.totalMembers) || members.length;
  const activeMembers = _getActiveMembers(members);

  if (activeMembers.length >= totalMembers) {
    console.log(`[CIRCLES] All ${totalMembers} members active — auto-activating circle ${circleId}`);
    await circleRef.update({status: 'active'});
  }

  return null;
});

const onOpenCircleCreated = onDocumentCreated('circles/{circleId}', async (event) => {
  const data = event.data?.data();
  if (!data) return null;

  const enrollmentMode = _readString(data, ['enrollment_mode', 'enrollmentMode']);
  const circleType = _readString(data, ['type']);
  if (enrollmentMode !== 'open' || circleType !== 'teacher') return null;

  const circleName = _readString(data, ['title'], 'a savings circle');
  const contributionAmount = _toNumber(data.contribution_amount ?? data.contributionAmount);
  const eligibilityRules = data.eligibility_rules || data.eligibilityRules || null;

  const incomeMultiplier = eligibilityRules ? _toNumber(eligibilityRules.income_multiplier ?? eligibilityRules.incomeMultiplier) || 0 : 0;
  const minTenureMonths = eligibilityRules ? _toNumber(eligibilityRules.min_tenure_months ?? eligibilityRules.minTenureMonths) || 0 : 0;
  const minShiftsLast30Days = eligibilityRules ? _toNumber(eligibilityRules.min_shifts_last_30_days ?? eligibilityRules.minShiftsLast30Days) || 0 : 0;

  const teachersSnapshot = await db()
    .collection('users')
    .where('user_type', '==', 'teacher')
    .where('is_active', '==', true)
    .get();

  if (teachersSnapshot.empty) return null;

  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const eligibleTeacherIds = [];

  for (const teacherDoc of teachersSnapshot.docs) {
    const teacher = teacherDoc.data();
    let eligible = true;

    if (incomeMultiplier > 0 && contributionAmount > 0) {
      const hourlyRate = _toNumber(teacher.wage_override ?? teacher.hourly_rate) || 0;
      const estimatedMonthly = hourlyRate * 10 * 4;
      if (estimatedMonthly < contributionAmount * incomeMultiplier) {
        eligible = false;
      }
    }

    if (eligible && minTenureMonths > 0) {
      const startDate = _toDate(teacher.employment_start_date ?? teacher.date_added);
      if (!startDate) {
        eligible = false;
      } else {
        const monthsEmployed = Math.floor((now - startDate) / (30 * 24 * 60 * 60 * 1000));
        if (monthsEmployed < minTenureMonths) eligible = false;
      }
    }

    if (eligible && minShiftsLast30Days > 0) {
      try {
        const shiftsSnap = await db()
          .collection('teaching_shifts')
          .where('teacher_id', '==', teacherDoc.id)
          .where('date', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
          .get();
        if (shiftsSnap.size < minShiftsLast30Days) eligible = false;
      } catch {
        // Skip activity check on query failure
      }
    }

    if (eligible) {
      eligibleTeacherIds.push(teacherDoc.id);
    }
  }

  if (eligibleTeacherIds.length === 0) {
    console.log(`[CIRCLES] No eligible teachers found for open circle "${circleName}"`);
    return null;
  }

  console.log(`[CIRCLES] Notifying ${eligibleTeacherIds.length} eligible teachers about open circle "${circleName}"`);
  await _sendNotifications(
    eligibleTeacherIds,
    'New savings circle available!',
    `A new circle "${circleName}" is open for enrollment. Check if you qualify and join now!`,
    {
      type: 'open_circle_available',
      circleId: event.params.circleId,
    },
  );

  return null;
});

const onOpenCircleMemberAdded = onDocumentCreated('circle_members/{memberId}', async (event) => {
  const data = event.data?.data();
  if (!data) return null;

  const memberStatus = _readString(data, ['status']);
  if (memberStatus !== 'active') return null;

  const circleId = _readString(data, ['circle_id', 'circleId']);
  if (!circleId) return null;

  const circleRef = db().collection('circles').doc(circleId);
  const circleSnap = await circleRef.get();
  if (!circleSnap.exists) return null;

  const circleData = circleSnap.data() || {};
  const enrollmentMode = _readString(circleData, ['enrollment_mode', 'enrollmentMode']);
  if (enrollmentMode !== 'open') return null;

  const circleStatus = _readString(circleData, ['status']);
  if (circleStatus !== 'forming') return null;

  const maxMembers = _toNumber(circleData.max_members ?? circleData.maxMembers);
  if (!maxMembers || maxMembers <= 0) return null;

  const totalMembers = _toNumber(circleData.total_members ?? circleData.totalMembers);
  if (totalMembers >= maxMembers) {
    console.log(`[CIRCLES] Open circle ${circleId} reached max capacity (${maxMembers}) — auto-activating`);
    await circleRef.update({status: 'active'});
  }

  return null;
});

const _getInviterName = async (createdByUid) => {
  if (!createdByUid) return '';
  try {
    const userDoc = await db().collection('users').doc(createdByUid).get();
    if (!userDoc.exists) return '';
    const data = userDoc.data() || {};
    const first = _readString(data, ['first_name', 'firstName']);
    const last = _readString(data, ['last_name', 'lastName']);
    return [first, last].filter(Boolean).join(' ') || '';
  } catch {
    return '';
  }
};

const onInviteCreated = onDocumentCreated(
  {document: 'circle_invites/{inviteId}', secrets: twilioSecrets},
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    const inviteMethod = _readString(data, ['invite_method', 'inviteMethod']);
    const contactInfo = _readString(data, ['contact_info', 'contactInfo']);
    const circleName = _readString(data, ['circle_name', 'circleName'], 'a savings circle');
    const existingUserId = _readString(data, ['existing_user_id', 'existingUserId']);
    const isExistingUser = !!existingUserId;
    const createdBy = _readString(data, ['created_by', 'createdBy']);
    const inviterName = await _getInviterName(createdBy);

    if (inviteMethod === 'email' && contactInfo) {
      try {
        await sendCircleInviteEmail(contactInfo, circleName, isExistingUser, inviterName);
        console.log(`[CIRCLES] Sent invite email to ${contactInfo} for circle ${circleName}`);
      } catch (error) {
        console.error(`[CIRCLES] Failed to send invite email to ${contactInfo}:`, error.message);
      }
    }

    if (inviteMethod === 'phone' && contactInfo && !isExistingUser) {
      try {
        await sendCircleInviteMessage(contactInfo, circleName, inviterName);
        console.log(`[CIRCLES] Sent invite message to ${contactInfo} for circle ${circleName}`);
      } catch (error) {
        console.error(`[CIRCLES] Failed to send invite message to ${contactInfo}:`, error.message);
      }
    }

    if (isExistingUser) {
      try {
        const pushBody = inviterName
          ? `${inviterName} has invited you to join "${circleName}". Open the app to review and accept.`
          : `You have been invited to join "${circleName}". Open the app to review and accept.`;
        await _sendNotifications(
          [existingUserId],
          'You\'re invited to a savings circle!',
          pushBody,
          {
            type: 'circle_invite',
            circleId: _readString(data, ['circle_id', 'circleId']),
            inviteId: event.params.inviteId,
          },
        );
        console.log(`[CIRCLES] Sent FCM invite notification to user ${existingUserId} for circle ${circleName}`);
      } catch (error) {
        console.error(`[CIRCLES] Failed to send FCM invite to user ${existingUserId}:`, error.message);
      }
    }

    return null;
  },
);

const resendCircleInvite = onCall({secrets: twilioSecrets}, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const {inviteId} = request.data;
  if (!inviteId) {
    throw new HttpsError('invalid-argument', 'inviteId is required');
  }

  const inviteDoc = await db().collection('circle_invites').doc(inviteId).get();
  if (!inviteDoc.exists) {
    throw new HttpsError('not-found', 'Invite not found');
  }

  const data = inviteDoc.data();
  
  const circleId = _readString(data, ['circle_id', 'circleId']);
  const members = await _getCircleMembers(circleId);
  const head = _getHeadMember(members);
  
  if (!head || _readString(head, ['user_id', 'userId']) !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'Only the head of the circle can resend invites');
  }

  const inviteMethod = _readString(data, ['invite_method', 'inviteMethod']);
  const contactInfo = _readString(data, ['contact_info', 'contactInfo']);
  const circleName = _readString(data, ['circle_name', 'circleName'], 'a savings circle');
  const existingUserId = _readString(data, ['existing_user_id', 'existingUserId']);
  const isExistingUser = !!existingUserId;
  const inviterName = await _getInviterName(request.auth.uid);

  let emailSent = false;
  let smsSent = false;
  let pushSent = false;

  if (inviteMethod === 'email' && contactInfo) {
    try {
      await sendCircleInviteEmail(contactInfo, circleName, isExistingUser, inviterName);
      console.log(`[CIRCLES] Resent invite email to ${contactInfo} for circle ${circleName}`);
      emailSent = true;
    } catch (error) {
      console.error(`[CIRCLES] Failed to resend invite email to ${contactInfo}:`, error.message);
    }
  }

  if (inviteMethod === 'phone' && contactInfo && !isExistingUser) {
    try {
      const result = await sendCircleInviteReminderMessage(contactInfo, circleName, inviterName);
      if (result && result.sent) {
        console.log(`[CIRCLES] Resent invite via ${result.channel} to ${contactInfo} for circle ${circleName}`);
        smsSent = true;
      }
    } catch (error) {
      console.error(`[CIRCLES] Failed to resend invite message to ${contactInfo}:`, error.message);
    }
  }

  if (isExistingUser) {
    try {
      const pushBody = inviterName
        ? `${inviterName} is reminding you to join "${circleName}". Open the app to accept.`
        : `You have a pending invitation to join "${circleName}". Open the app to review and accept.`;
      await _sendNotifications(
        [existingUserId],
        'Reminder: You\'re invited to a savings circle!',
        pushBody,
        {
          type: 'circle_invite_reminder',
          circleId,
          inviteId,
        },
      );
      console.log(`[CIRCLES] Resent FCM invite notification to user ${existingUserId} for circle ${circleName}`);
      pushSent = true;
    } catch (error) {
      console.error(`[CIRCLES] Failed to resend FCM invite to user ${existingUserId}:`, error.message);
    }
  }

  if (!emailSent && !smsSent && !pushSent) {
    throw new HttpsError('failed-precondition', 'Could not deliver the invitation. Please check the contact information.');
  }

  return {success: true, emailSent, smsSent, pushSent};
});

module.exports = {
  onCircleActivated,
  onContributionStatusChanged,
  onCycleCompleted,
  onMemberJoined,
  onInviteCreated,
  onOpenCircleCreated,
  onOpenCircleMemberAdded,
  resendCircleInvite,
};
