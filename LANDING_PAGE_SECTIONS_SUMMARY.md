# Landing Page Sections & Subject Mapping - Complete Guide

## ✅ All Sections Now Present on Landing Page

The landing page now displays **all 5 main program categories** that match the enrollment form:

1. **Islamic Studies** → `'Islamic Studies: Quran, Hadith, Tawhid'`
2. **Languages** (Afro-lingual) → `'AfroLanguage: Poular, Mandingo, Swahili'`
3. **Adult Literacy** → `'Adult Literacy Studies: Reading, Writing (English)'` ⭐ NEW
4. **After School Tutoring** → `'After School Tutoring: Math, Science, History'`
5. **Math Classes** → `'After School Tutoring: Math, Science, History'` (for students)
6. **Programming** → `'After School Tutoring: Math, Science, History'` (for students)

## 📋 Subject Mapping Logic

### For Students (Academic Support)
**→ After School Tutoring: Math, Science, History**
- Math Classes
- Programming
- Science
- History
- Any academic subject help

### For Adults (Learning English)
**→ Adult Literacy Studies: Reading, Writing (English)**
- English page (defaults to Adult Literacy)
- Adult Literacy card on landing page

### For Language Learning (African Languages)
**→ AfroLanguage: Poular, Mandingo, Swahili**
- Languages card (Afro-lingual page)
- French, Yoruba, Hausa, Wolof, Adlam, etc.

### For Islamic Education
**→ Islamic Studies: Quran, Hadith, Tawhid**
- Islamic Studies card
- Quran, Arabic, Hadith, Tafsir courses

## 🎯 Navigation Flow

### From Landing Page Cards:

1. **Islamic Studies Card**
   - → Opens `IslamicCoursesPage`
   - → User clicks "Enroll Now" on any course
   - → Form pre-selects: `'Islamic Studies: Quran, Hadith, Tawhid'`

2. **Languages Card**
   - → Opens `AfrolingualPage`
   - → User clicks "Enroll Now" on any language
   - → Form pre-selects: `'AfroLanguage: Poular, Mandingo, Swahili'`

3. **Adult Literacy Card** ⭐ NEW
   - → Directly opens enrollment form
   - → Form pre-selects: `'Adult Literacy Studies: Reading, Writing (English)'`

4. **After School Tutoring Card**
   - → Directly opens enrollment form
   - → Form pre-selects: `'After School Tutoring: Math, Science, History'`

5. **Math Classes Card**
   - → Opens `MathPage`
   - → User clicks "Enroll Now"
   - → Form pre-selects: `'After School Tutoring: Math, Science, History'`

6. **Programming Card**
   - → Opens `ProgrammingPage`
   - → User clicks "Enroll Now"
   - → Form pre-selects: `'After School Tutoring: Math, Science, History'`

### From Subject Pages:

- **English Page** → Defaults to `'Adult Literacy Studies: Reading, Writing (English)'`
  - Note: Page includes message that students should choose "After School Tutoring" instead
  
- **Math Page** → `'After School Tutoring: Math, Science, History'`
- **Programming Page** → `'After School Tutoring: Math, Science, History'`
- **Islamic Courses Page** → `'Islamic Studies: Quran, Hadith, Tawhid'`
- **Afro-lingual Page** → `'AfroLanguage: Poular, Mandingo, Swahili'`

## 🔄 Smart Mapping Function

The `_mapSubjectToFormOption()` function in `ProgramSelectionPage` automatically converts:

| Input (from pages) | Output (form option) |
|-------------------|---------------------|
| "Adult Literacy" | `'Adult Literacy Studies: Reading, Writing (English)'` |
| "After School Tutoring" | `'After School Tutoring: Math, Science, History'` |
| "Math", "Programming", "Science" | `'After School Tutoring: Math, Science, History'` |
| "English" | `'Adult Literacy Studies: Reading, Writing (English)'` |
| "Islamic Studies", "Quran", "Arabic" | `'Islamic Studies: Quran, Hadith, Tawhid'` |
| "Afro", "French", "Yoruba", etc. | `'AfroLanguage: Poular, Mandingo, Swahili'` |

## 📝 Key Changes Made

1. ✅ **Added "Adult Literacy" card** to landing page (pink/magenta color)
2. ✅ **Updated English page** to default to Adult Literacy
3. ✅ **Added clarification** on English page that students should choose After School Tutoring
4. ✅ **Updated After School Tutoring card** to navigate directly to form
5. ✅ **Updated mapping function** to handle "Adult Literacy" and "After School Tutoring" as direct keywords
6. ✅ **Updated TutoringLiteracyPage** to navigate with correct subject

## 🎨 Visual Organization

The landing page now clearly separates:
- **Academic subjects** (Math, Programming) → After School Tutoring
- **Adult education** (English for adults) → Adult Literacy
- **Language learning** (African languages) → Languages
- **Religious education** → Islamic Studies

## ✅ Testing Checklist

- [ ] Click "Adult Literacy" card → Form shows "Adult Literacy Studies: Reading, Writing (English)"
- [ ] Click "After School Tutoring" card → Form shows "After School Tutoring: Math, Science, History"
- [ ] Click "Math Classes" → Math page → Enroll → Form shows "After School Tutoring: Math, Science, History"
- [ ] Click "Programming" → Programming page → Enroll → Form shows "After School Tutoring: Math, Science, History"
- [ ] Click "Languages" → Afro-lingual page → Enroll → Form shows "AfroLanguage: Poular, Mandingo, Swahili"
- [ ] Click "Islamic Studies" → Islamic page → Enroll → Form shows "Islamic Studies: Quran, Hadith, Tawhid"
- [ ] Navigate to English page → Enroll → Form shows "Adult Literacy Studies: Reading, Writing (English)"

## 💡 User Experience Improvements

1. **Clear separation** between student programs and adult programs
2. **Direct navigation** from landing page cards to enrollment form
3. **Smart pre-selection** based on user's starting point
4. **Flexibility** - users can still change the selection in the form if needed
5. **Clarification** on English page for students vs. adults

