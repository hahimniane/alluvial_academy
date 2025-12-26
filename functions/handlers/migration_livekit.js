/**
 * LiveKit Migration Script
 * 
 * Migrates all current and scheduled shifts from Zoom to LiveKit.
 * Only affects shifts that haven't started yet or are currently active.
 * Does NOT affect completed, missed, or cancelled shifts.
 */

const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

/**
 * HTTP endpoint to migrate shifts to LiveKit.
 * 
 * This is a one-time migration script that:
 * 1. Finds all shifts with status 'scheduled' or 'active'
 * 2. Filters to shifts where shift_start is today or in the future
 * 3. Updates video_provider to 'livekit' and sets livekit_room_name
 * 
 * Usage: GET /migrateShiftsToLiveKit?dryRun=true (preview mode)
 *        GET /migrateShiftsToLiveKit?dryRun=false (execute migration)
 */
const migrateShiftsToLiveKit = onRequest({
  cors: true,
  timeoutSeconds: 540, // 9 minutes for large migrations
}, async (req, res) => {
  const startTime = Date.now();
  const dryRun = req.query.dryRun !== 'false'; // Default to dry run for safety
  
  console.log(`[Migration] Starting LiveKit migration (dryRun: ${dryRun})`);
  
  const results = {
    dryRun,
    totalShiftsScanned: 0,
    shiftsToMigrate: 0,
    shiftsSkipped: 0,
    shiftsSuccessfullyMigrated: 0,
    shiftsFailed: 0,
    errors: [],
    migratedShiftIds: [],
    skippedReasons: {},
  };

  try {
    const db = admin.firestore();
    const shiftsRef = db.collection('teaching_shifts');
    
    // Get current timestamp for comparison
    const now = new Date();
    // Set to start of today (midnight) to include today's shifts
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayStartTimestamp = admin.firestore.Timestamp.fromDate(todayStart);
    
    console.log(`[Migration] Current time: ${now.toISOString()}`);
    console.log(`[Migration] Today start: ${todayStart.toISOString()}`);

    // Query all shifts - we'll filter in code for more control
    // This approach is safer as it handles edge cases
    const snapshot = await shiftsRef.get();
    results.totalShiftsScanned = snapshot.size;
    
    console.log(`[Migration] Found ${snapshot.size} total shifts`);

    // Process each shift
    const batch = db.batch();
    let batchCount = 0;
    const MAX_BATCH_SIZE = 500; // Firestore batch limit
    
    const shiftsToProcess = [];
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const shiftId = doc.id;
      
      // Skip check: already using LiveKit
      if (data.video_provider === 'livekit') {
        results.shiftsSkipped++;
        results.skippedReasons['already_livekit'] = (results.skippedReasons['already_livekit'] || 0) + 1;
        continue;
      }
      
      // Skip check: status is not scheduled or active
      const status = data.status;
      const validStatuses = ['scheduled', 'active', 'in_progress'];
      if (!validStatuses.includes(status)) {
        results.shiftsSkipped++;
        results.skippedReasons[`status_${status}`] = (results.skippedReasons[`status_${status}`] || 0) + 1;
        continue;
      }
      
      // Skip check: shift has already ended (shift_end is in the past)
      const shiftEnd = data.shift_end?.toDate();
      if (shiftEnd && shiftEnd < now) {
        results.shiftsSkipped++;
        results.skippedReasons['already_ended'] = (results.skippedReasons['already_ended'] || 0) + 1;
        continue;
      }
      
      // This shift qualifies for migration
      shiftsToProcess.push({
        id: shiftId,
        ref: doc.ref,
        data: data,
        shiftStart: data.shift_start?.toDate(),
        shiftEnd: shiftEnd,
        teacherName: data.teacher_name,
        currentProvider: data.video_provider || 'zoom',
      });
    }
    
    results.shiftsToMigrate = shiftsToProcess.length;
    console.log(`[Migration] ${shiftsToProcess.length} shifts qualify for migration`);
    
    if (dryRun) {
      // In dry run mode, just report what would be migrated
      results.migratedShiftIds = shiftsToProcess.map(s => ({
        id: s.id,
        teacherName: s.teacherName,
        shiftStart: s.shiftStart?.toISOString(),
        shiftEnd: s.shiftEnd?.toISOString(),
        currentProvider: s.currentProvider,
      }));
      
      res.status(200).json({
        success: true,
        message: `DRY RUN: Would migrate ${shiftsToProcess.length} shifts to LiveKit`,
        results,
        durationMs: Date.now() - startTime,
      });
      return;
    }
    
    // Execute migration in batches
    for (const shift of shiftsToProcess) {
      try {
        const updateData = {
          video_provider: 'livekit',
          livekit_room_name: `shift_${shift.id}`,
          // Keep zoom fields intact in case we need to revert
          // but they won't be used when video_provider is 'livekit'
        };
        
        batch.update(shift.ref, updateData);
        batchCount++;
        results.migratedShiftIds.push(shift.id);
        
        // Commit batch if we hit the limit
        if (batchCount >= MAX_BATCH_SIZE) {
          console.log(`[Migration] Committing batch of ${batchCount} updates...`);
          await batch.commit();
          batchCount = 0;
        }
        
        results.shiftsSuccessfullyMigrated++;
      } catch (error) {
        results.shiftsFailed++;
        results.errors.push({
          shiftId: shift.id,
          error: error.message,
        });
        console.error(`[Migration] Error migrating shift ${shift.id}:`, error);
      }
    }
    
    // Commit remaining batch
    if (batchCount > 0) {
      console.log(`[Migration] Committing final batch of ${batchCount} updates...`);
      await batch.commit();
    }
    
    const durationMs = Date.now() - startTime;
    console.log(`[Migration] Completed in ${durationMs}ms`);
    console.log(`[Migration] Migrated: ${results.shiftsSuccessfullyMigrated}, Failed: ${results.shiftsFailed}`);
    
    res.status(200).json({
      success: true,
      message: `Migration complete. Migrated ${results.shiftsSuccessfullyMigrated} shifts to LiveKit.`,
      results,
      durationMs,
    });
    
  } catch (error) {
    console.error('[Migration] Fatal error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      results,
      durationMs: Date.now() - startTime,
    });
  }
});

/**
 * Revert migration - switches shifts back to Zoom if needed.
 * 
 * Usage: GET /revertLiveKitMigration?dryRun=true (preview mode)
 *        GET /revertLiveKitMigration?dryRun=false&shiftIds=id1,id2,id3 (execute revert)
 */
const revertLiveKitMigration = onRequest({
  cors: true,
  timeoutSeconds: 540,
}, async (req, res) => {
  const startTime = Date.now();
  const dryRun = req.query.dryRun !== 'false';
  const shiftIdsParam = req.query.shiftIds;
  
  // If specific shift IDs provided, only revert those
  const specificShiftIds = shiftIdsParam 
    ? shiftIdsParam.split(',').map(id => id.trim()).filter(Boolean)
    : null;
  
  console.log(`[Revert] Starting LiveKit revert (dryRun: ${dryRun})`);
  if (specificShiftIds) {
    console.log(`[Revert] Reverting specific shifts: ${specificShiftIds.join(', ')}`);
  }
  
  const results = {
    dryRun,
    totalShiftsScanned: 0,
    shiftsToRevert: 0,
    shiftsReverted: 0,
    errors: [],
  };

  try {
    const db = admin.firestore();
    const shiftsRef = db.collection('teaching_shifts');
    
    let query;
    if (specificShiftIds && specificShiftIds.length > 0) {
      // Firestore 'in' query has a limit of 30 items
      // For simplicity, we'll fetch each individually
      const docs = [];
      for (const id of specificShiftIds) {
        const doc = await shiftsRef.doc(id).get();
        if (doc.exists) {
          docs.push(doc);
        }
      }
      results.totalShiftsScanned = docs.length;
      
      const shiftsToRevert = docs.filter(doc => doc.data().video_provider === 'livekit');
      results.shiftsToRevert = shiftsToRevert.length;
      
      if (dryRun) {
        res.status(200).json({
          success: true,
          message: `DRY RUN: Would revert ${shiftsToRevert.length} shifts back to Zoom`,
          results,
          shiftIds: shiftsToRevert.map(d => d.id),
        });
        return;
      }
      
      const batch = db.batch();
      for (const doc of shiftsToRevert) {
        batch.update(doc.ref, {
          video_provider: 'zoom',
          // Keep livekit_room_name for reference
        });
        results.shiftsReverted++;
      }
      await batch.commit();
      
    } else {
      // Revert ALL LiveKit shifts (use with caution)
      const snapshot = await shiftsRef.where('video_provider', '==', 'livekit').get();
      results.totalShiftsScanned = snapshot.size;
      results.shiftsToRevert = snapshot.size;
      
      if (dryRun) {
        res.status(200).json({
          success: true,
          message: `DRY RUN: Would revert ${snapshot.size} shifts back to Zoom`,
          results,
          shiftIds: snapshot.docs.map(d => d.id),
        });
        return;
      }
      
      const batch = db.batch();
      let batchCount = 0;
      
      for (const doc of snapshot.docs) {
        batch.update(doc.ref, {
          video_provider: 'zoom',
        });
        batchCount++;
        results.shiftsReverted++;
        
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
    }
    
    res.status(200).json({
      success: true,
      message: `Reverted ${results.shiftsReverted} shifts back to Zoom`,
      results,
      durationMs: Date.now() - startTime,
    });
    
  } catch (error) {
    console.error('[Revert] Error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      results,
    });
  }
});

module.exports = {
  migrateShiftsToLiveKit,
  revertLiveKitMigration,
};

