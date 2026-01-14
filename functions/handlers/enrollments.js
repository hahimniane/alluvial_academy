const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { createTransporter } = require('../services/email/transporter');

// Email template for enrollment confirmation to student/parent (single student)
const sendEnrollmentConfirmationEmail = async (enrollmentData) => {
  const transporter = createTransporter();
  const contact = enrollmentData.contact || {};
  const preferences = enrollmentData.preferences || {};
  const student = enrollmentData.student || {};
  const program = enrollmentData.program || {};
  const metadata = enrollmentData.metadata || {};

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
    subject: '🎓 Enrollment Request Received - Alluwal Academy',
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
            <p>Thank you for choosing Alluwal Academy</p>
          </div>
          
          <div class="content">
            <h2>Dear ${recipientName},</h2>
            ${isAdultStudent
              ? `<p>We're excited to inform you that we've received your enrollment request for Islamic studies at Alluwal Academy!</p>`
              : `<p>We're excited to inform you that we've received your enrollment request for <strong>${studentName}</strong>!</p>`
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
                <span class="info-label">Subject:</span>
                <span class="info-value">${enrollmentData.subject || 'Not specified'}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Grade Level:</span>
                <span class="info-value">${enrollmentData.gradeLevel || 'Not specified'}</span>
              </div>
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
            </div>
            
            <p>If you have any questions or need to update your enrollment information, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>
            
            <p>Best regards,<br>
            <strong>The Alluwal Academy Team</strong></p>
          </div>
          
          <div class="footer">
            <p>This is an automated confirmation. For questions, please contact our support team.</p>
            <p>Alluwal Academy - Excellence in Islamic Education</p>
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
  const studentCount = allEnrollments.length;

  // Build HTML for all students
  let studentsHtml = '';
  allEnrollments.forEach((enrollment, index) => {
    const student = enrollment.student || {};
    const program = enrollment.program || {};
    const preferences = enrollment.preferences || {};
    const subject = enrollment.subject || 'Not specified';
    const specificLanguage = enrollment.specificLanguage;
    const gradeLevel = enrollment.gradeLevel || 'Not specified';

    studentsHtml = studentsHtml + `
      <div style="background-color: #f9fafb; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0;">
        <h3 style="margin-top: 0; color: #111827;">👤 Student ${index + 1}: ${student.name || 'Student'}</h3>
        <div style="margin: 10px 0;">
          <strong>Name:</strong> ${student.name || 'Not provided'}<br>
          ${student.age ? `<strong>Age:</strong> ${student.age}<br>` : ''}
          ${student.gender ? `<strong>Gender:</strong> ${student.gender}<br>` : ''}
        </div>
        <div style="margin: 10px 0;">
          <strong>Program Details:</strong><br>
          <strong>Subject:</strong> ${subject}${specificLanguage ? ` (${specificLanguage})` : ''}<br>
          <strong>Level:</strong> ${gradeLevel}<br>
          ${program.classType ? `<strong>Class Type:</strong> ${program.classType}<br>` : ''}
          ${program.sessionDuration ? `<strong>Session Duration:</strong> ${program.sessionDuration}<br>` : ''}
        </div>
        ${preferences.days && preferences.days.length > 0 ? `
        <div style="margin: 10px 0;">
          <strong>Preferred Days:</strong> ${preferences.days.join(', ')}<br>
        </div>
        ` : ''}
        ${preferences.timeSlots && preferences.timeSlots.length > 0 ? `
        <div style="margin: 10px 0;">
          <strong>Preferred Times:</strong> ${preferences.timeSlots.join(', ')}<br>
        </div>
        ` : ''}
      </div>
    `;
  });

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: email,
    subject: `🎓 Enrollment Request Received - ${studentCount} Student${studentCount > 1 ? 's' : ''} - Alluwal Academy`,
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
            <p>Thank you for choosing Alluwal Academy</p>
          </div>
          
          <div class="content">
            <h2>Dear ${recipientName},</h2>
            <p>We're excited to inform you that we've received your enrollment request for <strong>${studentCount} student${studentCount > 1 ? 's' : ''}</strong>!</p>

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

            <div style="margin: 30px 0;">
              <h3 style="color: #111827; margin-bottom: 20px;">👥 Student${studentCount > 1 ? 's' : ''} Information</h3>
              ${studentsHtml}
            </div>
            
            <p>If you have any questions or need to update your enrollment information, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>
            
            <p>Best regards,<br>
            <strong>The Alluwal Academy Team</strong></p>
          </div>
          
          <div class="footer">
            <p>This is an automated confirmation. For questions, please contact our support team.</p>
            <p>Alluwal Academy - Excellence in Islamic Education</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`✅ Multi-student enrollment confirmation email sent to ${email} for ${studentCount} student(s)`);
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
    subject: `🔔 New Enrollment Request - ${student.name || 'New Student'}`,
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
                <span class="info-label">Subject:</span>
                <span class="info-value">${enrollmentData.subject || 'Not specified'}</span>
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
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
              <p><strong>Enrollment ID:</strong> ${enrollmentId}</p>
              <p style="font-size: 12px; color: #6b7280;">View this enrollment in the admin dashboard</p>
            </div>
          </div>
          
          <div class="footer">
            <p>This is an automated notification from Alluwal Academy</p>
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

// HTTP function for Admin to approve enrollment and create job
// Using HTTP instead of Callable to bypass Cloud Run IAM issues
const publishEnrollmentToJobBoardHttp = async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  if (req.method !== 'POST') {
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  console.log('🚀 publishEnrollmentToJobBoardHttp invoked');
  console.log('📦 Body:', JSON.stringify(req.body));
  
  let enrollmentId;
  
  try {
    // Verify Firebase ID token from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.warn('⚠️ Missing or invalid Authorization header');
      res.status(401).json({ success: false, error: 'Unauthorized: Missing Bearer token' });
      return;
    }
    
    const idToken = authHeader.split('Bearer ')[1];
    try {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      console.log('✅ Token verified for user:', decodedToken.uid);
    } catch (tokenError) {
      console.error('❌ Token verification failed:', tokenError.message);
      res.status(401).json({ success: false, error: 'Unauthorized: Invalid token' });
      return;
    }

    enrollmentId = req.body.enrollmentId;
    
    if (!enrollmentId) {
      res.status(400).json({ success: false, error: 'enrollmentId is required' });
      return;
    }
    
    const enrollmentDoc = await admin.firestore().collection('enrollments').doc(enrollmentId).get();
    if (!enrollmentDoc.exists) {
      res.status(404).json({ success: false, error: `Enrollment ${enrollmentId} not found` });
      return;
    }

    const enrollmentData = enrollmentDoc.data();
    
    if (!enrollmentData) {
      res.status(400).json({ success: false, error: 'Enrollment data is empty' });
      return;
    }
    
    console.log(`📋 Processing enrollment ${enrollmentId} with data keys:`, Object.keys(enrollmentData));
    
    // Check if already broadcasted or matched to prevent duplicates
    if (enrollmentData.metadata && 
       (enrollmentData.metadata.status === 'broadcasted' || enrollmentData.metadata.status === 'matched')) {
      res.status(200).json({ 
        success: false, 
        message: `Already ${enrollmentData.metadata.status}`, 
        jobId: enrollmentData.metadata.jobId 
      });
      return;
    }

    const jobId = await createJobOpportunity(enrollmentData, enrollmentId);
    
    console.log(`✅ Successfully created job ${jobId} for enrollment ${enrollmentId}`);
    res.status(200).json({ success: true, jobId });
    
  } catch (error) {
    console.error(`❌ Error publishing enrollment ${enrollmentId}:`, error);
    console.error(`❌ Error details:`, {
      message: error.message,
      stack: error.stack,
      enrollmentId: enrollmentId,
    });
    
    const errorMessage = error.message || 'Unknown error occurred';
    res.status(500).json({ success: false, error: errorMessage });
  }
};

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

module.exports = {
  onEnrollmentCreated,
  publishEnrollmentToJobBoard,
  publishEnrollmentToJobBoardHttp,
};

