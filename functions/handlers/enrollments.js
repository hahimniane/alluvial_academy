const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { createTransporter } = require('../services/email/transporter');

// Email template for enrollment confirmation to student/parent
const sendEnrollmentConfirmationEmail = async (enrollmentData) => {
  const transporter = createTransporter();
  const contact = enrollmentData.contact || {};
  const preferences = enrollmentData.preferences || {};
  const student = enrollmentData.student || {};
  const program = enrollmentData.program || {};
  
  const recipientName = contact.parentName || contact.email?.split('@')[0] || 'Student';
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
            <p>We're excited to inform you that we've received your enrollment request for <strong>${studentName}</strong>!</p>
            
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
              <h3>📋 Enrollment Details</h3>
              <div class="info-row">
                <span class="info-label">Student Name:</span>
                <span class="info-value">${studentName || 'Not provided'}</span>
              </div>
              ${student.age ? `
              <div class="info-row">
                <span class="info-label">Student Age:</span>
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

// Email template for admin notification
const sendAdminEnrollmentNotification = async (enrollmentData, enrollmentId) => {
  const transporter = createTransporter();
  const contact = enrollmentData.contact || {};
  const preferences = enrollmentData.preferences || {};
  const student = enrollmentData.student || {};
  const program = enrollmentData.program || {};
  
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
              <strong>⚠️ New enrollment request received and automatically posted to the job board.</strong>
              <p>Teachers can now view and accept this opportunity.</p>
            </div>
            
            <div class="info-box">
              <h3>📋 Contact Information</h3>
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
              ${contact.parentName ? `
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
const createJobOpportunity = async (enrollmentData, enrollmentId) => {
  try {
    const contact = enrollmentData.contact || {};
    const preferences = enrollmentData.preferences || {};
    const student = enrollmentData.student || {};
    
    const jobData = {
      enrollmentId: enrollmentId,
      studentName: student.name || 'Not provided',
      studentAge: student.age || '',
      subject: enrollmentData.subject || 'General',
      gradeLevel: enrollmentData.gradeLevel || '',
      days: preferences.days || [],
      timeSlots: preferences.timeSlots || [],
      timeZone: preferences.timeZone || '',
      status: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    const jobRef = await admin.firestore().collection('job_board').add(jobData);
    console.log(`✅ Job opportunity created: ${jobRef.id}`);
    
    // Update enrollment status
    await admin.firestore().collection('enrollments').doc(enrollmentId).update({
      'metadata.status': 'broadcasted',
      'metadata.broadcastedAt': admin.firestore.FieldValue.serverTimestamp(),
      'metadata.jobId': jobRef.id,
    });
    
    return jobRef.id;
  } catch (error) {
    console.error('❌ Failed to create job opportunity:', error);
    throw error;
  }
};

// Firebase trigger when enrollment is created
const onEnrollmentCreated = onDocumentCreated('enrollments/{enrollmentId}', async (event) => {
  const enrollmentId = event.params.enrollmentId;
  const enrollmentData = event.data.data();
  
  console.log(`📝 Processing new enrollment: ${enrollmentId}`);
  
  try {
    // 1. Send confirmation email to student/parent
    const confirmationSent = await sendEnrollmentConfirmationEmail(enrollmentData);
    
    // 2. Send notification email to admin
    const adminNotified = await sendAdminEnrollmentNotification(enrollmentData, enrollmentId);
    
    // 3. Create job opportunity
    const jobId = await createJobOpportunity(enrollmentData, enrollmentId);
    
    console.log(`✅ Enrollment processed successfully:
      - Confirmation email: ${confirmationSent ? 'Sent' : 'Failed'}
      - Admin notification: ${adminNotified ? 'Sent' : 'Failed'}
      - Job opportunity: ${jobId ? 'Created' : 'Failed'}
    `);
    
    return {
      success: true,
      enrollmentId,
      jobId,
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

module.exports = {
  onEnrollmentCreated,
};

