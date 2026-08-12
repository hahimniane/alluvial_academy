const {isDeepStrictEqual} = require('util');
const admin = require('firebase-admin');
const {
  onDocumentWrittenWithAuthContext,
} = require('firebase-functions/v2/firestore');
const {
  recordDecisionAudit,
} = require('../services/decision_audit');

const _value = (data, keys) => {
  for (const key of keys) {
    let value = data;
    for (const segment of key.split('.')) {
      value = value && value[segment];
    }
    if (value !== undefined && value !== null) {
      return value;
    }
  }
  return undefined;
};

const _string = (value) => (value == null ? '' : String(value).trim());

const _changed = (before, after, keys) =>
  keys.some(
    (key) => !isDeepStrictEqual(
      _value(before, [key]),
      _value(after, [key]),
    ),
  );

const _labelForUser = (data = {}, entityId = '') => {
  const first = _string(_value(data, ['first_name', 'firstName']));
  const last = _string(_value(data, ['last_name', 'lastName']));
  return (
    `${first} ${last}`.trim() ||
    _string(
      _value(data, [
        'display_name',
        'displayName',
        'full_name',
        'fullName',
        'name',
      ]),
    ) ||
    _string(_value(data, ['e-mail', 'email'])) ||
    (entityId ? `User ${entityId}` : 'User')
  );
};

const _labelForShift = (data = {}) =>
  _string(
    _value(data, [
      'custom_name',
      'auto_generated_name',
      'subject_display_name',
      'subject',
    ]),
  ) || 'Shift';

const _labelForInvoice = (data = {}, entityId = '') =>
  _string(_value(data, ['invoice_number', 'invoiceNumber'])) ||
  entityId ||
  'Invoice';

const _isTechnicalActor = (value) => {
  const normalized = _string(value).toLowerCase();
  return normalized === 'system' ||
    normalized === 'automation' ||
    normalized.endsWith('.gserviceaccount.com') ||
    normalized.includes('firebase-adminsdk') ||
    normalized.includes('compute@developer');
};

const _labelForTimesheet = (data = {}, entityId = '') =>
  _string(_value(data, ['shift_title', 'shiftTitle', 'subject'])) ||
  entityId ||
  'Timesheet';

const _labelForApplication = (data = {}, entityId = '') => {
  const first = _string(_value(data, ['first_name', 'firstName']));
  const last = _string(_value(data, ['last_name', 'lastName']));
  return (
    `${first} ${last}`.trim() ||
    _string(_value(data, ['name', 'full_name', 'fullName', 'email'])) ||
    entityId ||
    'Application'
  );
};

const _labelForTask = (data = {}, entityId = '') =>
  _string(_value(data, ['title', 'name'])) || entityId || 'Task';

const _labelForFormResponse = (data = {}, entityId = '') =>
  _string(_value(data, ['formTitle', 'form_title', 'title'])) ||
  entityId ||
  'Form response';

const _labelForNoShow = (data = {}, entityId = '') =>
  _string(
    _value(data, [
      'shift_title',
      'shiftTitle',
      'teacher_name',
      'teacherName',
      'student_name',
      'studentName',
    ]),
  ) || entityId || 'No-show report';

const _status = (data, keys = ['status']) => {
  const raw = _string(_value(data, keys)).toLowerCase();
  return raw.includes('.') ? raw.split('.').pop() : raw;
};

const classifyUserDecisions = (before, after) => {
  if (!before && after) return [{action: 'user.created'}];
  if (before && !after) return [{action: 'user.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  const beforeActive = before.is_active !== false;
  const afterActive = after.is_active !== false;
  if (beforeActive && !afterActive) {
    decisions.push({action: 'user.archived'});
  } else if (!beforeActive && afterActive) {
    decisions.push({action: 'user.restored'});
  }

  if (
    _changed(before, after, [
      'user_type',
      'userType',
      'role',
      'title',
      'secondary_roles',
      'secondaryRoles',
      'is_admin_teacher',
    ])
  ) {
    decisions.push({
      action: 'user.role_changed',
      metadata: {
        previous_role: _string(
          _value(before, ['user_type', 'userType', 'role', 'title']),
        ),
        new_role: _string(
          _value(after, ['user_type', 'userType', 'role', 'title']),
        ),
      },
    });
  }

  if (
    _changed(before, after, [
      'guardian_ids',
      'guardianIds',
      'children_ids',
      'childrenIds',
    ])
  ) {
    decisions.push({action: 'user.guardian_links_changed'});
  }

  return decisions;
};

const classifyShiftDecisions = (before, after) => {
  if (!before && after) return [{action: 'shift.created'}];
  if (before && !after) return [{action: 'shift.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  const beforeStatus = _string(before.status).toLowerCase();
  const afterStatus = _string(after.status).toLowerCase();
  if (beforeStatus !== 'cancelled' && afterStatus === 'cancelled') {
    decisions.push({action: 'shift.cancelled'});
  }

  if (!!before.is_published !== !!after.is_published) {
    decisions.push({
      action: after.is_published ? 'shift.published' : 'shift.unpublished',
    });
  }

  if (
    _changed(before, after, [
      'shift_start',
      'shiftStart',
      'shift_end',
      'shiftEnd',
    ])
  ) {
    decisions.push({action: 'shift.rescheduled'});
  }

  if (_changed(before, after, ['teacher_id', 'teacherId'])) {
    decisions.push({
      action: 'shift.teacher_changed',
      metadata: {
        previous_teacher_id: _string(
          _value(before, ['teacher_id', 'teacherId']),
        ),
        new_teacher_id: _string(
          _value(after, ['teacher_id', 'teacherId']),
        ),
      },
    });
  }

  if (_changed(before, after, ['student_ids', 'studentIds'])) {
    decisions.push({action: 'shift.students_changed'});
  }

  if (
    _changed(before, after, [
      'recording_enabled',
      'recordingEnabled',
      'recording_permission',
      'recordingPermission',
    ])
  ) {
    decisions.push({action: 'shift.recording_permission_changed'});
  }

  return decisions;
};

const classifyInvoiceDecisions = (before, after) => {
  if (!before && after) return [{action: 'invoice.created'}];
  if (before && !after) return [{action: 'invoice.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  const beforeStatus = _string(before.status).toLowerCase();
  const afterStatus = _string(after.status).toLowerCase();
  if (beforeStatus !== afterStatus) {
    if (afterStatus === 'paid') {
      decisions.push({action: 'invoice.paid'});
    } else if (afterStatus === 'cancelled') {
      decisions.push({action: 'invoice.cancelled'});
    } else if (beforeStatus === 'cancelled') {
      decisions.push({action: 'invoice.reopened'});
    }
  }

  if (
    _changed(before, after, [
      'total_amount',
      'totalAmount',
      'currency',
    ])
  ) {
    decisions.push({action: 'invoice.amount_changed'});
  }

  if (_changed(before, after, ['due_date', 'dueDate'])) {
    decisions.push({action: 'invoice.due_date_changed'});
  }

  if (
    _changed(before, after, ['access_cutoff_date', 'accessCutoffDate'])
  ) {
    decisions.push({action: 'invoice.cutoff_changed'});
  }

  return decisions;
};

const classifyTimesheetDecisions = (before, after) => {
  if (before && !after) return [{action: 'timesheet.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  const beforeStatus = _status(before);
  const afterStatus = _status(after);
  if (beforeStatus !== afterStatus) {
    if (afterStatus === 'approved') {
      decisions.push({action: 'timesheet.approved'});
    } else if (afterStatus === 'rejected') {
      decisions.push({action: 'timesheet.rejected'});
    } else if (
      ['approved', 'rejected'].includes(beforeStatus) &&
      ['draft', 'pending'].includes(afterStatus)
    ) {
      decisions.push({action: 'timesheet.reopened'});
    }
  }

  if (
    before.edit_approved !== true &&
    after.edit_approved === true
  ) {
    decisions.push({action: 'timesheet.edit_approved'});
  }
  if (
    before.original_data &&
    !after.original_data &&
    _string(after.edit_rejection_reason)
  ) {
    decisions.push({action: 'timesheet.edit_rejected'});
  }
  if (
    _changed(before, after, [
      'payment_amount',
      'paymentAmount',
      'total_pay',
      'totalPay',
    ]) &&
    ['approved', 'rejected'].includes(afterStatus)
  ) {
    decisions.push({action: 'timesheet.payment_changed'});
  }
  return decisions;
};

const classifyApplicationDecisions = (before, after) => {
  if (before && !after) return [{action: 'application.deleted'}];
  if (!before || !after) return [];

  const beforeStatus = _status(before);
  const afterStatus = _status(after);
  if (beforeStatus === afterStatus) return [];
  if (['approved', 'accepted', 'hired'].includes(afterStatus)) {
    return [{action: 'application.approved'}];
  }
  if (['rejected', 'declined'].includes(afterStatus)) {
    return [{action: 'application.rejected'}];
  }
  return [{
    action: 'application.status_changed',
    metadata: {
      previous_status: beforeStatus,
      new_status: afterStatus,
    },
  }];
};

const classifyTaskDecisions = (before, after) => {
  if (!before && after) return [{action: 'task.created'}];
  if (before && !after) return [{action: 'task.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  if (!!before.isArchived !== !!after.isArchived) {
    decisions.push({
      action: after.isArchived ? 'task.archived' : 'task.restored',
    });
  }
  if (_changed(before, after, ['assignedTo', 'assigned_to'])) {
    decisions.push({action: 'task.assignees_changed'});
  }
  if (_changed(before, after, ['dueDate', 'due_date'])) {
    decisions.push({action: 'task.due_date_changed'});
  }
  const beforeStatus = _status(before);
  const afterStatus = _status(after);
  if (beforeStatus !== afterStatus) {
    decisions.push({
      action: 'task.status_changed',
      metadata: {
        previous_status: beforeStatus,
        new_status: afterStatus,
      },
    });
  }
  return decisions;
};

const classifyFormResponseDecisions = (before, after) => {
  if (before && !after) return [{action: 'form_response.deleted'}];
  if (!before || !after) return [];
  const beforeStatus = _status(before, ['reviewStatus', 'review_status']);
  const afterStatus = _status(after, ['reviewStatus', 'review_status']);
  if (beforeStatus === afterStatus) return [];
  if (['accepted', 'approved'].includes(afterStatus)) {
    return [{action: 'form_response.accepted'}];
  }
  if (['rejected', 'declined'].includes(afterStatus)) {
    return [{action: 'form_response.rejected'}];
  }
  if (!afterStatus) return [{action: 'form_response.review_reset'}];
  return [{
    action: 'form_response.review_changed',
    metadata: {
      previous_status: beforeStatus,
      new_status: afterStatus,
    },
  }];
};

const classifyNoShowDecisions = (before, after) => {
  if (before && !after) return [{action: 'no_show.deleted'}];
  if (!before || !after) return [];
  const beforeStatus = _status(before);
  const afterStatus = _status(after);
  if (beforeStatus !== 'reviewed' && afterStatus === 'reviewed') {
    return [{action: 'no_show.reviewed'}];
  }
  if (beforeStatus === 'reviewed' && afterStatus !== 'reviewed') {
    return [{action: 'no_show.reopened'}];
  }
  return [];
};

const classifyEnrollmentDecisions = (before, after) => {
  if (before && !after) return [{action: 'enrollment.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  const statusKeys = ['metadata.status', 'status'];
  const beforeStatus = _status(before, statusKeys);
  const afterStatus = _status(after, statusKeys);
  if (beforeStatus !== afterStatus) {
    if (afterStatus === 'archived') {
      decisions.push({action: 'enrollment.archived'});
    } else if (beforeStatus === 'archived') {
      decisions.push({action: 'enrollment.restored'});
    } else if (afterStatus === 'matched') {
      decisions.push({action: 'enrollment.matched'});
    } else {
      decisions.push({
        action: 'enrollment.status_changed',
        metadata: {
          previous_status: beforeStatus,
          new_status: afterStatus,
        },
      });
    }
  }
  if (
    _changed(before, after, [
      'metadata.parentId',
      'metadata.parent_id',
      'parentId',
      'parent_id',
    ])
  ) {
    decisions.push({action: 'enrollment.parent_link_changed'});
  }
  return decisions;
};

const classifyAuditDecisions = (before, after) => {
  if (before && !after) return [{action: 'audit.deleted'}];
  if (!before || !after) return [];

  const decisions = [];
  const beforeStatus = _status(before);
  const afterStatus = _status(after);
  if (beforeStatus !== afterStatus) {
    decisions.push({
      action: 'audit.status_changed',
      metadata: {
        previous_status: beforeStatus,
        new_status: afterStatus,
      },
    });
  }
  if (_changed(before, after, ['reviewChain'])) {
    decisions.push({action: 'audit.review_changed'});
  }
  if (
    _changed(before, after, [
      'ceoBonusMonthlyUsd',
      'ceoPaycutMonthlyUsd',
      'ceoAdjustmentRationale',
      'paymentAdjustment',
      'payment_adjustment',
    ])
  ) {
    decisions.push({action: 'audit.compensation_changed'});
  }
  return decisions;
};

const classifySettingDecisions = (before, after) => {
  if (!before && after) return [{action: 'setting.created'}];
  if (before && !after) return [{action: 'setting.deleted'}];
  if (!before || !after || isDeepStrictEqual(before, after)) return [];
  const changedKeys = [...new Set([
    ...Object.keys(before),
    ...Object.keys(after),
  ])].filter((key) => !isDeepStrictEqual(before[key], after[key]));
  return [{
    action: 'setting.changed',
    metadata: {changed_keys: changedKeys.slice(0, 40)},
  }];
};

const _actorUidFor = (event, data, action) => {
  const authType = _string(event.authType).toLowerCase();
  const authId = _string(event.authId);
  if (
    authId &&
    authType !== 'system' &&
    !_isTechnicalActor(authId)
  ) {
    return authId;
  }

  const actionSpecificKeys = action.includes('archived')
    ? ['deactivated_by_uid', 'archived_by_uid', 'archivedByUid']
    : action.includes('restored')
      ? ['activated_by_uid', 'restored_by_uid', 'restoredByUid']
      : action.includes('deleted')
        ? ['deleted_by', 'deleted_by_uid', 'deletedBy', 'deletedByUid']
        : action === 'invoice.payment_recorded' ||
            action === 'invoice.paid'
          ? [
              'recorded_by_uid',
              'recorded_by',
              'last_payment_by_uid',
              'lastPaymentByUid',
              'payer_id',
              'payerId',
            ]
        : [];

  return _string(
    _value(data, [
      ...actionSpecificKeys,
      'updated_by_uid',
      'updated_by',
      'updatedBy',
      'metadata.updatedBy',
      'metadata.updated_by',
      'reviewed_by',
      'reviewedBy',
      'approved_by',
      'approvedBy',
      'rejected_by',
      'rejectedBy',
      'created_by_uid',
      'created_by',
      'createdBy',
      'created_by_admin_id',
    ]),
  );
};

const _actorFallbackFor = (data, action) => {
  const prefix = action.includes('archived')
    ? 'deactivated'
    : action.includes('restored')
      ? 'activated'
      : action.includes('deleted')
        ? 'deleted'
        : action.includes('created')
          ? 'created'
          : 'updated';
  return {
    actor_name: _value(data, [
      `${prefix}_by_name`,
      `${prefix}ByName`,
      'recorded_by_name',
      'recordedByName',
      'last_payment_by_name',
      'lastPaymentByName',
      'created_by_name',
      'createdByName',
      'actor_name',
      'actorName',
    ]),
    actor_email: _value(data, [
      `${prefix}_by_email`,
      `${prefix}ByEmail`,
      'recorded_by_email',
      'recordedByEmail',
      'last_payment_by_email',
      'lastPaymentByEmail',
      'created_by_email',
      'createdByEmail',
      'actor_email',
      'actorEmail',
    ]),
    actor_role: _value(data, ['actor_role', 'actorRole']),
  };
};

const _writeDecisions = async ({
  event,
  entityType,
  entityId,
  before,
  after,
  decisions,
  label,
}) => {
  const data = after || before || {};
  const authType = _string(event.authType).toLowerCase();

  if (
    !after &&
    authType === 'system' &&
    (entityType === 'user' || entityType === 'invoice')
  ) {
    return;
  }

  await Promise.all(
    decisions.map((decision, index) => {
      const actorUid = _actorUidFor(event, data, decision.action);
      const actorFallback = _actorFallbackFor(data, decision.action);
      if (
        entityType === 'user' &&
        decision.action === 'user.created' &&
        actorUid === entityId &&
        !_string(actorFallback.actor_name)
      ) {
        actorFallback.actor_name = _labelForUser(data, entityId);
      }
      return recordDecisionAudit({
        db: admin.firestore(),
        entityType,
        entityId,
        entityLabel: label,
        action: decision.action,
        actorUid,
        actorFallback,
        source: authType === 'system' || _isTechnicalActor(event.authId)
          ? 'server'
          : 'authenticated_write',
        metadata: decision.metadata || {},
        eventId: `${event.id || Date.now()}_${index}_${decision.action}`,
      });
    }),
  );
};

const onUserDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'users/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'user',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyUserDecisions(before, after),
      label: _labelForUser(after || before, event.params.entityId),
    });
  },
);

const onShiftDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'teaching_shifts/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'shift',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyShiftDecisions(before, after),
      label: _labelForShift(after || before),
    });
  },
);

const onInvoiceDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'invoices/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'invoice',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyInvoiceDecisions(before, after),
      label: _labelForInvoice(after || before, event.params.entityId),
    });
  },
);

const onPaymentDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'payments/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (before || !after) return;
    const invoiceId = _string(
      _value(after, ['invoice_id', 'invoiceId']),
    );
    if (!invoiceId) return;
    const invoice = await admin
      .firestore()
      .collection('invoices')
      .doc(invoiceId)
      .get();
    const invoiceData = invoice.exists ? invoice.data() || {} : {};
    await _writeDecisions({
      event,
      entityType: 'invoice',
      entityId: invoiceId,
      before: null,
      after,
      decisions: [
        {
          action: 'invoice.payment_recorded',
          metadata: {
            payment_id: event.params.entityId,
            amount: Number(after.amount || 0),
            payment_method: _string(
              _value(after, ['payment_method', 'paymentMethod']),
            ),
          },
        },
      ],
      label: _labelForInvoice(invoiceData, invoiceId),
    });
  },
);

const onTimesheetDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'timesheet_entries/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'timesheet',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyTimesheetDecisions(before, after),
      label: _labelForTimesheet(after || before, event.params.entityId),
    });
  },
);

const onTeacherApplicationDecisionWritten =
  onDocumentWrittenWithAuthContext(
    {document: 'teacher_applications/{entityId}', region: 'us-central1'},
    async (event) => {
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;
      await _writeDecisions({
        event,
        entityType: 'application',
        entityId: event.params.entityId,
        before,
        after,
        decisions: classifyApplicationDecisions(before, after),
        label: _labelForApplication(after || before, event.params.entityId),
      });
    },
  );

const onTaskDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'tasks/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'task',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyTaskDecisions(before, after),
      label: _labelForTask(after || before, event.params.entityId),
    });
  },
);

const onFormResponseDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'form_responses/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'form_response',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyFormResponseDecisions(before, after),
      label: _labelForFormResponse(after || before, event.params.entityId),
    });
  },
);

const _noShowHandler = (collection) =>
  onDocumentWrittenWithAuthContext(
    {document: `${collection}/{entityId}`, region: 'us-central1'},
    async (event) => {
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;
      await _writeDecisions({
        event,
        entityType: 'no_show',
        entityId: `${collection}:${event.params.entityId}`,
        before,
        after,
        decisions: classifyNoShowDecisions(before, after),
        label: _labelForNoShow(after || before, event.params.entityId),
      });
    },
  );

const onNoShowDecisionWritten = _noShowHandler('no_show_reports');
const onClassAttendanceAlertDecisionWritten =
  _noShowHandler('class_attendance_alerts');

const onEnrollmentDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'enrollments/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'enrollment',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifyEnrollmentDecisions(before, after),
      label: _labelForApplication(after || before, event.params.entityId),
    });
  },
);

const _auditHandler = (collection) =>
  onDocumentWrittenWithAuthContext(
    {document: `${collection}/{entityId}`, region: 'us-central1'},
    async (event) => {
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;
      const data = after || before || {};
      await _writeDecisions({
        event,
        entityType: 'audit',
        entityId: `${collection}:${event.params.entityId}`,
        before,
        after,
        decisions: classifyAuditDecisions(before, after),
        label: _string(
          _value(data, [
            'teacherName',
            'teacher_name',
            'adminName',
            'admin_name',
            'yearMonth',
          ]),
        ) || event.params.entityId,
      });
    },
  );

const onTeacherAuditDecisionWritten = _auditHandler('teacher_audits');
const onAdminAuditDecisionWritten = _auditHandler('admin_audits');

const onSettingDecisionWritten = onDocumentWrittenWithAuthContext(
  {document: 'settings/{entityId}', region: 'us-central1'},
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    await _writeDecisions({
      event,
      entityType: 'setting',
      entityId: event.params.entityId,
      before,
      after,
      decisions: classifySettingDecisions(before, after),
      label: event.params.entityId,
    });
  },
);

module.exports = {
  classifyApplicationDecisions,
  classifyAuditDecisions,
  classifyEnrollmentDecisions,
  classifyFormResponseDecisions,
  classifyInvoiceDecisions,
  classifyNoShowDecisions,
  classifyShiftDecisions,
  classifyTaskDecisions,
  classifyTimesheetDecisions,
  classifyUserDecisions,
  classifySettingDecisions,
  onAdminAuditDecisionWritten,
  onClassAttendanceAlertDecisionWritten,
  onEnrollmentDecisionWritten,
  onFormResponseDecisionWritten,
  onInvoiceDecisionWritten,
  onNoShowDecisionWritten,
  onPaymentDecisionWritten,
  onShiftDecisionWritten,
  onTaskDecisionWritten,
  onTeacherApplicationDecisionWritten,
  onTeacherAuditDecisionWritten,
  onTimesheetDecisionWritten,
  onUserDecisionWritten,
  onSettingDecisionWritten,
};
