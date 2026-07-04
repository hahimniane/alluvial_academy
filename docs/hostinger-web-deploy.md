# Hostinger Web Deploy

Use this path for the Flutter web app on Hostinger. Deployment coordinates
belong in local environment variables or an untracked `.hostinger-deploy.env`,
not in source control.

Required variables:

- `HOSTINGER_HOST`
- `HOSTINGER_PORT`
- `HOSTINGER_USER`
- `HOSTINGER_KEY`
- `REMOTE_DOMAIN_ROOT`
- `SITE_URL` (optional; defaults to the public domain)

Deploy with:

```bash
./scripts/deploy_hostinger_web.sh
```

The script always runs `./build_release.sh` first. Do not run
`flutter build web --release` directly for Hostinger deploys.

What the script does:

1. Runs `./build_release.sh`.
2. Reads the cache-busting version from `web/index.html`.
3. Creates a timestamped backup of the live `public_html` folder.
4. Runs rsync with `--delete` from `build/web/` to Hostinger.
5. Verifies the remote files and public site are serving the new version.

Manual upload command, only when debugging the deploy script:

```bash
rsync -az --delete --progress --stats \
  -e "ssh -i \"$HOSTINGER_KEY\" -p \"$HOSTINGER_PORT\" -o StrictHostKeyChecking=accept-new" \
  build/web/ \
  "$HOSTINGER_USER@$HOSTINGER_HOST:$REMOTE_DOMAIN_ROOT/public_html/"
```
