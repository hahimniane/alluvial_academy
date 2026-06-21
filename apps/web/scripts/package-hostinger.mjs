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

await rm(packageOut, { recursive: true, force: true });
await mkdir(packageOut, { recursive: true });
await cp(nextOut, packageOut, { recursive: true, force: true });

if (await exists(flutterWeb)) {
  await rm(join(packageOut, "app"), { recursive: true, force: true });
  await cp(flutterWeb, join(packageOut, "app"), { recursive: true, force: true });
  await rewriteFlutterBridgeBaseHref(join(packageOut, "app", "index.html"));
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
