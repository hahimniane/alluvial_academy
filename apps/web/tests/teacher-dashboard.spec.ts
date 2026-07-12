import { expect, test, type Page } from "@playwright/test";

const teacherEmail = process.env.ALLUWAL_TEACHER_E2E_EMAIL ?? "";
const teacherPassword = process.env.ALLUWAL_TEACHER_E2E_PASSWORD ?? "";

function skipUnlessTeacherE2EEnabled() {
  test.skip(
    process.env.ALLUWAL_RUN_TEACHER_E2E !== "1" || !teacherEmail || !teacherPassword,
    "Set ALLUWAL_RUN_TEACHER_E2E=1, ALLUWAL_TEACHER_E2E_EMAIL, and ALLUWAL_TEACHER_E2E_PASSWORD for teacher dashboard testing.",
  );
}

function skipUnlessDesktopTeacherE2EEnabled(projectName: string) {
  skipUnlessTeacherE2EEnabled();
  test.skip(projectName !== "chromium", "Authenticated teacher module navigation uses the desktop sidebar; mobile and WebKit keep guard coverage.");
}

function skipUnlessMobileTeacherE2EEnabled(projectName: string) {
  skipUnlessTeacherE2EEnabled();
  test.skip(projectName !== "mobile-chrome", "Mobile teacher drawer behavior is covered by the mobile Chrome project.");
}

function skipUnlessStableTeacherE2EEnabled(projectName: string) {
  skipUnlessTeacherE2EEnabled();
  test.skip(projectName === "webkit", "WebKit intermittently misses the authenticated teacher dashboard render; Chromium and mobile Chrome cover this flow.");
}

async function signInAsTeacher(page: Page) {
  await page.goto("/login/");
  await page.locator("input[type='email']").fill(teacherEmail);
  await page.locator("input[type='password']").fill(teacherPassword);
  await page.getByRole("button", { name: "Sign In" }).click();
  await page.waitForURL(/\/teacher\/$/, { timeout: 15000 }).catch(async () => {
    if (await page.getByText(/Network connection failed/).isVisible().catch(() => false)) {
      await page.getByRole("button", { name: "Sign In" }).click();
    }
    await page.waitForURL(/\/teacher\/$/, { timeout: 15000 });
  });
}

async function gotoTeacherGuard(page: Page, path: string) {
  await page.goto(path, { waitUntil: "commit" });
}

test.describe("teacher dashboard", () => {
  test("requires a teacher sign-in before rendering the dashboard", async ({ page }) => {
    await gotoTeacherGuard(page, "/teacher/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Next Class" })).toBeHidden();
  });

  test("teacher login opens the native teacher dashboard", async ({ page }, testInfo) => {
    skipUnlessStableTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await expect(page.getByRole("heading", { name: "Next Class" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Quick Access" })).toBeVisible();
    await expect(page.getByRole("link", { name: "View Full Schedule" })).toBeVisible();
    await expect(page.getByText("This Week")).toBeVisible();
    await expect(page.getByText("Earnings")).toBeVisible();
  });

  test("teacher mobile menu opens native teacher navigation", async ({ page }, testInfo) => {
    skipUnlessMobileTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("button", { name: "Open teacher menu" }).click();
    await expect(page.getByLabel("Teacher mobile menu")).toBeVisible();
    const mobileNav = page.getByRole("navigation", { name: "Teacher mobile navigation" });
    await expect(mobileNav.getByRole("link", { name: /Dashboard/ })).toBeVisible();
    await expect(mobileNav.getByRole("link", { name: /My Report/ })).toBeVisible();
    await expect(page.getByRole("button", {name: "Log out"})).toBeVisible();
    await mobileNav.getByRole("link", { name: /Time Clock/ }).click();
    await expect(page).toHaveURL(/\/teacher\/time-clock\/$/);
    await expect(page.getByText("Timesheet status")).toBeVisible();
  });

  test("teacher dashboard trading quick access opens native job board", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: "Trading" }).click();
    await expect(page).toHaveURL(/\/teacher\/job-board\/$/);
    await expect(page.getByRole("heading", { name: "New Student Opportunities" })).toBeVisible();
  });

  test("teacher account menu exposes role switch and logout", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByLabel("Open teacher account menu").click();
    const menu = page.getByRole("menu", {name: "Teacher account menu"});
    await expect(menu.getByRole("menuitem", {name: "Log out"})).toBeVisible();
    const adminSwitch = menu.getByRole("menuitem", {name: "Switch to Admin"});
    if (await adminSwitch.isVisible().catch(() => false)) await expect(adminSwitch).toHaveAttribute("href", "/admin/");
  });

  test("teacher can switch to the existing admin role", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByLabel("Open teacher account menu").click();
    const adminSwitch = page.getByRole("menu", {name: "Teacher account menu"}).getByRole("menuitem", {name: "Switch to Admin"});
    test.skip(!(await adminSwitch.isVisible().catch(() => false)), "The dev teacher fixture does not currently include the admin role.");
    await adminSwitch.click();
    await expect(page).toHaveURL(/\/admin\/$/);
  });

  test("teacher can log out from the account menu", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByLabel("Open teacher account menu").click();
    await page.getByRole("menu", {name: "Teacher account menu"}).getByRole("menuitem", {name: "Log out"}).click();
    await expect(page).toHaveURL(/\/login\/$/);
    await expect(page.getByRole("heading", {name: "Welcome Back"})).toBeVisible();
  });

  test("teacher sidebar favorites persist and reset", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("button", {name: "Pin Tasks"}).click();
    await page.reload();
    await expect(page.getByRole("navigation", {name: "Teacher dashboard navigation"}).getByText("Favorites")).toBeVisible();
    await page.getByRole("button", {name: "Reset Layout"}).click();
    await page.reload();
    await expect(page.getByRole("navigation", {name: "Teacher dashboard navigation"}).getByText("Favorites")).toBeHidden();
  });

  test("teacher sidebar and page content use separate desktop columns and scroll regions", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    const sidebar = page.getByRole("navigation", {name: "Teacher dashboard navigation"}).locator("..");
    const content = page.getByLabel("Teacher page content");
    const [sidebarBox, contentBox] = await Promise.all([sidebar.boundingBox(), content.boundingBox()]);
    expect(sidebarBox).not.toBeNull();
    expect(contentBox).not.toBeNull();
    expect((sidebarBox?.x ?? 0) + (sidebarBox?.width ?? 0)).toBeLessThanOrEqual(contentBox?.x ?? 0);
    const sidebarTop = sidebarBox?.y ?? 0;
    await content.evaluate((element) => { element.scrollTop = Math.min(240, element.scrollHeight - element.clientHeight); });
    expect(await page.evaluate(() => window.scrollY)).toBe(0);
    expect((await sidebar.boundingBox())?.y).toBe(sidebarTop);
  });

  test("requires a teacher sign-in before rendering my report", async ({ page }) => {
    await gotoTeacherGuard(page, "/teacher/report/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "My Performance Audit" })).toBeHidden();
  });

  test("teacher can open the native performance report", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    const navigation = page.getByRole("navigation", { name: "Teacher dashboard navigation" });
    await expect(navigation.getByText("Reports")).toBeVisible();
    await navigation.getByRole("link", { name: "My Report" }).click();
    await expect(page).toHaveURL(/\/teacher\/report\/$/);
    await expect(page.getByRole("heading", { name: "My Performance Audit" })).toBeVisible();
    await expect(page.getByText(/No audit data for|Score Breakdown/).first()).toBeVisible();
    await expect(page.getByRole("button", { name: "Refresh report" })).toBeVisible();
  });

  test("teacher performance report renders every populated section and exports CSV", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_REPORT_FIXTURE_E2E !== "1", "Enable only with the disposable dev teacher audit fixture.");
    await signInAsTeacher(page);
    await page.getByRole("navigation", { name: "Teacher dashboard navigation" }).getByRole("link", { name: "My Report" }).click();
    await expect(page.getByText("88.5%")).toBeVisible();
    await expect(page.getByText("Codex disposable report issue")).toBeVisible();
    await page.getByRole("tab", { name: "Classes" }).click();
    await expect(page.getByText("Codex Quran Class")).toBeVisible();
    await page.getByRole("tab", { name: "Clock-ins" }).click();
    await expect(page.getByText("submitted", { exact: true })).toBeVisible();
    await page.getByRole("tab", { name: "Forms" }).click();
    await expect(page.getByText("Codex Readiness Form")).toBeVisible();
    await page.getByRole("tab", { name: "Overview" }).click();
    await expect(page.getByText("Payment Summary")).toBeVisible();
    await expect(page.getByText("$225.00")).toBeVisible();
    await page.getByRole("button", { name: "Acknowledge that I have read this report" }).click();
    await expect(page.getByText(/Acknowledged/)).toBeVisible();
    await page.getByRole("button", { name: "Send correction request" }).click();
    await expect(page.getByText("Select the field you want corrected.")).toBeVisible();
    await page.getByLabel("Field to correct").selectOption("payment_amount");
    await page.getByLabel("Correction reason").fill("The payment amount should include my additional completed session.");
    await page.getByLabel("Suggested value").fill("$300.00");
    await page.getByRole("button", { name: "Send correction request" }).click();
    await expect(page.getByText("Your correction request was sent successfully.")).toBeVisible();
    await expect(page.getByText("Existing correction request")).toBeVisible();
    await expect(page.getByText(/Payment amount/).last()).toBeVisible();
    const downloadPromise = page.waitForEvent("download");
    await page.getByRole("button", { name: "Download My Teaching Data (CSV)" }).click();
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe("teacher-report-2026-07.csv");
    const stream = await download.createReadStream();
    let csv = "";
    for await (const chunk of stream) csv += chunk.toString();
    expect(csv).toContain('"Date","Shift Name","Status","Scheduled Hours","Worked Hours","Pay","Has Form"');
    expect(csv).toContain('"Codex Quran Class","completed","1.50","1.50","75.00","Yes"');
  });

  test("requires a teacher sign-in before rendering my shifts", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/shifts/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Weekly Calendar" })).toBeHidden();
  });

  test("teacher can open the native my shifts schedule", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /My Shifts/ }).click();
    await expect(page).toHaveURL(/\/teacher\/shifts\/$/);
    await expect(page.getByRole("heading", { name: "Weekly Calendar" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Week", exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "List", exact: true })).toBeVisible();
    await expect(page.getByText(/Grid shows three days at a time/)).toBeVisible();
    await page.getByRole("button", { name: "Day", exact: true }).click();
    const emptyDay = page.getByRole("heading", { name: "No Shifts Today" });
    const shiftAction = page.getByRole("button", { name: /Clock In Now|Clock Out|Clock In \(Not Yet\)|View Details/ }).first();
    await expect(emptyDay.or(shiftAction)).toBeVisible();
    await page.getByRole("button", { name: "Schedule settings" }).click();
    await expect(page.getByRole("heading", { name: "Report Schedule Issue" })).toBeVisible();
    await expect(page.getByText("Fix My Timezone Only")).toBeVisible();
  });

  test("my shifts prevents duplicate clock actions and recovers after reload", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SHIFT_RESILIENCE_E2E !== "1", "Enable only with the disposable dev My Shifts fixture.");
    await context.grantPermissions(["geolocation"]);
    await context.setGeolocation({latitude: 40.7128, longitude: -74.006});
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /My Shifts/}).click();
    const second = await context.newPage();
    await second.goto("/teacher/shifts/");
    const title = "Codex Teacher Shift Resilience QA";
    await Promise.all([expect(page.getByText(title)).toBeVisible(), expect(second.getByText(title)).toBeVisible()]);
    await Promise.all([
      page.getByRole("button", {name: "Clock In", exact: true}).click(),
      second.getByRole("button", {name: "Clock In", exact: true}).click(),
    ]);
    await Promise.all([
      expect(page.getByText(/Successfully clocked in|already clocked in/)).toBeVisible(),
      expect(second.getByText(/Successfully clocked in|already clocked in/)).toBeVisible(),
    ]);
    await Promise.all([page.reload(), second.reload()]);
    await Promise.all([
      expect(page.getByRole("button", {name: "Clock Out", exact: true})).toBeVisible(),
      expect(second.getByRole("button", {name: "Clock Out", exact: true})).toBeVisible(),
    ]);
    await Promise.all([
      page.getByRole("button", {name: "Clock Out", exact: true}).click(),
      second.getByRole("button", {name: "Clock Out", exact: true}).click(),
    ]);
    await Promise.all([
      expect(page.getByText(/Successfully clocked out|No active clock-in|already been clocked out/)).toBeVisible(),
      expect(second.getByText(/Successfully clocked out|No active clock-in|already been clocked out/)).toBeVisible(),
    ]);
  });

  test("requires a teacher sign-in before rendering time clock", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/time-clock/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "My Timesheet" })).toBeHidden();
  });

  test("teacher can open the native time clock timesheet", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Time Clock/ }).click();
    await expect(page).toHaveURL(/\/teacher\/time-clock\/$/);
    await expect(page.getByRole("heading", { name: "My Timesheet" })).toBeVisible();
    await expect(page.getByLabel("Timesheet range")).toBeVisible();
    await expect(page.getByRole("button", { name: "Export" })).toBeVisible();
    await expect(page.getByRole("columnheader", { name: /Clock-in Location/ })).toBeVisible();
    const pendingRow = page.getByRole("row").filter({ hasText: "Codex Time Clock Student" }).filter({ hasText: "Pending" }).first();
    await pendingRow.getByRole("button", { name: /View/ }).click();
    await expect(page.getByRole("heading", { name: "Timesheet Details" })).toBeVisible();
    await expect(page.getByText("Location Information")).toBeVisible();
    await page.getByLabel("Close").click();

    const draftRow = page.getByRole("row").filter({ hasText: "Codex Time Clock Student" }).filter({ hasText: "Draft" }).first();
    await draftRow.getByRole("button", { name: /Edit/ }).click();
    await expect(page.getByRole("heading", { name: "Edit Timesheet" })).toBeVisible();
    await expect(page.getByLabel("Clock In Time")).toBeVisible();
    await page.getByLabel("Close").click();
    await draftRow.getByRole("button", { name: /^Submit$/ }).click();
    await expect(page.getByRole("heading", { name: "Submit for Review" })).toBeVisible();
    await page.getByRole("button", { name: "Cancel" }).click();
  });

  test("teacher clock lifecycle writes Flutter-compatible metadata", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_CLOCK_WRITE_E2E !== "1", "Enable only with the disposable dev shift fixture.");
    await context.grantPermissions(["geolocation"]);
    await context.setGeolocation({latitude: 40.7128, longitude: -74.006});
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Time Clock/}).click();
    await expect(page.getByText("Codex Teacher Clock Metadata QA")).toBeVisible();
    await page.getByRole("button", {name: "Clock In Now"}).click();
    await expect(page.getByText(/Successfully clocked in/)).toBeVisible();
    await page.getByRole("button", {name: "Clock Out"}).click();
    await expect(page.getByText(/Successfully clocked out/)).toBeVisible();
  });

  test("teacher clock actions handle location denial, duplicate tabs, and reload", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_CLOCK_RESILIENCE_E2E !== "1", "Enable only with the disposable dev resilience shift fixture.");
    await page.addInitScript(() => {
      Object.defineProperty(navigator, "geolocation", {
        configurable: true,
        value: {
          getCurrentPosition: (_success: PositionCallback, error: PositionErrorCallback) => error({code: 1, message: "Permission denied", PERMISSION_DENIED: 1, POSITION_UNAVAILABLE: 2, TIMEOUT: 3} as GeolocationPositionError),
        },
      });
    });
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Time Clock/}).click();
    await expect(page.getByText("Codex Teacher Clock Resilience QA")).toBeVisible();
    await page.getByRole("button", {name: "Clock In Now"}).click();
    await expect(page.getByText(/Location access is required/)).toBeVisible();

    await context.grantPermissions(["geolocation"]);
    await context.setGeolocation({latitude: 40.7128, longitude: -74.006});
    const first = await context.newPage();
    const second = await context.newPage();
    await Promise.all([first.goto("/teacher/time-clock/"), second.goto("/teacher/time-clock/")]);
    await Promise.all([
      expect(first.getByText("Codex Teacher Clock Resilience QA")).toBeVisible(),
      expect(second.getByText("Codex Teacher Clock Resilience QA")).toBeVisible(),
    ]);
    await Promise.all([
      first.getByRole("button", {name: "Clock In Now"}).click(),
      second.getByRole("button", {name: "Clock In Now"}).click(),
    ]);
    await Promise.all([
      expect(first.getByText(/Successfully clocked in|already clocked in/)).toBeVisible(),
      expect(second.getByText(/Successfully clocked in|already clocked in/)).toBeVisible(),
    ]);
    await Promise.all([first.reload(), second.reload()]);
    await Promise.all([
      expect(first.getByRole("button", {name: "Clock Out"})).toBeVisible(),
      expect(second.getByRole("button", {name: "Clock Out"})).toBeVisible(),
    ]);
    await Promise.all([
      first.getByRole("button", {name: "Clock Out"}).click(),
      second.getByRole("button", {name: "Clock Out"}).click(),
    ]);
    await Promise.all([
      expect(first.getByText(/Successfully clocked out|No active clock-in|already been clocked out/)).toBeVisible(),
      expect(second.getByText(/Successfully clocked out|No active clock-in|already been clocked out/)).toBeVisible(),
    ]);
  });

  test("time clock reports offline submission and rejects a duplicate submit", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_TIMESHEET_SUBMIT_RESILIENCE_E2E !== "1", "Enable only with disposable dev draft fixtures.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Time Clock/}).click();

    const offlineRow = page.getByRole("row").filter({hasText: "Codex Offline Submission Student"}).first();
    await expect(offlineRow).toBeVisible();
    await context.setOffline(true);
    await offlineRow.getByRole("button", {name: /^Submit$/}).click();
    await page.getByRole("button", {name: "Submit for Review"}).click();
    await expect(page.getByText("You appear to be offline. Reconnect and try again.")).toBeVisible();
    await context.setOffline(false);
    await page.getByRole("button", {name: "Cancel"}).click();

    const second = await context.newPage();
    await second.goto("/teacher/time-clock/");
    const duplicateStudent = "Codex Duplicate Submission Student";
    const firstRow = page.getByRole("row").filter({hasText: duplicateStudent}).first();
    const secondRow = second.getByRole("row").filter({hasText: duplicateStudent}).first();
    await Promise.all([expect(firstRow).toBeVisible(), expect(secondRow).toBeVisible()]);
    await Promise.all([
      firstRow.getByRole("button", {name: /^Submit$/}).click(),
      secondRow.getByRole("button", {name: /^Submit$/}).click(),
    ]);
    await Promise.all([
      page.getByRole("button", {name: "Submit for Review"}).click(),
      second.getByRole("button", {name: "Submit for Review"}).click(),
    ]);
    await Promise.all([
      expect(page.getByText(/Timesheet submitted for review|already been submitted/)).toBeVisible(),
      expect(second.getByText(/Timesheet submitted for review|already been submitted/)).toBeVisible(),
    ]);
  });

  test("requires a teacher sign-in before rendering tasks", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/tasks/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Tasks" })).toBeHidden();
  });

  test("teacher can open the native tasks page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Tasks/ }).click();
    await expect(page).toHaveURL(/\/teacher\/tasks\/$/);
    await expect(page.getByRole("heading", { name: "Tasks" })).toBeVisible();
    await expect(page.getByLabel("Search tasks")).toBeVisible();
    await expect(page.getByRole("button", { name: "All Tasks" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Show filters" })).toBeVisible();
    const taskAction = page.getByRole("button", { name: "View and update" }).first();
    if (await taskAction.isVisible().catch(() => false)) {
      await taskAction.click();
      const dialog = page.getByRole("dialog", { name: /details$/ });
      await expect(dialog).toBeVisible();
      await expect(dialog.getByRole("heading", { name: "Update status" })).toBeVisible();
      await expect(dialog.getByRole("button", { name: "To Do" })).toBeVisible();
      await expect(dialog.getByRole("button", { name: "In Progress" })).toBeVisible();
      await expect(dialog.getByRole("button", { name: "Done" })).toBeVisible();
      await page.getByLabel("Close task details").click();
    }
  });

  test("assigned teacher can update a task status", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_TASK_WRITE_E2E !== "1", "Enable only with the disposable dev task fixture.");
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Tasks/ }).click();
    await page.getByLabel("Search tasks").fill("Codex Teacher Task Status QA");
    const task = page.locator("article").filter({hasText: "Codex Teacher Task Status QA"});
    await task.getByRole("button", {name: "View and update"}).click();
    const dialog = page.getByRole("dialog", {name: /Codex Teacher Task Status QA details/});
    await dialog.getByRole("button", {name: "In Progress"}).click();
    await expect(page.getByText("Task status updated")).toBeVisible();
    await expect(dialog.getByRole("button", {name: "In Progress"})).toBeDisabled();
    await dialog.getByRole("button", {name: "Done"}).click();
    await expect(page.getByText("Task submitted successfully")).toBeVisible();
    await expect(dialog.getByRole("button", {name: "Done"})).toBeDisabled();
  });

  test("teacher sees an actionable error when an open task becomes stale", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_TASK_RESILIENCE_E2E !== "1", "Enable only with the disposable dev task fixture.");
    await page.route("**/updateAssignedTaskStatus", (route) => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({error: {status: "NOT_FOUND", message: "Task not found"}}),
    }));
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Tasks/}).click();
    await page.getByLabel("Search tasks").fill("Codex Teacher Task Status QA");
    await page.locator("article").filter({hasText: "Codex Teacher Task Status QA"}).getByRole("button", {name: "View and update"}).click();
    const dialog = page.getByRole("dialog", {name: /Codex Teacher Task Status QA details/});
    const target = dialog.getByRole("button", {name: "Done"});
    if (await target.isDisabled()) await dialog.getByRole("button", {name: "To Do"}).click();
    else await target.click();
    await expect(dialog.getByRole("alert")).toHaveText("This task is no longer available. Close it and refresh your task list.");
  });

  test("teacher sees an actionable error after task assignment is revoked", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_TASK_RESILIENCE_E2E !== "1", "Enable only with the disposable dev task fixture.");
    await page.route("**/updateAssignedTaskStatus", (route) => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({error: {status: "PERMISSION_DENIED", message: "Only assigned users can update this task"}}),
    }));
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Tasks/}).click();
    await page.getByLabel("Search tasks").fill("Codex Teacher Task Status QA");
    await page.locator("article").filter({hasText: "Codex Teacher Task Status QA"}).getByRole("button", {name: "View and update"}).click();
    const dialog = page.getByRole("dialog", {name: /Codex Teacher Task Status QA details/});
    const target = dialog.getByRole("button", {name: "Done"});
    if (await target.isDisabled()) await dialog.getByRole("button", {name: "To Do"}).click();
    else await target.click();
    await expect(dialog.getByRole("alert")).toHaveText("You are no longer assigned to this task and cannot update it.");
  });

  test("requires a teacher sign-in before rendering job board", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/job-board/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "New Student Opportunities" })).toBeHidden();
  });

  test("teacher can open the native job board", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Job Board/ }).click();
    await expect(page).toHaveURL(/\/teacher\/job-board\/$/);
    await expect(page.getByRole("heading", { name: "New Student Opportunities" })).toBeVisible();
    await expect(page.getByText("Accept new students to fill your schedule")).toBeVisible();
    await expect(page.locator("text=/No opportunities right now|Submit availability|Filled Opportunities/").first()).toBeVisible();
  });

  test("job board filters targeted posts and handles offline and concurrent responses", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_JOB_RESILIENCE_E2E !== "1", "Enable only with disposable dev job fixtures.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Job Board/}).click();
    await expect(page.getByText("Codex Job Concurrency Student")).toBeVisible();
    await expect(page.getByText("Codex Hidden Target Student")).toBeHidden();

    const firstCard = page.locator("article").filter({hasText: "Codex Job Concurrency Student"});
    await firstCard.getByRole("button", {name: "Submit availability"}).click();
    await context.setOffline(true);
    await page.getByRole("dialog", {name: "Reply to broadcast"}).getByRole("button", {name: "Submit", exact: true}).click();
    await expect(page.getByText("You appear to be offline. Reconnect and try again.")).toBeVisible();
    await context.setOffline(false);
    await page.getByRole("dialog", {name: "Reply to broadcast"}).getByRole("button", {name: "Cancel"}).click();

    const second = await context.newPage();
    await second.goto("/teacher/job-board/");
    await Promise.all([
      firstCard.getByRole("button", {name: "Submit availability"}).click(),
      second.locator("article").filter({hasText: "Codex Job Concurrency Student"}).getByRole("button", {name: "Submit availability"}).click(),
    ]);
    const firstDialog = page.getByRole("dialog", {name: "Reply to broadcast"});
    const secondDialog = second.getByRole("dialog", {name: "Reply to broadcast"});
    await Promise.all([
      firstDialog.getByRole("button", {name: "Submit", exact: true}).click(),
      secondDialog.getByRole("button", {name: "Submit", exact: true}).click(),
    ]);
    await expect.poll(async () => Number(await firstDialog.isVisible()) + Number(await secondDialog.isVisible())).toBe(1);
    const losingPage = await firstDialog.isVisible() ? page : second;
    await expect(losingPage.getByText(/This opportunity is closed|not open for availability responses|You do not have permission to update this opportunity/)).toBeVisible();
  });

  test("teacher can review withdraw confirmation for an accepted job", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Job Board/ }).click();
    await expect(page).toHaveURL(/\/teacher\/job-board\/$/);
    const acceptedCard = page.locator("article").filter({ hasText: "Codex Job Board Withdraw QA" }).first();
    await acceptedCard.waitFor({ timeout: 10000 }).catch(() => null);
    test.skip(!(await acceptedCard.isVisible().catch(() => false)), "Codex Job Board Withdraw QA fixture is not seeded.");
    const withdrawButton = acceptedCard.getByRole("button", { name: "Withdraw & Re-broadcast" });
    await expect(withdrawButton).toBeEnabled();
    await withdrawButton.click();
    await expect(page.getByRole("dialog", { name: "Withdraw from this student?" })).toBeVisible();
    await expect(page.getByText("This will re-broadcast the opportunity to other teachers.")).toBeVisible();
    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(page.getByRole("dialog", { name: "Withdraw from this student?" })).toBeHidden();
  });

  test("teacher can withdraw and rebroadcast an accepted dev job", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_JOB_WRITE_E2E !== "1", "Enable only with the disposable dev job fixture.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Job Board/}).click();
    const acceptedCard = page.locator("article").filter({hasText: "Codex Teacher Job Lifecycle QA"});
    await acceptedCard.getByRole("button", {name: "Withdraw & Re-broadcast"}).click();
    await page.getByRole("dialog", {name: "Withdraw from this student?"}).getByRole("button", {name: "Withdraw", exact: true}).click();
    await expect(page.getByText("You have withdrawn. The job is now available for other teachers.")).toBeVisible();
    await expect(acceptedCard.getByRole("button", {name: "Submit availability"})).toBeVisible();
  });

  test("requires a teacher sign-in before rendering chat", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/chat/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("button", { name: "Recent Chats" })).toBeHidden();
  });

  test("teacher can open the native chat page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Chat/ }).click();
    await expect(page).toHaveURL(/\/teacher\/chat\/$/);
    await expect(page.getByRole("button", { name: "Recent Chats" })).toBeVisible();
    await expect(page.getByRole("button", { name: "My Contacts" })).toBeVisible();
    await expect(page.getByLabel("Search conversations and users")).toBeVisible();
    await expect(page.getByText(/No conversations yet|Admin Support|Administrators|Codex Chat/).first()).toBeVisible();
  });

  test("teacher can send an admin support chat message", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    const message = `Codex chat smoke ${Date.now()}`;
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Chat/ }).click();
    await expect(page).toHaveURL(/\/teacher\/chat\/$/);
    await page.getByRole("button", { name: "My Contacts" }).click();
    await page.getByRole("button", { name: /Admin Support/ }).click();
    await expect(page.getByRole("heading", { name: "Admin Support" })).toBeVisible();
    await page.getByLabel("Type a message").fill(message);
    await page.getByLabel("Send message").click();
    await expect(page.getByText(message)).toBeVisible();
  });

  test("failed offline chat send restores the teacher draft", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    const message = `Offline draft ${Date.now()}`;
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Chat/}).click();
    await page.getByRole("button", {name: "My Contacts"}).click();
    await page.getByRole("button", {name: /Admin Support/}).click();
    await context.setOffline(true);
    await page.getByLabel("Type a message").fill(message);
    await page.getByLabel("Send message").click();
    await expect(page.getByText("Message could not be sent. Please try again.")).toBeVisible();
    await expect(page.getByLabel("Type a message")).toHaveValue(message);
    await context.setOffline(false);
  });

  test("recent chats reorder live after the latest message changes", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_CHAT_ORDERING_E2E !== "1", "Enable only with disposable dev ordering fixtures.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Chat/}).click();
    const older = page.getByRole("button", {name: /Codex Chat Older Contact.*Older preview/i});
    const newer = page.getByRole("button", {name: /Codex Chat Newer Contact/i});
    await Promise.all([expect(older).toBeVisible(), expect(newer).toBeVisible()]);
    const before = await page.locator("section button").filter({hasText: /Codex Chat (Older|Newer) Contact/}).allTextContents();
    expect(before[0]).toContain("Codex Chat Newer Contact");
    await older.click();
    await page.getByLabel("Type a message").fill("Promoted preview");
    await page.getByLabel("Send message").click();
    await page.getByLabel("Back to chats").click();
    const promoted = page.getByRole("button", {name: /Codex Chat Older Contact.*Promoted preview/i});
    await expect(promoted).toBeVisible();
    await expect.poll(async () => {
      const after = await page.locator("section button").filter({hasText: /Codex Chat (Older|Newer) Contact/}).allTextContents();
      return after[0] ?? "";
    }).toContain("Codex Chat Older Contact");
  });

  test("mobile browser back returns from a conversation to the chat list", async ({ page }, testInfo) => {
    skipUnlessMobileTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.goto("/teacher/chat/");
    await page.getByRole("button", {name: "My Contacts"}).click();
    await page.getByRole("button", {name: /Admin Support/}).click();
    await expect(page.getByRole("heading", {name: "Admin Support"})).toBeVisible();
    await page.goBack();
    await expect(page.getByRole("heading", {name: "Admin Support"})).toBeHidden();
    await expect(page.getByRole("button", {name: "Recent Chats"})).toBeVisible();
    await expect(page).toHaveURL(/\/teacher\/chat\/$/);
  });

  test("opening a conversation clears incoming unread messages", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_CHAT_READ_E2E !== "1", "Enable only with the disposable dev chat fixture.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Chat/}).click();
    const chat = page.getByRole("button", {name: /codex_chat_sender_qa.*Unread fixture message/i});
    await expect(chat.getByText("1", {exact: true})).toBeVisible();
    await chat.click();
    await expect(page.getByRole("paragraph").filter({hasText: "Unread fixture message"})).toBeVisible();
    await page.getByLabel("Back to chats").click();
    await expect(chat.getByText("1", {exact: true})).toBeHidden();
  });

  test("teacher can send an image attachment in chat", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_CHAT_ATTACHMENT_E2E !== "1", "Enable only for disposable dev chat uploads.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Chat/}).click();
    await page.getByRole("button", {name: "My Contacts"}).click();
    await page.getByRole("button", {name: /Admin Support/}).click();
    await page.locator("input[type=file]").setInputFiles({
      name: "codex-chat-attachment-qa.png",
      mimeType: "image/png",
      buffer: Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=", "base64"),
    });
    await expect(page.getByText("📷 Photo").last()).toBeVisible();
    await expect(page.getByRole("img", {name: "📷 Photo"})).toBeVisible();
  });

  test("requires a teacher sign-in before rendering classes", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/classes/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Classes" })).toBeHidden();
  });

  test("teacher can open the native classes page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Classes/ }).click();
    await expect(page).toHaveURL(/\/teacher\/classes\/$/);
    await expect(page.getByRole("heading", { name: "Classes", exact: true })).toBeVisible();
    await expect(page.getByLabel("Class Recordings")).toBeVisible();
    await expect(page.locator("text=/No Classes Right Now|Upcoming|In Progress|^Scheduled$/").first()).toBeVisible();
    const presenceCard = page.locator("article").filter({ hasText: "Codex Classroom Presence QA" }).first();
    if (await presenceCard.isVisible().catch(() => false)) {
      await expect(presenceCard.getByText("Live participants")).toBeVisible();
      await page.context().grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(page.url()).origin });
      await presenceCard.getByLabel(/Copy class link for Codex Classroom Presence QA/).click();
      const copiedLink = await page.evaluate(() => navigator.clipboard.readText());
      expect(copiedLink).toContain("/classroom/join/");
      expect(copiedLink).toContain("guestShift=codex_teacher_classroom_presence_current");
      await presenceCard.getByLabel(/Class details for Codex Classroom Presence QA/).click();
      await expect(page.getByRole("dialog", { name: "Class details" })).toBeVisible();
      await expect(page.getByText(/Currently in Class/)).toBeVisible();
      await expect(page.getByText(/No one has joined yet|in class/).first()).toBeVisible();
      await page.getByLabel("Close class details").click();
    }
  });

  test("requires a teacher sign-in before joining a classroom", async ({ page }) => {
    await gotoTeacherGuard(page, "/teacher/classroom/?shiftId=teacher-classroom-guard");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
  });

  test("Zoom provider classroom routes through the existing Zoom host with a return path", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_ZOOM_ROUTING_E2E !== "1", "Enable only with the disposable dev Zoom-provider shift.");
    await page.route("**/getZoomJoinInfo", (route) => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({result: {
        success: true,
        meetingNumber: "12345678901",
        password: "codex-pass",
        signature: "codex-signature",
        sdkKey: "codex-sdk-key",
        displayName: "Codex CMS Staff",
        customerKey: "uZyvgk7VBeRrhsZfYAzGfOSRCJo2",
        shiftName: "Codex Zoom Routing QA",
        breakoutRoomName: "Codex Student Room",
        breakoutRoomKey: "codex-room-key",
        autoJoinBreakoutRoom: true,
        classEndsAtIso: "2026-07-12T06:00:00.000Z",
      }}),
    }));
    await signInAsTeacher(page);
    await page.goto("/teacher/classroom/?shiftId=codex_teacher_zoom_routing_qa");
    await expect.poll(() => page.url()).toMatch(/\/zoom_meeting(?:\.html)?(?:\?join=\d+)?#/);
    expect(page.url()).toContain("returnUrl=http%3A%2F%2F127.0.0.1%3A3021%2Fteacher%2Fclasses%2F");
    expect(page.url()).toContain("breakoutRoomKey=codex-room-key");
    expect(page.url()).toContain("autoJoinBreakoutRoom=1");
    await page.goto("/teacher/classes/");
    await expect(page.getByRole("heading", {name: "Classes", exact: true})).toBeVisible();
  });

  test("requires a teacher sign-in before rendering recordings", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/recordings/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Students" })).toBeHidden();
  });

  test("teacher can open the native recordings page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Recordings/ }).click();
    await expect(page).toHaveURL(/\/teacher\/recordings\/$/);
    await expect(page.getByRole("heading", { name: "Students" })).toBeVisible();
    await expect(page.getByLabel("Refresh recordings")).toBeVisible();
    await expect(page.getByText(/No recordings yet|recording/).first()).toBeVisible();
  });

  test("recordings reports a missing playback URL", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await mockTeacherRecordingList(page);
    await page.route("**/getClassRecordingPlaybackUrl", (route) => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({result: {success: true, url: ""}}),
    }));
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Recordings/}).click();
    await openPlaybackFixture(page);
    await page.getByRole("button", {name: "Play", exact: true}).click();
    await expect(page.getByText("Playback URL not available")).toBeVisible();
  });

  test("recordings reports browser playback failure", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await mockTeacherRecordingList(page);
    await page.route("**/getClassRecordingPlaybackUrl", (route) => route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({result: {success: true, url: "https://recording.invalid/codex-missing.mp4"}}),
    }));
    await page.route("https://recording.invalid/**", (route) => route.abort("failed"));
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Recordings/}).click();
    await openPlaybackFixture(page);
    await page.getByRole("button", {name: "Play", exact: true}).click();
    await expect(page.getByText("This recording could not be played. Refresh its playback link and try again.")).toBeVisible();
  });

  test("requires a teacher sign-in before rendering surah podcasts", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/surah-podcasts/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Surah Content" })).toBeHidden();
  });

  test("teacher can open the native surah podcasts page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Surah Podcasts/ }).click();
    await expect(page).toHaveURL(/\/teacher\/surah-podcasts\/$/);
    await expect(page.getByRole("heading", { name: "Surah Content" })).toBeVisible();
    await expect(page.getByRole("button", { name: /Library/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /Shared/ })).toBeVisible();
    await expect(page.getByLabel("Refresh surah podcasts")).toBeVisible();
    await expect(page.getByText(/No content available|Surah [0-9]|No results found/).first()).toBeVisible();
  });

  test("teacher can share and unshare Surah content", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SURAH_WRITE_E2E !== "1", "Enable only with disposable dev podcast and shift fixtures.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Surah Podcasts/}).click();
    await page.getByLabel("Search by surah name or number").fill("Codex Surah Share QA");
    await page.getByRole("button", {name: /Surah 114/}).click();
    await page.getByLabel("Share Codex Surah Share QA with students").click();
    const dialog = page.getByRole("dialog", {name: "Share with Students"});
    const selectionStatus = dialog.getByText(/^[01] of 1 selected$/);
    await expect(selectionStatus).toBeVisible();
    const shareOne = dialog.getByRole("button", {name: "Share (1)"});
    if ((await selectionStatus.textContent())?.startsWith("0")) {
      await dialog.getByRole("button", {name: "Codex Surah Student QA"}).click();
    }
    await shareOne.click();
    await page.getByRole("button", {name: "Back to surah library"}).click();
    await page.getByRole("button", {name: /Shared/}).click();
    await expect(page.getByText("Codex Surah Share QA")).toBeVisible();
    await page.getByLabel("Remove Codex Surah Share QA").click();
    await expect(page.getByText("Codex Surah Share QA")).toBeHidden();
  });

  test("Surah sharing preserves state across offline failures and empty selection", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SURAH_RESILIENCE_E2E !== "1", "Enable only with disposable dev Surah fixtures.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Surah Podcasts/}).click();
    await page.getByRole("button", {name: /Shared/}).click();
    await expect(page.getByText("Codex Surah Resilience QA")).toBeVisible();
    await context.setOffline(true);
    await page.getByLabel("Remove Codex Surah Resilience QA").click();
    await expect(page.getByText("You appear to be offline. Reconnect and try again.")).toBeVisible();
    await expect(page.getByText("Codex Surah Resilience QA")).toBeVisible();
    await context.setOffline(false);

    await page.getByRole("button", {name: /Library/}).click();
    await page.getByLabel("Search by surah name or number").fill("Codex Surah Resilience QA");
    await page.getByRole("button", {name: /113.*Al-Falaq/}).click();
    await page.getByLabel("Share Codex Surah Resilience QA with students").click();
    const dialog = page.getByRole("dialog", {name: "Share with Students"});
    await dialog.getByRole("button", {name: "Codex Surah Resilience Student"}).click();
    await expect(dialog.getByRole("button", {name: "Share (0)"})).toBeDisabled();
    await dialog.getByRole("button", {name: "Codex Surah Resilience Student"}).click();
    await context.setOffline(true);
    await dialog.getByRole("button", {name: "Share (1)"}).click();
    await expect(dialog.getByText("You appear to be offline. Reconnect and try again.")).toBeVisible();
    await expect(dialog.getByText("1 of 1 selected")).toBeVisible();
    await context.setOffline(false);
  });

  test("Surah share dialog fits the mobile viewport", async ({ page }, testInfo) => {
    skipUnlessMobileTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SURAH_RESILIENCE_E2E !== "1", "Enable only with disposable dev Surah fixtures.");
    await signInAsTeacher(page);
    await page.goto("/teacher/surah-podcasts/");
    await page.getByLabel("Search by surah name or number").fill("Codex Surah Resilience QA");
    await page.getByRole("button", {name: /113.*Al-Falaq/}).click();
    await page.getByLabel("Share Codex Surah Resilience QA with students").click();
    const dialog = page.getByRole("dialog", {name: "Share with Students"});
    await expect(dialog).toBeVisible();
    const box = await dialog.locator("section").boundingBox();
    expect(box).not.toBeNull();
    expect((box?.y ?? 0) + (box?.height ?? 0)).toBeLessThanOrEqual(testInfo.project.use.viewport?.height ?? 720);
    await expect(dialog.getByRole("button", {name: /Share \([01]\)/})).toBeVisible();
  });

  test("requires a teacher sign-in before rendering curriculum books", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/curriculum-books/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Curriculum Books" })).toBeHidden();
  });

  test("teacher can open the native curriculum books page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Curriculum Books/ }).click();
    await expect(page).toHaveURL(/\/teacher\/curriculum-books\/$/);
    await expect(page.getByRole("heading", { name: "Curriculum Books" })).toBeVisible();
    await expect(page.getByText("Shared Learning Materials")).toBeVisible();
    await expect(page.getByText("PowerPoint files")).toBeVisible();
    await expect(page.getByRole("link", { name: /Open/ }).first()).toBeVisible();
    await expect(page.getByRole("link", { name: /Download/ }).first()).toBeVisible();
  });

  test("curriculum open and download targets resolve and navigate", async ({ page, request }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Curriculum Books/}).click();
    const links = page.getByRole("link", {name: /Open|Download/});
    await expect(links).toHaveCount(8);
    const hrefs = await links.evaluateAll((anchors) => anchors.map((anchor) => (anchor as HTMLAnchorElement).href.replace(/#.*$/, "")));
    for (const href of hrefs) {
      const response = await request.head(href);
      expect(response.ok(), `${href} should resolve`).toBe(true);
      expect(Number(response.headers()["content-length"] ?? 0)).toBeGreaterThan(0);
    }
    await expect(page.getByRole("link", {name: "Open"}).first()).toHaveAttribute("href", /alphabet_and_fatha\.pdf#view=Fit$/);
    await expect(page.getByRole("link", {name: "Open"}).first()).toHaveAttribute("target", "_blank");
    await expect(page.getByRole("link", {name: "Download"}).first()).toHaveAttribute("href", /alphabet_and_fatha\.pptx$/);
  });

  test("requires a teacher sign-in before rendering submit form", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/submit-form/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Forms Reports" })).toBeHidden();
  });

  test("teacher can open the native submit form page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", { name: /Submit Form/ }).click();
    await expect(page).toHaveURL(/\/teacher\/submit-form\/$/);
    await expect(page.getByRole("heading", { name: "Forms Reports" })).toBeVisible();
    await expect(page.getByLabel("Search forms")).toBeVisible();
    await expect(page.getByText("Teaching Reports")).toBeVisible();
    await expect(page.getByText(/Daily Class Report|No active forms match your search/).first()).toBeVisible();
    await page.getByLabel("Search forms").fill("Codex Time Field QA");
    await page.getByRole("button", { name: /Codex Time Field QA/ }).click();
    await expect(page.getByRole("heading", { name: "Codex Time Field QA" })).toBeVisible();
    await expect(page.locator("input[type='time']")).toBeVisible();
    await page.getByLabel("Close form").click();
    await page.getByLabel("Search forms").fill("Codex Upload Field QA");
    await page.getByRole("button", { name: /Codex Upload Field QA/ }).click();
    await expect(page.getByRole("heading", { name: "Codex Upload Field QA" })).toBeVisible();
    await expect(page.getByLabel("Session photo")).toBeAttached();
    await expect(page.getByLabel("Teacher signature")).toBeAttached();
    let browserAlertShown = false;
    page.once("dialog", async (dialog) => {
      browserAlertShown = true;
      await dialog.dismiss();
    });
    await page.getByLabel("Session photo").setInputFiles({
      name: "not-an-image.txt",
      mimeType: "text/plain",
      buffer: Buffer.from("not an image"),
    });
    await expect(page.getByText("Please choose an image file.")).toBeVisible();
    expect(browserAlertShown).toBe(false);
  });

  test("teacher form validates email and phone fields like Flutter", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_FORM_VALIDATION_E2E !== "1", "Enable only with the disposable dev form template.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Submit Form/}).click();
    await page.getByLabel("Search forms").fill("Codex Teacher Validation QA");
    await page.getByRole("button", {name: /Codex Teacher Validation QA/}).click();
    await page.getByLabel("Contact email").fill("invalid-email");
    await page.getByLabel("Contact phone").fill("invalid phone!");
    await page.getByRole("button", {name: "Submit Form", exact: true}).click();
    await expect(page.getByText("Please enter a valid email address")).toBeVisible();
    await expect(page.getByText("Please enter a valid phone number")).toBeVisible();
  });

  test("offline form submission keeps entered values available to retry", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /Submit Form/}).click();
    await page.getByLabel("Search forms").fill("Codex Time Field QA");
    await page.getByRole("button", {name: /Codex Time Field QA/}).click();
    await page.getByLabel("What time should the makeup class start?").fill("14:30");
    await page.getByLabel("Reason").fill("Offline retry verification");
    await context.setOffline(true);
    await page.getByRole("button", {name: "Submit Form", exact: true}).click();
    await expect(page.getByText("You appear to be offline. Reconnect and try again.")).toBeVisible();
    await expect(page.getByLabel("What time should the makeup class start?")).toHaveValue("14:30");
    await expect(page.getByLabel("Reason")).toHaveValue("Offline retry verification");
    await context.setOffline(false);
  });

  test("per-session form submission rejects a concurrent duplicate", async ({ page, context }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_FORM_DUPLICATE_E2E !== "1", "Enable only with disposable dev form and shift fixtures.");
    await signInAsTeacher(page);
    const second = await context.newPage();
    await Promise.all([page.goto("/teacher/submit-form/"), second.goto("/teacher/submit-form/")]);
    for (const target of [page, second]) {
      await target.getByLabel("Search forms").fill("Codex Duplicate Form QA");
      await target.getByRole("button", {name: /Codex Duplicate Form QA/}).click();
      const shift = target.locator("article").filter({hasText: "Codex Duplicate Form Student"});
      await shift.getByRole("button", {name: "Form", exact: true}).click();
      await target.getByLabel("Session summary").fill("Concurrent submission QA");
    }
    await Promise.all([
      page.getByRole("button", {name: "Submit Form", exact: true}).click(),
      second.getByRole("button", {name: "Submit Form", exact: true}).click(),
    ]);
    await Promise.all([
      expect(page.getByText(/Form submitted successfully|already been submitted/)).toBeVisible(),
      expect(second.getByText(/Form submitted successfully|already been submitted/)).toBeVisible(),
    ]);
  });

  test("requires a teacher sign-in before rendering my form submissions", async ({ page, browserName }) => {
    test.skip(browserName === "webkit", "WebKit intermittently hangs before committing teacher module static routes late in the full suite; Chromium and mobile Chrome cover the guard.");
    await gotoTeacherGuard(page, "/teacher/form-submissions/");
    await expect(page.getByRole("heading", { name: "Teacher sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "My Form Submissions" })).toBeHidden();
  });

  test("teacher can open the native my form submissions page", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    await signInAsTeacher(page);
    await page.getByRole("navigation", {name: "Teacher dashboard navigation"}).getByRole("link", {name: "My Form Submissions"}).click();
    await expect(page).toHaveURL(/\/teacher\/form-submissions\/$/);
    await expect(page.getByRole("heading", { name: "My Form Submissions" })).toBeVisible();
    await expect(page.getByLabel("Search by form name or status")).toBeVisible();
    await expect(page.getByText(/No form submissions yet|submission/).first()).toBeVisible();
    const viewAll = page.getByRole("button", { name: "View All" });
    if (await viewAll.isVisible().catch(() => false)) await viewAll.click();
    await page.getByLabel("Search by form name or status").fill("Codex Time Field QA");
    const timeFieldGroup = page.getByRole("button", { name: /Codex Time Field QA/ });
    const noResults = page.getByRole("heading", { name: "No results found" });
    await expect(timeFieldGroup.or(noResults)).toBeVisible();
    if (await noResults.isVisible().catch(() => false)) return;
    await timeFieldGroup.click();
    const groupDialog = page.getByRole("dialog", { name: "Codex Time Field QA" });
    await expect(groupDialog).toBeVisible();
    await groupDialog.getByRole("button", { name: /completed/i }).first().click();
    await expect(page.getByRole("dialog", { name: /Codex Time Field QA details/ })).toBeVisible();
    await expect(page.getByText("What time should the makeup class start?")).toBeVisible();
    await expect(page.getByText("Class Start Time")).toBeHidden();
  });

  test("teacher submission details render uploaded files", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SUBMISSION_FILE_E2E !== "1", "Enable only with the disposable dev response fixture.");
    await signInAsTeacher(page);
    await page.getByRole("navigation", {name: "Teacher dashboard navigation"}).getByRole("link", {name: "My Form Submissions"}).click();
    const group = page.getByRole("button", {name: /Codex Teacher File Response QA/});
    await group.click();
    await page.getByRole("dialog", {name: "Codex Teacher File Response QA"}).getByRole("button").filter({hasText: /completed/i}).click();
    const details = page.getByRole("dialog", {name: /Codex Teacher File Response QA details/});
    await expect(details.getByText("Session photo")).toBeVisible();
    await expect(details.getByRole("img", {name: "qa-photo.png"})).toBeVisible();
    await expect(details.getByRole("link", {name: "qa-photo.png"})).toBeVisible();
  });

  test("form submissions render missing-template legacy and empty responses", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SUBMISSION_LEGACY_E2E !== "1", "Enable only with disposable dev legacy response fixtures.");
    await signInAsTeacher(page);
    await page.getByRole("navigation", {name: "Teacher dashboard navigation"}).getByRole("link", {name: "My Form Submissions"}).click();
    await page.getByLabel("Search by form name or status").fill("Codex Missing Template QA");
    await page.getByRole("button", {name: /Codex Missing Template QA/}).click();
    await page.getByRole("dialog", {name: "Codex Missing Template QA"}).getByRole("button").filter({hasText: /completed/i}).click();
    const legacyDetails = page.getByRole("dialog", {name: /Codex Missing Template QA details/});
    await expect(legacyDetails.getByText("Legacy Question")).toBeVisible();
    await expect(legacyDetails.getByText("Legacy response value")).toBeVisible();
    await legacyDetails.getByLabel("Close").click();

    await page.getByLabel("Search by form name or status").fill("Codex Empty Legacy QA");
    await page.getByRole("button", {name: /Codex Empty Legacy QA/}).click();
    await page.getByRole("dialog", {name: "Codex Empty Legacy QA"}).getByRole("button").filter({hasText: /completed/i}).click();
    await expect(page.getByRole("dialog", {name: /Codex Empty Legacy QA details/}).getByText("No responses recorded")).toBeVisible();
  });
});

async function mockTeacherRecordingList(page: Page) {
  await page.route("**/listClassRecordings", (route) => route.fulfill({
    status: 200,
    contentType: "application/json",
    body: JSON.stringify({result: {
      success: true,
      recordings: [{
        recordingId: "codex-recording-playback-qa",
        shiftId: "codex-recording-shift-qa",
        shiftName: "Codex Playback QA",
        subjectName: "Quran",
        teacherId: "uZyvgk7VBeRrhsZfYAzGfOSRCJo2",
        teacherName: "Codex CMS Staff",
        studentIds: [],
        status: "complete",
        mergeStatus: "complete",
        error: "",
        filePath: "recordings/codex-playback-qa.mp4",
        startedAtIso: "2026-07-12T03:30:00.000Z",
        requestedAtIso: "2026-07-12T03:29:00.000Z",
        updatedAtIso: "2026-07-12T03:31:00.000Z",
        deleteAfterIso: "2026-08-12T03:30:00.000Z",
        canPlay: true,
      }],
    }}),
  }));
}

async function openPlaybackFixture(page: Page) {
  await page.getByRole("button", {name: /Unknown student/}).click();
  await page.getByRole("button", {name: /Jul 11, 2026/}).click();
  await page.getByRole("button", {name: /Codex Playback QA/}).click();
}
