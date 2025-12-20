# Cloud Tasks Queue Setup Guide

## Problem
You're getting this error when creating shifts:
```
Cloud Tasks queue not found or permission denied. Queue: shift-lifecycle-queue in northamerica-northeast1
```

This happens because the Cloud Tasks queue hasn't been created yet.

## Solution

You need to create the `shift-lifecycle-queue` in Google Cloud Console.

### Option 1: Google Cloud Console (Recommended - No CLI needed)

1. **Open Google Cloud Console**
   - Go to: https://console.cloud.google.com/cloudtasks
   - Make sure you're in the **alluwal-academy** project (top bar)

2. **Create the Queue**
   - Click **"CREATE QUEUE"** button
   - Fill in the details:
     - **Name:** `shift-lifecycle-queue`
     - **Region:** `northamerica-northeast1` (must match exactly!)
     - **Max dispatches per second:** `10`
     - **Max concurrent dispatches:** `10`
     - **Max attempts:** `3`
     - **Min backoff:** `60s`
     - **Max backoff:** `3600s`
   - Click **CREATE**

3. **Wait 1-2 minutes** for the queue to initialize

4. **Try creating a shift again** - it should work now!

### Option 2: Using gcloud CLI (If you have it installed)

Run these commands in your terminal:

```bash
# Create the queue
gcloud tasks queues create shift-lifecycle-queue \
  --location=northamerica-northeast1 \
  --project=alluwal-academy \
  --max-dispatches-per-second=10 \
  --max-concurrent-dispatches=10 \
  --max-attempts=3 \
  --min-backoff=60s \
  --max-backoff=3600s

# Verify it was created
gcloud tasks queues describe shift-lifecycle-queue \
  --location=northamerica-northeast1 \
  --project=alluwal-academy
```

### Option 3: Install gcloud CLI (If not installed)

**macOS:**
```bash
# Using Homebrew
brew install google-cloud-sdk

# Or download from:
# https://cloud.google.com/sdk/docs/install
```

**After installing, authenticate:**
```bash
gcloud auth login
gcloud config set project alluwal-academy
```

Then use the commands from Option 2.

## Verifying the Queue Exists

After creating the queue, verify it exists:

### Via Console:
- Go to: https://console.cloud.google.com/cloudtasks
- You should see `shift-lifecycle-queue` in the list
- Region should show: `northamerica-northeast1`
- State should show: **Enabled** (green)

### Via gcloud CLI:
```bash
gcloud tasks queues list --location=northamerica-northeast1 --project=alluwal-academy
```

## Permissions

The queue should automatically grant the necessary permissions to your Cloud Functions service account:
- Service Account: `554077757249-compute@developer.gserviceaccount.com`
- Required Role: **Cloud Tasks Enqueuer**

If you still get permission errors after creating the queue:

1. Go to: https://console.cloud.google.com/iam-admin/iam?project=alluwal-academy
2. Find the service account: `554077757249-compute@developer.gserviceaccount.com`
3. Click **EDIT** (pencil icon)
4. Click **ADD ANOTHER ROLE**
5. Search for and add: **Cloud Tasks Enqueuer**
6. Click **SAVE**

## How Shift Lifecycle Works

Once the queue is set up, here's what happens:

1. **Admin creates a shift** in the Flutter app
2. Flutter calls `scheduleShiftLifecycle` Cloud Function
3. Cloud Function creates 2 Cloud Tasks:
   - **Start Task** - Scheduled for shift start time → calls `handleShiftStartTask`
   - **End Task** - Scheduled for shift end time → calls `handleShiftEndTask`
4. At shift start time:
   - Task executes → `handleShiftStartTask` runs
   - Sets shift status to `active`
5. At shift end time:
   - Task executes → `handleShiftEndTask` runs
   - Auto-clocks out teacher if they forgot
   - Calculates worked minutes
   - Sets shift status to `fullyCompleted`, `partiallyCompleted`, or `missed`

## Troubleshooting

### "Queue does not exist" after creating it
- Wait 1-2 minutes for initialization
- Refresh the Cloud Console page
- Verify the region is exactly `northamerica-northeast1`

### "Permission denied"
- Check IAM permissions (see Permissions section above)
- Make sure the service account has Cloud Tasks Enqueuer role

### "Wrong region" or region mismatch
The queue MUST be in `northamerica-northeast1`. If you created it in a different region:
1. Delete the incorrectly placed queue
2. Create a new one in `northamerica-northeast1`

### Still not working?
Check Cloud Functions logs:
```bash
firebase functions:log --only scheduleShiftLifecycle
```

Look for lines starting with `[DEBUG]` or `[ERROR]` for detailed error messages.

## Environment Variables (Already Configured)

These are set in `functions/services/tasks/config.js`:
- `TASKS_LOCATION`: `northamerica-northeast1`
- `SHIFT_TASK_QUEUE`: `shift-lifecycle-queue`
- `PROJECT_ID`: Auto-detected from Firebase
- `FUNCTION_REGION`: `us-central1`

No changes needed to the code!

## Next Steps

After creating the queue:

1. ✅ Create the Cloud Tasks queue (Option 1 or 2 above)
2. ✅ Wait 1-2 minutes for initialization
3. ✅ Try creating a shift in your app
4. ✅ Verify in Firebase Console that the shift was created with status `scheduled`
5. ✅ Check that the shift transitions to `active` at start time
6. ✅ Check that the shift transitions to completed status at end time

---

**Quick Link:** https://console.cloud.google.com/cloudtasks/queue/create?project=alluwal-academy&queueId=shift-lifecycle-queue&region=northamerica-northeast1

