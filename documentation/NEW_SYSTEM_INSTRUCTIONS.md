# Shift Management System - New Implementation (ConnectTeam Inspired)

## Overview
This implementation introduces a robust shift management system using `_new` suffixed collections (`shifts_new`, `users_new`, etc.) to ensure no impact on production data during testing.

## Key Features
1.  **UTC Storage**: All timestamps are stored as UTC in Firestore.
2.  **Local Display**: Times are converted to the user's local timezone (or device timezone) for display.
3.  **Recurrence**: Explicit generation of shift occurrences using RFC-5545 rules.
4.  **Excel Export**: Detailed timesheet export functionality.

## Architecture

### Firestore Collections
-   `shifts_new`: Stores shift occurrences.
    -   Fields: `start_utc`, `end_utc`, `timezone`, `recurrence_rule`, `recurrence_instance_index`, etc.
-   `users_new`: Stores user profiles with timezone.
-   `time_entries_new`: Stores clock-in/out events in UTC.

### Flutter Components
-   `ShiftListScreenNew`: Main dashboard for the new system.
    -   **Access**: Click "Test New System" (Purple Button) in the existing Shift Management screen.
-   `CreateShiftDialogNew`: Creation form.
    -   Converts selected Date + Time + Timezone -> UTC.
-   `ShiftCardNew`: Display widget.
    -   Converts UTC -> User Timezone for display.
    -   Shows DEBUG info to verify timezone conversion.

### Cloud Functions (`functions/new_implementation.js`)
-   `onShiftCreateNew`: Triggered when a shift with `recurrence_instance_index: 0` and a rule is created. Generates future occurrences.
-   `exportTimesheet`: Callable HTTPS function to generate and download an Excel file.

## Deployment Instructions

### 1. Cloud Functions
The new logic is located in `functions/new_implementation.js`. To deploy:

1.  Install dependencies in `functions/`:
    ```bash
    cd functions
    npm install rrule luxon exceljs
    ```
2.  Import and export the functions in `functions/index.js`:
    ```javascript
    const newImpl = require('./new_implementation');
    exports.onShiftCreateNew = newImpl.onShiftCreateNew;
    exports.exportTimesheet = newImpl.exportTimesheet;
    ```
3.  Deploy functions:
    ```bash
    firebase deploy --only functions
    ```

### 2. Flutter App
The new screens are already integrated.
1.  Run the app.
2.  Navigate to **Shift Management** (Admin).
3.  Click the **Test New System** button.

## Diagnostics: UTC Display Issue
**Problem**: The old app likely displayed UTC because:
1.  It relied on `DateTime` objects derived from Firestore Timestamps without explicit timezone conversion in the UI widget context.
2.  Or the user's timezone was not correctly loaded/stored.

**Fix**:
In the new implementation (`ShiftCardNew`):
1.  We explicitly load the user's timezone (`TimezoneService.getCurrentUserTimezone`).
2.  We use `TimezoneUtils.convertToTimezone(startUtc, userTimezone)` to get the correct local time.
3.  We display the Timezone Abbreviation (e.g., "EST") to avoid ambiguity.
4.  Debug info is shown on the card to verify the underlying UTC value and the applied timezone.

## Migration to Production
Once testing is complete:
1.  Rename collections (or point code to original collections).
2.  Migrate existing data to the new schema (ensure `start_utc` is correctly calculated from existing data).
3.  Deploy Cloud Functions to listen to the production collection.

