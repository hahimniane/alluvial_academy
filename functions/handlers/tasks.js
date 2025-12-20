const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {sendTaskAssignmentEmail} = require('../services/email/senders');
const {createTransporter} = require('../services/email/transporter');

const sendTaskAssignmentNotification = async (data) => {
  console.log('--- TASK ASSIGNMENT NOTIFICATION ---');
  console.log('Raw data received:', data);
  console.log('Data type:', typeof data);
  console.log('Data keys:', data ? Object.keys(data) : 'data is null/undefined');

  try {
    const {taskId, taskTitle, taskDescription, dueDate, assignedUserIds, assignedByName} =
      data.data || {};

    console.log('Extracted fields:', {
      taskId,
      taskTitle,
      taskDescription,
      dueDate,
      assignedUserIds,
      assignedByName,
    });

    if (!taskId || !taskTitle || !Array.isArray(assignedUserIds) || assignedUserIds.length === 0) {
      console.error('Invalid or missing fields:', {taskId, taskTitle, assignedUserIds});
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing or invalid required fields: taskId, taskTitle, or assignedUserIds must be a non-empty array.'
      );
    }

    console.log(`Processing task assignment notification for task: ${taskTitle}`);
    console.log(`Assigned to ${assignedUserIds.length} users`);

    const results = [];
    const errors = [];

    for (const userId of assignedUserIds) {
      try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();

        if (!userDoc.exists) {
          console.error(`User not found: ${userId}`);
          errors.push({
            userId,
            error: 'User not found',
          });
          continue;
        }

        const userData = userDoc.data();
        const userEmail = userData['e-mail'] || userData.email;
        const userName = `${userData.first_name || ''} ${userData.last_name || ''}`.trim() || 'User';

        if (!userEmail) {
          console.error(`No email found for user: ${userId}`);
          errors.push({
            userId,
            error: 'No email address found',
          });
          continue;
        }

        const emailSent = await sendTaskAssignmentEmail(
          userEmail,
          userName,
          taskTitle,
          taskDescription,
          dueDate,
          assignedByName || 'System Administrator'
        );

        results.push({
          userId,
          email: userEmail,
          name: userName,
          emailSent,
        });

        console.log(
          `Email notification processed for ${userName} (${userEmail}): ${
            emailSent ? 'SUCCESS' : 'FAILED'
          }`
        );
      } catch (error) {
        console.error(`Error processing notification for user ${userId}:`, error);
        errors.push({
          userId,
          error: error.message,
        });
      }
    }

    return {
      success: true,
      taskId,
      taskTitle,
      totalAssignees: assignedUserIds.length,
      emailsSent: results.filter((r) => r.emailSent).length,
      emailsFailed: results.filter((r) => !r.emailSent).length,
      results,
      errors,
    };
  } catch (error) {
    console.error('Error in sendTaskAssignmentNotification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};

const sendTaskStatusUpdateNotification = async (request) => {
  console.log('--- TASK STATUS UPDATE NOTIFICATION ---');

  try {
    const {taskId, taskTitle, oldStatus, newStatus, updatedByName, createdBy} = request.data || {};

    if (!taskId || !taskTitle || !newStatus || !createdBy) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: taskId, taskTitle, newStatus, and createdBy are required.'
      );
    }

    const db = admin.firestore();

    let assignedByEmail;
    let assignedByName;

    if (createdBy === 'test-creator-id') {
      assignedByEmail = 'hassimiou.niane@maine.edu';
      assignedByName = 'Test Creator';
      console.log('Using test data for task status update notification');
    } else {
      const creatorDoc = await db.collection('users').doc(createdBy).get();
      if (!creatorDoc.exists) {
        console.log(`Task creator ${createdBy} not found in database`);
        return {success: false, message: `Task creator ${createdBy} not found`};
      }

      const creatorData = creatorDoc.data();
      assignedByEmail = creatorData['e-mail'] || creatorData.email;
      assignedByName = `${creatorData.first_name || ''} ${creatorData.last_name || ''}`.trim() || 'Task Creator';

      console.log('Creator data:', {
        createdBy,
        'e-mail': creatorData['e-mail'],
        email: creatorData.email,
        first_name: creatorData.first_name,
        last_name: creatorData.last_name,
      });

      if (!assignedByEmail) {
        console.log('Task creator email not found. Available fields:', Object.keys(creatorData));
        return {success: false, message: 'Task creator email not found'};
      }
    }

    const transporter = createTransporter();

    const statusColors = {
      pending: '#f59e0b',
      in_progress: '#3b82f6',
      completed: '#10b981',
      cancelled: '#ef4444',
      todo: '#6b7280',
      done: '#10b981',
    };

    const statusEmojis = {
      pending: '⏳',
      in_progress: '🔄',
      completed: '✅',
      cancelled: '❌',
      todo: '📋',
      done: '✅',
    };

    const statusColor = statusColors[newStatus] || '#6b7280';
    const statusEmoji = statusEmojis[newStatus] || '📋';

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      to: assignedByEmail,
      subject: `${statusEmoji} Task Status Updated: ${taskTitle}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Task Status Update</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; }
          .header { background: linear-gradient(135deg, #0386FF 0%, #0693e3 100%); color: white; padding: 25px 20px; text-align: center; }
          .header h1 { margin: 0; font-size: 24px; font-weight: bold; }
          .content { padding: 30px 20px; }
          .status-update { background-color: #f8fafc; border: 2px solid ${statusColor}; padding: 20px; margin: 20px 0; border-radius: 8px; text-align: center; }
          .status-badge { display: inline-block; background-color: ${statusColor}; color: white; padding: 8px 16px; border-radius: 20px; font-weight: bold; text-transform: uppercase; margin: 0 5px; }
          .task-info { background-color: #f0f9ff; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 0 8px 8px 0; }
          .cta-button { display: inline-block; background-color: #0386FF; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold; margin: 20px 0; }
          .footer { background-color: #f8fafc; padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          .arrow { font-size: 24px; color: #6b7280; margin: 0 10px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>${statusEmoji} Task Status Updated</h1>
            <p>One of your assigned tasks has been updated</p>
          </div>
          
          <div class="content">
            <div class="task-info">
              <h2>📋 Task Details</h2>
              <p><strong>Task:</strong> ${taskTitle}</p>
              <p><strong>Task ID:</strong> ${taskId}</p>
              <p><strong>Updated by:</strong> ${updatedByName || 'Unknown User'}</p>
              <p><strong>Updated:</strong> ${new Date().toLocaleString()}</p>
            </div>
            
            <div class="status-update">
              <h3>Status Change</h3>
              <div style="display: flex; align-items: center; justify-content: center; flex-wrap: wrap;">
                ${oldStatus ? `<span class="status-badge" style="background-color: #6b7280;">${oldStatus.replace('_', ' ')}</span>` : ''}
                <span class="arrow">→</span>
                <span class="status-badge">${newStatus.replace('_', ' ')}</span>
              </div>
            </div>
            
            <div style="text-align: center; margin: 30px 0;">
              <p>You can view the complete task details and progress in your dashboard.</p>
              <a href="https://alluwaleducationhub.org/tasks" class="cta-button">View Task Details</a>
            </div>
            
            <div style="background-color: #ecfdf5; border: 1px solid #10b981; padding: 15px; margin: 20px 0; border-radius: 6px;">
              <h4 style="margin-top: 0;">💡 Quick Actions</h4>
              <ul>
                <li>Review task progress and details</li>
                <li>Add comments or feedback</li>
                <li>Update task priority if needed</li>
                <li>Check other pending tasks</li>
              </ul>
            </div>
          </div>
          
          <div class="footer">
            <p>© ${new Date().getFullYear()} Alluwal Education Hub. All rights reserved.</p>
            <p>This notification was sent to ${assignedByEmail}. You're receiving this because you assigned this task.</p>
          </div>
        </div>
      </body>
      </html>
      `,
    };

    await transporter.sendMail(mailOptions);
    console.log(`Task status update email sent successfully to ${assignedByEmail}`);

    return {success: true, message: `Status update notification sent to ${assignedByEmail}`};
  } catch (error) {
    console.error('Error sending task status update email:', error);
    throw new functions.https.HttpsError('internal', `Failed to send status update email: ${error.message}`);
  }
};

const getTaskCommentEmailTemplate = (data) => {
  const {
    taskTitle,
    taskDescription,
    commentAuthor,
    commentText,
    taskDueDate,
    taskPriority,
    taskStatus,
    commentDate,
  } = data;

  const formattedDueDate = new Date(taskDueDate).toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const formattedCommentDate = new Date(commentDate).toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  const priorityColor =
    taskPriority === 'High' ? '#DC2626' : taskPriority === 'Medium' ? '#F59E0B' : '#10B981';

  const statusColor =
    taskStatus === 'Completed' ? '#10B981' : taskStatus === 'In Progress' ? '#8B5CF6' : '#3B82F6';

  return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>New Task Comment - Alluwal Academy</title>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
            .container { max-width: 600px; margin: 0 auto; background-color: white; }
            .header { background: linear-gradient(135deg, #0386FF 0%, #0369C9 100%); padding: 40px 30px; text-align: center; }
            .header h1 { color: white; margin: 0; font-size: 28px; font-weight: 600; }
            .header p { color: rgba(255,255,255,0.9); margin: 10px 0 0 0; font-size: 16px; }
            .content { padding: 40px 30px; }
            .comment-card { background: #f8fafc; border-left: 4px solid #0386FF; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .task-info { background: #f1f5f9; padding: 20px; border-radius: 8px; margin: 20px 0; }
            .task-title { font-size: 20px; font-weight: 600; color: #1e293b; margin: 0 0 10px 0; }
            .task-meta { display: flex; gap: 15px; margin: 15px 0; flex-wrap: wrap; }
            .badge { padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 500; }
            .priority { background-color: ${priorityColor}; color: white; }
            .status { background-color: ${statusColor}; color: white; }
            .comment-author { font-weight: 600; color: #0386FF; margin-bottom: 8px; }
            .comment-text { font-size: 15px; line-height: 1.6; color: #374151; }
            .comment-date { font-size: 13px; color: #6b7280; margin-top: 10px; }
            .task-description { font-size: 14px; color: #6b7280; margin: 10px 0; line-height: 1.5; }
            .due-date { font-size: 14px; color: #dc2626; font-weight: 500; }
            .footer { background: #f1f5f9; padding: 30px; text-align: center; border-top: 1px solid #e2e8f0; }
            .footer p { margin: 0; color: #6b7280; font-size: 14px; }
            .logo { width: 120px; height: auto; margin-bottom: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>💬 New Task Comment</h1>
                <p>Someone commented on a task you're involved with</p>
            </div>
            
            <div class="content">
                <div class="comment-card">
                    <div class="comment-author">${commentAuthor} commented:</div>
                    <div class="comment-text">"${commentText}"</div>
                    <div class="comment-date">🕒 ${formattedCommentDate}</div>
                </div>

                <div class="task-info">
                    <div class="task-title">📋 ${taskTitle}</div>
                    ${taskDescription ? `<div class="task-description">${taskDescription}</div>` : ''}
                    
                    <div class="task-meta">
                        <span class="badge priority">🔥 ${taskPriority} Priority</span>
                        <span class="badge status">📊 ${taskStatus}</span>
                    </div>
                    
                    <div class="due-date">⏰ Due: ${formattedDueDate}</div>
                </div>

                <p style="margin-top: 30px; font-size: 15px; color: #374151;">
                    You're receiving this notification because you're either assigned to this task or created it. 
                    Log into your Alluwal Academy dashboard to view the full conversation and respond.
                </p>
            </div>
            
            <div class="footer">
                <p>
                    <strong>Alluwal Education Hub</strong><br>
                    Islamic Education Management System<br>
                    <a href="mailto:support@alluwaleducationhub.org" style="color: #0386FF;">support@alluwaleducationhub.org</a>
                </p>
            </div>
        </div>
    </body>
    </html>
  `;
};

const processTaskCommentEmailTrigger = onDocumentCreated('mail/{emailId}', async (event) => {
  const snap = event.data;
  const emailData = snap.data();

  if (emailData.template?.name !== 'task_comment_notification') {
    return null;
  }

  try {
    const transporter = createTransporter();
    const templateData = emailData.template.data;
    const recipients = emailData.to;

    console.log('Processing task comment notification for:', recipients);

    const mailOptions = {
      from: 'support@alluwaleducationhub.org',
      to: recipients.join(', '),
      subject: `💬 New comment on task: ${templateData.taskTitle}`,
      html: getTaskCommentEmailTemplate(templateData),
    };

    await transporter.sendMail(mailOptions);
    console.log('Task comment notification sent successfully to:', recipients);

    await snap.ref.update({
      delivered: true,
      deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error sending task comment notification:', error);

    await snap.ref.update({
      failed: true,
      error: error.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return null;
});

const sendTaskCommentNotification = async (request) => {
  try {
    const {taskId, commentAuthorId, commentAuthorName, commentText, commentDate} = request.data || {};

    if (!taskId || !commentAuthorId || !commentAuthorName || !commentText) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: taskId, commentAuthorId, commentAuthorName, commentText'
      );
    }

    const taskSnap = await admin.firestore().collection('tasks').doc(taskId).get();
    if (!taskSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Task not found');
    }

    const task = taskSnap.data();
    const createdBy = task.createdBy;
    const assignedToRaw = task.assignedTo;
    const assignedTo = Array.isArray(assignedToRaw) ? assignedToRaw : assignedToRaw ? [assignedToRaw] : [];

    const recipientUserIdsSet = new Set();
    if (commentAuthorId === createdBy) {
      assignedTo.forEach((uid) => recipientUserIdsSet.add(uid));
    } else if (assignedTo.includes(commentAuthorId)) {
      if (createdBy) recipientUserIdsSet.add(createdBy);
    } else {
      if (createdBy) recipientUserIdsSet.add(createdBy);
      assignedTo.forEach((uid) => recipientUserIdsSet.add(uid));
    }
    recipientUserIdsSet.delete(commentAuthorId);

    const recipientUserIds = Array.from(recipientUserIdsSet);

    if (recipientUserIds.length === 0) {
      return {success: false, reason: 'No recipients to notify'};
    }

    const recipients = [];
    const recipientNames = [];
    for (const uid of recipientUserIds) {
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data() || {};
          const email = userData['e-mail'];
          const firstName = userData.first_name || '';
          const lastName = userData.last_name || '';
          const fullName = `${firstName} ${lastName}`.trim();
          if (email) {
            recipients.push(email);
            recipientNames.push(fullName || email);
          }
        }
      } catch (err) {
        console.error('Error resolving user email for uid', uid, err);
      }
    }

    if (recipients.length === 0) {
      return {success: false, reason: 'No recipient emails found'};
    }

    const toIsoString = (ts) => {
      if (!ts) return new Date().toISOString();
      if (ts && ts.toDate) return ts.toDate().toISOString();
      if (typeof ts === 'string') return new Date(ts).toISOString();
      if (typeof ts === 'number') return new Date(ts).toISOString();
      return new Date().toISOString();
    };

    const mapPriority = (p) => {
      if (typeof p === 'string') {
        const v = p.toLowerCase();
        if (v.includes('high')) return 'High';
        if (v.includes('medium')) return 'Medium';
        return 'Low';
      }
      if (typeof p === 'number') {
        return ['Low', 'Medium', 'High'][p] || 'Medium';
      }
      return 'Medium';
    };

    const mapStatus = (s) => {
      if (typeof s === 'string') {
        const v = s.toLowerCase();
        if (v.includes('done') || v.includes('completed')) return 'Completed';
        if (v.includes('progress')) return 'In Progress';
        return 'To Do';
      }
      if (typeof s === 'number') {
        return ['To Do', 'In Progress', 'Completed'][s] || 'To Do';
      }
      return 'To Do';
    };

    const templateData = {
      taskTitle: task.title || 'Untitled Task',
      taskDescription: task.description || '',
      commentAuthor: commentAuthorName,
      commentText,
      taskDueDate: toIsoString(task.dueDate),
      taskPriority: mapPriority(task.priority),
      taskStatus: mapStatus(task.status),
      taskId,
      commentDate: commentDate || new Date().toISOString(),
      recipients: recipientNames,
    };

    const transporter = createTransporter();
    const mailOptions = {
      from: 'support@alluwaleducationhub.org',
      to: recipients.join(', '),
      subject: `💬 New comment on task: ${templateData.taskTitle}`,
      html: getTaskCommentEmailTemplate(templateData),
    };

    console.log('Sending task comment notification to:', recipients);
    await transporter.sendMail(mailOptions);
    console.log('Task comment notification sent successfully');

    return {success: true, recipients};
  } catch (error) {
    console.error('sendTaskCommentNotification error:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Unknown error');
  }
};

const sendTaskDeletionNotification = async (request) => {
  console.log('--- TASK DELETION NOTIFICATION ---');
  try {
    const {taskId, taskTitle, taskDescription, deletedByName, deletedByEmail, deletedAt} = request.data || {};

    if (!taskId || !taskTitle || !deletedByName) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: taskId, taskTitle, deletedByName'
      );
    }

    // Get all admins
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('user_type', '==', 'admin')
      .get();

    const adminEmails = [];
    adminsSnapshot.forEach(doc => {
      const data = doc.data();
      const email = data['e-mail'] || data.email;
      if (email) adminEmails.push(email);
    });

    if (adminEmails.length === 0) {
      console.log('No admins found to notify');
      return {success: true, message: 'No admins found'};
    }

    const transporter = createTransporter();
    const formattedDate = new Date(deletedAt || Date.now()).toLocaleString();

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      bcc: adminEmails.join(', '), // Use BCC for multiple recipients
      subject: `🗑️ Task Deleted: ${taskTitle}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Task Deleted</title>
        <style>
          body { font-family: Arial, sans-serif; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }
          .header { background-color: #ef4444; color: white; padding: 15px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { padding: 20px; }
          .info-box { background-color: #fef2f2; border-left: 4px solid #ef4444; padding: 15px; margin: 15px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Task Deleted</h1>
          </div>
          <div class="content">
            <p>A task has been deleted from the system.</p>
            
            <div class="info-box">
              <p><strong>Task:</strong> ${taskTitle}</p>
              <p><strong>Description:</strong> ${taskDescription || 'No description'}</p>
              <p><strong>Deleted By:</strong> ${deletedByName} (${deletedByEmail})</p>
              <p><strong>Time:</strong> ${formattedDate}</p>
            </div>

            <p>This notification is sent to all administrators for security and tracking purposes.</p>
          </div>
        </div>
      </body>
      </html>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log(`Task deletion notification sent to ${adminEmails.length} admins`);

    return {success: true, recipientCount: adminEmails.length};
  } catch (error) {
    console.error('Error sending task deletion notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};

const sendTaskEditNotification = async (request) => {
  console.log('--- TASK EDIT NOTIFICATION ---');
  try {
    const {taskId, taskTitle, changes, editedByName, editedByEmail, editedAt} = request.data || {};

    if (!taskId || !changes || !editedByName) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    // Get all admins
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('user_type', '==', 'admin')
      .get();

    const adminEmails = [];
    adminsSnapshot.forEach(doc => {
      const data = doc.data();
      const email = data['e-mail'] || data.email;
      if (email) adminEmails.push(email);
    });

    if (adminEmails.length === 0) {
      return {success: true, message: 'No admins found'};
    }

    const transporter = createTransporter();
    const formattedDate = new Date(editedAt || Date.now()).toLocaleString();

    // Format changes for email
    let changesHtml = '';
    for (const [field, values] of Object.entries(changes)) {
      const fieldName = field.charAt(0).toUpperCase() + field.slice(1);
      let oldVal = values.old;
      let newVal = values.new;

      // Format arrays (assignees)
      if (Array.isArray(oldVal)) oldVal = oldVal.join(', ') || 'None';
      if (Array.isArray(newVal)) newVal = newVal.join(', ') || 'None';

      // Format dates
      if (field === 'dueDate') {
        oldVal = new Date(oldVal).toLocaleDateString();
        newVal = new Date(newVal).toLocaleDateString();
      }

      changesHtml += `
        <div style="margin-bottom: 15px; border-bottom: 1px solid #eee; padding-bottom: 10px;">
          <strong>${fieldName}:</strong><br>
          <span style="color: #ef4444; text-decoration: line-through;">${oldVal}</span> 
          <span style="color: #6b7280;">→</span> 
          <span style="color: #10b981; font-weight: bold;">${newVal}</span>
        </div>
      `;
    }

    const mailOptions = {
      from: 'Alluwal Education Hub <support@alluwaleducationhub.org>',
      bcc: adminEmails.join(', '),
      subject: `✏️ Task Edited: ${taskTitle}`,
      html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <title>Task Edited</title>
        <style>
          body { font-family: Arial, sans-serif; background-color: #f8fafc; }
          .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }
          .header { background-color: #f59e0b; color: white; padding: 15px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { padding: 20px; }
          .info-box { background-color: #fffbeb; border-left: 4px solid #f59e0b; padding: 15px; margin: 15px 0; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Task Edited</h1>
          </div>
          <div class="content">
            <p>A task has been modified.</p>
            
            <div class="info-box">
              <p><strong>Task:</strong> ${taskTitle}</p>
              <p><strong>Edited By:</strong> ${editedByName} (${editedByEmail})</p>
              <p><strong>Time:</strong> ${formattedDate}</p>
            </div>

            <h3>Changes:</h3>
            <div style="background: #f9fafb; padding: 15px; border-radius: 8px;">
              ${changesHtml}
            </div>

            <p style="margin-top: 20px; font-size: 12px; color: #6b7280;">This notification is sent to all administrators.</p>
          </div>
        </div>
      </body>
      </html>
      `
    };

    await transporter.sendMail(mailOptions);
    console.log(`Task edit notification sent to ${adminEmails.length} admins`);

    return {success: true, recipientCount: adminEmails.length};
  } catch (error) {
    console.error('Error sending task edit notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
};

// Scheduled function to send notifications for recurring tasks (2 days before due date)
const sendRecurringTaskReminders = onSchedule('every 24 hours', async () => {
    try {
      console.log('🔔 Running recurring task reminders check...');

      const now = new Date();
      const twoDaysFromNow = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
      const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

      // Get all recurring tasks
      const recurringTasksSnapshot = await admin
        .firestore()
        .collection('tasks')
        .where('isRecurring', '==', true)
        .where('isDraft', '==', false)
        .get();

      console.log(`Found ${recurringTasksSnapshot.size} recurring tasks`);

      if (recurringTasksSnapshot.empty) {
        console.log('No recurring tasks - skipping reminders');
        return;
      }

      let remindersSent = 0;

      for (const taskDoc of recurringTasksSnapshot.docs) {
        try {
          const task = taskDoc.data();
          const taskId = taskDoc.id;
          const enhancedRecurrence = task.enhancedRecurrence || {};

          if (!enhancedRecurrence.type || enhancedRecurrence.type === 'none') {
            continue;
          }

          // Calculate next occurrences
          // Use startDate if available, otherwise use dueDate
          let baseDate = task.startDate?.toDate();
          if (!baseDate) {
            baseDate = task.dueDate?.toDate();
          }
          if (!baseDate) {
            baseDate = new Date();
          }
          
          const nextOccurrences = calculateNextOccurrences(
            enhancedRecurrence,
            baseDate,
            10 // Get next 10 occurrences to find ones 2 days away
          );

          // Check if any occurrence is due in 2 days
          for (const occurrenceDate of nextOccurrences) {
            const occurrenceTime = occurrenceDate.getTime();
            const twoDaysTime = twoDaysFromNow.getTime();
            const threeDaysTime = threeDaysFromNow.getTime();

            // Check if this occurrence is between 2-3 days from now (to avoid duplicate notifications)
            if (occurrenceTime >= twoDaysTime && occurrenceTime < threeDaysTime) {
              // Check if we already sent a reminder for this occurrence
              const reminderKey = `reminder_sent_${occurrenceDate.toISOString().split('T')[0]}`;
              if (task[reminderKey] === true) {
                console.log(`Reminder already sent for task ${taskId} occurrence ${occurrenceDate.toISOString()}`);
                continue;
              }

              // Send notifications to all assigned users
              const assignedUserIds = task.assignedTo || [];
              if (assignedUserIds.length === 0) {
                continue;
              }

              const taskTitle = task.title || 'Untitled Task';
              const taskDescription = task.description || '';
              const formattedDate = occurrenceDate.toLocaleDateString('en-US', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric',
              });

              for (const userId of assignedUserIds) {
                try {
                  const userDoc = await admin.firestore().collection('users').doc(userId).get();
                  if (!userDoc.exists) continue;

                  const userData = userDoc.data();
                  const userEmail = userData['e-mail'] || userData.email;
                  const userName = `${userData.first_name || ''} ${userData.last_name || ''}`.trim() || 'User';

                  if (!userEmail) continue;

                  // Send email notification
                  await sendTaskAssignmentEmail(
                    userEmail,
                    userName,
                    `${taskTitle} (Due in 2 days)`,
                    `This recurring task is due in 2 days on ${formattedDate}.\n\n${taskDescription}`,
                    occurrenceDate.toISOString(),
                    task.createdBy ? 'System' : 'System Administrator'
                  );

                  console.log(`✅ Reminder sent to ${userName} (${userEmail}) for task ${taskId}`);
                } catch (error) {
                  console.error(`Error sending reminder to user ${userId}:`, error);
                }
              }

              // Mark reminder as sent
              await taskDoc.ref.update({
                [reminderKey]: true,
              });

              remindersSent += assignedUserIds.length;
              console.log(`✅ Reminders sent for task ${taskId} occurrence ${occurrenceDate.toISOString()}`);
              break; // Only send one reminder per task per day
            }
          }
        } catch (error) {
          console.error(`Error processing recurring task ${taskDoc.id}:`, error);
        }
      }

      console.log(`✅ Recurring task reminders completed: ${remindersSent} reminders sent`);
    } catch (error) {
      console.error('Error in sendRecurringTaskReminders:', error);
    }
});

// Helper function to calculate next occurrences from enhanced recurrence
function calculateNextOccurrences(enhancedRecurrence, startDate, maxCount) {
  const occurrences = [];
  const now = new Date();
  let currentDate = new Date(startDate);

  // If start date is in the past, start from today
  if (currentDate < now) {
    currentDate = new Date(now);
    // Reset to start of day
    currentDate.setHours(0, 0, 0, 0);
  }

  const type = enhancedRecurrence.type;
  let endDate = null;
  if (enhancedRecurrence.endDate) {
    // Handle both Timestamp and Date objects
    if (enhancedRecurrence.endDate.toDate) {
      endDate = enhancedRecurrence.endDate.toDate();
    } else if (enhancedRecurrence.endDate instanceof Date) {
      endDate = enhancedRecurrence.endDate;
    } else {
      endDate = new Date(enhancedRecurrence.endDate);
    }
  }
  const selectedMonthDays = enhancedRecurrence.selectedMonthDays || [];
  const selectedWeekdays = enhancedRecurrence.selectedWeekdays || [];
  const selectedMonths = enhancedRecurrence.selectedMonths || [];

  let count = 0;
  let iterations = 0;
  const maxIterations = 730; // Safety limit (2 years)

  while (count < maxCount && iterations < maxIterations) {
    iterations++;

    if (endDate && currentDate > endDate) {
      break;
    }

    let shouldInclude = false;

    switch (type) {
      case 'daily':
        shouldInclude = true;
        currentDate = new Date(currentDate.getTime() + 24 * 60 * 60 * 1000);
        break;

      case 'weekly':
        // Get weekday: 1 = Monday, 7 = Sunday
        const weekday = currentDate.getDay() === 0 ? 7 : currentDate.getDay();
        if (selectedWeekdays.includes(weekday)) {
          shouldInclude = true;
        }
        currentDate = new Date(currentDate.getTime() + 24 * 60 * 60 * 1000);
        break;

      case 'monthly':
        const dayOfMonth = currentDate.getDate();
        if (selectedMonthDays.includes(dayOfMonth)) {
          shouldInclude = true;
        }
        // Move to next day
        currentDate = new Date(currentDate.getTime() + 24 * 60 * 60 * 1000);
        // If we've moved to a new month and haven't found a match, skip to next month's first selected day
        if (currentDate.getDate() === 1 && !shouldInclude && selectedMonthDays.length > 0) {
          const firstSelectedDay = Math.min(...selectedMonthDays);
          currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), firstSelectedDay);
        }
        break;

      case 'yearly':
        const month = currentDate.getMonth() + 1; // 1-12
        const dayOfYear = currentDate.getDate();
        if (selectedMonths.includes(month)) {
          // For yearly, we need to check if this matches the original day
          // For simplicity, include if month matches (you may want to refine this)
          shouldInclude = true;
        }
        currentDate = new Date(currentDate.getTime() + 24 * 60 * 60 * 1000);
        break;

      default:
        return occurrences;
    }

    if (shouldInclude && currentDate >= now) {
      occurrences.push(new Date(currentDate));
      count++;
    }
  }

  return occurrences;
}

module.exports = {
  sendTaskAssignmentNotification,
  sendTaskStatusUpdateNotification,
  getTaskCommentEmailTemplate,
  processTaskCommentEmail: processTaskCommentEmailTrigger,
  sendTaskCommentNotification,
  sendTaskDeletionNotification,
  sendTaskEditNotification,
  sendRecurringTaskReminders,
};

