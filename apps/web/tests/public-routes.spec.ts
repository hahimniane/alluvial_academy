import { expect, test } from "@playwright/test";

const publicRoutes = [
  ["/", "Learn with online tutoring"],
  ["/about/", "Where education transcends boundaries"],
  ["/programs/", "Explore our programs"],
  ["/enroll/", "Who's enrolling"],
  ["/team/", "Meet the people"],
  ["/contact/", "Get in touch"],
  ["/teacher-application/", "Teacher Application"],
  ["/leadership-application/", "Join Our Leadership Team"],
  ["/login/", "Staff, parent, and student access"],
] as const;

test.describe("public route parity smoke", () => {
  for (const [route, heading] of publicRoutes) {
    test(`${route} renders without console errors`, async ({ page }) => {
      const errors: string[] = [];
      page.on("console", (message) => {
        if (message.type() === "error") errors.push(message.text());
      });
      page.on("pageerror", (error) => errors.push(error.message));

      await page.goto(route);
      await expect(page.getByRole("heading", { name: new RegExp(heading, "i") })).toBeVisible();
      expect(errors).toEqual([]);
    });
  }

  test("desktop navigation clicks between core pages", async ({ page, isMobile }) => {
    test.skip(isMobile, "Desktop header links are hidden in the mobile project.");
    await page.goto("/");
    await page.getByRole("link", { name: "Explore Our Programs" }).first().click();
    await expect(page).toHaveURL(/\/programs\/$/);
    await page.getByRole("link", { name: "Our Team" }).first().click();
    await expect(page).toHaveURL(/\/team\/$/);
    await page.getByRole("link", { name: "Contact Us" }).first().click();
    await expect(page).toHaveURL(/\/contact\/$/);
  });

  test("mobile navigation menu opens and routes", async ({ page, isMobile }) => {
    test.skip(!isMobile, "Mobile menu is only visible in mobile project.");
    await page.goto("/");
    const menuButton = page.getByRole("button", { name: "Open navigation menu" });
    await expect(menuButton).toHaveAttribute("aria-expanded", "false");
    await menuButton.click();
    await expect(menuButton).toHaveAttribute("aria-expanded", "true");
    await page.getByRole("link", { name: "Pricing" }).last().click();
    await expect(page).toHaveURL(/\/#pricing$/);
    await page.getByRole("button", { name: "Open navigation menu" }).click();
    await page
      .getByRole("navigation", { name: "Mobile navigation" })
      .getByRole("link", { name: "Islamic Studies" })
      .click();
    await expect(page).toHaveURL(/\/programs\/\?category=islamic$/);
  });

  test("team directory filters and profile sheet work", async ({ page }) => {
    await page.goto("/team/");
    await expect(page.getByRole("heading", { name: /Meet the people/i })).toBeVisible();

    await page.getByRole("button", { name: /^Teachers\s+Global Knowledge Carriers\s+\d+$/ }).click();
    await expect(page.getByText("Scholars and educators spanning 10+ countries")).toBeVisible();
    await expect(page.getByRole("button", { name: /Aliou Diallo/ })).toBeVisible();

    await page.getByRole("button", { name: /^Leadership\s+Vision & Direction\s+\d+$/ }).click();
    await expect(page.getByText("The architects and coordinators of Alluwal")).toBeVisible();

    await page.getByRole("button", { name: /Chernor A Diallo/ }).click();
    const profile = page.getByRole("dialog", { name: /Chernor A Diallo profile/ });
    await expect(profile).toBeVisible();
    await expect(profile.getByRole("link", { name: /Contact Chernor/ })).toBeVisible();
    await profile.getByRole("button", { name: "Close profile" }).last().click();
    await expect(profile).toBeHidden();
  });
});
