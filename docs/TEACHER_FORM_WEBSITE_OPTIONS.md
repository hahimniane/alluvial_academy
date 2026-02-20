# Teacher Form → Website Integration: Options for Data, Pictures & Updates

This document lists **options for taking form data (including pictures) into your app**, **where to store them**, and **how to keep profile pictures in sync when a teacher or admin updates them**. It also lists **files involved** so you can reorganize the website in a professional way.

---

## 1. Current State (Brief)

| What | Where |
|------|--------|
| **Form data** | Google Form → Google Sheet "Form_Responses" (name, role, city, major/university, background, languages, reasons for joining, **photo = Google Drive link**) |
| **Teachers on website** | Hardcoded in `lib/screens/teachers_page.dart` (local assets, fixed list) |
| **Profile pictures in app** | Firebase Storage `profile_pictures/{uid}_*.jpg` + Firestore `users/{uid}.profile_picture_url` |
| **Extended teacher info in app** | Firestore `teacher_profiles/{uid}` (full_name, professional_title, biography, specialties, education) |
| **Editable website content** | Firestore `website_content/{docId}` (public read, admin write) |

---

## 2. Options for Getting Picture + Info Into the System

### Option A: One-time / periodic import from Google Sheet

- **How:** Export Sheet as CSV or use **Google Sheets API** (or Apps Script) to read rows. Run a script (Node.js in `functions/` or a one-off script in `scripts/`) that:
  - Maps columns → your teacher model (name, role, city, education, background, languages, reasons, photo URL).
  - For each row: create or update a document (e.g. in `website_content/teachers` as a subcollection or a single doc with a list, or a dedicated `public_teachers` collection).
- **Pictures:** Either keep **Google Drive links** (see §3) or **download and re-upload to Firebase Storage** in the same script, then store the Firebase Storage URL in Firestore.
- **When teacher changes picture:** Not automatic. You’d need either: (1) teacher updates in the **app** (profile picture) and you **sync** that into the website data (e.g. by `userId`), or (2) manual re-import from Sheet if the form is edited.

**Best for:** Quick integration from existing form responses; form stays the initial source.

---

### Option B: App / admin as source of truth (no ongoing Sheet dependency)

- **How:** Import form responses **once** into Firestore (e.g. `public_teachers` or `website_content/teachers`). New teachers are added/edited only in the app (admin UI) or by teachers editing their own profile.
- **Pictures:** Stored only in **Firebase Storage** (e.g. `profile_pictures/` or a dedicated `website_teachers/` path). Website reads URL from Firestore.
- **When teacher changes picture:** Teacher (or admin) updates profile picture in the app → `ProfilePictureService` uploads to Storage and updates `users/{uid}.profile_picture_url`. If the **website** teacher list is keyed by **user id** and displays that same field (or a copy synced from it), the website updates automatically.

**Best for:** Long-term control, single source of truth, and automatic picture updates when teacher/admin change it in the app.

---

### Option C: Hybrid (form for onboarding, app for updates)

- **How:** New submissions from the Google Form are imported (manually or via scheduled script) into Firestore. Each imported teacher is **linked to a user id** when they have an app account (e.g. by matching email or manual admin link).
- **Pictures:** On import: use Drive link as-is **or** upload to Firebase Storage and save that URL. After link: for linked teachers, **prefer** `users/{uid}.profile_picture_url` for the website so that when they change their picture in the app, the website shows the new one without touching the form/Sheet.
- **When teacher changes picture:** Same as Option B for linked teachers; for not-yet-linked, you keep using the imported URL until they’re linked.

**Best for:** Keeping the form for new applicants while moving “live” picture (and maybe bio) to the app.

---

## 3. Options for Storing and Displaying Pictures

| Approach | Storage | Pros | Cons |
|----------|--------|------|------|
| **Use Google Drive links as-is** | Sheet → Firestore (store Drive URL) | No migration, simple | Drive sharing must be “Anyone with link”; link format may change; less control; CORS/embed limits on some clients. |
| **Convert Drive link to direct image URL** | Firestore holds converted URL | No re-upload | Drive’s `open?id=…` must be converted to a direct image URL (e.g. `https://drive.google.com/uc?export=view&id=FILE_ID`); still depends on Drive permissions. |
| **Re-host in Firebase Storage** | Storage (e.g. `website_teachers/{id}.jpg` or same path as profile pics) | Stable URLs, one place for all app + website images, works with your existing `storage.rules` | One-time (or periodic) script to download from Drive and upload to Storage. |
| **Use existing profile picture** | Firebase Storage `profile_pictures/` + `users.{uid}.profile_picture_url` | No duplicate storage; teacher/admin update in app = instant update on website | Only for teachers who have an app account; need to link form row → `userId`. |

**Recommendation:** Prefer **Firebase Storage** for website teacher photos (either re-host from form or use `profile_picture_url` when teacher is linked). This gives one place for pictures and lets teacher/admin updates in the app flow to the website.

**Using the form’s Drive links as-is:** All Drive links from the “Upload a professional Photo here” column use the format `https://drive.google.com/open?id=FILE_ID`. To display them in the app or on the web, convert to a direct image URL: `https://drive.google.com/uc?export=view&id=FILE_ID`. Use the helper **`lib/core/utils/google_drive_image_url.dart`**: call `toDirectImageUrl(driveLink)` and use the result in `Image.network()`. Each file must be shared **“Anyone with the link can view”** or the image will not load.

---

## 4. When a Teacher or Admin Changes the Profile Picture

- **In the app:** Already handled by `ProfilePictureService`: upload to Storage → update `users/{uid}.profile_picture_url` (and optionally `profile_picture_updated_at`).
- **On the website:** So that “change in app = change on site”:
  1. **Store a reference to the user** in the website teacher record (e.g. `userId` in `public_teachers` or in the list under `website_content/teachers`).
  2. When rendering the Teachers page, for each teacher with a `userId`, **read photo from** `users/{userId}.profile_picture_url` (or from a denormalized copy you update via Cloud Function when that field changes). If no `userId`, use the stored `photo_url` from the form/import.
- **Admin updates picture for a teacher:** If admin uses the same “profile picture” flow (e.g. editing that user’s profile), the same `users.{uid}.profile_picture_url` updates; no extra step if website reads from user doc or from a synced copy.

So: **one source of truth for the photo** (Firestore `users` + Storage) and **website reads that** (directly or via a synced/cached structure) so that any teacher or admin change is reflected.

---

## 5. Files and Areas Involved

### 5.1 Backend / Data

| File / area | Purpose |
|-------------|--------|
| **Firestore** | New or existing collection for “website teachers” (e.g. `website_content` doc or `public_teachers`). Fields: name, role, city, education, background, languages, reasons, `photo_url` and/or `userId`. |
| **Firebase Storage** | `profile_pictures/` (existing) or `website_teachers/` (if you store website-only photos). |
| **Cloud Functions** (optional) | Trigger on `users/{uid}` update to copy `profile_picture_url` into `website_content` or `public_teachers` so the website can read one list without joining. |
| **Scripts** | `scripts/import_teachers_from_sheet.js` (or similar): read Sheet (or CSV), map to your model, resolve photos (Drive → link or upload to Storage), write to Firestore. |

### 5.2 App / Website UI

| File | Purpose |
|------|--------|
| `lib/screens/teachers_page.dart` | **Replace** hardcoded `Teacher` list with data from Firestore (and optionally `users.{userId}.profile_picture_url`). Keep existing layout (carousel, cards, CTA). |
| `lib/core/models/website_teacher.dart` (new, optional) | Model for one teacher: name, role, city, education, background, languages, reasons, photoUrl, userId. |
| `lib/core/services/website_teachers_service.dart` (new, optional) | Fetches website teachers from Firestore; optionally merges in `profile_picture_url` from `users` for each `userId`. |
| `lib/screens/about_page.dart` | If you show “leadership” or same people, can share the same Firestore source or a separate `website_content` doc. |

### 5.3 Profile picture flow (already there)

| File | Purpose |
|------|--------|
| `lib/core/services/profile_picture_service.dart` | Upload/delete profile picture; updates `users.{uid}.profile_picture_url`. |
| `lib/features/profile/widgets/teacher_profile_edit_dialog.dart` | Teacher edits profile (and can change picture); uses `teacher_profiles` and can use `ProfilePictureService`. |
| `lib/features/profile/screens/teacher_profile_screen.dart` | Displays teacher profile (and picture). |

### 5.4 Admin (optional)

| File / area | Purpose |
|-------------|--------|
| Admin screen (new or existing) | List/edit “website teachers”: link to user, set order, override photo or use `users.profile_picture_url`, edit bio/role/city etc. Could live under `lib/features/website_management/` or admin dashboard. |
| `lib/features/website_management/screens/website_management_screen.dart` | If you already have website management, add a “Teachers” tab that reads/writes the same Firestore collection. |

### 5.5 Security

| File | Purpose |
|------|--------|
| `firestore.rules` | Ensure `website_content` (or `public_teachers`) is **public read**, **admin write** (and optionally allow teachers to update only their own row if you add that). |
| `storage.rules` | Already allows `profile_pictures/` for authenticated users; add `website_teachers/` if you use that path and want public read for display. |

---

## 6. Summary Table: Options at a Glance

| Option | Get data | Store pictures | Picture updates |
|--------|----------|-----------------|-----------------|
| **A** | Import from Sheet (CSV/API) | Drive link or re-upload to Storage | Manual re-import or separate sync from app |
| **B** | One-time import; then only app/admin | Firebase Storage only | Automatic when teacher/admin update in app (website reads user or synced doc) |
| **C** | Form import + link to user when they join app | Drive on import; then Storage via user profile | Automatic for linked teachers (website uses `userId` → `users.profile_picture_url`) |

**Suggested path:** **Option C** (hybrid): import current form responses once into a `website_content` doc or `public_teachers` collection; for each teacher that has an app account, set `userId` and have the website prefer `users.{userId}.profile_picture_url`. New form submissions can be imported periodically; when a teacher gets an account, admin links them so their future picture updates in the app automatically show on the website.

---

## 7. Next Steps (Concrete)

1. **Decide** which option (A, B, or C) and where to store website teachers (e.g. `website_content/teachers` vs `public_teachers`).
2. **Add Firestore structure** (e.g. one doc with a `teachers` array, or a subcollection) and optional Cloud Function to mirror `profile_picture_url` for linked users.
3. **Implement import script** (Sheet → Firestore, with Drive → Storage if you re-host).
4. **Add** `WebsiteTeacher` model and a small service to stream website teachers (and merge in profile picture by `userId`).
5. **Refactor** `teachers_page.dart` to use that service and show real data; optionally add an admin “Teachers” editor under website management.

If you tell me which option you prefer (A, B, or C) and whether you want teachers in `website_content` or a separate collection, I can outline the exact Firestore schema and the changes to `teachers_page.dart` and the new service next.
