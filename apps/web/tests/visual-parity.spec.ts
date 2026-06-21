import { expect, test } from "@playwright/test";

const publicRoutes = [
  { name: "home", path: "/" },
  { name: "about", path: "/about/" },
  { name: "team", path: "/team/" },
  { name: "programs", path: "/programs/" },
  { name: "contact", path: "/contact/" },
  { name: "teacher-application", path: "/teacher-application/" },
  { name: "leadership-application", path: "/leadership-application/" },
  { name: "login", path: "/login/" },
  { name: "enroll", path: "/enroll/" },
] as const;

// Seed snapshots from the Flutter baseline, then compare the Next candidate:
// PLAYWRIGHT_BASE_URL=http://localhost:3032 npm run test:visual:update
// PLAYWRIGHT_BASE_URL=http://localhost:3021 npm run test:visual
test.describe("visual parity routes", () => {
  test.skip(
    process.env.ALLUWAL_RUN_VISUAL_PARITY !== "1",
    "Set ALLUWAL_RUN_VISUAL_PARITY=1 when capturing or comparing migration screenshots.",
  );

  for (const route of publicRoutes) {
    test(`${route.name} has no browser console errors and matches snapshot`, async ({ page }) => {
      const errors: string[] = [];
      page.on("console", (message) => {
        if (message.type() === "error") errors.push(message.text());
      });
      page.on("pageerror", (error) => errors.push(error.message));

      await page.goto(route.path, { waitUntil: "networkidle" });
      await expect(page.locator("body")).toBeVisible();
      await expect(page).toHaveScreenshot(`${route.name}.png`, {
        fullPage: true,
        maxDiffPixelRatio: 0.02,
      });
      expect(errors).toEqual([]);
    });
  }
});
