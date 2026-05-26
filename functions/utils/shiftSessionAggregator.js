/**
 * Standardized aggregator for shift hours and pay.
 * Implements the "Smart Detect" logic (Rules R1-R6) to resolve
 * contradictions between multi-segment shifts and duplicate writes.
 */

function toDate(v) {
  if (!v) return null;
  if (v.toDate && typeof v.toDate === 'function') return v.toDate();
  if (v instanceof Date) return v;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

function toDouble(v, fallback = 0.0) {
  if (v === null || v === undefined) return fallback;
  const x = Number(v);
  return Number.isFinite(x) ? x : fallback;
}

function canonicalShiftIdForGrouping(rawSid) {
  const sid = String(rawSid || '').trim();
  if (!sid) return '';
  if (sid.startsWith('tpl_tpl_')) return 'tpl_' + sid.slice(8);
  return sid;
}

function getShiftIdIndexKeys(rawSid) {
  const sid = String(rawSid || '').trim();
  if (!sid) return [];
  
  const keys = new Set([sid]);
  let canonical = sid;
  if (sid.startsWith('tpl_tpl_')) {
    canonical = 'tpl_' + sid.slice(8);
  }
  keys.add(canonical);
  
  if (sid.startsWith('tpl_tpl_')) {
    keys.add('tpl_' + sid.slice(8));
  } else if (sid.startsWith('tpl_')) {
    keys.add('tpl_tpl_' + sid.slice(4));
  }
  
  return Array.from(keys);
}

function isRejected(data) {
  return String(data.status || '').toLowerCase() === 'rejected';
}

function getScheduledHours(shift) {
  const sStart = toDate(shift.shift_start || shift.start);
  const sEnd = toDate(shift.shift_end || shift.end);
  
  if (sStart && sEnd && sEnd > sStart) {
    return (sEnd.getTime() - sStart.getTime()) / 3600000;
  }
  
  const mins = toDouble(shift.duration_minutes, 0);
  if (mins > 0) return mins / 60.0;
  
  return toDouble(shift.duration, 0);
}

function hasMakeupAttestation(form) {
  const r =
    form.responses && typeof form.responses === 'object' ? form.responses : {};
  const nonEmpty = (v) => v != null && String(v).trim() !== '';
  if (!nonEmpty(r.makeup_occurred_at)) return false;
  if (!nonEmpty(r.makeup_start_time)) return false;
  if (!nonEmpty(r.makeup_end_time)) return false;
  const mode = String(r.makeup_delivery_mode || '')
    .trim()
    .toLowerCase();
  if (!nonEmpty(mode)) return false;
  if (mode === 'in_person') {
    if (!nonEmpty(r.makeup_location)) return false;
  } else if (mode === 'zoom' || mode === 'livekit') {
    if (!nonEmpty(r.makeup_zoom_host)) return false;
  } else if (mode === 'other') {
    if (!nonEmpty(r.makeup_other_detail)) return false;
  } else {
    return false;
  }
  if (!nonEmpty(r.makeup_students_present)) return false;
  return true;
}

function isLegacyMakeupWorkflowForm(form) {
  const raw = form.makeupApprovalStatus;
  return raw === undefined || raw === null || String(raw).trim() === '';
}

/**
 * Form-only (no clocked timesheet) pay uses this gate so Dart/Node stay aligned.
 * Legacy docs without makeupApprovalStatus keep prior behavior (still eligible if form exists).
 */
function isFormEligibleForFormOnlyMakeupEconomics(form) {
  if (isLegacyMakeupWorkflowForm(form)) return true;
  const status = String(form.makeupApprovalStatus)
    .trim()
    .toLowerCase();
  if (status === 'rejected') return false;
  if (status === 'pending' || status === 'approved') {
    return hasMakeupAttestation(form);
  }
  return false;
}

function filterFormsForMakeupEconomics(forms) {
  return forms.filter(isFormEligibleForFormOnlyMakeupEconomics);
}

function parseFormDuration(form) {
  let reported = toDouble(form.durationHours, -1);
  if (reported >= 0) return reported;
  
  reported = toDouble(form.reportedHours, -1);
  if (reported >= 0) return reported;
  
  const responses = form.responses;
  if (responses && typeof responses === 'object') {
    for (const key of Object.keys(responses)) {
      const k = String(key).toLowerCase();
      if (k.includes('duration') || k.includes('hours') || k.includes('time')) {
        const val = toDouble(responses[key], -1);
        if (val >= 0) return val;
      }
    }
  }
  return 0.0;
}

function getStoredPay(ts) {
  const paymentAmount = toDouble(ts.payment_amount, 0.0);
  if (paymentAmount > 0) return paymentAmount;
  return toDouble(ts.total_pay, 0.0);
}

/** Positive-length intersection only; touching or gaps => separate segments. */
function clockIntervalsOverlap(aStart, aEnd, bStart, bEnd) {
  const latestStart = aStart > bStart ? aStart : bStart;
  const earliestEnd = aEnd < bEnd ? aEnd : bEnd;
  return latestStart.getTime() < earliestEnd.getTime();
}

/**
 * Main aggregation function.
 * @param {Object} shift - The teaching_shifts document data.
 * @param {Array<Object>} timesheets - All timesheet_entries documents for this shift.
 * @param {Array<Object>} forms - All form_responses documents for this shift.
 * @returns {Object} { workedHours, realPay, payPaid, payApproved, payPending,
 *   hasPunchedTimesheets, hasForm }
 */
function computeSession(shift, timesheets = [], forms = []) {
  const scheduledHours = getScheduledHours(shift);
  const shiftRate = toDouble(shift.hourly_rate, 0.0);
  
  const shiftStart = toDate(shift.shift_start || shift.start);
  const shiftEnd = toDate(shift.shift_end || shift.end);

  // 1. Filter out rejected timesheets and those without full clock pairs
  const validTimesheets = [];
  for (const ts of timesheets) {
    if (isRejected(ts)) continue;
    
    const ci = toDate(ts.clock_in_time || ts.clock_in_timestamp);
    const co = toDate(ts.clock_out_time || ts.clock_out_timestamp);
    
    if (ci && co && co > ci) {
      validTimesheets.push(ts);
    }
  }

  // If no valid timesheets, check for form-only path
  if (validTimesheets.length === 0) {
    const eligibleForms = filterFormsForMakeupEconomics(forms);
    const shiftClaimsForm =
      shift.form_completed === true ||
      (shift.form_response_id && String(shift.form_response_id).trim() !== '');
    const formDone =
      eligibleForms.length > 0 || (shiftClaimsForm && forms.length === 0);

    if (eligibleForms.length === 0 && forms.length > 0) {
      return {
        workedHours: 0.0,
        realPay: 0.0,
        payPaid: 0.0,
        payApproved: 0.0,
        payPending: 0.0,
        hasPunchedTimesheets: false,
        hasForm: true,
      };
    }

    if (formDone) {
      let formHours = 0.0;
      if (eligibleForms.length > 0) {
        const sortedForms = [...eligibleForms].sort((a, b) => {
          const ta = toDate(a.submittedAt || a.created_at) || new Date(0);
          const tb = toDate(b.submittedAt || b.created_at) || new Date(0);
          return tb.getTime() - ta.getTime();
        });
        formHours = parseFormDuration(sortedForms[0]);
      } else {
        formHours = toDouble(shift.reported_hours, -1);
        if (formHours < 0) formHours = toDouble(shift.reportedHours, 0);
      }

      if (formHours <= 0) formHours = scheduledHours;

      const cappedHours = Math.min(formHours, scheduledHours);
      const pay = cappedHours * shiftRate;

      return {
        workedHours: cappedHours,
        realPay: pay,
        payPaid: 0.0,
        payApproved: 0.0,
        payPending: pay,
        hasPunchedTimesheets: false,
        hasForm: forms.length > 0 || shiftClaimsForm,
      };
    }

    return {
      workedHours: 0.0,
      realPay: 0.0,
      payPaid: 0.0,
      payApproved: 0.0,
      payPending: 0.0,
      hasPunchedTimesheets: false,
      hasForm: false,
    };
  }

  // 2. Strict overlap groups duplicates; adjacent clock-out/in pairs stay separate and sum.
  // Sort by clock_in ascending
  validTimesheets.sort((a, b) => {
    const ciA = toDate(a.clock_in_time || a.clock_in_timestamp);
    const ciB = toDate(b.clock_in_time || b.clock_in_timestamp);
    return ciA.getTime() - ciB.getTime();
  });

  const groups = [];
  for (const ts of validTimesheets) {
    const ci = toDate(ts.clock_in_time || ts.clock_in_timestamp);
    const co = toDate(ts.clock_out_time || ts.clock_out_timestamp);
    
    let addedToGroup = false;
    for (const group of groups) {
      let overlaps = false;
      for (const member of group) {
        const mCi = toDate(member.clock_in_time || member.clock_in_timestamp);
        const mCo = toDate(member.clock_out_time || member.clock_out_timestamp);
        if (clockIntervalsOverlap(ci, co, mCi, mCo)) {
          overlaps = true;
          break;
        }
      }
      
      if (overlaps) {
        group.push(ts);
        addedToGroup = true;
        break;
      }
    }
    
    if (!addedToGroup) {
      groups.push([ts]);
    }
  }

  // 3. Resolve each group to a single survivor and sum them up
  let totalWorkedHours = 0.0;
  let totalPay = 0.0;
  let payPaid = 0.0;
  let payApproved = 0.0;
  let payPending = 0.0;

  for (const group of groups) {
    let survivor = null;
    let survivorWorked = 0.0;
    
    for (const ts of group) {
      const ci = toDate(ts.clock_in_time || ts.clock_in_timestamp);
      const co = toDate(ts.clock_out_time || ts.clock_out_timestamp);
      
      // Clip to shift window
      let effectiveStart = ci;
      let effectiveEnd = co;
      
      if (shiftStart && effectiveStart < shiftStart) {
        effectiveStart = shiftStart;
      }
      if (shiftEnd && effectiveEnd > shiftEnd) {
        effectiveEnd = shiftEnd;
      }
      
      let worked = 0.0;
      if (effectiveEnd > effectiveStart) {
        worked = (effectiveEnd.getTime() - effectiveStart.getTime()) / 3600000;
      }
      
      if (!survivor) {
        survivor = ts;
        survivorWorked = worked;
      } else {
        // Survivor selection rule: longest worked -> highest stored pay -> newest activity
        if (worked > survivorWorked + 0.01) { // Add epsilon for float comparison
          survivor = ts;
          survivorWorked = worked;
        } else if (Math.abs(worked - survivorWorked) <= 0.01) {
          const payA = getStoredPay(ts);
          const payB = getStoredPay(survivor);
          if (payA > payB) {
            survivor = ts;
            survivorWorked = worked;
          } else if (payA === payB) {
            // Fallback to newest activity
            const actA = toDate(ts.updated_at || ts.created_at) || new Date(0);
            const actB = toDate(survivor.updated_at || survivor.created_at) || new Date(0);
            if (actA > actB) {
              survivor = ts;
              survivorWorked = worked;
            }
          }
        }
      }
    }
    
    if (survivor) {
      totalWorkedHours += survivorWorked;
      
      // Calculate pay for this segment
      let rate = toDouble(survivor.hourly_rate, 0.0);
      if (rate <= 0) rate = toDouble(survivor.hourlyRate, 0.0);
      if (rate <= 0) rate = shiftRate;
      
      const paymentAmount = toDouble(survivor.payment_amount, 0.0);
      const tPay = toDouble(survivor.total_pay, 0.0);
      
      let segmentPay = 0.0;
      if (paymentAmount > 0) {
        segmentPay = paymentAmount;
      } else if (tPay > 0) {
        segmentPay = tPay;
      } else {
        segmentPay = survivorWorked * rate;
      }
      
      totalPay += segmentPay;
      
      const status = String(survivor.status || 'pending');
      if (status === 'paid') {
        payPaid += segmentPay;
      } else if (status === 'approved') {
        payApproved += segmentPay;
      } else {
        payPending += segmentPay;
      }
    }
  }

  // 4. Cap at scheduled
  if (totalWorkedHours > scheduledHours && scheduledHours > 0) {
    totalWorkedHours = scheduledHours;
  }
  
  const maxPay = scheduledHours * shiftRate;
  if (totalPay > maxPay && maxPay > 0) {
    // Scale down the buckets proportionally if we hit the cap
    const ratio = maxPay / totalPay;
    payPaid *= ratio;
    payApproved *= ratio;
    payPending *= ratio;
    totalPay = maxPay;
  }

  return {
    workedHours: totalWorkedHours,
    realPay: totalPay,
    payPaid: payPaid,
    payApproved: payApproved,
    payPending: payPending,
    hasPunchedTimesheets: true,
    hasForm: forms.length > 0 || shift.form_completed === true,
  };
}

/**
 * Standardized minute rounding for display: ceil(workedHours * 60).
 * Use this whenever you display, persist, or compare worked time as minutes.
 */
function workedMinutesCeil(result) {
  if (!result || typeof result.workedHours !== 'number') return 0;
  return Math.ceil(result.workedHours * 60);
}

module.exports = {
  computeSession,
  workedMinutesCeil,
  canonicalShiftIdForGrouping,
  getShiftIdIndexKeys,
  getScheduledHours,
  isRejected,
  toDate,
  toDouble,
  hasMakeupAttestation,
  isFormEligibleForFormOnlyMakeupEconomics,
  filterFormsForMakeupEconomics,
};
