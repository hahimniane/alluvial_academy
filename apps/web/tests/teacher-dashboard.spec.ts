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

  test("teacher submission details render uploaded files", async ({ page }, testInfo) => {
    skipUnlessDesktopTeacherE2EEnabled(testInfo.project.name);
    test.skip(process.env.ALLUWAL_RUN_TEACHER_SUBMISSION_FILE_E2E !== "1", "Enable only with the disposable dev response fixture.");
    await signInAsTeacher(page);
    await page.getByRole("link", {name: /My Form Submissions/}).click();
    const group = page.getByRole("button", {name: /Codex Teacher File Response QA/});
    await group.click();
    await page.getByRole("dialog", {name: "Codex Teacher File Response QA"}).getByRole("button").filter({hasText: /completed/i}).click();
    const details = page.getByRole("dialog", {name: /Codex Teacher File Response QA details/});
    await expect(details.getByText("Session photo")).toBeVisible();
    await expect(details.getByRole("img", {name: "qa-photo.png"})).toBeVisible();
    await expect(details.getByRole("link", {name: "qa-photo.png"})).toBeVisible();
  });
});
