# Daily Limit Reached Error - Troubleshooting Guide

## Error Description
When running scripts or creating shifts, you may see "daily limit reached" errors. This guide explains the causes and solutions.

## Possible Causes

### 1. Firebase/Google Cloud Quotas

**Cloud Tasks Quotas:**
- Free tier: 1 million task creations per day
- Blaze plan: 100 million tasks per day
- Check quota: https://console.cloud.google.com/cloudtasks/usage?project=alluwal-academy

**Cloud Functions Quotas:**
- Free tier: 2 million invocations/month
- Read/write operations count toward quotas
- Check quota: https://console.cloud.google.com/functions?project=alluwal-academy

**Firestore Quotas:**
- Free tier: 50K reads, 20K writes, 20K deletes per day
- Blaze plan: Pay as you go (much higher limits)
- Check usage: https://console.firebase.google.com/project/alluwal-academy/firestore/usage

### 2. Script Running Too Many Operations

When running fix/cleanup scripts, they may:
- Read all documents in a collection
- Update many documents in a loop
- Hit daily quotas quickly

## Solutions

### Solution 1: Check Firebase Plan
1. Go to: https://console.firebase.google.com/project/alluwal-academy/settings/billing
2. Verify you're on the Blaze (pay-as-you-go) plan
3. If on free tier (Spark), upgrade to Blaze for higher limits

### Solution 2: Wait Until Quota Resets
- Firebase quotas reset daily at midnight Pacific Time
- Wait until the next day to continue operations

### Solution 3: Run Scripts in Batches
Instead of processing all documents at once, process in smaller batches:

```bash
# Instead of
node scripts/verify_stats_consistency.js

# Use batch mode with specific teacher
node scripts/verify_stats_consistency.js --teacher=TEACHER_ID_HERE
```

### Solution 4: Check Cloud Console for Specific Quotas
1. Open Google Cloud Console: https://console.cloud.google.com
2. Navigate to: IAM & Admin > Quotas
3. Filter by service to see which quota was exceeded
4. Request quota increase if needed

## Monitoring Usage

### View Firestore Usage
```bash
# In Firebase Console
# Firestore > Usage tab
```

### View Cloud Functions Usage
```bash
# Check logs for errors
firebase functions:log --limit 100
```

### View Cloud Tasks Usage
```bash
# List tasks in queue
gcloud tasks queues describe shift-lifecycle-queue \
  --location=northamerica-northeast1 \
  --project=alluwal-academy
```

## Preventing Future Issues

### 1. Add Rate Limiting to Scripts
```javascript
// Add delay between operations
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

for (const doc of docs) {
  await processDocument(doc);
  await delay(100); // 100ms delay between operations
}
```

### 2. Process in Smaller Batches
```javascript
const BATCH_SIZE = 100;
for (let i = 0; i < docs.length; i += BATCH_SIZE) {
  const batch = docs.slice(i, i + BATCH_SIZE);
  await processBatch(batch);
  console.log(`Processed ${i + BATCH_SIZE} of ${docs.length}`);
}
```

### 3. Use Firestore Batched Writes
```javascript
const batch = db.batch();
let count = 0;
const MAX_BATCH = 500;

for (const doc of docs) {
  batch.update(doc.ref, updateData);
  count++;
  
  if (count >= MAX_BATCH) {
    await batch.commit();
    batch = db.batch();
    count = 0;
  }
}

if (count > 0) {
  await batch.commit();
}
```

## When to Contact Support

If you've verified:
- You're on the Blaze plan
- The quota shouldn't be exceeded
- The error persists after reset

Contact Firebase support at: https://firebase.google.com/support

## Related Scripts

These scripts are designed with quota-awareness:

1. `scripts/verify_stats_consistency.js` - Run with `--teacher=ID` for smaller scope
2. `scripts/fix_timesheets_pay_and_status.js` - Use `--dry-run` first
3. `scripts/cleanup_orphaned_timesheets.js` - Processes in batches

## Quick Links

- [Firebase Console](https://console.firebase.google.com/project/alluwal-academy)
- [Cloud Console Quotas](https://console.cloud.google.com/iam-admin/quotas?project=alluwal-academy)
- [Cloud Tasks](https://console.cloud.google.com/cloudtasks?project=alluwal-academy)
- [Cloud Functions](https://console.cloud.google.com/functions?project=alluwal-academy)

