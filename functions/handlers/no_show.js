const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onCall} = require('firebase-functions/v2/https');
const {createTransporter} = require('../services/email/transporter');

/**
 * Report a no-show (teacher or student didn't arrive for class)
 * Called from the mobile app when detecting no-show
 */
const reportNoShow = onCall(async (request) => {
  const data = request.data || {};
  
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }
  
  const {
    shiftId,
    shiftName,
    roomName,
    reportedBy,
    reporterName,
    isTeacherNoShow,
    timestamp,
  } = data;
  
  if (!shiftId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Shift ID is required'
    );
  }
  
  try {
    // Get shift details
    const shiftDoc = await admin.firestore()
      .collection('shifts')
      .doc(shiftId)
      .get();
    
    const shiftData = shiftDoc.exists ? shiftDoc.data() : null;
    
    // Get all admins to notify
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('role', '==', 'admin')
      .get();
    
    const adminEmails = [];
    const adminTokens = [];
    
    adminsSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      if (userData.email) {
        adminEmails.push(userData.email);
      }
      if (userData.fcmToken) {
        adminTokens.push(userData.fcmToken);
      }
    });
    
    // Create the report record
    const reportData = {
      shiftId,
      shiftName: shiftName || shiftData?.shift_name || 'Unknown Class',
      roomName,
      reportedBy,
      reporterName,
      isTeacherNoShow,
      timestamp: timestamp ? new Date(timestamp) : admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
      teacherId: shiftData?.teacher_id || null,
      teacherName: shiftData?.teacher_name || null,
      studentIds: shiftData?.student_ids || [],
    };
    
    await admin.firestore()
      .collection('no_show_reports')
      .add(reportData);
    
    console.log(`[NO-SHOW] Report created for shift ${shiftId}, isTeacherNoShow: ${isTeacherNoShow}`);
    
    // Send email notifications to admins
    if (adminEmails.length > 0) {
      await sendNoShowEmail(adminEmails, reportData, isTeacherNoShow);
    }
    
    // Send push notifications to admins
    if (adminTokens.length > 0) {
      await sendNoShowPushNotification(adminTokens, reportData, isTeacherNoShow);
    }
    
    return {
      success: true,
      message: 'No-show report submitted successfully',
    };
  } catch (error) {
    console.error('[NO-SHOW] Error creating report:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to submit no-show report'
    );
  }
});

/**
 * Send email notification to admins about no-show
 */
async function sendNoShowEmail(adminEmails, reportData, isTeacherNoShow) {
  const transporter = createTransporter();
  
  const subject = isTeacherNoShow
    ? `⚠️ Teacher No-Show Alert: ${reportData.shiftName}`
    : `⚠️ Student No-Show Alert: ${reportData.shiftName}`;
  
  const reportType = isTeacherNoShow ? 'Teacher' : 'Student';
  const reportedByType = isTeacherNoShow ? 'student' : 'teacher';
  
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>No-Show Alert - Alluwal Academy</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background: linear-gradient(135deg, #F59E0B 0%, #D97706 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">⚠️ No-Show Alert</h1>
        <p style="color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px;">${reportType} Did Not Arrive</p>
      </div>
      
      <div style="background: #ffffff; padding: 40px; border-radius: 0 0 10px 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <h2 style="color: #2D3748; margin: 0 0 20px 0; font-size: 24px;">Class Attendance Issue</h2>
        
        <p style="margin: 0 0 20px 0; font-size: 16px; color: #4A5568;">
          A ${reportType.toLowerCase()} no-show has been reported for a scheduled class. Please review the details below and take appropriate action.
        </p>
        
        <div style="background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 20px; border-radius: 0 8px 8px 0; margin: 20px 0;">
          <h3 style="color: #92400E; margin: 0 0 15px 0; font-size: 18px;">📋 Report Details</h3>
          <table style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Class Name:</td>
              <td style="padding: 8px 0; color: #1C1917; font-weight: 600;">${reportData.shiftName}</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Issue Type:</td>
              <td style="padding: 8px 0; color: #DC2626; font-weight: 600;">${reportType} No-Show</td>
            </tr>
            ${isTeacherNoShow && reportData.teacherName ? `
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Missing Teacher:</td>
              <td style="padding: 8px 0; color: #1C1917;">${reportData.teacherName}</td>
            </tr>
            ` : ''}
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Reported By:</td>
              <td style="padding: 8px 0; color: #1C1917;">${reportData.reporterName} (${reportedByType})</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; color: #78716C; font-weight: 500;">Report Time:</td>
              <td style="padding: 8px 0; color: #1C1917;">${new Date().toLocaleString()}</td>
            </tr>
          </table>
        </div>
        
        <div style="background: #F7FAFC; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h3 style="color: #2D3748; margin: 0 0 10px 0; font-size: 16px;">Recommended Actions:</h3>
          <ul style="margin: 0; padding-left: 20px; color: #4A5568;">
            ${isTeacherNoShow ? `
            <li>Contact the teacher to understand the situation</li>
            <li>Notify affected students about the class status</li>
            <li>Consider rescheduling the class if needed</li>
            ` : `
            <li>Check if students are having technical issues</li>
            <li>Contact parents/guardians if students are minors</li>
            <li>Document the absence for records</li>
            `}
          </ul>
        </div>
        
        <p style="margin: 30px 0 0 0; font-size: 14px; color: #718096;">
          This is an automated notification from Alluwal Academy's attendance monitoring system.
        </p>
      </div>
      
      <div style="text-align: center; padding: 20px; color: #718096; font-size: 12px;">
        <p style="margin: 0;">© ${new Date().getFullYear()} Alluwal Academy. All rights reserved.</p>
        <p style="margin: 5px 0 0 0;">Quran Education Management System</p>
      </div>
    </body>
    </html>
  `;
  
  try {
    await transporter.sendMail({
      from: 'support@alluwaleducationhub.org',
      to: adminEmails.join(', '),
      subject,
      html: htmlContent,
    });
    console.log(`[NO-SHOW] Email sent to ${adminEmails.length} admins`);
  } catch (error) {
    console.error('[NO-SHOW] Failed to send email:', error);
  }
}

/**
 * Send push notification to admins about no-show
 */
async function sendNoShowPushNotification(tokens, reportData, isTeacherNoShow) {
  const title = isTeacherNoShow
    ? '⚠️ Teacher No-Show'
    : '⚠️ Student No-Show';
  
  const body = isTeacherNoShow
    ? `Teacher didn't arrive for ${reportData.shiftName}. Reported by ${reportData.reporterName}.`
    : `No students joined ${reportData.shiftName}. Reported by ${reportData.reporterName}.`;
  
  const message = {
    notification: {
      title,
      body,
    },
    data: {
      type: 'no_show_report',
      shiftId: reportData.shiftId,
      isTeacherNoShow: String(isTeacherNoShow),
    },
    tokens,
  };
  
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[NO-SHOW] Push notifications sent: ${response.successCount} successful, ${response.failureCount} failed`);
  } catch (error) {
    console.error('[NO-SHOW] Failed to send push notifications:', error);
  }
}

module.exports = {
  reportNoShow,
};
