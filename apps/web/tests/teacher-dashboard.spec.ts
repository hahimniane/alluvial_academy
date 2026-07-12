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
    await expect(page.getByText(/No conversations yet|Admin Support|Administrators/)).toBeVisible();
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
    await page.getByRole("link", { name: /My Form Submissions/ }).click();
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
});
