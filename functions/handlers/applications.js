const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { createTransporter } = require('../services/email/transporter');

// Email template for leadership application confirmation
const sendLeadershipApplicationConfirmation = async (applicationData) => {
  const transporter = createTransporter();
  const email = applicationData.email;
  const firstName = applicationData.firstName || '';
  const lastName = applicationData.lastName || '';
  const fullName = `${firstName} ${lastName}`.trim() || 'Applicant';

  if (!email) {
    console.warn('No email found in leadership application data, skipping confirmation email');
    return false;
  }

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: email,
    subject: '🎯 Leadership Application Received - Alluwal Academy',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Leadership Application Confirmation</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #f5f3ff; border-left: 4px solid #8B5CF6; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
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
            <h1>🎯 Leadership Application Received</h1>
            <p>Thank you for your interest in leadership at Alluwal Academy</p>
          </div>
          
          <div class="content">
            <h2>Dear ${fullName},</h2>
            <p>We're excited to inform you that we've received your leadership application!</p>

            <div class="success-note">
              <h3>✅ What Happens Next?</h3>
              <ul>
                <li>Our team will review your application within 5-7 business days</li>
                <li>We'll assess your qualifications and leadership experience</li>
                <li>You'll receive an email notification once your application has been reviewed</li>
                <li>If selected, we'll schedule an interview to discuss opportunities</li>
              </ul>
            </div>
            
            <div class="info-box">
              <h3>📋 Your Application Summary</h3>
              <div class="info-row">
                <span class="info-label">Name:</span>
                <span class="info-value">${fullName}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${email}</span>
              </div>
              ${applicationData.currentLocation ? `
              <div class="info-row">
                <span class="info-label">Location:</span>
                <span class="info-value">${applicationData.currentLocation}</span>
              </div>
              ` : ''}
              ${applicationData.currentStatus ? `
              <div class="info-row">
                <span class="info-label">Current Status:</span>
                <span class="info-value">${applicationData.currentStatus.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}${applicationData.currentStatusOther ? ` - ${applicationData.currentStatusOther}` : ''}</span>
              </div>
              ` : ''}
              ${applicationData.availabilityStart ? `
              <div class="info-row">
                <span class="info-label">Availability:</span>
                <span class="info-value">${applicationData.availabilityStart.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}${applicationData.availabilityStartOther ? ` - ${applicationData.availabilityStartOther}` : ''}</span>
              </div>
              ` : ''}
            </div>
            
            <p>If you have any questions or need to update your application information, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>
            
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
    console.log(`✅ Leadership application confirmation email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send leadership application confirmation email to ${email}:`, error);
    return false;
  }
};

// Email template for teacher application confirmation
const sendTeacherApplicationConfirmation = async (applicationData) => {
  const transporter = createTransporter();
  const email = applicationData.email;
  const firstName = applicationData.firstName || '';
  const lastName = applicationData.lastName || '';
  const fullName = `${firstName} ${lastName}`.trim() || 'Applicant';

  if (!email) {
    console.warn('No email found in teacher application data, skipping confirmation email');
    return false;
  }

  const teachingPrograms = applicationData.teachingPrograms || [];
  const languages = applicationData.languages || [];

  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: email,
    subject: '👨‍🏫 Teacher Application Received - Alluwal Academy',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Teacher Application Confirmation</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #ecfdf5; border-left: 4px solid #10B981; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
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
            <h1>👨‍🏫 Teacher Application Received</h1>
            <p>Thank you for your interest in teaching at Alluwal Academy</p>
          </div>
          
          <div class="content">
            <h2>Dear ${fullName},</h2>
            <p>We're excited to inform you that we've received your teacher application!</p>

            <div class="success-note">
              <h3>✅ What Happens Next?</h3>
              <ul>
                <li>Our team will review your application within 5-7 business days</li>
                <li>We'll assess your qualifications and teaching experience</li>
                <li>You'll receive an email notification once your application has been reviewed</li>
                <li>If selected, we'll schedule an interview and onboarding process</li>
              </ul>
            </div>
            
            <div class="info-box">
              <h3>📋 Your Application Summary</h3>
              <div class="info-row">
                <span class="info-label">Name:</span>
                <span class="info-value">${fullName}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${email}</span>
              </div>
              ${applicationData.currentLocation ? `
              <div class="info-row">
                <span class="info-label">Location:</span>
                <span class="info-value">${applicationData.currentLocation}</span>
              </div>
              ` : ''}
              ${teachingPrograms.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Teaching Programs:</span>
                <span class="info-value">${teachingPrograms.map(p => p.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())).join(', ')}${applicationData.teachingProgramOther ? `, ${applicationData.teachingProgramOther}` : ''}</span>
              </div>
              ` : ''}
              ${languages.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Languages:</span>
                <span class="info-value">${languages.join(', ')}</span>
              </div>
              ` : ''}
              ${applicationData.availabilityStart ? `
              <div class="info-row">
                <span class="info-label">Availability:</span>
                <span class="info-value">${applicationData.availabilityStart.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}${applicationData.availabilityStartOther ? ` - ${applicationData.availabilityStartOther}` : ''}</span>
              </div>
              ` : ''}
            </div>
            
            <p>If you have any questions or need to update your application information, please don't hesitate to contact us at <a href="mailto:support@alluwaleducationhub.org">support@alluwaleducationhub.org</a>.</p>
            
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
    console.log(`✅ Teacher application confirmation email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send teacher application confirmation email to ${email}:`, error);
    return false;
  }
};

// Admin notification for leadership application
const sendAdminLeadershipNotification = async (applicationData, applicationId) => {
  const transporter = createTransporter();
  const adminEmail = 'support@alluwaleducationhub.org';
  
  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: adminEmail,
    subject: `🔔 New Leadership Application - ${applicationData.firstName || ''} ${applicationData.lastName || ''}`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Leadership Application</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 700px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #f5f3ff; border-left: 4px solid #8B5CF6; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .info-row { display: flex; justify-content: space-between; margin: 10px 0; padding: 5px 0; border-bottom: 1px solid #e5e7eb; }
          .info-label { font-weight: bold; color: #374151; min-width: 150px; }
          .info-value { color: #6b7280; flex: 1; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .alert-box { background-color: #fef3c7; border: 2px solid #f59e0b; padding: 15px; margin: 15px 0; border-radius: 6px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔔 New Leadership Application</h1>
            <p>Action Required</p>
          </div>
          
          <div class="content">
            <div class="alert-box">
              <strong>📋 New leadership application received - Awaiting your review.</strong>
            </div>
            
            <div class="info-box">
              <h3>📋 Applicant Information</h3>
              <div class="info-row">
                <span class="info-label">Name:</span>
                <span class="info-value">${applicationData.firstName || ''} ${applicationData.lastName || ''}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${applicationData.email || 'Not provided'}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Phone:</span>
                <span class="info-value">${applicationData.phoneNumber || 'Not provided'}</span>
              </div>
              ${applicationData.currentLocation ? `
              <div class="info-row">
                <span class="info-label">Location:</span>
                <span class="info-value">${applicationData.currentLocation}</span>
              </div>
              ` : ''}
              ${applicationData.currentStatus ? `
              <div class="info-row">
                <span class="info-label">Current Status:</span>
                <span class="info-value">${applicationData.currentStatus.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}${applicationData.currentStatusOther ? ` - ${applicationData.currentStatusOther}` : ''}</span>
              </div>
              ` : ''}
              ${applicationData.interestReason ? `
              <div class="info-row">
                <span class="info-label">Interest Reason:</span>
                <span class="info-value">${applicationData.interestReason}</span>
              </div>
              ` : ''}
              ${applicationData.relevantExperience ? `
              <div class="info-row">
                <span class="info-label">Relevant Experience:</span>
                <span class="info-value">${applicationData.relevantExperience}</span>
              </div>
              ` : ''}
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
              <p><strong>Application ID:</strong> ${applicationId}</p>
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
    console.log(`✅ Admin notification email sent for leadership application ${applicationId}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send admin notification email for leadership application ${applicationId}:`, error);
    return false;
  }
};

// Admin notification for teacher application
const sendAdminTeacherNotification = async (applicationData, applicationId) => {
  const transporter = createTransporter();
  const adminEmail = 'support@alluwaleducationhub.org';
  
  const mailOptions = {
    from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
    to: adminEmail,
    subject: `🔔 New Teacher Application - ${applicationData.firstName || ''} ${applicationData.lastName || ''}`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>New Teacher Application</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 700px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; padding: 30px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 28px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .info-box { background-color: #ecfdf5; border-left: 4px solid #10B981; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .info-row { display: flex; justify-content: space-between; margin: 10px 0; padding: 5px 0; border-bottom: 1px solid #e5e7eb; }
          .info-label { font-weight: bold; color: #374151; min-width: 150px; }
          .info-value { color: #6b7280; flex: 1; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .alert-box { background-color: #fef3c7; border: 2px solid #f59e0b; padding: 15px; margin: 15px 0; border-radius: 6px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔔 New Teacher Application</h1>
            <p>Action Required</p>
          </div>
          
          <div class="content">
            <div class="alert-box">
              <strong>📋 New teacher application received - Awaiting your review.</strong>
            </div>
            
            <div class="info-box">
              <h3>📋 Applicant Information</h3>
              <div class="info-row">
                <span class="info-label">Name:</span>
                <span class="info-value">${applicationData.firstName || ''} ${applicationData.lastName || ''}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Email:</span>
                <span class="info-value">${applicationData.email || 'Not provided'}</span>
              </div>
              <div class="info-row">
                <span class="info-label">Phone:</span>
                <span class="info-value">${applicationData.phoneNumber || 'Not provided'}</span>
              </div>
              ${applicationData.currentLocation ? `
              <div class="info-row">
                <span class="info-label">Location:</span>
                <span class="info-value">${applicationData.currentLocation}</span>
              </div>
              ` : ''}
              ${applicationData.teachingPrograms && applicationData.teachingPrograms.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Teaching Programs:</span>
                <span class="info-value">${applicationData.teachingPrograms.map(p => p.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())).join(', ')}${applicationData.teachingProgramOther ? `, ${applicationData.teachingProgramOther}` : ''}</span>
              </div>
              ` : ''}
              ${applicationData.languages && applicationData.languages.length > 0 ? `
              <div class="info-row">
                <span class="info-label">Languages:</span>
                <span class="info-value">${applicationData.languages.join(', ')}</span>
              </div>
              ` : ''}
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
              <p><strong>Application ID:</strong> ${applicationId}</p>
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
    console.log(`✅ Admin notification email sent for teacher application ${applicationId}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send admin notification email for teacher application ${applicationId}:`, error);
    return false;
  }
};

// Firebase trigger when leadership application is created
const onLeadershipApplicationCreated = onDocumentCreated('leadership_applications/{applicationId}', async (event) => {
  const applicationId = event.params.applicationId;
  const applicationData = event.data.data();
  
  console.log(`📝 Processing new leadership application: ${applicationId}`);
  
  try {
    // Send confirmation email to applicant
    const confirmationSent = await sendLeadershipApplicationConfirmation(applicationData);
    
    // Send notification email to admin
    const adminNotified = await sendAdminLeadershipNotification(applicationData, applicationId);
    
    console.log(`✅ Leadership application processed successfully:
      - Confirmation email: ${confirmationSent ? 'Sent' : 'Failed'}
      - Admin notification: ${adminNotified ? 'Sent' : 'Failed'}
    `);
    
    return {
      success: true,
      applicationId,
      emailsSent: {
        confirmation: confirmationSent,
        admin: adminNotified,
      },
    };
  } catch (error) {
    console.error(`❌ Error processing leadership application ${applicationId}:`, error);
    return {
      success: false,
      error: error.message,
    };
  }
});

// Firebase trigger when teacher application is created
const onTeacherApplicationCreated = onDocumentCreated('teacher_applications/{applicationId}', async (event) => {
  const applicationId = event.params.applicationId;
  const applicationData = event.data.data();
  
  console.log(`📝 Processing new teacher application: ${applicationId}`);
  
  try {
    // Send confirmation email to applicant
    const confirmationSent = await sendTeacherApplicationConfirmation(applicationData);
    
    // Send notification email to admin
    const adminNotified = await sendAdminTeacherNotification(applicationData, applicationId);
    
    console.log(`✅ Teacher application processed successfully:
      - Confirmation email: ${confirmationSent ? 'Sent' : 'Failed'}
      - Admin notification: ${adminNotified ? 'Sent' : 'Failed'}
    `);
    
    return {
      success: true,
      applicationId,
      emailsSent: {
        confirmation: confirmationSent,
        admin: adminNotified,
      },
    };
  } catch (error) {
    console.error(`❌ Error processing teacher application ${applicationId}:`, error);
    return {
      success: false,
      error: error.message,
    };
  }
});

module.exports = {
  onLeadershipApplicationCreated,
  onTeacherApplicationCreated,
};
