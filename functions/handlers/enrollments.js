const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const functions = require('firebase-functions');
const {brandedEmailHtml} = require('../services/email/branding');
const admin = require('firebase-admin');
const { createTransporter } = require('../services/email/transporter');
const { generateRandomPassword } = require('../utils/password');

/** Escape text for safe HTML interpolation (names, notes, etc.). */
const escapeHtml = (value) => String(value ?? '')
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;');

// Resolve the user-friendly program name; falls back to raw subject.
const resolveProgramName = (enrollmentData) => {
  return enrollmentData.programTitle || enrollmentData.subject || 'our program';
};

// Build an HTML pricing block from the stored pricing / pricingSnapshot.
const buildPricingHtml = (enrollmentData) => {
  const pricing = enrollmentData.pricing || {};
  const snap = (enrollmentData.metadata || {}).pricingSnapshot || {};
  const hourly = snap.hourlyRateUsd ?? pricing.hourlyRate;
  const monthly = snap.monthlyEstimateUsd ?? pricing.monthlyEstimate;
  const hours = snap.hoursPerWeek ?? pricing.hoursPerWeek;
  if (!hourly && !monthly) return '';
  const rows = [];
  if (hours) rows.push(`<div class="info-row"><span class="info-label">Hours per week:</span><span class="info-value">${hours}</span></div>`);
  if (hourly) rows.push(`<div class="info-row"><span class="info-label">Hourly rate:</span><span class="info-value">$${Number(hourly).toFixed(2)} USD</span></div>`);
  if (monthly) rows.push(`<div class="info-row"><span class="info-label">Est. monthly:</span><span class="info-value">~$${Number(monthly).toFixed(0)} USD</span></div>`);
  return `
    <div class="info-box">
      <h3>💰 Pricing Estimate</h3>
      ${rows.join('\n')}
      <p style="font-size:12px;color:#94a3b8;margin:10px 0 0;">Final pricing confirmed upon enrollment approval.</p>
      <div style="margin-top:15px;padding-top:15px;border-top:1px dashed #cbd5e1;font-size:13px;color:#475569;">
        <strong>Payment Policy:</strong> Payment is due at the beginning of each month. We accept Zelle, CashApp, and other major payment methods.
      </div>
    </div>`;
};

// Email template for enrollment confirmation to student/parent (single student)
const sendEnrollmentConfirmationEmail = async (enrollmentData) => {
  const transporter = createTransporter();
  const contact = enrollmentData.contact || {};
  const preferences = enrollmentData.preferences || {};
  const student = enrollmentData.student || {};
  const program = enrollmentData.program || {};
  const metadata = enrollmentData.metadata || {};
  const programName = resolveProgramName(enrollmentData);

  // Determine if this is an adult student enrollment
  const isAdultStudent = metadata.isAdult || enrollmentData.isAdult || false;

  // For adult students, address the email to the student directly
  // For minors, address to parent/guardian
  const recipientName = isAdultStudent
    ? (student.name || contact.email?.split('@')[0] || 'Student')
    : (contact.parentName || contact.email?.split('@')[0] || 'Parent');

  const studentName = student.name || 'Student';
  const email = contact.email;

  if (!email) {
    console.warn('No email found in enrollment data, skipping confirmation email');
    return false;
  }

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: email,
    subject: '🎓 Enrollment Request Received - Alluwal Education Hub',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Enrollment Confirmation</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .info-row { display: flex; justify-content: space-between; margin: 10px 0; padding: 5px 0; border-bottom: 1px solid #e5e7eb; }
          .info-label { font-weight: bold; color: #374151; }
          .info-value { color: #6b7280; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .success-note { background-color: #ecfdf5; border: 1px solid #10b981; padding: 15px; margin: 15px 0; border-radius: 6px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎓 Enrollment Request Received</h1>
            <p>Thank you for choosing Alluwal Education Hub</p>
          </div>
          
          <div class="content">
            <h2>Dear ${recipientName},</h2>
            ${isAdultStudent
              ? `<p>We're excited to inform you that we've received your enrollment request for <strong>${programName}</strong> at Alluwal Education Hub!</p>`
              : `<p>We're excited to inform you that we've received your enrollment request for <strong>${studentName}</strong> in <strong>${programName}</strong>!</p>`
            }

            <div class="success-note">
              <h3>✅ What Happens Next?</h3>
              <ul>
                <li>Our team will review your enrollment request within 24-48 hours</li>
                <li>We'll match you with a qualified teacher based on your preferences</li>
                <li>You'll receive an email notification once a teacher accepts your request</li>
                <li>We'll then help you set up your first class session</li>
              </ul>
            </div>
            
            <div class="info-box">
              <h3>📋 ${isAdultStudent ? 'Your Information' : 'Student Information'}</h3>
              <div class="info-row">
                <span class="info-label">${isAdultStudent ? 'Name:' : 'Student Name:'}</span>
                <span class="info-value">${studentName || 'Not provided'}</span>
              </div>
              ${student.age ? `
              <div class="info-row">
                <span class="info-label">${isAdultStudent ? 'Age:' : 'Student Age:'}</span>
                <span class="info-value">${student.age}</span>
              </div>
              ` : ''}
              <div class="info-row">
                <span class="info-label">Program:</span>
                <span class="info-value">${programName}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Grade Level:</span>
                <span class="info-value">${enrollmentData.gradeLevel || 'Not specified'}</span>
              </div>
              ${program.classType ? `
              <div class="info-row">
                <span class="info-label">Class Type:</span>
                <span class="info-value">${program.classType}</span>
              </div>
              ` : ''}
              ${program.sessionDuration ? `
              <div class="info-row">
                <span class="info-label">Session Duration:</span>
                <span class="info-value">${program.sessionDuration}</span>
              </div>
              ` : ''}
              ${enrollmentData.specificLanguage ? `
              <div class="info-row">
                <span class="info-label">Specific Language:</span>
                <span class="info-value">${enrollmentData.specificLanguage}</span>
              </div>
              ` : ''}
              ${preferences.days && preferences.days.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Preferred Days:</span>
                <span class="info-value">${preferences.days.join(', ')}</span>
              </div>
              ` : ''}
              ${preferences.timeSlots && preferences.timeSlots.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Preferred Times:</span>
                <span class="info-value">${preferences.timeSlots.join(', ')}</span>
              </div>
              ` : ''}
              ${preferences.timeZone ? `
              <div class="info-row">
                <span class="info-label">Timezone:</span>
                <span class="info-value">${preferences.timeZone}</span>
              </div>
              ` : ''}
              ${preferences.schedulingNotes ? `
              <div class="info-row">
                <span class="info-label">Scheduling notes:</span>
                <span class="info-value">${escapeHtml(preferences.schedulingNotes)}</span>
              </div>
              ` : ''}
            </div>

            ${buildPricingHtml(enrollmentData)}
            
            <p>If you have any questions or need to update your enrollment information, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>
            
            <p>Best regards,<br>
            <strong>The Alluwal Education Hub Team</strong></p>
          </div>
          
          <div class="footer">
            <p>This is an automated confirmation. For questions, please contact our support team.</p>
            <p>Alluwal Education Hub - Excellence in Islamic Education</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Enrollment confirmation email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send enrollment confirmation email to ${email}:`, error);
    return false;
  }
};

// Email template for multi-student enrollment confirmation (consolidated)
const sendMultiStudentEnrollmentEmail = async (allEnrollments) => {
  const transporter = createTransporter();
  
  if (!allEnrollments || allEnrollments.length === 0) {
    console.warn('No enrollments provided for multi-student email');
    return false;
  }

  // Use first enrollment for parent/contact info (all should have same parent)
  const firstEnrollment = allEnrollments[0];
  const contact = firstEnrollment.contact || {};
  const email = contact.email;

  if (!email) {
    console.warn('No email found in enrollment data, skipping confirmation email');
    return false;
  }

  const recipientName = contact.parentName || contact.email?.split('@')[0] || 'Parent';
  // One enrollment per student per program, so the document count is a count
  // of classes, not children. A parent enrolling one child in two programs
  // must not be told we received a request for "2 students".
  const studentNames = new Set(
    allEnrollments.map((e) => ((e.student || {}).name || '').trim().toLowerCase()).filter(Boolean)
  );
  const studentCount = studentNames.size || allEnrollments.length;
  const programCount = allEnrollments.length;
  const sharedSchedulingNotes = (firstEnrollment.preferences || {}).schedulingNotes;
  const programListText = [...new Set(allEnrollments.map((e) => resolveProgramName(e)))].join(', ');

  // Build HTML for all students (aligned rows + per-student pricing)
  let studentsHtml = '';
  allEnrollments.forEach((enrollment, index) => {
    const student = enrollment.student || {};
    const program = enrollment.program || {};
    const preferences = enrollment.preferences || {};
    const programName = resolveProgramName(enrollment);
    const specificLanguage = enrollment.specificLanguage;
    const gradeLevel = enrollment.gradeLevel || 'Not specified';
    const studentTitle = escapeHtml(student.name || `Student ${index + 1}`);

    studentsHtml += `
      <div class="student-block">
        <h3 class="student-block-title">👤 Student ${index + 1}: ${studentTitle}</h3>
        <div class="info-row">
          <span class="info-label">Name</span>
          <span class="info-value">${escapeHtml(student.name || 'Not provided')}</span>
        </div>
        ${student.age ? `
        <div class="info-row">
          <span class="info-label">Age</span>
          <span class="info-value">${escapeHtml(String(student.age))}</span>
        </div>` : ''}
        ${student.gender ? `
        <div class="info-row">
          <span class="info-label">Gender</span>
          <span class="info-value">${escapeHtml(String(student.gender))}</span>
        </div>` : ''}
        <div class="info-row">
          <span class="info-label">Program</span>
          <span class="info-value">${escapeHtml(programName)}${specificLanguage ? ` (${escapeHtml(specificLanguage)})` : ''}</span>
        </div>
        <div class="info-row">
          <span class="info-label">Level</span>
          <span class="info-value">${escapeHtml(gradeLevel)}</span>
        </div>
        ${program.classType ? `
        <div class="info-row">
          <span class="info-label">Class type</span>
          <span class="info-value">${escapeHtml(program.classType)}</span>
        </div>` : ''}
        ${program.sessionDuration ? `
        <div class="info-row">
          <span class="info-label">Session duration</span>
          <span class="info-value">${escapeHtml(program.sessionDuration)}</span>
        </div>` : ''}
        ${preferences.days && preferences.days.length > 0 ? `
        <div class="info-row">
          <span class="info-label">Preferred days</span>
          <span class="info-value">${escapeHtml(preferences.days.join(', '))}</span>
        </div>` : ''}
        ${preferences.timeSlots && preferences.timeSlots.length > 0 ? `
        <div class="info-row">
          <span class="info-label">Preferred times</span>
          <span class="info-value">${escapeHtml(preferences.timeSlots.join(', '))}</span>
        </div>` : ''}
        ${preferences.timeZone ? `
        <div class="info-row">
          <span class="info-label">Timezone</span>
          <span class="info-value">${escapeHtml(preferences.timeZone)}</span>
        </div>` : ''}
        ${buildPricingHtml(enrollment)}
      </div>
    `;
  });

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: email,
    subject: `🎓 Enrollment Request Received - ${studentCount} Student${studentCount > 1 ? 's' : ''} - Alluwal Education Hub`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Enrollment Confirmation</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 700px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .info-row { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; margin: 8px 0; padding: 5px 0; border-bottom: 1px solid #e5e7eb; }
          .info-label { font-weight: bold; color: #374151; flex: 0 0 42%; text-align: left; }
          .info-value { color: #6b7280; flex: 1; text-align: right; word-break: break-word; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .success-note { background-color: #ecfdf5; border: 1px solid #10b981; padding: 15px; margin: 15px 0; border-radius: 6px; }
          .student-block { background-color: #f9fafb; border-left: 4px solid #0386FF; padding: 14px 14px 8px; margin: 12px 0; border-radius: 0 8px 8px 0; }
          .student-block .info-box { margin: 12px 0 0; }
          .student-block-title { margin: 0 0 8px; color: #111827; font-size: 16px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎓 Enrollment Request Received</h1>
            <p>Thank you for choosing Alluwal Education Hub</p>
          </div>
          
          <div class="content">
            <h2>Dear ${recipientName},</h2>
            <p>We're excited to inform you that we've received your enrollment request for <strong>${studentCount} student${studentCount > 1 ? 's' : ''}</strong>${programCount > studentCount ? ` across <strong>${programCount} programs</strong>` : ''}${programListText ? `: <strong>${escapeHtml(programListText)}</strong>` : ''}.</p>

            <div class="success-note">
              <h3>✅ What Happens Next?</h3>
              <ul>
                <li>Our team will review your enrollment request within 24-48 hours</li>
                <li>We'll match you with qualified teachers based on your preferences</li>
                <li>You'll receive email notifications once teachers accept your requests</li>
                <li>We'll then help you set up your first class sessions</li>
              </ul>
            </div>

            <div class="info-box">
              <h3>📋 Parent/Guardian Information</h3>
              <div class="info-row">
                <span class="info-label">Name:</span>
                <span class="info-value">${contact.parentName || 'Not provided'}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${email}</span>
              </div>
              ${contact.phone ? `
              <div class="info-row">
                <span class="info-label">Phone:</span>
                <span class="info-value">${contact.phone}</span>
              </div>
              ` : ''}
              ${contact.city ? `
              <div class="info-row">
                <span class="info-label">City:</span>
                <span class="info-value">${contact.city}</span>
              </div>
              ` : ''}
              ${contact.country ? `
              <div class="info-row">
                <span class="info-label">Country:</span>
                <span class="info-value">${contact.country.name || contact.country.code || 'Not provided'}</span>
              </div>
              ` : ''}
            </div>

            ${sharedSchedulingNotes ? `
            <div class="info-box" style="margin: 20px 0;">
              <h3 style="margin-top: 0;">📝 Scheduling notes</h3>
              <p style="margin: 0; color: #374151;">${escapeHtml(sharedSchedulingNotes)}</p>
            </div>
            ` : ''}

            <div style="margin: 24px 0 8px;">
              <h3 style="color: #111827; margin: 0 0 12px;">👥 Students and pricing</h3>
              ${studentsHtml}
            </div>
            
            <p>If you have any questions or need to update your enrollment information, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>
            
            <p>Best regards,<br>
            <strong>The Alluwal Education Hub Team</strong></p>
          </div>
          
          <div class="footer">
            <p>This is an automated confirmation. For questions, please contact our support team.</p>
            <p>Alluwal Education Hub - Excellence in Islamic Education</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Multi-student enrollment confirmation email sent to ${email} for ${studentCount} student(s) across ${programCount} program(s)`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send multi-student enrollment confirmation email to ${email}:`, error);
    return false;
  }
};

// Email template for admin notification
const sendAdminEnrollmentNotification = async (enrollmentData, enrollmentId) => {
  const transporter = createTransporter();
  const contact = enrollmentData.contact || {};
  const preferences = enrollmentData.preferences || {};
  const student = enrollmentData.student || {};
  const program = enrollmentData.program || {};
  const metadata = enrollmentData.metadata || {};

  // Determine if this is an adult student enrollment
  const isAdultStudent = metadata.isAdult || enrollmentData.isAdult || false;

  // Admin email - you can configure this or get from Firestore
  const adminEmail = 'support@alluwaleducationhub.org'; // Change to your admin email
  
  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: adminEmail,
    subject: `🔔 New Enrollment Request - ${student.name || 'New Student'} - ${resolveProgramName(enrollmentData)}`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Enrollment Request</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 700px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #dc2626 0%, #ef4444 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .info-row { display: flex; justify-content: space-between; margin: 10px 0; padding: 5px 0; border-bottom: 1px solid #e5e7eb; }
          .info-label { font-weight: bold; color: #374151; min-width: 150px; }
          .info-value { color: #6b7280; flex: 1; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .action-button { display: inline-block; background-color: #0386FF; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0; }
          .alert-box { background-color: #fef3c7; border: 2px solid #f59e0b; padding: 15px; margin: 15px 0; border-radius: 6px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔔 New Enrollment Request</h1>
            <p>Action Required</p>
          </div>
          
          <div class="content">
            <div class="alert-box">
              <strong>📋 New enrollment request received - Awaiting your approval.</strong>
              <p>Please review this enrollment and broadcast to teachers when ready.</p>
            </div>
            
            <div class="info-box">
              <h3>📋 ${isAdultStudent ? 'Student Contact Information' : 'Contact Information'}</h3>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${contact.email || 'Not provided'}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Phone:</span>
                <span class="info-value">${contact.phone || 'Not provided'}</span>
              </div>
              ${contact.whatsApp ? `
              <div class="info-row">
                <span class="info-label">WhatsApp:</span>
                <span class="info-value">${contact.whatsApp}</span>
              </div>
              ` : ''}
              ${!isAdultStudent && contact.parentName ? `
              <div class="info-row">
                <span class="info-label">Parent/Guardian:</span>
                <span class="info-value">${contact.parentName}</span>
              </div>
              ` : ''}
              ${contact.city ? `
              <div class="info-row">
                <span class="info-label">City:</span>
                <span class="info-value">${contact.city}</span>
              </div>
              ` : ''}
              ${contact.country ? `
              <div class="info-row">
                <span class="info-label">Country:</span>
                <span class="info-value">${(contact.country.name || contact.country.code || enrollmentData.countryName || 'Not provided')}</span>
              </div>
              ` : enrollmentData.countryName ? `
              <div class="info-row">
                <span class="info-label">Country:</span>
                <span class="info-value">${enrollmentData.countryName}</span>
              </div>
              ` : ''}
            </div>
            
            <div class="info-box">
              <h3>👤 Student Information</h3>
              <div class="info-row">
                <span class="info-label">Name:</span>
                <span class="info-value">${student.name || 'Not provided'}</span>
              </div>
              ${student.age ? `
              <div class="info-row">
                <span class="info-label">Age:</span>
                <span class="info-value">${student.age}</span>
              </div>
              ` : ''}
              ${student.gender ? `
              <div class="info-row">
                <span class="info-label">Gender:</span>
                <span class="info-value">${student.gender}</span>
              </div>
              ` : ''}
            </div>
            
            <div class="info-box">
              <h3>📚 Program Details</h3>
              <div class="info-row">
                <span class="info-label">Program:</span>
                <span class="info-value">${resolveProgramName(enrollmentData)}</span>
              </div>
              ${enrollmentData.specificLanguage ? `
              <div class="info-row">
                <span class="info-label">Specific Language:</span>
                <span class="info-value">${enrollmentData.specificLanguage}</span>
              </div>
              ` : ''}
              <div class="info-row">
                <span class="info-label">Grade Level:</span>
                <span class="info-value">${enrollmentData.gradeLevel || 'Not specified'}</span>
              </div>
              ${program.classType ? `
              <div class="info-row">
                <span class="info-label">Class Type:</span>
                <span class="info-value">${program.classType}</span>
              </div>
              ` : ''}
              ${program.sessionDuration ? `
              <div class="info-row">
                <span class="info-label">Session Duration:</span>
                <span class="info-value">${program.sessionDuration}</span>
              </div>
              ` : ''}
              ${preferences.preferredLanguage ? `
              <div class="info-row">
                <span class="info-label">Preferred Language:</span>
                <span class="info-value">${preferences.preferredLanguage}</span>
              </div>
              ` : ''}
              ${student.knowsZoom !== undefined ? `
              <div class="info-row">
                <span class="info-label">Knows Zoom:</span>
                <span class="info-value">${student.knowsZoom ? 'Yes' : 'No'}</span>
              </div>
              ` : ''}
            </div>
            
            <div class="info-box">
              <h3>📅 Availability</h3>
              ${preferences.days && preferences.days.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Preferred Days:</span>
                <span class="info-value">${preferences.days.join(', ')}</span>
              </div>
              ` : ''}
              ${preferences.timeSlots && preferences.timeSlots.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Preferred Times:</span>
                <span class="info-value">${preferences.timeSlots.join(', ')}</span>
              </div>
              ` : ''}
              ${preferences.timeOfDayPreference ? `
              <div class="info-row">
                <span class="info-label">Time Preference:</span>
                <span class="info-value">${preferences.timeOfDayPreference}</span>
              </div>
              ` : ''}
              ${preferences.timeZone ? `
              <div class="info-row">
                <span class="info-label">Timezone:</span>
                <span class="info-value">${preferences.timeZone}</span>
              </div>
              ` : ''}
              ${preferences.schedulingNotes ? `
              <div class="info-row">
                <span class="info-label">Scheduling notes:</span>
                <span class="info-value">${String(preferences.schedulingNotes).replace(/</g, '&lt;').replace(/>/g, '&gt;')}</span>
              </div>
              ` : ''}
            </div>
            
            ${buildPricingHtml(enrollmentData)}

            <div style="text-align: center; margin: 30px 0;">
              <p><strong>Enrollment ID:</strong> ${enrollmentId}</p>
              <p style="font-size: 12px; color: #6b7280;">View this enrollment in the admin dashboard</p>
            </div>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from Alluwal Education Hub</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Admin notification email sent to ${adminEmail}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send admin notification email to ${adminEmail}:`, error);
    return false;
  }
};

// Create job opportunity from enrollment
// Enhanced to include all enrollment data for proper teacher matching and admin scheduling
const createJobOpportunity = async (enrollmentData, enrollmentId) => {
  try {
    if (!enrollmentData) {
      throw new Error('enrollmentData is null or undefined');
    }

    const contact = enrollmentData.contact || {};
    const preferences = enrollmentData.preferences || {};
    const student = enrollmentData.student || {};
    const program = enrollmentData.program || {};
    const metadata = enrollmentData.metadata || {};

    // Ensure arrays are valid
    const days = Array.isArray(preferences.days) ? preferences.days :
                 Array.isArray(enrollmentData.preferredDays) ? enrollmentData.preferredDays : [];
    const timeSlots = Array.isArray(preferences.timeSlots) ? preferences.timeSlots :
                      Array.isArray(enrollmentData.preferredTimeSlots) ? enrollmentData.preferredTimeSlots : [];

    // Improved Data Mapping - Ensure all critical data is passed to Job Board
    // CRITICAL: All fields must have explicit defaults (null, '', [], false) to prevent undefined values
    const jobData = {
      enrollmentId: enrollmentId,

      // Student Details - Add defaults for ALL fields
      studentName: student.name || enrollmentData.studentName || 'Student',
      studentAge: student.age || enrollmentData.studentAge || 'N/A',
      gender: student.gender || enrollmentData.gender || 'Not specified',

      // Program Details
      subject: enrollmentData.subject || 'General',
      specificLanguage: enrollmentData.specificLanguage || null,
      gradeLevel: enrollmentData.gradeLevel || '',

      // Schedule Preferences (The Source of Truth for Admin Scheduling)
      days: days,
      timeSlots: timeSlots,
      timeZone: preferences.timeZone || enrollmentData.timeZone || 'UTC', // IANA Timezone (e.g., 'America/New_York', 'Africa/Casablanca')
      sessionDuration: program.sessionDuration || enrollmentData.sessionDuration || '60 minutes',
      timeOfDayPreference: preferences.timeOfDayPreference || enrollmentData.timeOfDayPreference || null,

      // Location (Useful for teachers to know context)
      countryName: enrollmentData.countryName || (contact.country && contact.country.name) || '',
      countryCode: enrollmentData.countryCode || (contact.country && contact.country.code) || '',
      city: contact.city || enrollmentData.city || '',

      // Additional Context
      classType: program.classType || enrollmentData.classType || null,
      preferredLanguage: preferences.preferredLanguage || enrollmentData.preferredLanguage || null,
      knowsZoom: (student.knowsZoom !== undefined) ? student.knowsZoom : (enrollmentData.knowsZoom !== undefined ? enrollmentData.knowsZoom : null),
      isAdult: (metadata.isAdult !== undefined) ? metadata.isAdult : (enrollmentData.isAdult !== undefined ? enrollmentData.isAdult : false),

      // Metadata
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Remove any remaining undefined keys just in case (safety check)
    Object.keys(jobData).forEach(key => {
      if (jobData[key] === undefined) {
        console.warn(`⚠️ Removing undefined key from jobData: ${key}`);
        delete jobData[key];
      }
    });

    // Log the jobData structure before saving (for debugging)
    console.log(`📦 Creating job with data:`, JSON.stringify(jobData, null, 2));

    let jobRef;
    try {
      // Validate jobData before attempting to save
      console.log(`🔍 Validating jobData before save...`);
      const validationErrors = [];

      // Check for any invalid values
      Object.keys(jobData).forEach(key => {
        const value = jobData[key];
        if (value === undefined) {
          validationErrors.push(`Field ${key} is undefined`);
        } else if (value !== null && typeof value === 'object' && !Array.isArray(value) && !(value instanceof admin.firestore.Timestamp) && !(value instanceof admin.firestore.FieldValue)) {
          // Check for nested undefined values
          try {
            JSON.stringify(value); // This will fail if there are undefined values
          } catch (e) {
            validationErrors.push(`Field ${key} contains invalid nested data: ${e.message}`);
          }
        }
      });

      if (validationErrors.length > 0) {
        throw new Error(`Validation failed: ${validationErrors.join(', ')}`);
      }

      console.log(`✅ JobData validation passed. Attempting to save to Firestore...`);
      jobRef = await admin.firestore().collection('job_board').add(jobData);
      console.log(`✅ Job opportunity created: ${jobRef.id} with IANA timezone: ${jobData.timeZone}`);
    } catch (firestoreError) {
      console.error('❌ Firestore error creating job:', firestoreError);
      console.error('❌ Firestore error details:', {
        code: firestoreError.code,
        message: firestoreError.message,
        stack: firestoreError.stack,
        jobDataKeys: Object.keys(jobData),
        jobDataSample: JSON.stringify(jobData, (key, value) => {
          if (value === undefined) return 'UNDEFINED_VALUE';
          if (value instanceof admin.firestore.FieldValue) return 'FieldValue';
          if (value instanceof admin.firestore.Timestamp) return value.toDate().toISOString();
          return value;
        }, 2),
      });

      // Extract meaningful error message
      let errorMsg = 'Unknown Firestore error';
      if (firestoreError.message) {
        errorMsg = firestoreError.message;
      } else if (firestoreError.code) {
        errorMsg = `Firestore error code: ${firestoreError.code}`;
      } else if (firestoreError.toString && firestoreError.toString() !== '[object Object]') {
        errorMsg = firestoreError.toString();
      }

      throw new Error(`Firestore error creating job: ${errorMsg}`);
    }

    // Update enrollment status
    try {
      await admin.firestore().collection('enrollments').doc(enrollmentId).update({
        'metadata.status': 'broadcasted',
        'metadata.broadcastedAt': admin.firestore.FieldValue.serverTimestamp(),
        'metadata.jobId': jobRef.id,
      });
      console.log(`✅ Updated enrollment ${enrollmentId} status to broadcasted`);
    } catch (updateError) {
      console.error('❌ Error updating enrollment status:', updateError);
      // Don't fail the whole operation if status update fails - job was already created
      console.warn(`⚠️ Job created but enrollment status update failed. Job ID: ${jobRef.id}`);
    }
    
    return jobRef.id;
  } catch (error) {
    console.error('❌ Failed to create job opportunity:', error);
    console.error('❌ Error details:', {
      message: error.message || error.toString(),
      stack: error.stack,
      enrollmentId: enrollmentId,
      enrollmentDataKeys: Object.keys(enrollmentData || {}),
      enrollmentDataType: typeof enrollmentData,
      errorName: error.name,
      errorCode: error.code,
    });
    // Wrap error with more context - ensure we always have a meaningful message
    let errorMessage = 'Unknown error creating job opportunity';
    if (error.message) {
      errorMessage = error.message;
    } else if (error.toString && error.toString() !== '[object Object]') {
      errorMessage = error.toString();
    } else if (error.code) {
      errorMessage = `Error code: ${error.code}`;
    }
    throw new Error(`Failed to create job opportunity: ${errorMessage}`);
  }
};

// Firebase trigger when enrollment is created
const onEnrollmentCreated = onDocumentCreated('enrollments/{enrollmentId}', async (event) => {
  const enrollmentId = event.params.enrollmentId;
  const enrollmentData = event.data.data();
  
  console.log(`📝 Processing new enrollment: ${enrollmentId}`);
  
  try {
    const metadata = enrollmentData.metadata || {};
    const parentLinkId = metadata.parentLinkId;
    const studentIndex = metadata.studentIndex;
    const totalStudents = metadata.totalStudents;

    let confirmationSent = false;

    // Check if this is a multi-student submission
    if (parentLinkId && typeof studentIndex === 'number' && typeof totalStudents === 'number') {
      console.log(`🔗 Multi-student enrollment detected: parentLinkId=${parentLinkId}, studentIndex=${studentIndex}, totalStudents=${totalStudents}`);
      
      // Only send email for the last student (to ensure all enrollments are created)
      if (studentIndex === totalStudents - 1) {
        console.log(`📧 This is the last student (${studentIndex + 1}/${totalStudents}), collecting all enrollments for consolidated email...`);
        
        // Wait a bit to ensure all documents are created
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Query all enrollments with the same parentLinkId
        const enrollmentsSnapshot = await admin.firestore()
          .collection('enrollments')
          .where('metadata.parentLinkId', '==', parentLinkId)
          .orderBy('metadata.studentIndex', 'asc')
          .get();
        
        if (enrollmentsSnapshot.empty) {
          console.warn(`⚠️ No enrollments found with parentLinkId=${parentLinkId}`);
          // Fallback to single email
          confirmationSent = await sendEnrollmentConfirmationEmail(enrollmentData);
        } else {
          const allEnrollments = enrollmentsSnapshot.docs.map(doc => doc.data());
          console.log(`✅ Found ${allEnrollments.length} enrollment(s) linked to parentLinkId=${parentLinkId}`);
          
          // Send consolidated email with all students
          confirmationSent = await sendMultiStudentEnrollmentEmail(allEnrollments);
        }
      } else {
        console.log(`⏭️ Skipping email for student ${studentIndex + 1}/${totalStudents} (will be sent with last student)`);
        // Don't send email for intermediate students
        confirmationSent = true; // Mark as "handled" to avoid errors
      }
    } else {
      // Single student enrollment - send normal email
      console.log(`👤 Single student enrollment, sending normal confirmation email`);
      confirmationSent = await sendEnrollmentConfirmationEmail(enrollmentData);
    }
    
    // 2. Send notification email to admin (always send for each enrollment)
    const adminNotified = await sendAdminEnrollmentNotification(enrollmentData, enrollmentId);
    
    // 3. Create job opportunity - DISABLED: Now manual via Admin Dashboard
    // const jobId = await createJobOpportunity(enrollmentData, enrollmentId);

    console.log(`✅ Enrollment processed successfully:
      - Confirmation email: ${confirmationSent ? 'Sent' : 'Failed'}
      - Admin notification: ${adminNotified ? 'Sent' : 'Failed'}
      - Job opportunity: Manual Approval Required
    `);

    return {
      success: true,
      enrollmentId,
      // jobId,
      emailsSent: {
        confirmation: confirmationSent,
        admin: adminNotified,
      },
    };
  } catch (error) {
    console.error(`❌ Error processing enrollment ${enrollmentId}:`, error);
    // Don't throw - we don't want to fail the enrollment creation
    return {
      success: false,
      error: error.message,
    };
  }
});

// Callable function wrapper (kept for backwards compatibility, but may not work due to IAM)
const publishEnrollmentToJobBoard = async (request) => {
  console.log('🚀 publishEnrollmentToJobBoard (callable) invoked');
  const { enrollmentId } = request.data;
  
  if (!request.auth) {
    console.warn('⚠️ Callable function called without authentication');
  }
  
  try {
    if (!enrollmentId) {
      throw new functions.https.HttpsError('invalid-argument', 'enrollmentId is required');
    }
    
    const enrollmentDoc = await admin.firestore().collection('enrollments').doc(enrollmentId).get();
    if (!enrollmentDoc.exists) {
      throw new functions.https.HttpsError('not-found', `Enrollment ${enrollmentId} not found`);
    }

    const enrollmentData = enrollmentDoc.data();
    if (!enrollmentData) {
      throw new functions.https.HttpsError('invalid-argument', 'Enrollment data is empty');
    }
    
    // Check if already broadcasted or matched
    if (enrollmentData.metadata && 
       (enrollmentData.metadata.status === 'broadcasted' || enrollmentData.metadata.status === 'matched')) {
      return { 
        success: false, 
        message: `Already ${enrollmentData.metadata.status}`, 
        jobId: enrollmentData.metadata.jobId 
      };
    }

    const jobId = await createJobOpportunity(enrollmentData, enrollmentId);
    return { success: true, jobId };
    
  } catch (error) {
    console.error(`❌ Error in callable publishEnrollmentToJobBoard:`, error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message || 'Unknown error');
  }
};

/**
 * Admin-only callable: invite or link a parent to an enrollment's student.
 *
 * Accepts: {
 *   enrollmentId: string,
 *   studentUid: string,     // existing student Auth UID (from createStudentAccount)
 *   email: string,          // parent email
 *   firstName?: string,
 *   lastName?: string,
 *   phone?: string,
 *   countryCode?: string,
 * }
 *
 * Behavior:
 *  - If a Firebase Auth user already exists for the email → re-use it.
 *    If that existing user has a `users/{uid}` doc with user_type='parent',
 *    adds studentUid to children_ids (idempotent). Otherwise creates/updates
 *    the users doc as a parent.
 *  - If no Auth user exists for the email, creates one (random password) and
 *    the users/* parent doc.
 *  - Adds parent uid to student users/{studentUid}.guardian_ids.
 *  - Sends a password-reset link email so the parent can set their password.
 *  - Stamps the enrollment doc with:
 *      metadata.parentInviteStatus = 'invited' | 'linked'
 *      metadata.parentUserId = <parentUid>
 *      contact.guardianId = <parentUid>
 *
 * Only callers whose `users/{auth.uid}` is an admin may invoke.
 */
const inviteParentForEnrollment = async (request) => {
  const auth = request.auth;
  if (!auth || !auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign-in required');
  }

  // Admin check: look up caller's users/* doc and verify admin role fields.
  const callerDoc = await admin.firestore().collection('users').doc(auth.uid).get();
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Caller has no user profile');
  }
  const callerData = callerDoc.data() || {};
  const callerRole = (callerData.role || callerData.user_type || '').toString().toLowerCase();
  const isAdmin =
    callerRole === 'admin' ||
    callerRole === 'super_admin' ||
    callerData.isAdmin === true ||
    callerData.is_admin === true ||
    callerData.isSuperAdmin === true ||
    callerData.is_super_admin === true;
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin role required');
  }

  const payload = request.data || {};
  const enrollmentId = String(payload.enrollmentId || '').trim();
  const studentUid = String(payload.studentUid || '').trim();
  const rawEmail = String(payload.email || '').trim();
  const email = rawEmail.toLowerCase();
  const firstName = String(payload.firstName || '').trim();
  const lastName = String(payload.lastName || '').trim();
  const phone = String(payload.phone || '').trim();
  const countryCode = String(payload.countryCode || '').trim();

  if (!enrollmentId) {
    throw new functions.https.HttpsError('invalid-argument', 'enrollmentId is required');
  }
  if (!studentUid) {
    throw new functions.https.HttpsError('invalid-argument', 'studentUid is required');
  }
  if (!email || !email.includes('@')) {
    throw new functions.https.HttpsError('invalid-argument', 'A valid parent email is required');
  }

  const db = admin.firestore();
  const enrollmentRef = db.collection('enrollments').doc(enrollmentId);
  const enrollmentSnap = await enrollmentRef.get();
  if (!enrollmentSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Enrollment ${enrollmentId} not found`);
  }

  const studentRef = db.collection('users').doc(studentUid);
  const studentSnap = await studentRef.get();
  if (!studentSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Student ${studentUid} not found`);
  }

  let parentUid;
  let parentAlreadyExists = false;
  let createdAuthUser = false;

  try {
    const existing = await admin.auth().getUserByEmail(email);
    parentUid = existing.uid;
    parentAlreadyExists = true;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') {
      throw new functions.https.HttpsError('internal', e.message || 'Auth lookup failed');
    }
    // Create a fresh parent Auth user with a generated temporary password; the
    // parent sets their own password through the reset link below.
    const tempPassword = generateRandomPassword();
    const created = await admin.auth().createUser({
      email,
      password: tempPassword,
      displayName: `${firstName} ${lastName}`.trim() || email,
      emailVerified: false,
    });
    parentUid = created.uid;
    createdAuthUser = true;
  }

  const parentRef = db.collection('users').doc(parentUid);
  const parentSnap = await parentRef.get();

  const now = admin.firestore.FieldValue.serverTimestamp();

  // The merge below sets user_type to 'parent'. When the email already belongs
  // to an account, that must only ever be a parent account: applied to an
  // admin, teacher or student it silently rewrites who that person is in the
  // system — an admin who enrols their own child would lose the admin console.
  if (parentSnap.exists) {
    const existingData = parentSnap.data() || {};
    const existingType = String(existingData.user_type || existingData.role || '').toLowerCase();
    const secondary = Array.isArray(existingData.secondary_roles)
      ? existingData.secondary_roles.map((r) => String(r).toLowerCase())
      : [];
    const isParentAlready = existingType === 'parent' || existingType === '' || secondary.includes('parent');
    if (!isParentAlready) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `${email} belongs to an existing ${existingType} account. Linking it as a parent would change that account's role. ` +
          `Use a different email for the parent, or add "parent" to that account's secondary roles first.`
      );
    }
  }
  const parentDocUpdate = {
    'e-mail': email,
    user_type: 'parent',
    is_active: true,
    uid: parentUid,
    updated_at: now,
  };
  if (firstName) parentDocUpdate.first_name = firstName;
  if (lastName) parentDocUpdate.last_name = lastName;
  if (phone) parentDocUpdate.phone_number = phone;
  if (countryCode) parentDocUpdate.country_code = countryCode;

  if (!parentSnap.exists) {
    parentDocUpdate.date_added = now;
    parentDocUpdate.password_reset_required = true;
    parentDocUpdate.children_ids = [studentUid];
    // Generate a kiosque code for the new parent so they can be linked later.
    parentDocUpdate.kiosk_code = await generateKiosqueCodeForParent();
    await parentRef.set(parentDocUpdate, { merge: true });
  } else {
    // Merge children_ids idempotently.
    const existingType = String((parentSnap.data() || {}).user_type || '').toLowerCase();
    const update = { ...parentDocUpdate, children_ids: admin.firestore.FieldValue.arrayUnion(studentUid) };
    // A staff account that is a parent only through secondary_roles keeps its primary role.
    if (existingType && existingType !== 'parent') delete update.user_type;
    await parentRef.set(update, { merge: true });
  }

  // Add parent to the student's guardian_ids (idempotent).
  await studentRef.set(
    {
      guardian_ids: admin.firestore.FieldValue.arrayUnion(parentUid),
      updated_at: now,
    },
    { merge: true },
  );

  // Stamp enrollment with linking metadata.
  await enrollmentRef.set(
    {
      contact: { guardianId: parentUid },
      metadata: {
        parentInviteStatus: parentAlreadyExists ? 'linked' : 'invited',
        parentUserId: parentUid,
        parentInvitedAt: now,
        parentInvitedBy: auth.uid,
      },
    },
    { merge: true },
  );

  // Send a password setup email when we had to create the Auth user.
  // Tell the parent. Linking someone to a child and never saying so leaves
  // them with an account they do not know exists — and, for a parent who
  // already had one, no sign that anything happened at all.
  const studentName = [
    (studentSnap.data() || {}).first_name,
    (studentSnap.data() || {}).last_name,
  ].filter(Boolean).join(' ').trim() || 'your child';

  let inviteSent = false;
  let inviteError = null;
  try {
    const transporter = await createTransporter();
    const from = `"Alluwal Education Hub" <no-reply@alluwaleducationhub.org>`;
    const greeting = `As-salamu alaykum ${escapeHtml(firstName || '')},`;
    let subject;
    let html;

    if (createdAuthUser) {
      const link = await admin.auth().generatePasswordResetLink(email);
      subject = 'Set up your Alluwal Education Hub parent account';
      html = brandedEmailHtml({
        heading: 'Set up your parent account',
        bodyHtml: `
          <p>${greeting}</p>
          <p>An administrator has linked you as the parent of <strong>${escapeHtml(studentName)}</strong> at Alluwal Education Hub.</p>
          <p>Set your password to open your parent dashboard, where you can see their schedule, attendance and invoices.</p>
          <p><a class="button" href="${link}">Set your password</a></p>
          <p class="fallback">If the button does not work, copy this URL into your browser:<br/>${link}</p>`,
      });
    } else {
      // An account they already have: no password link, just what changed.
      subject = `${studentName} has been linked to your Alluwal account`;
      html = brandedEmailHtml({
        heading: 'A student was added to your account',
        bodyHtml: `
          <p>${greeting}</p>
          <p><strong>${escapeHtml(studentName)}</strong> is now linked to your Alluwal Education Hub parent account.</p>
          <p>Sign in with your usual password to see their schedule, attendance and invoices.</p>
          <p><a class="button" href="https://alluwaleducationhub.org/app/">Open your dashboard</a></p>`,
      });
    }

    await transporter.sendMail({ from, to: email, subject, html });
    inviteSent = true;
  } catch (e) {
    inviteError = e.message || String(e);
    console.error('inviteParentForEnrollment: failed to send invite email', inviteError);
  }

  // Push, for a parent who already has the app. A brand-new account has no
  // devices yet, so this simply finds nothing — the email above is their way in.
  let pushSent = 0;
  try {
    const parentAfter = (await parentRef.get()).data() || {};
    const tokens = [];
    if (Array.isArray(parentAfter.fcmTokens)) {
      for (const entry of parentAfter.fcmTokens) {
        const token = typeof entry === 'string' ? entry : entry && entry.token;
        if (token) tokens.push(token);
      }
    }
    if (parentAfter.fcmToken) tokens.push(parentAfter.fcmToken);
    if (tokens.length > 0) {
      const res = await admin.messaging().sendEachForMulticast({
        notification: {
          title: 'A student was linked to your account',
          body: `${studentName} is now on your Alluwal parent dashboard.`,
        },
        data: { type: 'parent_linked', studentUid: String(studentUid), enrollmentId: String(enrollmentId) },
        tokens,
      });
      pushSent = res.successCount;
      console.log(`inviteParentForEnrollment: push ${res.successCount}/${tokens.length} delivered`);
    }
  } catch (e) {
    // A push failure must not fail the link, which is already committed.
    console.error('inviteParentForEnrollment: push failed', e.message || e);
  }

  return {
    success: true,
    parentUid,
    parentAlreadyExists,
    createdAuthUser,
    inviteSent,
    inviteError,
    pushSent,
    studentName,
    status: parentAlreadyExists ? 'linked' : 'invited',
  };
};

// Verify the caller is an authenticated admin. Returns the caller's uid.
async function requireAdminCaller(request) {
  const auth = request.auth;
  if (!auth || !auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign-in required');
  }
  const callerDoc = await admin.firestore().collection('users').doc(auth.uid).get();
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Caller has no user profile');
  }
  const callerData = callerDoc.data() || {};
  const callerRole = (callerData.role || callerData.user_type || '').toString().toLowerCase();
  const isAdmin =
    callerRole === 'admin' ||
    callerRole === 'super_admin' ||
    callerData.isAdmin === true ||
    callerData.is_admin === true ||
    callerData.isSuperAdmin === true ||
    callerData.is_super_admin === true;
  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin role required');
  }
  return auth.uid;
}

function roleValue(data) {
  return (data?.role || data?.user_type || data?.userType || '')
    .toString()
    .trim()
    .toLowerCase();
}

function isParentUser(data) {
  const role = roleValue(data);
  return role === 'parent' || role === 'guardian';
}

function stringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item).trim()).filter(Boolean);
}

async function validRemainingGuardianIds(db, guardianIds) {
  const uniqueIds = [...new Set(guardianIds.map((id) => id.trim()).filter(Boolean))];
  if (uniqueIds.length === 0) return [];

  const snaps = await Promise.all(
    uniqueIds.map((id) => db.collection('users').doc(id).get()),
  );

  return snaps
    .map((snap, index) => ({ id: uniqueIds[index], snap }))
    .filter(({ snap }) => snap.exists && isParentUser(snap.data() || {}))
    .map(({ id }) => id);
}

/**
 * Admin-only: sever the link between a parent/guardian and a student.
 *
 * The link created by `inviteParentForEnrollment` is two-sided plus enrollment
 * metadata, so unlinking must undo all three atomically:
 *   - remove parentUid from the student's `guardian_ids` (+ legacy `guardianIds`)
 *   - remove studentUid from the parent's `children_ids`
 *   - mark any enrollment that linked this pair as `unlinked`
 * Every unlink is recorded in `guardian_link_history` for an audit trail.
 */
const unlinkGuardianFromStudent = async (request) => {
  const callerUid = await requireAdminCaller(request);

  const payload = request.data || {};
  const studentUid = String(payload.studentUid || '').trim();
  const parentUid = String(payload.parentUid || '').trim();
  const reason = String(payload.reason || '').trim().slice(0, 500);
  const convertStudentToAdult =
    payload.convertStudentToAdult === true ||
    payload.markStudentAdult === true;

  if (!studentUid) {
    throw new functions.https.HttpsError('invalid-argument', 'studentUid is required');
  }
  if (!parentUid) {
    throw new functions.https.HttpsError('invalid-argument', 'parentUid is required');
  }
  if (studentUid === parentUid) {
    throw new functions.https.HttpsError('invalid-argument', 'studentUid and parentUid must differ');
  }

  const db = admin.firestore();
  const studentRef = db.collection('users').doc(studentUid);
  const parentRef = db.collection('users').doc(parentUid);

  const [studentSnap, parentSnap] = await Promise.all([studentRef.get(), parentRef.get()]);
  if (!studentSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Student ${studentUid} not found`);
  }

  const studentData = studentSnap.data() || {};
  if (roleValue(studentData) !== 'student') {
    throw new functions.https.HttpsError('failed-precondition', 'Selected user is not a student');
  }
  const currentGuardians = [
    ...stringList(studentData.guardian_ids),
    ...stringList(studentData.guardianIds),
    studentData.guardian_id ? String(studentData.guardian_id).trim() : '',
    studentData.parent_id ? String(studentData.parent_id).trim() : '',
    studentData.parentId ? String(studentData.parentId).trim() : '',
  ].filter(Boolean);
  const parentData = parentSnap.exists ? (parentSnap.data() || {}) : {};
  if (parentSnap.exists && !isParentUser(parentData)) {
    throw new functions.https.HttpsError('failed-precondition', 'Selected guardian is not a parent account');
  }
  const currentChildren = [
    ...stringList(parentData.children_ids),
    ...stringList(parentData.childrenIds),
  ];

  const wasLinked =
    currentGuardians.includes(parentUid) || currentChildren.includes(studentUid);
  if (!wasLinked) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'This parent is not linked to this student',
    );
  }

  // Safety net: never leave a minor student without a guardian. A minor is any
  // student that hasn't been explicitly flagged as an adult. Adult students are
  // allowed to stand alone (they manage their own classes/invoices).
  const dedupedGuardians = [...new Set(
    currentGuardians.map((id) => id.trim()).filter(Boolean),
  )];
  const remainingGuardians = dedupedGuardians.filter((id) => id !== parentUid);
  const isMinor = studentData.is_adult_student !== true;
  const validRemainingGuardians = await validRemainingGuardianIds(db, remainingGuardians);
  if (isMinor && validRemainingGuardians.length === 0 && !convertStudentToAdult) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Cannot unlink the only guardian of a minor student. Link another guardian first, or mark this student as an adult.',
      { reason: 'last_guardian_minor' },
    );
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  batch.set(
    studentRef,
    {
      guardian_ids: admin.firestore.FieldValue.arrayRemove(parentUid),
      guardianIds: admin.firestore.FieldValue.arrayRemove(parentUid),
      ...(String(studentData.guardian_id || '').trim() === parentUid
        ? { guardian_id: admin.firestore.FieldValue.delete() }
        : {}),
      ...(String(studentData.parent_id || '').trim() === parentUid
        ? { parent_id: admin.firestore.FieldValue.delete() }
        : {}),
      ...(String(studentData.parentId || '').trim() === parentUid
        ? { parentId: admin.firestore.FieldValue.delete() }
        : {}),
      ...(isMinor && validRemainingGuardians.length === 0 && convertStudentToAdult
        ? {
            is_adult_student: true,
            adult_status_updated_at: now,
            adult_status_updated_by: callerUid,
          }
        : {}),
      updated_at: now,
    },
    { merge: true },
  );

  if (parentSnap.exists) {
    batch.set(
      parentRef,
      {
        children_ids: admin.firestore.FieldValue.arrayRemove(studentUid),
        childrenIds: admin.firestore.FieldValue.arrayRemove(studentUid),
        updated_at: now,
      },
      { merge: true },
    );
  }

  await batch.commit();

  // Best-effort: mark enrollments that linked this exact pair as unlinked so the
  // pipeline UI no longer shows a stale "linked" chip.
  let enrollmentsTouched = 0;
  try {
    const enrollmentSnap = await db
      .collection('enrollments')
      .where('metadata.parentUserId', '==', parentUid)
      .get();
    const enrollmentBatch = db.batch();
    enrollmentSnap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const meta = data.metadata || {};
      const enrollmentStudent = String(meta.studentUserId || meta.studentUid || '');
      if (enrollmentStudent && enrollmentStudent !== studentUid) return;
      enrollmentBatch.set(
        doc.ref,
        {
          contact: { guardianId: admin.firestore.FieldValue.delete() },
          metadata: {
            parentInviteStatus: 'unlinked',
            parentUnlinkedAt: now,
            parentUnlinkedBy: callerUid,
          },
        },
        { merge: true },
      );
      enrollmentsTouched += 1;
    });
    if (enrollmentsTouched > 0) await enrollmentBatch.commit();
  } catch (e) {
    console.error('unlinkGuardianFromStudent: enrollment cleanup failed', e.message || e);
  }

  // Audit trail.
  try {
    await db.collection('guardian_link_history').add({
      action: 'unlink',
      studentUid,
      parentUid,
      reason: reason || null,
      performedBy: callerUid,
      enrollmentsTouched,
      convertedStudentToAdult:
        isMinor && validRemainingGuardians.length === 0 && convertStudentToAdult,
      studentName: `${studentData.first_name || ''} ${studentData.last_name || ''}`.trim() || null,
      parentName: `${parentData.first_name || ''} ${parentData.last_name || ''}`.trim() || null,
      createdAt: now,
    });
  } catch (e) {
    console.error('unlinkGuardianFromStudent: audit write failed', e.message || e);
  }

  const remainingGuardianCount = validRemainingGuardians.length;

  return {
    success: true,
    studentUid,
    parentUid,
    remainingGuardianCount,
    enrollmentsTouched,
    convertedStudentToAdult:
      isMinor && validRemainingGuardians.length === 0 && convertStudentToAdult,
  };
};

// Small helper: generate a unique 6-digit kiosque code for new parents
// (matches the format used elsewhere).
async function generateKiosqueCodeForParent() {
  const db = admin.firestore();
  for (let i = 0; i < 10; i += 1) {
    const code = String(Math.floor(100000 + Math.random() * 900000));
    const q = await db.collection('users').where('kiosk_code', '==', code).limit(1).get();
    if (q.empty) return code;
  }
  return String(Date.now()).slice(-6);
}

module.exports = {
  onEnrollmentCreated,
  publishEnrollmentToJobBoard,
  inviteParentForEnrollment,
  unlinkGuardianFromStudent,
};
