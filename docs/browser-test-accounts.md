# Browser test accounts

The repository owner approved the following designated accounts for browser
testing against the production Firebase project. Account identifiers are not
secrets; passwords and tokens must never be added to this repository.

| Role | Account identifier | Password environment variable |
| --- | --- | --- |
| Admin | `hassimiou.niane@maine.edu` | `ALLUWAL_E2E_ADMIN_PASSWORD` |
| Teacher | `billing@alluwaleducationhub.org` | `ALLUWAL_E2E_TEACHER_PASSWORD` |
| Parent | `nenenane2@gmail.com` | `ALLUWAL_E2E_PARENT_PASSWORD` |
| Student | `test.student` | `ALLUWAL_E2E_STUDENT_PASSWORD` |

Set credentials only in the local shell, CI secret store, or an ignored local
environment file. Never print them in command output, screenshots, traces, or
test reports.

## Production browser-test safeguards

1. Prefer `alluwal-dev` for write tests whenever it can verify the behavior.
2. Production browser writes are allowed only when the task requires production
   verification and must use one of the designated accounts above.
3. Create uniquely named disposable fixtures with a `codex_qa_` prefix and a
   timestamp. Do not modify real classes, invoices, audits, forms, submissions,
   notifications, or user profiles for testing.
4. Record every fixture document ID before interacting with it.
5. Delete all disposable fixtures at the end of the test and confirm each read
   returns not found.
6. Do not send test push, email, SMS, or chat messages to non-test accounts.
7. Production deployments still require the repository's normal targeted tests
   and explicit project flags.

## Standard browser-test variables

```text
ALLUWAL_E2E_ADMIN_EMAIL
ALLUWAL_E2E_ADMIN_PASSWORD
ALLUWAL_E2E_TEACHER_EMAIL
ALLUWAL_E2E_TEACHER_PASSWORD
ALLUWAL_E2E_PARENT_EMAIL
ALLUWAL_E2E_PARENT_PASSWORD
ALLUWAL_E2E_STUDENT_LOGIN
ALLUWAL_E2E_STUDENT_PASSWORD
```

Agents should use the repository's Playwright workflow and place screenshots,
traces, and videos under `output/playwright/`.
