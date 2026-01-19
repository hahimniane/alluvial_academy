# Alluwal Education Hub - System Design Document

**Version:** 2.0
**Last Updated:** January 2026
**Purpose:** Comprehensive system overview for UI/UX design reference

---

## 1. Product Overview

### What is Alluwal Education Hub?

A multi-platform educational management system for Islamic education. The platform connects administrators, teachers, students, and parents through web and mobile applications.

### Mission
Providing accessible Islamic education management with features for scheduling, time tracking, communication, and student progress monitoring.

### Platforms

| Platform | Primary Use | Status |
|----------|-------------|--------|
| **Web** | Admin dashboard, teacher portal, public landing page | Live |
| **Android** | Mobile app for all roles | Live (Play Store) |
| **iOS** | Mobile app for all roles | Live (App Store) |

### Website
- **URL:** https://alluvaleducationhub.org
- **Package ID:** org.alluvaleducationhub.academy

---

## 2. User Roles & Personas

### 2.1 Administrator
**Description:** School management staff with full system access

**Primary Tasks:**
- Manage all users (create, edit, deactivate, delete)
- Create and monitor teaching shifts
- Review and approve teacher timesheets
- Send notifications to users/groups
- Build and manage forms
- Assign tasks to staff
- Export reports (CSV/PDF/Excel)
- Manage website content

**Access Level:** Full system access

**Key Screens (Web):**
- Dashboard (statistics overview)
- User Management (Syncfusion DataGrid)
- Shift Management (calendar/grid view)
- Time Clock Review
- Form Builder
- Tasks
- Reports
- Chat (all rooms)

**Key Screens (Mobile):**
- Home Dashboard
- Send Notifications
- User Management
- Chat
- Tasks

### 2.2 Teacher
**Description:** Educators who conduct classes and track their time

**Primary Tasks:**
- View assigned shifts/classes
- Clock in/out for shifts (with geolocation)
- View timesheet history
- Submit forms
- Communicate via chat
- Manage assigned tasks

**Access Level:** Own data + assigned students

**Key Screens (Web/Mobile):**
- Dashboard (upcoming shifts, stats)
- Time Clock (clock in/out with timer)
- Shifts (view schedule)
- Chat
- Forms
- Tasks

### 2.3 Student
**Description:** Learners enrolled in classes

**Primary Tasks:**
- View class schedule
- Communicate with teachers
- Submit assigned tasks
- Complete forms

**Access Level:** Own data only

**Key Screens:**
- Dashboard (classes, schedule)
- My Classes
- Chat
- Tasks

### 2.4 Parent/Guardian
**Description:** Parents monitoring their children's education

**Primary Tasks:**
- View linked children's schedules
- View payment information
- Communicate with teachers/admin
- Complete forms

**Access Level:** Linked children's data

**Key Screens:**
- Dashboard (children overview)
- Children's Classes
- Payments
- Chat

### 2.5 Dual-Role: Admin-Teacher
**Description:** Administrators who also teach classes

**Behavior:** Can switch between Admin and Teacher modes using role switcher widget

---

## 3. Navigation Architecture

### 3.1 Web Navigation

**Public Landing Page (Unauthenticated):**
```
Landing Page
├── Home Section (hero, mission)
├── Programs Section
│   ├── Islamic Studies
│   ├── Languages (Afro-lingual)
│   ├── Adult Literacy
│   ├── After School Tutoring
│   ├── Math Classes
│   └── Programming
├── About Section
├── Contact Section
└── Sign In Button → Employee Hub
```

**Admin Dashboard (Authenticated):**
```
Sidebar Navigation
├── Dashboard (home icon)
├── User Management (people icon)
├── Shift Management (schedule icon)
├── Chat (chat icon)
├── Time Clock Review (clock icon)
├── Forms (description icon)
├── Tasks (checkbox icon)
└── Reports (chart icon)
```

**Teacher Dashboard (Authenticated):**
```
Sidebar Navigation
├── Dashboard (home icon)
├── Time Clock (clock icon)
├── Chat (chat icon)
├── Forms (description icon)
└── Tasks (checkbox icon)
```

### 3.2 Mobile Navigation

**Admin (5 Bottom Tabs):**
```
Bottom Navigation Bar
├── Home (dashboard icon)
├── Notify (notification icon)
├── Users (people icon)
├── Chat (chat icon)
└── Tasks (checkbox icon)
```

**Teacher (5 Bottom Tabs):**
```
Bottom Navigation Bar
├── Home (dashboard icon)
├── Forms (description icon)
├── Time Clock (clock icon)
├── Shifts (schedule icon)
└── Tasks (checkbox icon)
```

**Student/Parent (4 Bottom Tabs):**
```
Bottom Navigation Bar
├── Home (dashboard icon)
├── Chat (chat icon)
├── [Role-specific tab]
└── Tasks (checkbox icon)
```

---

## 4. Feature Breakdown

### 4.1 User Management

**Purpose:** Manage all system users

**Capabilities:**
- Create new users (all roles)
- Edit user details (name, email, phone, role, hourly rate)
- Activate/Deactivate users
- Promote users to admin
- Delete users (with confirmation)
- Search and filter by role/status
- Export user list

**Data Fields:**
- First Name, Last Name
- Email (used as login)
- Phone Number (with country code)
- Role (admin/teacher/student/parent)
- Hourly Rate (for teachers)
- Timezone
- Active Status
- Profile Picture

### 4.2 Shift Management

**Purpose:** Schedule and monitor teaching sessions

**Current Features:**
- Create shifts (teacher + students + subject + time)
- Recurring shifts (daily/weekly/monthly)
- View by status tabs: Scheduled, Active, Completed, Missed
- Force clock-out capability
- Clean duplicate shifts
- Subject color coding

**Future Vision (ConnectTeam-inspired):**
- Weekly grid view (teachers as rows, days as columns)
- Color-coded shift blocks by subject
- Leader schedules (admin duties)
- Click-to-create on empty cells
- Drag-and-drop shift moving

**Shift Statuses:**
| Status | Color | Description |
|--------|-------|-------------|
| Scheduled | Blue | Upcoming shift |
| Active | Amber | Currently in progress |
| Completed | Green | Successfully finished |
| Missed | Red | Teacher didn't clock in |
| Cancelled | Gray | Manually cancelled |

### 4.3 Time Clock

**Purpose:** Track teacher working hours

**Clock-In Flow:**
1. Teacher opens Time Clock screen
2. System detects valid upcoming shift (15 min window)
3. Teacher clicks "Clock In"
4. GPS location captured
5. Timer starts running
6. Shift status → Active

**Clock-Out Flow:**
1. Teacher clicks "Stop/Clock Out"
2. End time + location recorded
3. Timesheet entry created
4. Shift status → Completed

**Auto-Logout:** System auto-clocks-out 15 min after shift end time

**Timesheet Export Columns:**
- Employee Name
- Scheduled Shift Title
- Start Date/Time
- Clock-In Time
- Clock-In Device (Mobile/Web)
- End Date/Time
- Clock-Out Time
- Clock-Out Device
- Shift Hours
- Daily Total
- Scheduled Hours
- Difference (+/-)

### 4.4 Forms & Form Builder

**Purpose:** Create and collect digital forms

**Form Types:**
- Permission slips
- Surveys
- Registration forms
- Feedback forms
- Custom forms

**Form Builder Features:**
- Drag-and-drop field placement
- Field types: text, number, date, dropdown, checkbox, radio
- Required/optional fields
- Form preview
- Save as draft
- Publish to specific roles

**Submission Flow:**
1. User sees form in Forms screen
2. Fills out required fields
3. Submits form
4. Admin reviews submissions
5. Export responses

### 4.5 Chat/Messaging

**Purpose:** Real-time communication

**Features:**
- Individual chats (1-on-1)
- Group chats
- File attachments (up to 25MB)
- Emoji support
- Admin can enter any chat room
- Pin announcements

### 4.6 Live Video Classes (LiveKit)

**Purpose:** Real-time virtual classroom for live teaching sessions

**Current Implementation:**
- **LiveKit Integration:** In-app video conferencing (no external app needed)
- **Zoom Fallback:** Legacy Zoom support for external meetings
- **Access Control:** Only assigned teacher + enrolled students can join
- **Join Window:** 15 minutes before class start time

**Teacher Experience:**
1. Views scheduled shift on dashboard
2. "Start Class" button appears 15 min before start
3. Clicks to open LiveKit video room
4. Camera/microphone controls
5. Screen sharing capability
6. Student participant list

**Student Experience:**
1. Sees classes in "My Classes" screen
2. "Join Class" button turns green when ready
3. "Ready to Join" / "Opens in X min" status badges
4. One-tap to join video room
5. Teacher's video stream + audio

**Technical Details:**
- Provider switching: `VideoProvider.livekit` or `VideoProvider.zoom`
- Room creation: On-demand when teacher starts class
- Token generation: Server-side with student/teacher verification
- Platforms: Web, Android, iOS

**Current Screens:**
| Screen | User | Purpose |
|--------|------|---------|
| Student Classes Screen | Student | View schedule, join live classes |
| Teacher Dashboard | Teacher | See upcoming, start video class |
| Admin Zoom Screen | Admin | Create/manage Zoom meetings |
| In-App Meeting Screen | All | LiveKit video room interface |

---

### 4.7 Tasks

**Purpose:** Assign and track tasks

**Current Features:**
- Create tasks with title, description, due date
- Assign to multiple users
- Attach files
- Mark as complete
- Grid view

**Future Vision (ConnectTeam-inspired):**
- Tab navigation: Created By Me, My Tasks, All Tasks, Archived
- List view option
- Group by assignee
- Overdue tasks badge (red counter)
- Sub-tasks support
- Labels/tags

**Task Fields:**
- Title
- Description
- Assignees
- Due Date
- Status (pending/in_progress/completed)
- Attachments
- Labels

### 4.7 Notifications (Mobile)

**Purpose:** Instant push notifications

**Send To Options:**
- Everyone (all active users)
- By Role (teachers/students/parents/admins)
- Individual users

**Notification Types:**
- Instant admin notifications
- Shift reminders (automated, 15 min before)
- Task assignments
- Form submissions

### 4.8 Dashboard

**Purpose:** Overview and quick access

**Admin Dashboard Widgets:**
- Total users count
- Active shifts
- Pending timesheets
- Recent activity
- Quick actions

**Teacher Dashboard Widgets:**
- Upcoming shifts
- Current clock status
- Recent tasks
- Islamic calendar with prayer times

**Student Dashboard Widgets:**
- Today's classes
- Upcoming assignments
- Recent messages

### 4.9 Reports & Export

**Purpose:** Data export for analysis

**Export Formats:**
- CSV
- PDF
- Excel (multi-sheet)

**Available Reports:**
- User list
- Timesheet/attendance
- Shift history
- Form responses
- Task completion

---

## 5. Design System

### 5.1 Color Palette

**Primary Colors:**
```
Primary Blue:    #0386FF (main actions, links)
Secondary Blue:  #0693E3 (hover states)
```

**Background Colors:**
```
White:           #FFFFFF (cards, dialogs)
Light Gray:      #F8FAFC (page background)
Border Gray:     #E2E8F0 (dividers, borders)
```

**Status Colors:**
```
Success Green:   #10B981
Warning Amber:   #F59E0B
Error Red:       #EF4444
Info Blue:       #3B82F6
Neutral Gray:    #6B7280
```

**Subject Colors (Shift Blocks):**
```
Quran:           #10B981 (Green)
Hadith:          #F59E0B (Amber)
Fiqh:            #8B5CF6 (Purple)
Arabic:          #3B82F6 (Blue)
History:         #EF4444 (Red)
Aqeedah:         #06B6D4 (Cyan)
Tafseer:         #EC4899 (Pink)
Seerah:          #F97316 (Orange)
Leadership:      #6366F1 (Indigo)
Admin Duties:    #64748B (Slate)
```

**Role Badge Colors:**
```
Admin:           Gray badge
Teacher:         Blue badge
Student:         Green badge
Parent:          Purple badge
```

### 5.2 Typography

**Font Family:** Inter (Google Fonts)

**Font Sizes:**
```
Heading 1:       28px bold
Heading 2:       24px semi-bold
Heading 3:       20px semi-bold
Subtitle:        16px regular
Body:            14px regular
Label:           14px semi-bold
Caption:         12px regular
Badge:           12px bold
```

### 5.3 Spacing Scale

```
4px   - Tight spacing
8px   - Default small
12px  - Medium
16px  - Default
20px  - Large
24px  - Section padding
32px  - Major sections
```

### 5.4 Component Heights

```
Header Bar:      60px
Toolbar:         50px
Table Row:       48px-80px
Button:          40px (default), 48px (large)
Input Field:     48px
Bottom Nav:      56px (mobile)
```

### 5.5 Border Radius

```
Small:           4px (inputs, small buttons)
Default:         8px (cards, buttons)
Medium:          12px (badges, chips)
Large:           16px (dialogs, modals)
Full:            9999px (pills, avatars)
```

---

## 6. Screen Inventory

### 6.1 Public Website Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Landing Page | Marketing, program info | Hero, program cards, testimonials, contact form |
| Islamic Studies Page | Course details | Course list, enrollment CTA |
| Languages Page | Afro-lingual courses | Language options, enrollment |
| Math Page | Math tutoring | Course info, enrollment |
| Programming Page | Coding courses | Course info, enrollment |
| Enrollment Form | Student registration | Multi-step form, program selection |

### 6.2 Authentication Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Login (Web) | Employee sign in | Email, password, forgot password link |
| Login (Mobile) | Mobile sign in | Animated logo, email, password |
| Forgot Password | Password reset | Email input, reset button |

### 6.3 Admin Screens (Web)

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Dashboard | Overview | Stats cards, quick actions, activity feed |
| User Management | User CRUD | Syncfusion DataGrid, filters, search, export |
| Add/Edit User | User form | Name, email, role, rate, timezone |
| Shift Management | Scheduling | Status tabs, shift grid/calendar, create dialog |
| Create Shift Dialog | New shift | Teacher select, students, subject, time, recurrence |
| Shift Details Dialog | View/edit shift | Shift info, force clock-out, status change |
| Time Clock Review | Timesheet approval | Date range, teacher filter, approve/reject, export |
| Form Builder | Create forms | Drag-drop fields, preview, publish |
| Forms List | View submissions | Form cards, submission count, view responses |
| Tasks | Task management | Task grid, create, assign, filter |
| Chat | Messaging | Room list, message thread, file upload |
| Reports | Data export | Report type select, date range, export buttons |
| Settings | Preferences | Profile, notifications, theme |

### 6.4 Admin Screens (Mobile)

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Home Dashboard | Overview | Stats, quick actions |
| Notification Send | Push notifications | Recipient chips, title, message, send |
| User Management | User list | Search, filter chips, user cards, action sheet |
| User Action Sheet | User actions | Activate, edit, promote, delete |
| Chat | Messaging | Room list, conversation |
| Tasks | Task list | Task cards, status filter |

### 6.5 Teacher Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Dashboard | Overview | Upcoming shifts, clock status, Islamic calendar |
| Time Clock | Clock in/out | Current shift, clock button, running timer, location |
| Timesheet | History | Date range, entries table |
| Shifts | My schedule | Shift list, status badges |
| Forms | Form submission | Form list, fill out, submit |
| Chat | Messaging | Conversation threads |
| Tasks | My tasks | Task list, complete checkbox |
| Settings | Preferences | Profile, notifications, theme toggle |

### 6.6 Student Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Dashboard | Overview | Today's classes, upcoming |
| My Classes | Class schedule | Class cards with teacher, time |
| Chat | Messaging | Teacher conversations |
| Tasks | Assignments | Task list, due dates |

### 6.7 Parent Screens

| Screen | Purpose | Key Elements |
|--------|---------|--------------|
| Dashboard | Children overview | Child cards, class info |
| Children's Classes | Schedule view | Per-child schedule |
| Payments | Payment info | Payment history, status |
| Chat | Communication | Teacher/admin messages |

---

## 7. Key User Flows

### 7.1 Teacher Clock-In Flow
```
1. Teacher opens app
2. Sees "Upcoming Shift" widget on dashboard
3. Taps to go to Time Clock screen
4. Sees shift details and "Clock In" button (enabled 15 min before)
5. Taps "Clock In"
6. Location permission request (if first time)
7. Location captured, timer starts
8. Success feedback shown
9. Dashboard shows "Currently Clocked In" status
```

### 7.2 Admin Creates Shift Flow
```
1. Admin opens Shift Management
2. Clicks "+ Create Shift" button
3. Dialog opens with form:
   - Select Teacher (dropdown)
   - Select Students (multi-select)
   - Select Subject (dropdown)
   - Pick Date and Time
   - Optional: Set Recurrence
4. Clicks "Create"
5. Shift appears in Scheduled tab
6. Notifications sent to teacher & students
```

### 7.3 Student Enrollment Flow (Public)
```
1. Visitor lands on homepage
2. Clicks program card (e.g., "Islamic Studies")
3. Views course details page
4. Clicks "Enroll Now"
5. Enrollment form opens with program pre-selected
6. Fills in: Name, Email, Phone, Age, Program Selection
7. Submits form
8. Confirmation message shown
9. Admin receives notification of new enrollment
```

### 7.4 Admin Sends Notification Flow (Mobile)
```
1. Admin opens Notify tab
2. Selects recipient type: Everyone / By Role / Individual
3. If "By Role": selects role chips (Teachers, Students, etc.)
4. If "Individual": bottom sheet with user search
5. Enters notification title and message
6. Taps "Send Notification"
7. Loading indicator
8. Success dialog with delivery stats
```

---

## 8. Programs & Subjects

### 8.1 Program Categories

| Category | Form Value | Target Audience |
|----------|------------|-----------------|
| Islamic Studies | Islamic Studies: Quran, Hadith, Tawhid | All ages |
| Languages | AfroLanguage: Poular, Mandingo, Swahili | All ages |
| Adult Literacy | Adult Literacy Studies: Reading, Writing (English) | Adults |
| After School Tutoring | After School Tutoring: Math, Science, History | Students |

### 8.2 Islamic Studies Subjects
- Quran (recitation, memorization)
- Arabic Language
- Hadith
- Tafseer (Quran interpretation)
- Fiqh (Islamic jurisprudence)
- Aqeedah (Islamic creed)
- Seerah (Prophet's biography)
- Islamic History

### 8.3 Language Offerings
- Pular/Fulani
- Mandingo
- Swahili
- Wolof
- Yoruba
- Hausa
- French
- Adlam script

---

## 9. Technical Integrations

### 9.1 Firebase Services
- **Authentication:** Email/password login
- **Firestore:** Real-time database
- **Cloud Storage:** File uploads
- **Cloud Functions:** Backend logic
- **Cloud Messaging:** Push notifications (mobile)
- **Remote Config:** Force app updates

### 9.2 Third-Party Libraries
- **Syncfusion:** DataGrids, Calendar, Date Picker
- **Google Fonts:** Inter typography
- **Google Maps/Geocoding:** Location services
- **LiveKit:** Real-time video conferencing for live classes
- **Zoom SDK:** Legacy video meeting support

---

## 10. Future Roadmap

### 10.1 Class Recording & Replay (Phase 1)

**Vision:** Every live class automatically recorded for students to revisit

**Features:**
- [ ] Automatic recording when teacher starts class
- [ ] Cloud storage for recordings (Firebase/S3)
- [ ] Video library organized by subject/teacher/date
- [ ] Student access to recordings of their enrolled classes
- [ ] Playback controls (speed, skip, rewind)
- [ ] Bookmarking and timestamped notes
- [ ] Download for offline viewing
- [ ] Recording retention policies (30/60/90 days)

**Student Replay Screen:**
- Class recordings tab in My Classes
- Thumbnail previews with duration
- Watch progress indicator
- "Continue Watching" section
- Search by subject or teacher

**Teacher Recording Dashboard:**
- View own recorded classes
- Option to mark as private/unlisted
- Delete outdated recordings
- View student watch statistics

---

### 10.2 AI-Assisted Learning (Phase 2)

**Vision:** AI tutors that help students learn Islamic subjects more effectively

#### 10.2.1 Quran Learning AI
- [ ] **Tajweed Correction:** AI listens to recitation, provides real-time feedback on pronunciation
- [ ] **Memorization Assistant:** AI-powered Quran memorization with spaced repetition
- [ ] **Progress Tracking:** Track which Surahs/Ayahs are memorized
- [ ] **Voice Recognition:** Student reads, AI verifies correctness
- [ ] **Mistake Highlighting:** Visual feedback on where pronunciation errors occur

**Quran AI Screen Concept:**
```
┌─────────────────────────────────────────┐
│ Surah Al-Fatiha - Ayah 1               │
│                                         │
│   بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ   │
│                                         │
│ [🎤 Record Your Recitation]            │
│                                         │
│ AI Feedback:                           │
│ ✓ "Bismillah" - Correct               │
│ ⚠ "Rahman" - Extend the 'a' sound     │
│ ✓ "Raheem" - Good pronunciation       │
│                                         │
│ Overall Score: 85%                     │
│ [Listen to Correct] [Try Again]        │
└─────────────────────────────────────────┘
```

#### 10.2.2 Arabic Language AI
- [ ] **Pronunciation Coach:** AI feedback on Arabic letter sounds
- [ ] **Vocabulary Builder:** AI-generated flashcards with audio
- [ ] **Conversation Practice:** AI chatbot for Arabic conversation
- [ ] **Grammar Correction:** Real-time grammar feedback

#### 10.2.3 Islamic Knowledge AI
- [ ] **Q&A Assistant:** Students ask questions, AI provides answers with scholarly references
- [ ] **Hadith Lookup:** Search and explain Hadith
- [ ] **Quiz Generation:** AI creates quizzes from lesson content
- [ ] **Personalized Learning Path:** AI recommends next topics based on progress

**AI Tutor Chat Screen Concept:**
```
┌─────────────────────────────────────────┐
│ Islamic Knowledge Assistant             │
├─────────────────────────────────────────┤
│ Student: What are the 5 pillars of     │
│          Islam?                         │
│                                         │
│ AI: The five pillars of Islam are:     │
│     1. Shahada (Declaration of Faith)  │
│     2. Salah (Prayer - 5 times daily)  │
│     3. Zakat (Almsgiving)              │
│     4. Sawm (Fasting in Ramadan)       │
│     5. Hajj (Pilgrimage to Makkah)     │
│                                         │
│     📚 Source: Hadith of Jibril        │
│                                         │
│ [Related: Pillars of Iman] [Quiz Me]   │
├─────────────────────────────────────────┤
│ [Type your question...]          [Send]│
└─────────────────────────────────────────┘
```

---

### 10.3 On-Demand Course Marketplace (Phase 3)

**Vision:** Platform for pre-recorded courses created by teachers or the institution

#### 10.3.1 Course Types
| Type | Owner | Revenue |
|------|-------|---------|
| Institution Courses | Alluwal Education Hub | 100% to institution |
| Teacher Courses | Individual Teacher | Revenue share (70/30) |
| Collaborative | Joint production | Negotiated split |

#### 10.3.2 Course Structure
```
Course
├── Module 1: Introduction
│   ├── Lesson 1.1: Overview (Video - 10 min)
│   ├── Lesson 1.2: Key Concepts (Video - 15 min)
│   ├── Quiz 1 (5 questions)
│   └── Assignment 1
├── Module 2: Deep Dive
│   ├── Lesson 2.1: ...
│   └── ...
├── Final Exam
└── Certificate of Completion
```

#### 10.3.3 Course Creation Tools (Teacher)
- [ ] Video upload with processing (transcoding, thumbnails)
- [ ] Lesson builder (drag-drop modules)
- [ ] Quiz/assignment creator
- [ ] Pricing options (free, one-time, subscription)
- [ ] Course preview before publishing
- [ ] Analytics dashboard (enrollments, completion rates, revenue)

**Course Builder Screen Concept:**
```
┌─────────────────────────────────────────┐
│ Create New Course                       │
├─────────────────────────────────────────┤
│ Title: [Tajweed Fundamentals          ]│
│ Category: [Quran Studies        ▼     ]│
│ Level: [Beginner ▼] Price: [$49       ]│
│                                         │
│ Modules:                                │
│ ┌────────────────────────────────────┐ │
│ │ 📁 Module 1: Arabic Letters        │ │
│ │    ├─ 🎬 Introduction (12:34)     │ │
│ │    ├─ 🎬 Makhaarij (18:22)        │ │
│ │    └─ 📝 Quiz: Letter Recognition │ │
│ ├────────────────────────────────────┤ │
│ │ 📁 Module 2: Tajweed Rules        │ │
│ │    └─ [+ Add Lesson]              │ │
│ └────────────────────────────────────┘ │
│                                         │
│ [+ Add Module]                          │
│                                         │
│ [Save Draft] [Preview] [Publish Course] │
└─────────────────────────────────────────┘
```

#### 10.3.4 Student Course Experience
- [ ] Browse course catalog (by subject, teacher, rating)
- [ ] Course preview (free lessons)
- [ ] Enrollment and payment
- [ ] Progress tracking per course
- [ ] Completion certificates (PDF/digital badge)
- [ ] Rate and review courses
- [ ] Continue watching across devices

**Course Catalog Screen Concept:**
```
┌─────────────────────────────────────────┐
│ Course Catalog                          │
│ [Search courses...]          [Filters]  │
├─────────────────────────────────────────┤
│ Featured Courses                        │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │ 📖      │ │ 🕌      │ │ 📿      │    │
│ │ Quran   │ │ Fiqh    │ │ Seerah  │    │
│ │ Basics  │ │ 101     │ │ Journey │    │
│ │ ⭐ 4.8  │ │ ⭐ 4.5  │ │ ⭐ 4.9  │    │
│ │ Free    │ │ $29     │ │ $49     │    │
│ └─────────┘ └─────────┘ └─────────┘    │
├─────────────────────────────────────────┤
│ My Courses (In Progress)                │
│ ┌───────────────────────────────────┐  │
│ │ Tajweed Fundamentals    [75%]━━━━ │  │
│ │ Arabic for Beginners    [30%]━━   │  │
│ └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

#### 10.3.5 Revenue & Analytics
- [ ] Teacher earnings dashboard
- [ ] Payout management (Stripe Connect)
- [ ] Institution revenue reports
- [ ] Course performance metrics
- [ ] Student engagement analytics

---

### 10.4 Enhanced Live Classes (Phase 1.5)

**Purpose:** Improve live class experience before AI integration

- [ ] Whiteboard collaboration (teacher draws, students see)
- [ ] Screen sharing with annotation
- [ ] Breakout rooms for group study
- [ ] Raise hand feature
- [ ] Live polls/quizzes during class
- [ ] Chat during video class
- [ ] Picture-in-picture mode (mobile)
- [ ] Virtual backgrounds
- [ ] Class transcript (auto-generated)
- [ ] Multi-language subtitles

---

### 10.5 Student Progress System

**Purpose:** Comprehensive tracking of student learning journey

- [ ] Subject-by-subject progress tracking
- [ ] Quran memorization tracker (Surah/Juz completion)
- [ ] Badge/achievement system
- [ ] Learning streaks (daily practice)
- [ ] Weekly progress reports to parents
- [ ] Leaderboards (optional, gamification)
- [ ] Certificates for milestones

**Progress Dashboard Concept:**
```
┌─────────────────────────────────────────┐
│ Ahmed's Progress                        │
├─────────────────────────────────────────┤
│ 🔥 7-Day Streak! Keep it up!           │
├─────────────────────────────────────────┤
│ Quran Memorization                      │
│ [Juz 1: ████████░░] 80% Complete       │
│ Last Surah: Al-Baqarah (Ayah 142)      │
├─────────────────────────────────────────┤
│ Badges Earned                           │
│ 🏅 First Surah  🏅 10 Classes  🏅 Quiz │
├─────────────────────────────────────────┤
│ Recent Achievements                     │
│ ✓ Completed Surah Al-Fatiha (100%)     │
│ ✓ Attended 10 live classes             │
│ ✓ First perfect quiz score             │
└─────────────────────────────────────────┘
```

---

### 10.6 Parent Portal Enhancements

- [ ] Real-time class attendance notifications
- [ ] Recording access for parent review
- [ ] Monthly progress reports (PDF)
- [ ] Payment portal integration (Stripe)
- [ ] Payment history and invoices
- [ ] Multiple children management
- [ ] Direct messaging with teachers
- [ ] Push notifications for milestones

---

### 10.7 Shift Management Improvements

- [ ] Weekly grid view (ConnectTeam-style)
- [ ] Drag-and-drop shift scheduling
- [ ] Leader schedule management (admin duties)
- [ ] Shift conflicts detection
- [ ] Teacher availability management

### 10.8 Timesheet Enhancements

- [ ] ConnectTeam-style Excel export with pivot tables
- [ ] Daily/weekly totals
- [ ] Scheduled vs actual comparison
- [ ] Overtime tracking

### 10.9 Tasks Redesign

- [ ] Tab navigation (My Tasks, Created By Me, All, Archived)
- [ ] List view option
- [ ] Group by assignee
- [ ] Sub-tasks support
- [ ] Overdue badge counter
- [ ] Labels/tags

### 10.10 Mobile Improvements

- [ ] Offline mode (download recordings)
- [ ] Biometric login
- [ ] Home screen widget for upcoming shifts
- [ ] Apple Watch / Wear OS companion app

---

## 11. Implementation Priority

| Phase | Focus Area | Timeline |
|-------|------------|----------|
| **1** | Class Recording & Replay | Foundation for content library |
| **1.5** | Enhanced Live Classes | Improve teaching experience |
| **2** | AI-Assisted Learning | Start with Quran AI |
| **3** | On-Demand Courses | Teacher marketplace |
| **4** | Advanced AI | Full AI tutor experience |

### Phase 1 MVP (Recording)
1. Integrate LiveKit recording API
2. Store recordings in Firebase Storage / S3
3. Build student recordings library screen
4. Implement access control (only enrolled students)
5. Basic playback with controls

### Phase 2 MVP (AI)
1. Start with Quran recitation verification
2. Use speech-to-text for Arabic
3. Compare against reference recitations
4. Simple feedback: correct/incorrect + where to improve
5. Expand to other subjects over time

---

## 12. Appendix

### 12.1 Firestore Collections

| Collection | Purpose |
|------------|---------|
| users | All user accounts and profiles |
| shifts | Teaching shift records |
| time_entries | Clock in/out records |
| forms | Form definitions |
| form_submissions | Form responses |
| tasks | Task records |
| chats | Chat rooms and messages |
| notifications | Notification history |

### 12.2 User Document Fields
```
{
  "e-mail": "user@email.com",
  "first_name": "John",
  "last_name": "Doe",
  "phone_number": "+1234567890",
  "user_type": "teacher",
  "hourly_rate": 25.00,
  "timezone": "America/New_York",
  "is_active": true,
  "profile_image_url": "https://...",
  "fcm_tokens": ["token1", "token2"],
  "last_login": Timestamp,
  "created_at": Timestamp
}
```

### 12.3 Shift Document Fields
```
{
  "teacher_id": "userId",
  "teacher_name": "Teacher Name",
  "student_ids": ["id1", "id2"],
  "student_names": ["Student 1", "Student 2"],
  "subject_id": "quran",
  "shift_start": Timestamp,
  "shift_end": Timestamp,
  "status": "scheduled",
  "clock_in_time": Timestamp,
  "clock_out_time": Timestamp,
  "clock_in_location": GeoPoint,
  "recurrence_rule": "FREQ=WEEKLY;BYDAY=MO,WE,FR",
  "created_at": Timestamp
}
```

### 12.4 Future: Recordings Collection
```
{
  "id": "recording_123",
  "shift_id": "shift_456",
  "teacher_id": "userId",
  "subject": "Quran",
  "recorded_at": Timestamp,
  "duration_seconds": 3600,
  "storage_url": "https://storage.../recording.mp4",
  "thumbnail_url": "https://storage.../thumb.jpg",
  "student_ids": ["id1", "id2"],
  "views": 45,
  "status": "available",
  "retention_until": Timestamp
}
```

### 12.5 Future: Courses Collection
```
{
  "id": "course_789",
  "title": "Tajweed Fundamentals",
  "teacher_id": "userId",
  "owner_type": "teacher",
  "price_cents": 4900,
  "currency": "USD",
  "modules": [
    {
      "id": "mod_1",
      "title": "Introduction",
      "lessons": [
        {
          "id": "les_1",
          "title": "Welcome",
          "type": "video",
          "video_url": "...",
          "duration_seconds": 600
        }
      ]
    }
  ],
  "enrollments_count": 150,
  "rating_average": 4.8,
  "status": "published",
  "created_at": Timestamp
}
```

---

**Document maintained by:** Alluwal Education Hub Development Team
**For design inquiries:** Use this document as reference for Figma designs
**Version History:**
- v2.0 (Jan 2026): Added LiveKit classes, AI vision, course marketplace, recording features
