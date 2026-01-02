const {Timestamp} = require('firebase-admin/firestore');

const _asDate = (value) => {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
};

const _toNumber = (value) => {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  const parsed = Number(value);
  return isNaN(parsed) ? 0 : parsed;
};

const generateInvoiceFromShifts = ({shifts, parentId, studentId, period, currency = 'USD'}) => {
  const issuedDate = new Date();
  const dueDate = new Date(issuedDate.getTime() + 30 * 24 * 60 * 60 * 1000);

  const items = [];
  let totalAmount = 0;

  for (const shift of shifts) {
    const start = _asDate(shift.shift_start || shift.shiftStart);
    const end = _asDate(shift.shift_end || shift.shiftEnd);
    const hourlyRate = _toNumber(shift.hourly_rate ?? shift.hourlyRate);

    const hours = start && end ? Math.max(0, (end.getTime() - start.getTime()) / 36e5) : 0;
    const total = Number((hours * hourlyRate).toFixed(2));
    totalAmount += total;

    const subject =
      (shift.subject_display_name || shift.subjectDisplayName || shift.subject || 'Class').toString();
    const dateLabel = start ? start.toISOString().slice(0, 10) : 'Unknown date';
    const description = `${subject} • ${dateLabel}`;

    items.push({
      description,
      quantity: 1,
      unit_price: Number(hourlyRate.toFixed(2)),
      total,
      shift_ids: [shift.id].filter(Boolean),
    });
  }

  totalAmount = Number(totalAmount.toFixed(2));

  return {
    parent_id: parentId,
    student_id: studentId,
    status: 'pending',
    total_amount: totalAmount,
    paid_amount: 0,
    currency,
    issued_date: Timestamp.fromDate(issuedDate),
    due_date: Timestamp.fromDate(dueDate),
    items,
    shift_ids: shifts.map((s) => s.id).filter(Boolean),
    period: period || null,
  };
};

module.exports = {
  generateInvoiceFromShifts,
};

