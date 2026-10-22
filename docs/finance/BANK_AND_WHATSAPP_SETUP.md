# Bank deposits and WhatsApp payment proofs: owner setup

Both features are built, tested with sample data, and **switched off** until
Alluwal opens the accounts below. With no keys saved, the Bank deposits page
shows "Not connected", the daily sync and both webhooks do nothing, and no
error is raised. Nothing here can move money: Plaid is read-only, and a
screenshot never marks an invoice paid. An admin confirms every match.

| Part | What it does |
|---|---|
| Plaid | Reads the bank's transactions once a day (and when Plaid pings the webhook, and when an admin presses "Check the bank now"). Zelle deposits are matched to invoices as suggestions. |
| WhatsApp | A parent sends the Zelle screenshot to the Alluwal WhatsApp number. The picture is stored, read by Gemini (amount, date, sender, confirmation number), tied to the parent by phone number, and matched to the bank deposit when it arrives. |
| Admin | Confirms a match on Finance → Bank deposits. Only then are payments recorded (method Zelle, reference = the bank transaction id). |

Costs and approval rules change. **Confirm current pricing and requirements on
Plaid's and Meta's own pages before applying.** As a rough guide only: Plaid
charges for Transactions per connected account once in Production; Meta charges
per message under the WhatsApp Business Platform price list (a reply sent
inside 24 hours of the parent's message is a customer-service reply and needs
no template); Gemini reading a screenshot costs a fraction of a cent and uses
the Gemini key the AI tutor already has.

---

## 1. Plaid (the bank connection)

1. Create an account at <https://dashboard.plaid.com> with Alluwal's company
   details.
2. **Apply for Production access** (Dashboard → request production access).
   Choose the **Transactions** product only. You describe the use ("a school
   reading its own business checking account to match tuition deposits"), give
   company information and answer Plaid's security questionnaire. Some banks
   (for example Chase) also need an OAuth-institution approval inside the same
   application; Plaid shows the status per bank.
3. While Production is pending, try everything in **Sandbox** (see "Testing").
4. Developers → Keys: copy the **client_id** and the **secret** for the
   environment you use (the secret differs between Sandbox and Production).
5. Save them as Firebase secrets. Run each line and paste the value when asked:

   ```
   firebase functions:secrets:set PLAID_CLIENT_ID --project alluwal-academy
   firebase functions:secrets:set PLAID_SECRET    --project alluwal-academy
   firebase functions:secrets:set PLAID_ENV       --project alluwal-academy   # sandbox or production
   ```

6. Let the functions read them (see "How the secrets are read"). Run once,
   after the secrets of both sections exist (skip names you have not created):

   ```
   for NAME in PLAID_CLIENT_ID PLAID_SECRET PLAID_ENV PLAID_WEBHOOK_URL \
               WHATSAPP_TOKEN WHATSAPP_PHONE_NUMBER_ID WHATSAPP_VERIFY_TOKEN WHATSAPP_APP_SECRET; do
     gcloud secrets add-iam-policy-binding $NAME --project alluwal-academy \
       --member="serviceAccount:554077757249-compute@developer.gserviceaccount.com" \
       --role="roles/secretmanager.secretAccessor"
   done
   ```

   (`554077757249` is the project number. If the functions run as a different
   service account, see Cloud Run → a finance function → Security, and use that
   address.)
7. **Webhook URL.** After the functions are deployed, find the address of
   `plaidWebhook` (Firebase console → Functions, or `firebase functions:list`;
   it looks like `https://plaidwebhook-xxxx-uc.a.run.app`) and save it:

   ```
   firebase functions:secrets:set PLAID_WEBHOOK_URL --project alluwal-academy
   ```

   The app hands this address to Plaid when the bank is connected, so Plaid
   pings it when new transactions are ready. Without it, the daily 6:00 AM
   (New York) sync and the "Check the bank now" button still work.
8. In the app: **Finance → Bank deposits → Connect your bank**. Choose the
   Alluwal business checking account in Plaid's window. The first sync runs
   straight away.

How the webhook is checked: Plaid signs every webhook with an ES256 JWT in the
`Plaid-Verification` header. The function fetches Plaid's public key for that
token, verifies the signature, rejects anything older than five minutes, and
checks that the token's `request_body_sha256` equals the SHA-256 of the body it
received. There is no shared secret in the URL.

If the bank asks Alluwal to sign in again, the page says so; reconnect from the
same button (the app asks Plaid for its repair mode).

## 2. WhatsApp (payment proofs)

1. **Meta Business verification.** At <https://business.facebook.com> →
   Settings → Security Center, verify Alluwal as a business (legal name,
   address, documents).
2. **Create the app.** At <https://developers.facebook.com> → Create app → type
   **Business** → add the **WhatsApp** product and attach it to the verified
   business. This creates a WhatsApp Business Account.
3. **Add the Alluwal number.** WhatsApp → API Setup → Add phone number.
   - If the number is on the **WhatsApp Business app** today, use Meta's
     *coexistence* option (connect an existing Business-app number during
     setup) so the team keeps using the app while the same number also reaches
     the API. Availability depends on country and app version; check Meta's
     current documentation.
   - Otherwise the number has to be **migrated**: removed from the regular
     WhatsApp or Business app (and two-step verification turned off) before it
     can be registered on the Platform. Old chat history stays in the old app.
   - Parents keep writing to the same number either way.
4. **Permanent token.** Business Settings → Users → System users → add a system
   user (Admin), assign the app and the WhatsApp account with full control, then
   **Generate token** for the app with `whatsapp_business_messaging` and
   `whatsapp_business_management`, expiry **Never**. This is `WHATSAPP_TOKEN`.
5. **Phone number id.** WhatsApp → API Setup shows "Phone number ID": this is
   `WHATSAPP_PHONE_NUMBER_ID`.
6. **App secret.** App settings → Basic → App secret: this is
   `WHATSAPP_APP_SECRET`.
7. **Verify token.** Make up a long random string (for example
   `openssl rand -hex 24`); this is `WHATSAPP_VERIFY_TOKEN`. Keep a copy for
   step 8.

   ```
   firebase functions:secrets:set WHATSAPP_TOKEN            --project alluwal-academy
   firebase functions:secrets:set WHATSAPP_PHONE_NUMBER_ID  --project alluwal-academy
   firebase functions:secrets:set WHATSAPP_APP_SECRET       --project alluwal-academy
   firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN     --project alluwal-academy
   ```

   Then run the permission loop from Plaid step 6.
8. **Webhook.** WhatsApp → Configuration → Webhook → Edit. **Callback URL** =
   the address of `whatsappWebhook` (Firebase console → Functions). **Verify
   token** = the string from step 7. Save, then under Webhook fields subscribe
   to **messages**. Meta calls the address once; when it passes, Finance → Bank
   deposits shows WhatsApp as Connected.

How the webhook is checked: the handshake answers only when `hub.verify_token`
equals `WHATSAPP_VERIFY_TOKEN`. Every message POST must carry
`X-Hub-Signature-256`, the HMAC-SHA256 of the raw body keyed with
`WHATSAPP_APP_SECRET`; anything else gets 401 and nothing is stored.

**Replies to parents** go out only when Finance → Settings → *Parent messages*
is ON (it is off until the owner turns it on). With it off, screenshots are
still stored, read and matched; the parent just gets no automatic answer.

Pictures that are not payments (a timetable, a photo) are never treated as
payments: they appear as "Not a payment" and an admin notification of type
`whatsapp_message` is created, like a normal message.

The Gemini key is the existing `GEMINI_API_KEY` (already deployed for the AI
tutor); nothing new to create.

## 3. How the secrets are read

The Plaid and WhatsApp secrets are **not** attached to the functions at deploy
time. If they were, `firebase deploy` would fail for as long as a secret does
not exist yet. Instead each function reads the value when it runs: first
`process.env.NAME`, then Google Secret Manager (`NAME`, latest version) using
the function's own service account (hence the permission loop). Values are
cached for five minutes, so a newly saved secret works within minutes with no
redeploy. A missing secret means "not connected".

Only `GEMINI_API_KEY`, which already exists, is attached to `whatsappWebhook`.

If you prefer the standard attachment later, add the names to a `secrets: [...]`
list on the functions in `functions/handlers/finance_bank.js` and
`functions/index.js` once every secret exists.

## 4. Deploying (when the owner is ready)

Nothing here has been deployed. When it is time, follow the repo's usual deploy
rules (deploy only the changed functions; prune revisions before and after):

```
firebase deploy --project alluwal-academy --only \
  functions:linkBankAccount,functions:syncBankTransactions,functions:decideBankMatch,\
functions:decidePaymentProof,functions:scheduledBankSync,functions:plaidWebhook,functions:whatsappWebhook
firebase deploy --project alluwal-academy --only firestore:rules,storage
firebase deploy --project alluwal-academy --only firestore:indexes   # never with --force
```

The payments change (`recordManualPaymentCore` in
`functions/handlers/payments.js`, used by the bank matcher) ships with the
functions deploy; `recordManualPayment` behaves as before.

New data: `bank_transactions`, `known_payers`, `payment_proofs`, `known_phones`
(a parent's WhatsApp number → family) and `finance_private/plaid` (the Plaid
access token and sync cursor). Firestore rules give clients no write access to
any of them and no access at all to the last two. Screenshots are stored under
`payment-proofs/` in Storage: administrators can read them, nobody can write
from a client.

## 5. Testing without real money

Automated, no keys needed:

```
cd functions && npx jest tests/finance_bank
cd apps/web && npm run -s test:unit
```

These cover the matching rules with the prototype's cases (exact by memo, new
payer, split September + October, unknown $75, the Zoom charge, a Stripe
transfer), the confirm / reject / manual / ignore decisions, the closed-month
lock, both webhooks' signature checks, and "a screenshot never records a
payment".

Plaid Sandbox: save the Sandbox `PLAID_CLIENT_ID`, `PLAID_SECRET` and
`PLAID_ENV=sandbox`, press Connect your bank, choose *First Platypus Bank* and
sign in with `user_good` / `pass_good`. Sandbox transactions are generic (not
Zelle payments), so they exercise linking, syncing and the "Not tuition" /
"Use as recurring" paths; use the automated tests for the Zelle cases. To go
live, save the Production secret and `PLAID_ENV=production`, then connect the
real bank again from the page (the stored connection is replaced).

WhatsApp: the Meta app's API Setup gives a free test number and lets you add up
to five recipient numbers. Point the webhook at `whatsappWebhook`, add a
parent's own phone as a recipient, and send a Zelle screenshot from it. Expect
a card under *Payment proofs from WhatsApp* within seconds: "Waiting for the
bank" (no deposit yet), "Who sent this?" (number not on an account), or
"Matches the bank deposit". Send the same screenshot twice to see "Duplicate".

## 6. If something looks wrong

| You see | Cause and fix |
|---|---|
| Page says Not connected after the secrets are saved | The service account lacks the Secret Accessor role (Plaid step 6), or a secret name is misspelled. Names are exact, upper case. |
| "Alluwal has to finish the bank setup first" | `PLAID_CLIENT_ID` / `PLAID_SECRET` are missing or unreadable. |
| Deposits arrive a day late | No `PLAID_WEBHOOK_URL`, so only the 6:00 AM sync runs. Add it and reconnect once, or press *Check the bank now*. |
| WhatsApp stays Not connected | Meta has not called the webhook, or the verify token differs from `WHATSAPP_VERIFY_TOKEN`. |
| "Could not read this picture" | The Gemini key is missing or over quota, or the image is not a photo. The original opens from the card. |
| "Who sent this?" for a known parent | The phone number on the parent's account is missing or typed differently. Pick the family once; the number is remembered. A number on two accounts is never guessed. |
| Confirm says the month is closed | An owner has to reopen that month first (Finance → Close month). |
