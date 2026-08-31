const DEFAULT_BATCH_SIZE = 5;
const DEFAULT_DELAY_MS = 1000;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Sends `sendFn(item)` for every item in `items`, in small concurrent
 * batches with a delay between batches, instead of firing every email at
 * once. Shared SMTP hosts (e.g. Hostinger) rate-limit/flag bursts of
 * simultaneous connections from one mailbox, which is what this avoids.
 *
 * A single recipient's failure never stops the rest of the batch — each
 * result is returned as { item, ok, error } so callers can log/report
 * per-recipient failures the same way Promise.all(...) callers did before.
 */
async function sendEmailBatch(
  items,
  sendFn,
  { batchSize = DEFAULT_BATCH_SIZE, delayMs = DEFAULT_DELAY_MS } = {}
) {
  const results = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(async (item) => {
        try {
          await sendFn(item);
          return { item, ok: true };
        } catch (error) {
          return { item, ok: false, error };
        }
      })
    );
    results.push(...batchResults);
    if (i + batchSize < items.length) {
      await sleep(delayMs);
    }
  }
  return results;
}

module.exports = { sendEmailBatch, sleep };
