import { expect, test } from "@playwright/test";

test.describe("auth bridge", () => {
  test("login page presents a normal user-facing dashboard login", async ({ page }) => {
    await page.goto("/login/");
    await expect(page.getByRole("heading", { name: /Welcome Back/i })).toBeVisible();
    await expect(page.getByText(/Firebase project:/)).toHaveCount(0);
    await expect(page.getByText(/bridge/i)).toHaveCount(0);
    await expect(page.getByText(/migration/i)).toHaveCount(0);
  });

  test("real login reaches dashboard", async ({ page }) => {
    test.skip(
      !process.env.ALLUWAL_E2E_EMAIL || !process.env.ALLUWAL_E2E_PASSWORD,
      "Set ALLUWAL_E2E_EMAIL and ALLUWAL_E2E_PASSWORD for dev Firebase login testing.",
    );

    await page.goto("/login/");
    await page.locator("input[type='email']").fill(process.env.ALLUWAL_E2E_EMAIL ?? "");
    await page.locator("input[type='password']").fill(process.env.ALLUWAL_E2E_PASSWORD ?? "");
    await page.getByRole("button", { name: "Sign In" }).click();
    await expect(page).toHaveURL(/(\/admin\/|\/teacher\/|\/app\/#\/login)$/);
    await expect(page).toHaveTitle(/Alluwal Education Hub/i);
  });
});
