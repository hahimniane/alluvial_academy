const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {generateRandomPassword} = require('../utils/password');
const {sendStudentNotificationEmail} = require('../services/email/senders');

const normalizeString = (str) =>
  str
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '')
    .substring(0, 10);

const generateStudentCode = (firstName, lastName) => {
  const firstNormalized = normalizeString(firstName);
  const lastNormalized = normalizeString(lastName);
  return `${firstNormalized}.${lastNormalized}`;
};

const createStudentAccount = async (data) => {
  console.log('--- CREATE STUDENT ACCOUNT ---');
  console.log('Raw data received:', data);

  try {
    if (!data || typeof data !== 'object') {
      console.error('Invalid data received:', data);
      throw new functions.https.HttpsError('invalid-argument', 'Data must be an object');
    }

    const studentData = data.data || data;
    console.log('Using studentData:', JSON.stringify(studentData, null, 2));

    const {
      firstName,
      lastName,
      isAdultStudent,
      guardianIds,
      phoneNumber,
      email,
      address,
      emergencyContact,
      notes,
    } = studentData;

    console.log('Extracted fields:', {
      firstName: firstName || 'MISSING',
      lastName: lastName || 'MISSING',
      isAdultStudent: isAdultStudent !== undefined ? isAdultStudent : 'MISSING',
      guardianIds: guardianIds || 'OPTIONAL',
      phoneNumber: phoneNumber || 'OPTIONAL',
      email: email || 'OPTIONAL',
      address: address || 'OPTIONAL',
      emergencyContact: emergencyContact || 'OPTIONAL',
      notes: notes || 'OPTIONAL',
    });

    const missingFields = [];
    if (!firstName || String(firstName).trim() === '') missingFields.push('firstName');
    if (!lastName || String(lastName).trim() === '') missingFields.push('lastName');
    if (isAdultStudent === undefined || isAdultStudent === null) missingFields.push('isAdultStudent');

    if (missingFields.length > 0) {
      console.error('Missing required fields:', missingFields);
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Missing required fields: ${missingFields.join(', ')}`
      );
    }

    console.log('All required fields validated successfully');

    let studentCode;
    let attempts = 0;
    const maxAttempts = 10;

    do {
      const baseStudentCode = generateStudentCode(firstName, lastName);
      studentCode = attempts === 0 ? baseStudentCode : `${attempts}${baseStudentCode}`;
      attempts += 1;

      const existingQuery = await admin
        .firestore()
        .collection('users')
        .where('student_code', '==', studentCode)
        .limit(1)
        .get();

      if (existingQuery.empty) {
        break;
      }

      if (attempts >= maxAttempts) {
        throw new functions.https.HttpsError(
          'internal',
          'Failed to generate unique Student ID after multiple attempts'
        );
      }
    } while (attempts < maxAttempts);

    console.log(`Generated unique Student ID: ${studentCode}`);

    const aliasEmail = `${studentCode}@alluwaleducationhub.org`;
    const tempPassword = generateRandomPassword();

    console.log(`Creating Firebase Auth user with alias email: ${aliasEmail}`);

    const userRecord = await admin.auth().createUser({
      email: aliasEmail,
      password: tempPassword,
      displayName: `${firstName} ${lastName}`,
      emailVerified: false,
    });

    const authUserId = userRecord.uid;
    console.log(`Auth user created with UID: ${authUserId}`);

    const firestoreUserData = {
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      'e-mail': email || aliasEmail,
      user_type: 'student',
      student_code: studentCode,
      is_adult_student: isAdultStudent,
      phone_number: phoneNumber || '',
      address: address || '',
      emergency_contact: emergencyContact || '',
      guardian_ids: guardianIds || [],
      notes: notes || '',
      date_added: admin.firestore.FieldValue.serverTimestamp(),
      last_login: null,
      is_active: true,
      email_verified: false,
      uid: authUserId,
      created_by_admin: true,
      password_reset_required: true,
      temp_password: tempPassword,
    };

    await admin.firestore().collection('users').doc(authUserId).set(firestoreUserData);
    console.log(`User document created for Student ID: ${studentCode}`);

    const studentDocData = {
      student_code: studentCode,
      auth_user_id: authUserId,
      first_name: firstName.trim(),
      last_name: lastName.trim(),
      is_adult_student: isAdultStudent,
      guardian_ids: guardianIds || [],
      phone_number: phoneNumber || '',
      email: email || aliasEmail,
      address: address || '',
      emergency_contact: emergencyContact || '',
      notes: notes || '',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      is_active: true,
    };

    await admin.firestore().collection('students').doc(authUserId).set(studentDocData);
    console.log('Student document created in students collection');

    let guardianEmails = [];
    console.log('=== GUARDIAN PROCESSING DEBUG ===');
    console.log(`Guardian IDs received: ${JSON.stringify(guardianIds)}`);
    console.log(`Guardian IDs type: ${typeof guardianIds}`);
    console.log(`Guardian IDs is array: ${Array.isArray(guardianIds)}`);
    console.log(`Guardian IDs length: ${guardianIds ? guardianIds.length : 'null/undefined'}`);

    if (guardianIds && Array.isArray(guardianIds) && guardianIds.length > 0) {
      const batch = admin.firestore().batch();
      console.log(`Processing ${guardianIds.length} guardian(s)...`);

      for (const guardianId of guardianIds) {
        console.log(`\n--- Processing guardian ID: ${guardianId} ---`);
        const guardianRef = admin.firestore().collection('users').doc(guardianId);

        try {
          const guardianDoc = await guardianRef.get();
          console.log(`Guardian document exists: ${guardianDoc.exists}`);

          if (guardianDoc.exists) {
            const guardianData = guardianDoc.data();
            console.log('Guardian data:', JSON.stringify(guardianData, null, 2));

            const guardianEmail = guardianData['e-mail'] || guardianData.email;
            const guardianName = `${guardianData.first_name || ''} ${
              guardianData.last_name || ''
            }`.trim() || 'Guardian';

            console.log(`Extracted guardian email: ${guardianEmail}`);
            console.log(`Extracted guardian name: ${guardianName}`);

            if (guardianEmail) {
              guardianEmails.push({
                email: guardianEmail,
                name: guardianName,
              });
              console.log('✅ Added guardian email to notification list');
            } else {
              console.log(`❌ No email found for guardian ${guardianId}`);
            }
          } else {
            console.log(`❌ Guardian document ${guardianId} does not exist`);
          }
        } catch (error) {
          console.error(`❌ Error getting guardian ${guardianId} data:`, error);
        }

        batch.update(guardianRef, {
          children_ids: admin.firestore.FieldValue.arrayUnion(authUserId),
        });
        console.log("Added student to guardian's children_ids array");
      }

      await batch.commit();
      console.log(`Updated ${guardianIds.length} guardian documents with new student`);
    } else {
      console.log('⚠️ No guardian IDs to process (empty, null, or not an array)');
    }

    console.log('=== GUARDIAN PROCESSING SUMMARY ===');
    console.log(`Guardian emails collected: ${guardianEmails.length}`);
    console.log('Guardian emails list:', JSON.stringify(guardianEmails, null, 2));
    console.log('=== END GUARDIAN DEBUG ===\n');

    let emailsSent = 0;
    console.log('=== EMAIL NOTIFICATION DEBUG ===');
    console.log(`Guardian emails found: ${guardianEmails.length}`);
    console.log('Guardian emails array:', JSON.stringify(guardianEmails, null, 2));
    console.log(`isAdultStudent: ${isAdultStudent}`);

    if (guardianEmails.length > 0) {
      const studentEmailData = {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        studentCode,
        email: email || aliasEmail,
        phoneNumber,
        isAdultStudent,
      };

      const credentials = {
        email: email || aliasEmail,
        tempPassword,
      };

      console.log('Student data for email:', JSON.stringify(studentEmailData, null, 2));
      console.log('Credentials for email:', {email: credentials.email, tempPassword: '[HIDDEN]'});

      for (const guardian of guardianEmails) {
        console.log('\n--- Attempting to send email to guardian ---');
        console.log(`Guardian name: ${guardian.name}`);
        console.log(`Guardian email: ${guardian.email}`);

        try {
          const emailSent = await sendStudentNotificationEmail(
            guardian.email,
            guardian.name,
            studentEmailData,
            credentials
          );
          console.log(`Email send result: ${emailSent}`);

          if (emailSent) {
            emailsSent += 1;
            console.log(`✅ Student notification email sent to ${guardian.name} (${guardian.email})`);
          } else {
            console.log(
              `❌ Failed to send email to ${guardian.name} (${guardian.email}) - sendStudentNotificationEmail returned false`
            );
          }
        } catch (error) {
          console.error(
            `❌ Exception while sending student notification email to ${guardian.email}:`,
            error
          );
          console.error('Error stack:', error.stack);
        }
      }
    } else {
      console.log('⚠️ No guardian emails found - skipping email notifications');
      if (guardianIds && guardianIds.length > 0) {
        console.log(`Guardian IDs were provided: ${JSON.stringify(guardianIds)}`);
        console.log('But no valid email addresses were found for these guardians');
      } else {
        console.log('No guardian IDs were provided in the request');
      }
    }

    console.log('=== EMAIL NOTIFICATION SUMMARY ===');
    console.log(`Total guardian emails: ${guardianEmails.length}`);
    console.log(`Emails sent successfully: ${emailsSent}`);
    console.log('=== END EMAIL DEBUG ===\n');

    return {
      success: true,
      studentId: authUserId,
      studentCode,
      aliasEmail,
      tempPassword,
      message: 'Student account created successfully',
      isAdultStudent,
      guardiansUpdated: guardianIds ? guardianIds.length : 0,
      emailsToGuardians: guardianEmails.length,
      emailsSent,
    };
  } catch (error) {
    console.error('--- FULL FUNCTION ERROR ---');
    console.error('ERROR MESSAGE:', error.message);
    console.error('ERROR STACK:', error.stack);
    throw new functions.https.HttpsError('internal', error.message, error.stack);
  }
};

module.exports = {
  createStudentAccount,
};

