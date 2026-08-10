# `hosting/pay` — the payment-link site

Public directory for the `pay` Hosting target (site `alluwal-pay`, custom domain
`pay.alluwaleducationhub.org`).

It is deliberately almost empty. Every path rewrites to the `handlePaymentLink`
Cloud Function, which renders the page for a token:

    https://pay.alluwaleducationhub.org/<token>

Only `robots.txt` is served statically — Hosting matches static files before
rewrites — so payment URLs stay out of search indexes.

This site is separate from the app's site (`alluwal-academy`) on purpose:

- `pay.` must not serve the whole admin/parent app.
- A bad app deploy can't take the payment page down, and vice versa.

Deploy this site alone with:

    firebase deploy --project alluwal-academy --only hosting:pay

`alluwaleducationhub.org` is served by Cloudflare/LiteSpeed, not Firebase, so
Hosting rewrites never apply there. That is why payment links need this
dedicated Firebase-hosted subdomain.
