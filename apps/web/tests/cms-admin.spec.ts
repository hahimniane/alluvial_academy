import { expect, type Page, test } from "@playwright/test";

const adminEmail = process.env.ALLUWAL_E2E_EMAIL ?? "";
const adminPassword = process.env.ALLUWAL_E2E_PASSWORD ?? "";
const linkedUserUid = process.env.ALLUWAL_E2E_LINKED_USER_UID ?? "";
const linkedUserSearch = process.env.ALLUWAL_E2E_LINKED_USER_SEARCH ?? adminEmail;

async function signInAndOpenCms(page: Page) {
  await page.goto("/login/");
  await page.locator("input[type='email']").fill(adminEmail);
  await page.locator("input[type='password']").fill(adminPassword);
  await page.getByRole("button", { name: "Sign In" }).click();
  await expect(page).toHaveURL(/\/(app\/#\/login|admin\/?)$/);
  await page.goto("/admin/public-site-cms/");
  await expect(page.getByRole("heading", { name: "Pricing" })).toBeVisible();
}

async function signInAndOpenAdmin(page: Page) {
  await page.goto("/login/");
  await page.locator("input[type='email']").fill(adminEmail);
  await page.locator("input[type='password']").fill(adminPassword);
  await page.getByRole("button", { name: "Sign In" }).click();
  await expect(page).toHaveURL(/\/(app\/#\/login|admin\/?)$/);
  await page.goto("/admin/");
  await expect(page.getByText(/Welcome Back|Dashboard/i).first()).toBeVisible({ timeout: 20_000 });
}

function skipUnlessAdminDashboardEnabled() {
  test.skip(
    process.env.ALLUWAL_RUN_ADMIN_CMS_E2E !== "1" || !adminEmail || !adminPassword,
    "Set ALLUWAL_RUN_ADMIN_CMS_E2E=1, ALLUWAL_E2E_EMAIL, and ALLUWAL_E2E_PASSWORD for admin dashboard testing.",
  );
}

function skipUnlessAdminCmsWriteEnabled(projectName: string) {
  test.skip(projectName !== "chromium", "Admin CMS write verification only runs once in Chromium.");
  test.skip(
    process.env.ALLUWAL_RUN_ADMIN_CMS_E2E !== "1" || !adminEmail || !adminPassword,
    "Set ALLUWAL_RUN_ADMIN_CMS_E2E=1, ALLUWAL_E2E_EMAIL, and ALLUWAL_E2E_PASSWORD for admin CMS write testing.",
  );
}

test.describe("public site CMS admin module", () => {
  test("requires an admin sign-in before rendering the admin dashboard", async ({ page }) => {
    await page.goto("/admin/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: /Welcome Back/i })).toBeHidden();
  });

  test("authenticated admin dashboard links to the public site CMS module", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await expect(page.getByRole("heading", { name: "Public pricing & team" })).toBeVisible();
    await expect(page.getByRole("link", { name: /Pricing & public team/i }).first()).toHaveAttribute(
      "href",
      "/admin/public-site-cms/",
    );
    await expect(page.getByRole("link", { name: /Open editor/i })).toHaveAttribute(
      "href",
      "/admin/public-site-cms/",
    );
  });

  test("admin dashboard sidebar search filters navigation items", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    const nav = page.getByRole("navigation", { name: "Admin dashboard navigation" });

    await page.getByLabel("Search dashboard").fill("surah");

    await expect(nav.getByRole("link", { name: "Surah Podcasts" })).toBeVisible();
    await expect(nav.getByRole("link", { name: "Users" })).toHaveCount(0);

    await page.getByRole("button", { name: "Clear search" }).click();

    await expect(nav.getByRole("link", { name: "Users" })).toBeVisible();
    await expect(nav.getByRole("link", { name: "Surah Podcasts" })).toBeVisible();
  });

  test("admin dashboard sidebar sections collapse and reset", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    const nav = page.getByRole("navigation", { name: "Admin dashboard navigation" });

    await page.getByRole("button", { name: "Collapse Communication" }).click();

    await expect(nav.getByRole("link", { name: "Chat" })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Expand Communication" })).toBeVisible();

    await page.getByLabel("Search dashboard").fill("surah");
    await expect(nav.getByRole("link", { name: "Surah Podcasts" })).toBeVisible();

    await page.getByRole("button", { name: "Reset Layout" }).click();

    await expect(nav.getByRole("link", { name: "Chat" })).toBeVisible();
    await expect(page.getByLabel("Search dashboard")).toHaveValue("");
  });

  test("admin dashboard sidebar can pin favorite items", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);

    await page.getByRole("button", { name: "Pin Users" }).click();

    const favorites = page.getByLabel("Pinned dashboard items");
    await expect(favorites.getByText("Favorites")).toBeVisible();
    await expect(favorites.getByRole("link", { name: "Users" })).toBeVisible();

    await favorites.getByRole("button", { name: "Unpin Users" }).click();
    await expect(page.getByLabel("Pinned dashboard items")).toHaveCount(0);

    await page.getByRole("button", { name: "Pin Users" }).click();
    await page.getByRole("button", { name: "Reset Layout" }).click();
    await expect(page.getByLabel("Pinned dashboard items")).toHaveCount(0);
  });

  test("requires an admin sign-in before rendering the CMS editor", async ({ page }) => {
    const errors: string[] = [];
    page.on("console", (message) => {
      if (message.type() === "error") errors.push(message.text());
    });
    page.on("pageerror", (error) => errors.push(error.message));

    await page.goto("/admin/public-site-cms/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Pricing" })).toBeHidden();

    expect(errors).toEqual([]);
  });

  test("requires an admin sign-in before rendering users", async ({ page }) => {
    await page.goto("/admin/users/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "User Management" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering shifts", async ({ page }) => {
    await page.goto("/admin/shifts/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Shift Management" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering timesheets", async ({ page }) => {
    await page.goto("/admin/timesheets/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Timesheet Review" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering tasks", async ({ page }) => {
    await page.goto("/admin/tasks/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Tasks" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering audits", async ({ page }) => {
    await page.goto("/admin/audits/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Audit Management" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering chat", async ({ page }) => {
    await page.goto("/admin/chat/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("button", { name: "Recent Chats" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering classes", async ({ page }) => {
    await page.goto("/admin/classes/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Classes", exact: true })).toBeHidden();
  });

  test("requires an admin sign-in before rendering recordings", async ({ page }) => {
    await page.goto("/admin/recordings/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Teachers" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering surah podcasts", async ({ page }) => {
    await page.goto("/admin/surah-podcasts/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Surah Library" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering curriculum books", async ({ page }) => {
    await page.goto("/admin/curriculum-books/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Curriculum Books" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering notifications", async ({ page }) => {
    await page.goto("/admin/notifications/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Send Notification" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering form builder", async ({ page }) => {
    await page.goto("/admin/form-builder/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Form Templates" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering all submissions", async ({ page }) => {
    await page.goto("/admin/all-submissions/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "All Submissions (Admin)" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering submit form", async ({ page }) => {
    await page.goto("/admin/submit-form/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Forms Reports" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering invoices", async ({ page }) => {
    await page.goto("/admin/invoices/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Create Invoice" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering circles", async ({ page }) => {
    await page.goto("/admin/circles/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Pricing" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering student applicants", async ({ page }) => {
    await page.goto("/admin/student-applicants/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Student Applicants" })).toBeHidden();
  });

  test("requires an admin sign-in before rendering teacher applicants", async ({ page }) => {
    await page.goto("/admin/teacher-applicants/");
    await expect(page.getByRole("heading", { name: "Admin sign-in required" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Go to login" })).toHaveAttribute("href", "/login/");
    await expect(page.getByRole("heading", { name: "Teacher Applicants" })).toBeHidden();
  });

  test("authenticated admin can open student applicants", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Student Applicants" }).click();
    await expect(page).toHaveURL(/\/admin\/student-applicants\/$/);
    await expect(page.getByRole("heading", { name: "Student Applicants" })).toBeVisible();
    await expect(page.getByRole("button", { name: /Inbox/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Ready/i })).toBeVisible();
    await expect(page.getByRole("button", { name: /Live/i })).toBeVisible();
  });

  test("authenticated admin can open users", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.goto("/admin/users/");
    await expect(page).toHaveURL(/\/admin\/users\/$/);
    await expect(page.getByRole("heading", { name: "User Management" })).toBeVisible();
    await expect(page.getByRole("button", { name: /^USERS \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^ADMINS \(/ })).toBeVisible();
    await expect(page.getByLabel("Search users")).toBeVisible();
  });

  test("authenticated admin can filter users by parent", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.goto("/admin/users/");

    await page.getByRole("button", { name: "Filter By Parent" }).click();
    const dialog = page.getByRole("dialog", { name: "Filter By Parent" });
    await expect(dialog.getByLabel("Search parents")).toBeVisible();

    const parentRows = dialog.locator("button").filter({ hasText: /\d+ students?/ });
    if ((await parentRows.count()) === 0) {
      await expect(dialog.getByText("No parents found")).toBeVisible();
      return;
    }

    const linkedParentRows = dialog.locator("button").filter({ hasText: /[1-9][0-9]* students?/ });
    if ((await linkedParentRows.count()) > 0) {
      await linkedParentRows.first().click();
    } else {
      await parentRows.first().click();
    }

    await expect(page.getByText(/^Parent filter:/)).toBeVisible();
    await expect(page.getByRole("button", { name: "Clear" })).toBeVisible();
    await page.getByRole("button", { name: "Clear" }).click();
    await expect(page.getByText(/^Parent filter:/)).toHaveCount(0);
  });

  test("authenticated admin can open shifts", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Shifts", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/shifts\/$/);
    await expect(page.getByRole("heading", { name: "Shift Management" })).toBeVisible();
    await expect(page.getByRole("button", { name: /^All Shifts \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^Today \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^Upcoming \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^Active \(/ })).toBeVisible();
    await expect(page.getByLabel("Search users or shifts")).toBeVisible();
  });

  test("authenticated admin can open timesheets", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Timesheets", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/timesheets\/$/);
    await expect(page.getByRole("heading", { name: "Timesheet Review" })).toBeVisible();
    await expect(page.getByRole("button", { name: /^All \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^Pending \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^Approved \(/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /^Rejected \(/ })).toBeVisible();
    await expect(page.getByLabel("Search timesheets")).toBeVisible();
  });

  test("authenticated admin can open tasks", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Tasks", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/tasks\/$/);
    await expect(page.getByRole("heading", { name: "Tasks" })).toBeVisible();
    await expect(page.getByRole("button", { name: "All Tasks" })).toBeVisible();
    await expect(page.getByRole("button", { name: "My Tasks" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Today" })).toBeVisible();
    await expect(page.getByLabel("Search tasks")).toBeVisible();
    await expect(page.getByRole("button", { name: "Add Task" })).toBeVisible();
  });

  test("authenticated admin can open audits", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Audits", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/audits\/$/);
    await expect(page.getByRole("heading", { name: "Audit Management" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Teachers" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Admins" })).toBeVisible();
    await expect(page.getByLabel("Search audits")).toBeVisible();
    await expect(page.getByRole("button", { name: "Generate Audits" })).toBeVisible();
  });

  test("authenticated admin can open chat", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Chat", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/chat\/$/);
    await expect(page.getByRole("button", { name: "Recent Chats" })).toBeVisible();
    await expect(page.getByRole("button", { name: "My Contacts" })).toBeVisible();
    await expect(page.getByLabel("Search conversations and users")).toBeVisible();
    await expect(page.getByRole("button", { name: "Create Group" })).toBeVisible();
  });

  test("authenticated admin can open classes", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Classes", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/classes\/$/);
    await expect(page.getByRole("heading", { name: "Classes", exact: true })).toBeVisible();
    await expect(page.getByLabel("Search classes teacher student subject")).toBeVisible();
    await expect(page.getByRole("button", { name: "Filters" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Your classes" })).toBeVisible();
  });

  test("authenticated admin can open recordings", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Recordings", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/recordings\/$/);
    await expect(page.getByRole("heading", { name: "Teachers" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Refresh recordings" })).toBeVisible();
    await expect(page.getByText(/\d+ teachers?$/)).toBeVisible();
  });

  test("authenticated admin can open surah podcasts", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Surah Podcasts", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/surah-podcasts\/$/);
    await expect(page.getByRole("heading", { name: "Surah Library" })).toBeVisible();
    await expect(page.getByLabel("Search by surah name or number")).toBeVisible();
    await expect(page.getByRole("button", { name: "Add Content" })).toBeVisible();
  });

  test("authenticated admin can open curriculum books", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Curriculum Books", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/curriculum-books\/$/);
    await expect(page.getByRole("heading", { name: "Curriculum Books" })).toBeVisible();
    await expect(page.getByText("Shared Learning Materials")).toBeVisible();
    await expect(page.getByRole("link", { name: "Open" }).first()).toBeVisible();
    await expect(page.getByRole("link", { name: "Download" }).first()).toBeVisible();
  });

  test("authenticated admin can open notifications", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Notifications", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/notifications\/$/);
    await expect(page.getByRole("heading", { name: "Send Notification" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Compose Notification" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Select User" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Send Notification" })).toBeVisible();
  });

  test("authenticated admin can open form builder", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Form Builder", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/form-builder\/$/);
    await expect(page.getByRole("heading", { name: "Form Templates" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Create Form" }).first()).toBeVisible();
    await expect(page.getByRole("button", { name: "Form Templates" })).toBeVisible();
    await expect(page.getByLabel("Search forms")).toBeVisible();
    await expect(page.getByLabel("Status filter")).toBeVisible();
    await expect(page.getByLabel("Sort forms")).toBeVisible();
  });

  test("authenticated admin can open all submissions", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "All Submissions", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/all-submissions\/$/);
    await expect(page.getByRole("heading", { name: "All Submissions (Admin)" })).toBeVisible();
    await expect(page.getByLabel("Search submissions")).toBeVisible();
    await expect(page.getByText("Teachers (All)")).toBeVisible();
    await expect(page.getByLabel("Submission status")).toBeVisible();
    await expect(page.getByText("All forms")).toBeVisible();
  });

  test("authenticated admin can open submit form", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Submit Form", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/submit-form\/$/);
    await expect(page.getByRole("heading", { name: "Forms Reports" })).toBeVisible();
    await expect(page.getByLabel("Search forms")).toBeVisible();
    await expect(page.getByText(/Teaching Reports/i)).toBeVisible();
    await expect(page.getByText("Daily Class Report")).toBeVisible();
  });

  test("authenticated admin can open invoices", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Invoices", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/invoices\/$/);
    await expect(page.getByRole("heading", { name: "Create Invoice" })).toBeVisible();
    await expect(page.getByText("Bill a parent or adult student")).toBeVisible();
    await expect(page.getByRole("button", { name: "All Invoices" })).toBeVisible();
  });

  test("authenticated admin can open circles", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Circles", exact: true }).click();
    await expect(page).toHaveURL(/\/admin\/circles\/$/);
    await expect(page.getByRole("heading", { name: "Pricing" })).toBeVisible();
    await expect(page.getByText("Set the hourly rates and bullets")).toBeVisible();
    await expect(page.getByRole("button", { name: "Team on website" })).toBeVisible();
  });

  test("authenticated admin can open teacher applicants", async ({ page }) => {
    skipUnlessAdminDashboardEnabled();
    await signInAndOpenAdmin(page);
    await page.getByRole("link", { name: "Teacher Applicants" }).click();
    await expect(page).toHaveURL(/\/admin\/teacher-applicants\/$/);
    await expect(page.getByRole("heading", { name: "Teacher Applicants" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Pending" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Reviewed" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Approved" })).toBeVisible();
  });

  test("authenticated admin can save and delete a temporary team profile", async ({ page }, testInfo) => {
    skipUnlessAdminCmsWriteEnabled(testInfo.project.name);

    const profileName = `Playwright CMS ${Date.now()}`;
    await signInAndOpenCms(page);

    await page.getByRole("button", { name: "Team on website" }).click();
    await page.getByRole("button", { name: "Add profile" }).click();
    await page.getByLabel("Name").fill(profileName);
    await page.getByLabel("Role / title").fill("CMS verification profile");
    await page.getByLabel("City").fill("Test City");
    await page.getByLabel("Sort order").fill("9999");
    await page.getByRole("button", { name: "Search users..." }).click();
    if (linkedUserUid) {
      await page.getByPlaceholder("Or paste Firebase user UID").fill(linkedUserUid);
    } else {
      await page.getByLabel("Search by email or UID").fill(linkedUserSearch);
      await page.getByRole("button").filter({ hasText: linkedUserSearch }).first().click();
    }
    await page.getByRole("button", { name: "Save" }).click();

    await expect(page.getByText("Profile saved")).toBeVisible();
    await expect(page.getByText(profileName)).toBeVisible();

    await page.getByRole("button", { name: `Delete ${profileName}` }).click();
    const dialog = page.getByRole("dialog", { name: "Delete this profile from the website?" });
    await expect(dialog.getByText(profileName)).toBeVisible();
    await dialog.getByRole("button", { name: "Delete" }).click();
    await expect(page.getByText("Profile deleted.")).toBeVisible();
    await expect(page.getByRole("button", { name: `Delete ${profileName}` })).toHaveCount(0);
  });

  test("authenticated admin can upload a temporary landing hero image", async ({ page }, testInfo) => {
    skipUnlessAdminCmsWriteEnabled(testInfo.project.name);
    test.skip(
      process.env.ALLUWAL_RUN_ADMIN_CMS_UPLOAD_E2E !== "1",
      "Set ALLUWAL_RUN_ADMIN_CMS_UPLOAD_E2E=1 to run the Storage upload verification.",
    );

    await signInAndOpenCms(page);
    await page.getByRole("button", { name: "Home hero" }).click();

    await page.locator("article").filter({ hasText: "Center hero image" }).locator("input[type='file']").setInputFiles({
      name: "cms-upload-test.png",
      mimeType: "image/png",
      buffer: Buffer.from(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/az7n2kAAAAASUVORK5CYII=",
        "base64",
      ),
    });

    await expect(page.getByText("Image uploaded. Save landing hero to publish this URL.")).toBeVisible({
      timeout: 20_000,
    });
    await expect(page.locator("article").filter({ hasText: "Center hero image" }).locator("input").first()).toHaveValue(
      /https:\/\/firebasestorage\.googleapis\.com\//,
    );
  });
});
