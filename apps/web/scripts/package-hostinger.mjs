import { cp, mkdir, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const webDir = join(scriptDir, "..");
const repoRoot = join(webDir, "..", "..");
const nextOut = join(webDir, "out");
const flutterWeb = join(repoRoot, "build", "web");
const packageOut = join(repoRoot, "build", "hostinger-web");

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

if (!(await exists(nextOut))) {
  throw new Error("apps/web/out is missing. Run `cd apps/web && npm run build` first.");
}

// The public site's enrollment, contact and teacher-application forms write
// straight to Firestore, so a bundle built against the dev project drops real
// submissions into alluwal-dev where nobody reads them. With
// NEXT_PUBLIC_FIREBASE_ENV=prod the config ternary folds at build time and the
// dev config disappears from the output — so its presence means the env var
// went missing and this build must not ship.
async function assertBuiltAgainstProd(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      await assertBuiltAgainstProd(path);
    } else if (entry.name.endsWith(".js")) {
      if ((await readFile(path, "utf8")).includes("alluwal-dev")) {
        throw new Error(
          `Refusing to package: ${path} still references the dev Firebase project.\n` +
          "Build with NEXT_PUBLIC_FIREBASE_ENV=prod (apps/web/.env.production sets it) and rebuild."
        );
      }
    }
  }
}

await assertBuiltAgainstProd(join(nextOut, "_next"));

await rm(packageOut, { recursive: true, force: true });
await mkdir(packageOut, { recursive: true });
await cp(nextOut, packageOut, { recursive: true, force: true });

// These screens render inside the Flutter web app (/app/), which is
// cross-origin isolated (COEP) for the Zoom SDK. A COEP document may only
// frame documents that send a COEP header themselves, so without this the
// browser blocks the embed with a blank error page — no network request, and
// nothing in DevTools to explain it. Every embedded route needs an entry here.
for (const embeddedRoute of [
  ["admin", "shifts"],
  ["admin", "student-applicants"],
  ["teacher", "job-board"],
]) {
  await writeFile(
    join(packageOut, ...embeddedRoute, ".htaccess"),
    [
      "<IfModule mod_headers.c>",
      '    Header always set Cross-Origin-Embedder-Policy "credentialless"',
      "</IfModule>",
      "",
    ].join("\n"),
  );
}

// Caching. With no Cache-Control at all the browser falls back to heuristic
// caching — roughly a tenth of the time since the file was last modified — so
// a page that sat unchanged for a week keeps serving the old build for hours
// after a deploy. That is invisible to us and confusing for families, who are
// shown a form we believe we already replaced.
//
// The root rule makes HTML and the Next.js RSC payloads revalidate every time;
// the answer is normally a 304 and costs nothing. The immutable rule is scoped
// to _next/static, whose filenames are content hashes — deliberately NOT
// applied at the root, because the Flutter app under /app/ versions itself
// with a ?v= query instead and has its own rules.
await writeFile(
  join(packageOut, ".htaccess"),
  [
    "RewriteEngine On",
    "",
    "RewriteCond %{HTTP_HOST} ^(ops|routing|control)\\.alluwaleducationhub\\.org$ [NC]",
    "RewriteRule ^$ /admin/routing-control/ [R=302,L]",
    "",
    "<IfModule mod_headers.c>",
    '    <FilesMatch "\\.(html|txt|json)$">',
    '        Header set Cache-Control "no-cache, must-revalidate"',
    "    </FilesMatch>",
    "</IfModule>",
    "",
  ].join("\n"),
);

await mkdir(join(packageOut, "_next", "static"), { recursive: true });
await writeFile(
  join(packageOut, "_next", "static", ".htaccess"),
  [
    "<IfModule mod_headers.c>",
    "    # Filenames here are content hashes, so a new build asks for new names.",
    '    Header set Cache-Control "public, max-age=31536000, immutable"',
    "</IfModule>",
    "",
  ].join("\n"),
);

if (await exists(flutterWeb)) {
  await rm(join(packageOut, "app"), { recursive: true, force: true });
  await cp(flutterWeb, join(packageOut, "app"), { recursive: true, force: true });
  await rewriteFlutterBridgeBaseHref(join(packageOut, "app", "index.html"));
  await rewriteFlutterBridgeHtaccess(join(packageOut, "app", ".htaccess"));
  await rm(join(packageOut, "app", "flutter_service_worker.js"), { force: true });
  await removeByName(packageOut, ".DS_Store");
  console.log("Packaged Next.js site with Flutter bridge at build/hostinger-web/app.");
} else {
  console.warn(
    "Flutter build/web was not found, so build/hostinger-web/app was not created.",
  );
  console.warn(
    "For release packaging, build Flutter with the repo-approved command before this script:",
  );
  console.warn("./increment_version.sh && flutter build web --release --pwa-strategy=none");
}

async function rewriteFlutterBridgeBaseHref(indexPath) {
  const html = await readFile(indexPath, "utf8");
  const updated = html.replace(/<base href="[^"]*">/, '<base href="/app/">');
  await writeFile(indexPath, updated);
}

async function rewriteFlutterBridgeHtaccess(htaccessPath) {
  if (!(await exists(htaccessPath))) return;
  const htaccess = await readFile(htaccessPath, "utf8");
  const updated = htaccess
    .replace(/RewriteBase \/\s*$/m, "RewriteBase /app/")
    .replace(/RewriteRule \. \/index\.html \[L\]/, "RewriteRule . /app/index.html [L]")
    // Rewrite targets are absolute from the domain root, so anything left
    // pointing at / escapes the bridge and lands on the Next site. Without
    // this, /app/privacy-policy served the root policy page instead of the
    // Flutter one.
    .replace(
      /RewriteRule \^privacy-policy\/\?\$ \/privacy-policy\.html \[L\]/,
      "RewriteRule ^privacy-policy/?$ /app/privacy-policy.html [L]",
    );
  await writeFile(htaccessPath, updated);
}

async function removeByName(root, fileName) {
  const entries = await readdir(root, { withFileTypes: true });
  await Promise.all(entries.map(async (entry) => {
    const fullPath = join(root, entry.name);
    if (entry.name === fileName) {
      await rm(fullPath, { recursive: true, force: true });
      return;
    }
    if (entry.isDirectory()) {
      await removeByName(fullPath, fileName);
    }
  }));
}
