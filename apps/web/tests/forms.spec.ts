import { expect, test } from "@playwright/test";

test.describe("public forms", () => {
  test("contact form validates required fields before submit", async ({ page }) => {
    await page.goto("/contact/");
    await page.getByRole("button", { name: "Send message" }).click();
    await expect(page.locator("input[name='name']")).toBeFocused();
  });

  test("teacher application form accepts a complete draft", async ({ page }) => {
    const longAnswer = Array.from({ length: 105 }, (_, index) => `motivation${index}`).join(" ");
    const scenarioAnswer = Array.from({ length: 105 }, (_, index) => `scenario${index}`).join(" ");

    await page.goto("/teacher-application/");
    await page.locator("input[name='firstName']").fill("Playwright");
    await page.locator("input[name='lastName']").fill("Teacher");
    await page.locator("input[name='email']").fill("playwright.teacher@example.com");
    await page.locator("input[name='countryCode']").fill("+1");
    await page.locator("input[name='phoneNumber']").fill("5555550123");
    await page.locator("input[name='currentLocation']").fill("Test City, USA");
    await page.locator("input[name='nationality']").fill("Test");
    await page.locator("select[name='gender']").selectOption("female");
    await page.locator("select[name='currentStatus']").selectOption("university_graduate");
    await page.getByRole("button", { name: "Next", exact: true }).click();

    await page.getByRole("button", { name: /Islamic & AdLam/ }).click();
    await page.locator("select[name='tajwidLevel']").selectOption("yes");
    await page.locator("select[name='quranMemorization']").selectOption("hafiz");
    await page.locator("select[name='arabicProficiency']").selectOption("excellent");
    await page.getByRole("button", { name: "English", exact: true }).click();
    await page.getByRole("button", { name: "Arabic", exact: true }).click();
    await page.getByRole("button", { name: "Next", exact: true }).click();

    await page.locator("select[name='timeDiscipline']").selectOption("100%");
    await page.locator("select[name='scheduleBalance']").selectOption("100%");
    await page.locator("textarea[name='interestReason']").fill(longAnswer);
    await page.locator("select[name='electricityAccess']").selectOption("always");
    await page.locator("select[name='teachingComfort']").selectOption("very_comfortable");
    await page.locator("select[name='studentInteractionGuarantee']").selectOption("yes_always");
    await page.locator("select[name='availabilityStart']").selectOption("two_weeks");
    await page.getByRole("button", { name: "Next", exact: true }).click();

    await page.locator("select[name='teachingDevice']").selectOption("computer");
    await page.locator("select[name='internetAccess']").selectOption("always");
    await page.getByRole("button", { name: "Next", exact: true }).click();

    await page.locator("textarea[name='scenarioNonParticipatingStudent']").fill(scenarioAnswer);

    await expect(page.getByRole("button", { name: "Submit Application" })).toBeEnabled();
  });

  test("enrollment flow reaches review step with required data", async ({ page }) => {
    await page.goto("/enroll/");
    await page.getByRole("button", { name: "Parent" }).click();
    await page.getByRole("button", { name: "Continue" }).click();

    await page.locator("input[name='name']").fill("Playwright Student");
    await page.locator("input[name='age']").fill("12");
    await page.getByRole("button", { name: "Female" }).click();
    await page.getByRole("button", { name: "Continue" }).click();

    await page.getByRole("button", { name: /Islamic Program/ }).click();
    await page.locator("select[name='level']").selectOption("Beginner");
    await page.getByRole("button", { name: "1-on-1" }).click();
    await page.locator("select[name='preferredLanguage']").selectOption("English");
    await page.getByRole("button", { name: "Continue" }).click();

    await page.getByRole("button", { name: "Evening" }).click();
    await page.getByRole("button", { name: "Mon" }).click();
    await page.getByRole("button", { name: "5:00 PM - 6:00 PM" }).click();
    await page.getByRole("button", { name: "Continue" }).click();

    await page.locator("input[name='parentName']").fill("Playwright Parent");
    await page.locator("input[name='email']").fill("playwright.parent@example.com");
    await page.locator("input[name='phoneNumber']").fill("5555550123");
    await page.locator("input[name='city']").fill("New York");
    await expect(page.getByRole("button", { name: "Submit Request" })).toBeEnabled();
  });

  test("parent enrollment supports adding multiple students", async ({ page }) => {
    await page.goto("/enroll/");
    await page.getByRole("button", { name: "Parent" }).click();
    await page.getByRole("button", { name: "Add student" }).click();
    await expect(page.locator("form").getByText("2", { exact: true })).toBeVisible();
    await page.getByRole("button", { name: "Continue" }).click();

    await page.locator("input[name='name']").fill("First Student");
    await page.locator("input[name='age']").fill("10");
    await page.getByRole("button", { name: "Student 2" }).click();
    await page.locator("input[name='student2Name']").fill("Second Student");
    await page.locator("input[name='student2Age']").fill("8");

    await expect(page.getByRole("button", { name: "Continue" })).toBeEnabled();
  });
});

test.describe("Firebase write workflows", () => {
  test.skip(process.env.ALLUWAL_RUN_WRITE_E2E !== "1", "Set ALLUWAL_RUN_WRITE_E2E=1 to write to the dev Firebase project.");

  test("contact form writes to dev Firestore", async ({ page }) => {
    await page.goto("/contact/");
    await page.locator("input[name='name']").fill("Playwright Contact");
    await page.locator("input[name='email']").fill("playwright.contact@example.com");
    await page.locator("textarea[name='message']").fill("Browser write test for the Next.js migration.");
    await page.getByRole("button", { name: "Send message" }).click();
    await expect(page.getByText("Message sent successfully")).toBeVisible({ timeout: 15_000 });
  });
});
