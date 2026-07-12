import { cp, mkdir, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = dirname(fileURLToPath(import.meta.url));
const webDir = join(appDir, "..");
const repoRoot = join(webDir, "..", "..");
const publicDir = join(webDir, "public");
const assetsDir = join(publicDir, "assets");

async function copyFileOrDir(from, to) {
  await mkdir(dirname(to), { recursive: true });
  await cp(from, to, { recursive: true, force: true });
}

await rm(assetsDir, { recursive: true, force: true });
await mkdir(assetsDir, { recursive: true });

await Promise.all([
  copyFileOrDir(
    join(repoRoot, "assets", "Alluwal_Education_Hub_Logo.png"),
    join(assetsDir, "Alluwal_Education_Hub_Logo.png"),
  ),
  copyFileOrDir(
    join(repoRoot, "assets", "logo_navigation_bar.PNG"),
    join(assetsDir, "logo_navigation_bar.PNG"),
  ),
  copyFileOrDir(
    join(repoRoot, "assets", "background_images"),
    join(assetsDir, "background_images"),
  ),
  copyFileOrDir(
    join(repoRoot, "assets", "teachers"),
    join(assetsDir, "teachers"),
  ),
  copyFileOrDir(
    join(repoRoot, "assets", "data", "staff.json"),
    join(assetsDir, "data", "staff.json"),
  ),
  copyFileOrDir(
    join(repoRoot, "assets", "images", "staff"),
    join(assetsDir, "images", "staff"),
  ),
  copyFileOrDir(join(repoRoot, "web", "favicon.png"), join(publicDir, "favicon.png")),
  copyFileOrDir(join(repoRoot, "web", "logo-192.png"), join(publicDir, "logo-192.png")),
  copyFileOrDir(join(repoRoot, "web", "logo-512.png"), join(publicDir, "logo-512.png")),
  copyFileOrDir(join(repoRoot, "web", "zoom_meeting.html"), join(publicDir, "zoom_meeting.html")),
]);

console.log("Prepared Next.js public assets.");
