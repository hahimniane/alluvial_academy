# My Submissions Screen - Field Labels Fix

## Issue Identified
**Date**: November 11, 2025  
**Reported By**: User

### Problem
The "My Submissions" screen was showing:
1. "Untitled Form" for all form titles in the list
2. Raw field IDs (like `1756564707506`, `1754407141413`) instead of actual question text when viewing submission details

### User Experience Impact
- Teachers couldn't identify which forms they had submitted
- Viewing submitted responses showed meaningless numbers instead of questions
- Made the feature unusable for reviewing past submissions

## Root Cause

### Issue 1: Missing Form Titles
The code was reading `formTitle` from the stored submission data, but:
- Some submissions didn't have the title stored
- Some had "Untitled Form" as the default value
- No fallback to fetch the actual form title from the form template

### Issue 2: Field IDs Instead of Labels
When displaying submission details, the code used the field ID (e.g., `entry.key`) directly as the display label:

```dart
// Before (line 527-528):
final entry = responses.entries.elementAt(index);
return _buildResponseField(entry.key, entry.value, index + 1);
// entry.key was the field ID like "1756564707506"
```

The form template contains the actual question labels in the `fields` array, but these weren't being fetched.

## Solution

### Fix 1: Dynamic Form Title Fetching

Created a `_getFormTitle()` method that:
1. First checks stored data for title (multiple field name variations)
2. If missing or "Untitled Form", fetches from the form template
3. Falls back to "Form Submission" if all else fails

```dart
Future<String> _getFormTitle(Map<String, dynamic> data, String? formId) async {
  // Try stored title first
  final storedTitle = data['formTitle'] ?? data['form_title'] ?? data['title'];
  if (storedTitle != null && storedTitle.toString().isNotEmpty && 
      storedTitle.toString() != 'Untitled Form') {
    return storedTitle.toString();
  }

  // Fetch from form template if needed
  if (formId != null && formId.isNotEmpty) {
    final formDoc = await FirebaseFirestore.instance
        .collection('form')
        .doc(formId)
        .get();
    if (formDoc.exists) {
      final title = formDoc.data()?['title'] ?? formDoc.data()?['formTitle'];
      if (title != null) return title.toString();
    }
  }

  return 'Form Submission';
}
```

Updated the card builder to use `FutureBuilder`:

```dart
Widget _buildSubmissionCard(String submissionId, Map<String, dynamic> data) {
  return FutureBuilder<String>(
    future: _getFormTitle(data, formId),
    builder: (context, snapshot) {
      final formTitle = snapshot.data ?? 'Loading...';
      // ... build card with formTitle
    },
  );
}
```

### Fix 2: Field Label Mapping

Converted `_SubmissionDetailView` from `StatelessWidget` to `StatefulWidget` and added:

1. **State variables**:
```dart
Map<String, String> _fieldLabels = {};
bool _isLoadingLabels = true;
```

2. **Form template loading on init**:
```dart
Future<void> _loadFormTemplate() async {
  final formId = widget.data['formId'];
  final formDoc = await FirebaseFirestore.instance
      .collection('form')
      .doc(formId)
      .get();

  final fields = formData['fields'] as List;
  final labels = <String, String>{};
  for (var field in fields) {
    final id = field['id'];
    final label = field['label'];
    if (id != null && label != null) {
      labels[id] = label;  // Map field ID to question text
    }
  }

  setState(() {
    _fieldLabels = labels;
    _isLoadingLabels = false;
  });
}
```

3. **Updated display logic**:
```dart
itemBuilder: (context, index) {
  final entry = responses.entries.elementAt(index);
  final fieldId = entry.key;
  final fieldLabel = _fieldLabels[fieldId] ?? fieldId;  // Use label, fallback to ID
  return _buildResponseField(fieldLabel, entry.value, index + 1);
}
```

4. **Added loading state**:
```dart
Expanded(
  child: _isLoadingLabels
      ? const Center(child: CircularProgressIndicator())
      : ListView.separated(...)
)
```

## Changes Made

### Modified Files
- `lib/features/forms/screens/my_submissions_screen.dart`

### Key Changes

1. **Added `_getFormTitle()` method** (lines 87-119)
   - Checks stored data first
   - Fetches from form template if needed
   - Provides fallback values

2. **Updated `_buildSubmissionCard()`** (lines 242-364)
   - Wrapped in `FutureBuilder` to load form title
   - Shows "Loading..." while fetching

3. **Converted `_SubmissionDetailView` to StatefulWidget** (lines 476-494)
   - Added state management
   - Added `initState()` to trigger form template loading

4. **Added `_loadFormTemplate()` method** (lines 502-546)
   - Fetches form template from Firestore
   - Extracts field labels into a map
   - Handles errors gracefully

5. **Updated detail view rendering** (lines 652-697)
   - Added loading indicator
   - Maps field IDs to labels before display
   - Falls back to field ID if label not found

## Results

### Before
```
List view:
- "Untitled Form"
- "Untitled Form"

Detail view:
1. 1756564707506
   Arabic

2. 1754407141413
   [empty]

3. 1754406457284
   IBRAHIM CAMARA
```

### After
```
List view:
- "Teacher Weekly Report"
- "Classroom Observation Form"

Detail view:
1. What language do you speak?
   Arabic

2. What is your phone number?
   [empty]

3. What is your full name?
   IBRAHIM CAMARA
```

## Technical Details

### Performance Considerations
- Form template fetching is done only once per detail view opening
- List view uses `FutureBuilder` which caches results automatically
- Minimal impact on scroll performance

### Error Handling
- Graceful fallbacks if form template not found
- Shows field ID if label cannot be loaded
- Loading states prevent confusion

### Firestore Queries
The fix requires two additional read operations per submission:
1. Form template read for title (list view)
2. Form template read for field labels (detail view)

Both are only executed when needed and cached appropriately.

## Testing Checklist

- [x] List view shows correct form titles
- [x] List view shows "Loading..." briefly then updates
- [x] Detail view shows actual question text instead of IDs
- [x] Detail view shows loading indicator while fetching labels
- [x] Falls back gracefully if form template missing
- [x] Falls back gracefully if field labels missing
- [x] No linter errors
- [x] No performance degradation

## Related Files

- `lib/features/forms/screens/my_submissions_screen.dart` - Main implementation
- `MY_SUBMISSIONS_FEATURE.md` - Original feature documentation
- `FORM_SUBMISSIONS_SECURITY.md` - Security implementation

## User Feedback

**User reported**: "all I'm seeing is Untitled Form. and when i click inside im just seeing these numbers"

**Status after fix**: ✅ **Resolved** - Users now see meaningful form titles and question labels

---

**Fixed Date**: November 11, 2025  
**Impact**: High - Feature now usable for all teachers

