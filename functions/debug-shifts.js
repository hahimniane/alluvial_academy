const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

async function checkRecentShifts() {
    const shiftIds = ['Til6da36gRut3jgJPdzT', 's0YEHzBlLYDbs7Hh7RW8', 'XaFXFxm4Wx2b8TfZ4ibU'];
    console.log(`Fetching shifts: ${shiftIds.join(', ')}...`);

    for (const id of shiftIds) {
        const doc = await db.collection('teaching_shifts').doc(id).get();
        if (!doc.exists) {
            console.log(`\nShift ${id}: NOT FOUND`);
            continue;
        }
        const data = doc.data();
        console.log(`\nShift ID: ${doc.id}`);
        console.log(`Teacher: ${data.teacher_name || data.teacher_id}`);
        console.log(`Start (UTC): ${data.shift_start?.toDate().toISOString()}`);
        console.log(`End (UTC):   ${data.shift_end?.toDate().toISOString()}`);
        console.log(`Host Email: ${data.zoom_host_email}`);
        console.log(`Meeting ID: ${data.zoom_meeting_id}`);
        console.log(`Zoom URL:   ${data.zoom_encrypted_join_url ? 'Yes' : 'No'}`);
        console.log(`Status: ${data.status}`);
        console.log(`Created At: ${data.created_at?.toDate().toISOString()}`);
        console.log(`Zoom Error: ${data.zoom_error || 'None'}`);
    }
}

checkRecentShifts().catch(console.error);
