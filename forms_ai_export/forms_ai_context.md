# Alluvial Academy — forms context for AI

Generated: 2026-03-22T18:48:35.597Z
Project: alluwal-academy

## How to use this
- **formTemplates** / **legacyForms**: each entry is one Firestore document; **questions** are UI fields.
- **fieldId** is the key stored under `responses` / `answers` in `form_responses` (numeric ids or snake_case strings).
- **responseSamples**: example answer shapes per template or legacy form.

## Summary

| Metric | Value |
|--------|-------|
| form_templates documents | 47 |
| form (legacy) documents | 33 |
| Total questions (rows) | 1320 |
| Distinct fieldIds in schemas | 599 |
| form_responses docs scanned (samples) | 4000 |

## Form templates (`form_templates`)

### All Bi-Weely Coachees Performance

- **Firestore**: `form_templates/0Nsvp0FofwFKa67mNVBX`
- **Questions**: 34
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754647635467` | How many times this teacher did their post class video recording for the past 2 weeks? | dropdown |  |
| 2 | `1754646633544` | Are this coachee Clock in & Out Hours correctly entered for the past 2 weeks? | radio | yes |
| 3 | `1754648183894` | How many Quizzes did this teacher give the past 2 weeks? | dropdown |  |
| 4 | `1754648539104` | How many formal excuses did this teacher requested for last month? | dropdown |  |
| 5 | `1762603006992` | Have you reviewed and approved the clock in and out for this teacher for the past 2 weeks | dropdown | yes |
| 6 | `1754646704061` | Is this teacher schedule up to date as of today? | dropdown | yes |
| 7 | `1754648459627` | If you listed any student in the previous question have you updated the Student Learning Coordinator (Kadijatu) about the students absences | dropdown |  |
| 8 | `1754648035001` | In the past month, how many interactions did you have with this teacher (interaction include: call, meeting and chats) | dropdown |  |
| 9 | `1754646853504` | What is the number of times this teacher left comments on his/her readiness for the past 2 week? | dropdown |  |
| 10 | `1754648658350` | Any comment additional comment about this teacher and his/her class | text |  |
| 11 | `1754646952991` | As the coach, have you addressed those comments? | dropdown |  |
| 12 | `1754648245467` | How many Assignment did this teacher give in the past 2 weeks? | dropdown |  |
| 13 | `1754625964834` | Coachee | dropdown |  |
| 14 | `1754647696457` | As the coach, have you been checking the general performance of this teacher's students by sometimes randonmly testing them, checking their grades or asking the teachers about them | dropdown |  |
| 15 | `1754625570522` | Coach Name | dropdown | yes |
| 16 | `1754648359902` | If applicable how many exam this teacher give this semester? | dropdown |  |
| 17 | `1754648697271` | Rate the overall performance of this teacher for the last 2 weeks | text |  |
| 18 | `1754625657517` | What is the total number of teachers you are coaching this month? | number | yes |
| 19 | `1754648319664` | How many absences does this teacher incur in the past 2 weeks? | dropdown |  |
| 20 | `1754625919184` | Week | dropdown | yes |
| 21 | `1754648607874` | If any student has been absent for more than 2 weeks, did you make sure the teacher is not attending this classDropdown | dropdown |  |
| 22 | `1754647920053` | Did this teacher's students attend last Month Bayana based on the readiness form record? | dropdown |  |
| 23 | `1754646906866` | How many of those comments you needed to address? | dropdown |  |
| 24 | `1754647985504` | If the previous question is not 100% attendance, have you contacted this teacher to know why | dropdown |  |
| 25 | `1754646984814` | So far does the clock in pattern correctly reflect this teacher's weekly schedule on the Connecteam Channel? | dropdown | yes |
| 26 | `1754648408096` | If applicable has this teacher update his/her Paycheck Form for the previous month? | radio |  |
| 27 | `1754648121895` | If applicable how many time has this teacher conducted students midterm? | dropdown |  |
| 28 | `1754646589540` | Is this the 1st or 2nd time you are submitting this form this teacher in this month? | dropdown | yes |
| 29 | `1754648429149` | List the names of students who have been absent from class for the past 2 weeks? | text |  |
| 30 | `1754647396475` | Does this teacher number of readiness form submitted match the number of time the clock in submisson? | dropdown |  |
| 31 | `1754647852703` | How many times this teacher join class late the past 2 weeks? | dropdown |  |
| 32 | `1754646772880` | Based on your careful review, how often does this coach edit his or her hours before submitting his or her clock in & out. | dropdown |  |
| 33 | `1754851252144` | Date | date | yes |
| 34 | `1754625695824` | To help prevent potential infractions or violations that could impact teachers' salaries at the end of the month, it is essential to promptly address any mistakes you observe while reviewing this form by guiding the teacher in making corrections before the following week. Will you commit to taking immediate action when you notice any issues? | dropdown | yes |

**Options (choice fields)**

- **1754647635467** (How many times this teacher did their post class video recording for the past 2 weeks?): 0; 1; 3; 4 +; Teacher is exempted
- **1754648183894** (How many Quizzes did this teacher give the past 2 weeks?): 0; 1 - 2; 3 - 5; 7 +
- **1754648539104** (How many formal excuses did this teacher requested for last month?): 0; 1; 2; 3; 4 - 6; 7 +
- **1762603006992** (Have you reviewed and approved the clock in and out for this teacher for the past 2 weeks): Yes I have approved it for this teacher; Not yet; I am lazy employee
- **1754646704061** (Is this teacher schedule up to date as of today?): No i will go fix it now; No -but i have fixed now; Yes it is all good
- **1754648459627** (If you listed any student in the previous question have you updated the Student Learning Coordinator (Kadijatu) about the students absences): Yes; No; I will
- **1754648035001** (In the past month, how many interactions did you have with this teacher (interaction include: call, meeting and chats)): 0; 1; 2; 3; 4-6; 7 +
- **1754646853504** (What is the number of times this teacher left comments on his/her readiness for the past 2 week?): 0; 1; 2-4; 5-7
- **1754646952991** (As the coach, have you addressed those comments?): Yes; No; I will this week
- **1754648245467** (How many Assignment did this teacher give in the past 2 weeks?): 0; 1; 2; 3-5; 6 +
- **1754625964834** (Coachee): Rahmatulahi Balde; Aliou Diallo; Ustada Lubna; Ustadha Siyam; Thieno Abdul; Abdoulai Yayah; Abdulai Diallo; Ustadha Elham; Ustadha NasruLlah; Ustaz Abu Faruk; Ustaz Al-hassan; Ustaz Arabieu; Ustaz Abdullah; Ustaz Abdulwarith; Ustaz Abdulkarim; Uataz Mohammed Jan; Ustaz Abdurahmane; Ustaz Ibrahim Bah; Ustaz Ibrahim Balde; Ustaz Kosiah…
- **1754647696457** (As the coach, have you been checking the general performance of this teacher's students by sometimes randonmly testing them, checking their grades or asking the teachers about them): Yes - 100% sure; Maybe - not sure cuz i don't often check; No - 0% learning; To some extent - 40 to 70 % learning; I need to improve my oversight
- **1754625570522** (Coach Name): Mamoudou; Mohammed Bah; Kadijatu Jalloh; Salimatu; Intern
- **1754648359902** (If applicable how many exam this teacher give this semester?): 0; 1; 2; 3
- **1754648319664** (How many absences does this teacher incur in the past 2 weeks?): 0; 1; 2; 3; 4; 5 +
- **1754625919184** (Week): Week 1; Week 3
- **1754648607874** (If any student has been absent for more than 2 weeks, did you make sure the teacher is not attending this classDropdown): Yes; No; I will double check
- **1754647920053** (Did this teacher's students attend last Month Bayana based on the readiness form record?): N/A; Yes - 100% attended; No - 0% attended; Just > 50% attended; Just < 50% attended
- **1754646906866** (How many of those comments you needed to address?): None; A couple; All
- **1754647985504** (If the previous question is not 100% attendance, have you contacted this teacher to know why): Yes - I have; No - I have not; I will later
- **1754646984814** (So far does the clock in pattern correctly reflect this teacher's weekly schedule on the Connecteam Channel?): Yes it is alright - I checked; No - there is mismatch- but I engaged the teacher already; No - many mismatches - but will contact this teacher; No time for me fix anything
- **1754648121895** (If applicable how many time has this teacher conducted students midterm?): 0; 1; 2; 3 - 5; 6 +; N/A
- **1754646589540** (Is this the 1st or 2nd time you are submitting this form this teacher in this month?): 1st Time; 2nd Time; N/A
- **1754647396475** (Does this teacher number of readiness form submitted match the number of time the clock in submisson?): I am lazy to check it out; Yes - this teacher has no problem with it; No - yes this teacher has a mismatch; I will check it out later
- **1754647852703** (How many times this teacher join class late the past 2 weeks?): 0; 1; 2; 3; 4; 5 +
- **1754646772880** (Based on your careful review, how often does this coach edit his or her hours before submitting his or her clock in & out.): Often; Never - this teacher is a pro Always; Rarely; N/A
- **1754625695824** (To help prevent potential infractions or violations that could impact teachers' salaries at the end of the month, it is essential to promptly address any mistakes you observe while reviewing this form by guiding the teacher in making corrections before the following week. Will you commit to taking immediate action when you notice any issues?): Yes I will; No I won't; I will try; I am unfocus rn

**Descriptions / placeholders**

- **1754647635467**: placeholder: Enter dropdown...
- **1754646633544**: placeholder: Verify this from the Time Sheet located in the Time Clock 
- **1754648183894**: placeholder: Enter dropdown...
- **1754648539104**: placeholder: Answer this only once a month
- **1762603006992**: placeholder: If not please do this now before submitting this form 
- **1754646704061**: placeholder: Go to the Schedule channel to fix any inaccurate or incomplete schedule...
- **1754648459627**: placeholder: Enter dropdown...
- **1754648035001**: placeholder: Answer this question once per month.
- **1754646853504**: placeholder: Enter dropdown...
- **1754648658350**: placeholder: Type here
- **1754646952991**: placeholder: Enter dropdown...
- **1754648245467**: placeholder: Enter dropdown...
- **1754625964834**: placeholder: Enter dropdown...
- **1754647696457**: placeholder: Do you really know if this teacher's students are truly learning?
- **1754625570522**: placeholder: Enter dropdown...
- **1754648359902**: placeholder: Enter dropdown...
- **1754648697271**: placeholder: 1 - 5, with 5 being the highest
- **1754625657517**: placeholder: Type here
- **1754648319664**: placeholder: Check the In and Out Zoom hosting form to determine
- **1754625919184**: placeholder: Enter dropdown...
- **1754648607874**: placeholder: This applies only to one - on - one class or if a whole group class stopped attending
- **1754647920053**: placeholder: Enter dropdown...
- **1754646906866**: placeholder: Enter dropdown...
- **1754647985504**: placeholder: Enter dropdown...
- **1754646984814**: placeholder: pls verify it and don't be lazy
- **1754648408096**: placeholder: Enter yes/no...
- **1754648121895**: placeholder: Enter dropdown...
- **1754646589540**: placeholder: Enter dropdown...
- **1754648429149**: placeholder: Check this teacher readiness form to student names
- **1754647396475**: placeholder: Pls go verify and demand the teacher to fix it if there is a problem, otherwise, waiting for the end of month to verify would have you equally responsible for any mistmatch
- **1754647852703**: placeholder: Check out the In and Out Zoom hosting form to find this information
- **1754646772880**: placeholder: Be sure to double check, do not guess because Chernor will know if you do
- **1754851252144**: placeholder: Enter date...
- **1754625695824**: placeholder: Tap to select

### X Progress Summary Report

- **Firestore**: `form_templates/0wxe4mCVTe3Y2ME67uEp`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1763638822522` | How many receipts were issued to parents by you this week? | text | yes |
| 2 | `1763639639755` | Note | long_text |  |
| 3 | `1763638433884` | How often did you verify the bank account this week? | dropdown | yes |
| 4 | `1763638190823` | Weeks | multi_select | yes |
| 5 | `1763639419218` | How many times did you submit the Zoom Hosting report this week? | multi_select |  |
| 6 | `1763638285875` | How many times did you submit the finance update this week? | dropdown | yes |
| 7 | `1763638908346` | Did you verify your teachers schudule this week? | radio | yes |
| 8 | `1763639124381` | How many times did you submit the End-of-Shift report this week? | multi_select | yes |
| 9 | `1763638106920` | Days | dropdown | yes |
| 10 | `1763638075534` | Name | text | yes |

**Options (choice fields)**

- **1763638433884** (How often did you verify the bank account this week?): 1 time; 2 time; 3 time; 4 time; 0 time; 5 time; 6 time; 7 time
- **1763638190823** (Weeks): Week1; Week2; Week3; Week4
- **1763639419218** (How many times did you submit the Zoom Hosting report this week?): 1 Time; 2 Time; 3 Time; 4 Time; 5 Time; 0 Time; 6 time; 7 Time
- **1763638285875** (How many times did you submit the finance update this week?): Week1; Week2; Week3; Week4
- **1763639124381** (How many times did you submit the End-of-Shift report this week?): 1 Time; 2 Time; 3 Time; 4 Time; 5 Time; 0 Time; 6 time; 7 Time
- **1763638106920** (Days): Sunday; Monday; Tuesday; Wednesday; Thursday; Friday; Saturday

**Descriptions / placeholders**

- **1763638822522**: placeholder: Enter text input...
- **1763639639755**: placeholder: Enter long text...
- **1763638433884**: placeholder: Enter dropdown...
- **1763638190823**: placeholder: Enter multi-select...
- **1763639419218**: placeholder: Enter multi-select...
- **1763638285875**: placeholder: Enter dropdown...
- **1763638908346**: placeholder: Yes, No, N/A
- **1763639124381**: placeholder: Enter multi-select...
- **1763638106920**: placeholder: Enter dropdown...
- **1763638075534**: placeholder: Enter text input...

### Weekly Summary

- **Firestore**: `form_templates/1jn3ilyI5P1QnoHSMe5E`
- **Questions**: 3
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `challenges` | Any challenges or support needed? | long_text |  |
| 2 | `achievements` | What were the key achievements this week? | long_text | yes |
| 3 | `weekly_progress` | How would you rate this week overall? | radio | yes |

**Options (choice fields)**

- **weekly_progress** (How would you rate this week overall?): Excellent; Good; Needs Improvement

**Descriptions / placeholders**

- **challenges**: placeholder: Leave empty if none
- **achievements**: placeholder: Summarize student progress, milestones reached, etc.

### Marketing Weekly Progress Summary Report

- **Firestore**: `form_templates/3MB3jxkjcCdD11us9q4N`
- **Questions**: 23
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754420784391` | What is your Name: | text |  |
| 2 | `1754420795708` | This week i feel | dropdown | yes |
| 3 | `1754420830580` | Date | date |  |
| 4 | `1754420858912` | Last week i was late for zoom hosting | dropdown | yes |
| 5 | `1754420898444` | Last week i was absence for zoom hosting | dropdown | yes |
| 6 | `1754420940618` | Last week i missed submitting my end of shit | dropdown | yes |
| 7 | `1754420961705` | How many Posts you did this week? | number | yes |
| 8 | `1754420976840` | Achievement | long_text | yes |
| 9 | `1754420990377` | Challenges | long_text | yes |
| 10 | `1754421007390` | Are your teacher schedules up to date - meaning their classes time, days are all correct? | dropdown | yes |
| 11 | `1754421038728` | If this is the fourth week of the month, have completed auditing all your teachers work & sent in the outcome to each teacher? | radio | yes |
| 12 | `1754421070183` | List how many task did you identify and assign to team members including teachers for this week ? | number | yes |
| 13 | `1754421089461` | List the names/titles of the forms you reviewed this week | long_text |  |
| 14 | `1754421102825` | How many flyers made this week | number | yes |
| 15 | `1754421119537` | How many video edited this week | number | yes |
| 16 | `1754421137310` | This week i worked on or updated info/content on: | multi_select | yes |
| 17 | `1754421194649` | How many time you submitted the Zoom Hosting Form this week? | number | yes |
| 18 | `1754421195861` | How many students did you directly and personally recruit this week? | number | yes |
| 19 | `1754421226081` | How many time you submitted the End of Shift Form this week? | number | yes |
| 20 | `1754421253332` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | long_text | yes |
| 21 | `1754421278858` | As a leader, how much do you feel that you are in control of teachers, projects, students and personal tasks this week? | number | yes |
| 22 | `1764197338442` | List the name of all your teachers whose clock in you have approve for this week | long_text |  |
| 23 | `1764197447609` | Have you approved all your teachers clock in hours for this week | dropdown |  |

**Options (choice fields)**

- **1754420795708** (This week i feel): Very productive ( achieved beyond expectation); Distracted/unproductive (no much achievement); Fairly Productive (did a little but must do better next week)
- **1754420858912** (Last week i was late for zoom hosting): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754420898444** (Last week i was absence for zoom hosting): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754420940618** (Last week i missed submitting my end of shit): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754421007390** (Are your teacher schedules up to date - meaning their classes time, days are all correct?): No Problem but I didn't check; Too lazy to check this week; I checked - no problem
- **1754421038728** (If this is the fourth week of the month, have completed auditing all your teachers work & sent in the outcome to each teacher?): Option 1
- **1754421137310** (This week i worked on or updated info/content on:): The Newsletter; Facebook/IG; Tiktok/Youtube; Website
- **1764197447609** (Have you approved all your teachers clock in hours for this week): Option 1

**Descriptions / placeholders**

- **1754420784391**: placeholder: What is your Name:
- **1754420795708**: placeholder: This week i feel
- **1754420830580**: placeholder: Date
- **1754420858912**: placeholder: Last week i was late for zoom hosting
- **1754420898444**: placeholder: Last week i was absence for zoom hosting
- **1754420940618**: placeholder: Last week i missed submitting my end of shit
- **1754420961705**: placeholder: How many Posts you did this week?
- **1754420976840**: placeholder: Achievement
- **1754420990377**: placeholder: Challenges
- **1754421007390**: placeholder: Are your teacher schedules up to date - meaning their classes time, days are all correct?
- **1754421038728**: placeholder: If this is the fourth week of the month, have completed auditing all your teachers work & sent in the outcome to each teacher?
- **1754421070183**: placeholder: List how many task did you identify and assign to team members including teachers for this week ?
- **1754421089461**: placeholder: List the names/titles of the forms you reviewed this week
- **1754421102825**: placeholder: How many flyers made this week
- **1754421119537**: placeholder: How many video edited this week
- **1754421137310**: placeholder: This week i worked on or updated info/content on:
- **1754421194649**: placeholder: How many time you submitted the Zoom Hosting Form this week?
- **1754421195861**: placeholder: How many students did you directly and personally recruit this week?
- **1754421226081**: placeholder: How many time you submitted the End of Shift Form this week?
- **1754421253332**: placeholder: Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction
- **1754421278858**: placeholder: As a leader, how much do you feel that you are in control of teachers, projects, students and personal tasks this week?
- **1764197338442**: placeholder: List the name of all your teachers whose clock in you have approve for this week
- **1764197447609**: placeholder:  Have you approved all your teachers clock in hours for this week

### Daily End of Shift form - CEO

- **Firestore**: `form_templates/4G0oKBSTA8l0780cQ2Vx`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754473430887` | Name/Nom | dropdown | yes |
| 2 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 3 | `1754473754870` | Days - Jour | dropdown | yes |
| 4 | `1754473834242` | Week - Semaine | dropdown | yes |
| 5 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift/Copiez et collez les objectifs de service d’aujourd’hui que vous avez partagés dans le groupe Eboard au début de ce service. | long_text | yes |
| 6 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement/Copiez et collez les objectifs de votre shift d’aujourd’hui que vous avez partagés dans le groupe Eboard au début de ce shift. | long_text | yes |
| 7 | `1754474096020` | For this week I am doing my shift for the/Pour cette semaine, j’effectue mon service pour le: | dropdown |  |
| 8 | `1754474204210` | What Time Are You Reporting to work/shift today/Septième fois | time | yes |
| 9 | `1754474407345` | Total Hours worked today/Nombre total d’heures travaillées aujourd’hui ? | text | yes |
| 10 | `1754474278156` | What Time Are Ending the work/shift today/À quelle heure terminez-vous votre travail/shift aujourd’hui? | text | yes |
| 11 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I/En fonction du total d’heures de travail que je rapporte pour le service d’aujourd’hui, je… | dropdown | yes |
| 12 | `1754474344242` | List All Your Challenges you experienced today/Listez tous les défis que vous avez rencontrés aujourd’hui. | text | yes |
| 13 | `1754476043141` | For this week I missed working during my expected shift/Cette semaine, j’ai manqué mon service prévu. | dropdown | yes |
| 14 | `1754476189834` | This week I missed reporting submitting my end of shift/Cette semaine, je n’ai pas soumis mon rapport de fin de service | dropdown | yes |
| 15 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift/Veuillez indiquer le nombre total de nouvelles tâches que vous vous êtes attribuées pendant ce service | text | yes |
| 16 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift/Indiquez le nombre total de nouvelles tâches que vous avez assignées aux autres membres de l'équipe pendant ce quart de travail. | text | yes |
| 17 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform/Au cours du service d’aujourd’hui, avez-vous innové ou apporté des améliorations à notre système ou plateforme | dropdown | yes |
| 18 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift/Avant de soumettre ce formulaire, j'ai appelé Chernor pour faire mon bilan de 5 minutes après chaque quart de travail. | dropdown | yes |
| 19 | `1762032275336` | For today's shift did you review the following forms and take action where necessary/Pour votre quart de travail d'aujourd'hui, avez-vous examiné les formulaires suivants et pris les mesures nécessaires? | multi_select | yes |
| 20 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete/À la fin de ce quart de travail, combien de tâches en retard reste-t-il à accomplir ?? | number | yes |
| 21 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift.  En vous basant sur le nombre total de tâches qui vous ont été assignées sur le site web, veuillez indiquer le titre de toutes les tâches que vous avez terminées et clôturées pendant votre quart de travail d'aujourd'hui. | long_text |  |

**Options (choice fields)**

- **1754473430887** (Name/Nom): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Akan; Kadijatu Jalloh; Sulaiman Barry; Mariama Cire Niane
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754473754870** (Days - Jour): Monday, Lundi; Tuesday, Mardi; Wednesday,; Thursday, Mercredi; Friday, Vendredi; Saturday, Samedi; Sunday, Dimanche
- **1754473834242** (Week - Semaine): Week1 - Semaine 1; Week2 - Semaine 2; Week3 - Semaine 3; Week4 - Semaine 4; Week5 - Semaine 5; N/A
- **1754474096020** (For this week I am doing my shift for the/Pour cette semaine, j’effectue mon service pour le:): 1st time - Première fois; 2nd time - Deuxième fois; 3rd time - Troisième fois; 4th time - Quatrième fois; 5th time - Cinquième fois; 6th time - Sixième fois; 7th time - Septième fois
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I/En fonction du total d’heures de travail que je rapporte pour le service d’aujourd’hui, je…): Underperformed today/Performance inférieure aujourd’hui; Overperformed today/Performance supérieure aujourd’hui; Need to do better/Doit s’améliorer; Fairly Performed/Performance correcte
- **1754476043141** (For this week I missed working during my expected shift/Cette semaine, j’ai manqué mon service prévu.): 1 time - Une fois; 2 times - Deux fois; 3 times - Trois fois; 4 times - 4 fois; 0 time - 0 temps; >5 times - >5 fois
- **1754476189834** (This week I missed reporting submitting my end of shift/Cette semaine, je n’ai pas soumis mon rapport de fin de service): 1 time - 1 Fois; 2 times - 2 Fois; 3 times - 3 Fois; 4 times - 4 Fois; >5 times - >5 Fois; 0 time - 0 Fois
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform/Au cours du service d’aujourd’hui, avez-vous innové ou apporté des améliorations à notre système ou plateforme): Yes - Oui; Today - Aujourd'hui; No - Non; Sometime Last Week - La semaine dernière; Never yet - Jamais encore
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift/Avant de soumettre ce formulaire, j'ai appelé Chernor pour faire mon bilan de 5 minutes après chaque quart de travail.): Yes he answered my call - Oui, il a répondu à mon appel.; Left him 2 missed calls - Il lui a laissé 2 appels manqués; I am too lazy to call him - J'ai la flemme de l'appeler
- **1762032275336** (For today's shift did you review the following forms and take action where necessary/Pour votre quart de travail d'aujourd'hui, avez-vous examiné les formulaires suivants et pris les mesures nécessaires?): None of the below - Aucun des choix ci-dessous; Readiness form - Formulaire de préparation; Fact-finding form - Formulaire de collecte de données; Excuse form - Formulaire d'excuse; Student Application Form - Formulaire de demande d'étudiant

**Descriptions / placeholders**

- **1754473430887**: placeholder: Select
- **1754473570961**: placeholder: I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team. Je confirme que j’accomplirai mes responsabilités de service avec sérieux, sans distraction, et que je respecterai la confiance placée en moi par l’équipe.
- **1754473754870**: placeholder: Select
- **1754473834242**: placeholder: Select
- **1763928780219**: placeholder: Paste here
- **1754473916403**: placeholder: Write here/Écrivez ici
- **1754474096020**: placeholder: Select
- **1754474204210**: placeholder: Select
- **1754474407345**: placeholder: Total
- **1754474278156**: placeholder: Write here/Écrivez ici
- **1754474569443**: placeholder: Rate Yourself/Évaluez-vous.
- **1754474344242**: placeholder: List Your Challenges/Listez vos défis.
- **1754476043141**: placeholder: Select
- **1754476189834**: placeholder: Select
- **1754476306952**: placeholder: State here - État ici
- **1754476452166**: placeholder: State here - État ici
- **1754476605073**: placeholder: Select
- **1762032619153**: placeholder: Select
- **1762032275336**: placeholder: Select
- **1763175894707**: placeholder: State here - État ici
- **1767596925135**: placeholder: State here- État ici

### Daily Class Report

- **Firestore**: `form_templates/4RDaZtzNDgizrydeDCS5`
- **Questions**: 4
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `session_quality` | How did the session go? | radio | yes |
| 2 | `issues` | Any issues or concerns? | long_text |  |
| 3 | `students_present` | How many students attended? | number | yes |
| 4 | `lesson_completed` | What lesson/topic did you cover today? | text | yes |

**Options (choice fields)**

- **session_quality** (How did the session go?): Excellent; Good; Average; Challenging

**Descriptions / placeholders**

- **issues**: placeholder: Leave empty if none
- **students_present**: placeholder: Number of students present
- **lesson_completed**: placeholder: e.g., Surah Al-Fatiha verses 1-3

### Forms/Facts Finding & Complains Report - leaders/CEO

- **Firestore**: `form_templates/5aXUrmtZnRGC5lj0bx7a`
- **Questions**: 13
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754483161194` | Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed | dropdown | yes |
| 2 | `1754483204692` | Your Name | dropdown | yes |
| 3 | `1754509820261` | What (title, form, or name) is your report about? | long_text | yes |
| 4 | `1754483410122` | Is this for | dropdown | yes |
| 5 | `1754483452846` | Month | dropdown | yes |
| 6 | `1754483514511` | Week | dropdown | yes |
| 7 | `1754483281251` | Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it | dropdown | yes |
| 8 | `1754483634804` | Who or what is this report/complaints ABOUT? | long_text | yes |
| 9 | `1754483675790` | Mention the team leader(s) this report should concern | long_text | yes |
| 10 | `1754483696467` | What findings are you reporting here: briefly explain | long_text | yes |
| 11 | `1754483719927` | Potential Repercussion for this complaint based on the bylaws | dropdown | yes |
| 12 | `1754483797967` | What do you want for the leader to do about this report | long_text | yes |
| 13 | `1754483819860` | Image Upload | text |  |

**Options (choice fields)**

- **1754483161194** (Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed): Yes; No
- **1754483204692** (Your Name): Chernor; Hashim; Mohammed; Salimatu; Mariama Cire Niane; Khadijah; Mamoudou; Akan Marcellinus Ikongshull; Sulaiman A. Barry
- **1754483410122** (Is this for): Complaint Againts An Issue; Just Awareness
- **1754483452846** (Month): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754483514511** (Week): Week1; Week2; Week3; Week4
- **1754483281251** (Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it): Yes I addressed it; No - it is outside my ability; I will address it later
- **1754483719927** (Potential Repercussion for this complaint based on the bylaws): $3-$9 paycut; $10-$19 paycut; $20 + paycut; Warning Letter; Suspension without payment; N/A

**Descriptions / placeholders**

- **1754483161194**: placeholder: Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed
- **1754483204692**: placeholder: Your Name
- **1754509820261**: placeholder: What (title, form, or name) is your report about?
- **1754483410122**: placeholder: Is this for 
- **1754483452846**: placeholder: Month
- **1754483514511**: placeholder: Week
- **1754483281251**: placeholder: Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it
- **1754483634804**: placeholder: Who or what is this report/complaints ABOUT?
- **1754483675790**: placeholder: Mention the team leader(s) this report should concern 
- **1754483696467**: placeholder: What findings are you reporting here: briefly explain 
- **1754483719927**: placeholder: Potential Repercussion for this complaint based on the bylaws
- **1754483797967**: placeholder: What do you want for the leader to do about this report
- **1754483819860**: placeholder: Image Upload

### Excuse Form for teachers & leaders/Formulaire d'excuse des enseignants CEO/Khadijatu

- **Firestore**: `form_templates/6YBwJQoLQ5tNU3RjDp7f`
- **Questions**: 16
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754399726889` | What is your name/Quel est ton nom?Please add your name as it appears in our records/Veuillez ajouter votre nom tel qu'il apparaît dans nos dossiers | text | yes |
| 2 | `1754400366403` | Who is submitting this form/Qui remplit ce formulaire ?? | multi_select | yes |
| 3 | `1754401719744` | If you are a teacher, how many student do you have now/ Combien d’élèves avez-vous actuellement ?? Please select from the dropdown the number of students you have/Veuillez sélectionner dans la liste déroulante le nombre d'étudiants que vous avez. | multi_select |  |
| 4 | `1754402171621` | If you are an admin or an intern, type below why do you want to be excused from mention name of tasks, works or role you need this excuse for/Si vous êtes administrateur ou stagiaire, indiquez ci-dessous pourquoi vous demandez cette excuse, en précisant le nom des tâches, travaux ou responsabilités pour lesquels vous avez besoin de cette absence. | text |  |
| 5 | `1754402244111` | If you are an admin list the title/names of your projects and tasks due during your excuse period so that the team can handle them while you are away/Si vous êtes un administrateur, veuillez lister les titres/noms de vos projets et tâches prévus pendant votre période d’absence afin que l’équipe puisse les gérer en votre absence. | text |  |
| 6 | `1754402305480` | Why do you want to be excused/Pourquoi veux-tu être excusé ? This document is accessible to admins so your information is save as per your constitution and data policy/Ce document est accessible aux administrateurs afin que vos informations soient enregistrées conformément à votre constitution et à votre politique de données. | text | yes |
| 7 | `1754402396459` | How many days are you asking for/Combien de jours demandez-vous ? | text | yes |
| 8 | `1754402840684` | Which date would you like to be excused/Quand souhaiteriez-vous être excusé ? Please specify the exalt date you will be unavailable/Veuillez préciser la date d'exaltation à laquelle vous ne serez pas disponible. | date | yes |
| 9 | `1754402885007` | Which date will you be back to work/Quand seras-tu de retour? The exalt date you will be returning to work/Quelle est la date à laquelle vous retournerez au travail ? | date | yes |
| 10 | `1754402926724` | Is this part of your pay leave/Est-ce que cela fait partie de votre congé payé ? If no, please know you won't be paid for the hours you are missing/Si non, sachez que vous ne serez pas payé pour les heures manquantes. | radio | yes |
| 11 | `1754402977293` | Have you arranged with another teacher/leader to cover your class or task while you are  You can find a teacher/leader to do this or we will assign your student to a teacher for the duration of your leave, and they will be paid for the additional hours/Vous pouvez trouver un enseignant pour le faire ou nous assignerons votre élève à un enseignant pour la durée de votre congé, et celui-ci sera rémunéré pour les heures supplémentaires. | multi_select | yes |
| 12 | `1754403200671` | If you answered yes to previous question, or you have found someone to replace you or to teach your class or do your task while you are away, pls write the person's name below. Ignore this question if you have not found anyone. Si vous avez répondu « oui » à la question précédente, ou si vous avez trouvé quelqu’un pour vous remplacer, assurer votre cours ou accomplir votre tâche pendant votre absence, veuillez indiquer son nom ci-dessous. Ignorez cette question si vous n’avez trouvé personne. | text |  |
| 13 | `1754403234621` | As per our Bylaws, you must be submit this excuse at least (2 days) before the main date of your excuse. So how soon are you submitting this form? Anything less than 2 days for a foreseeable excuse will be penalized/Selon nos règlements, toute demande d’excuse doit être soumise au moins 2 jours à l’avance. Tout délai inférieur à 2 jours pour une absence prévisible entraînera une pénalité. | multi_select | yes |
| 14 | `1754403284826` | If this is part of your 3 days free pay-leave break for this semester is it your. Si cela fait partie de vos 3 jours de congé payé pour ce semestre, veuillez le confirmer. | multi_select | yes |
| 15 | `1754403356959` | Sure! Here’s a shoAlert: If this is not part of your 3 paid leave days, valid evidence must be uploaded for this excuse to be considered Upload any reasonable evidence - without which your excuse might not be granted. Si cette absence ne fait pas partie de vos 3 jours de congé payé, vous devez télécharger une preuve valable pour qu’elle soit prise en considération. À défaut de justificatif raisonnable, votre demande pourrait être refusée. | text |  |
| 16 | `1754403394893` | Any comment/Avez-vous des commentaires. | text |  |

**Options (choice fields)**

- **1754400366403** (Who is submitting this form/Qui remplit ce formulaire ??): A Teacher - Un enseignant; An Admin - Un administrateur; An Intern - Un stagiaire
- **1754401719744** (If you are a teacher, how many student do you have now/ Combien d’élèves avez-vous actuellement ?? Please select from the dropdown the number of students you have/Veuillez sélectionner dans la liste déroulante le nombre d'étudiants que vous avez.): 1; 2-3; Above 5/Au-dessus de 5
- **1754402977293** (Have you arranged with another teacher/leader to cover your class or task while you are  You can find a teacher/leader to do this or we will assign your student to a teacher for the duration of your leave, and they will be paid for the additional hours/Vous pouvez trouver un enseignant pour le faire ou nous assignerons votre élève à un enseignant pour la durée de votre congé, et celui-ci sera rémunéré pour les heures supplémentaires.): Yes; No; Help me found one; No need
- **1754403234621** (As per our Bylaws, you must be submit this excuse at least (2 days) before the main date of your excuse. So how soon are you submitting this form? Anything less than 2 days for a foreseeable excuse will be penalized/Selon nos règlements, toute demande d’excuse doit être soumise au moins 2 jours à l’avance. Tout délai inférieur à 2 jours pour une absence prévisible entraînera une pénalité.): 2 days earlier - 2 jours plus tôt; Less than a day earlier - Moins d’un jour avant; 3 - 5 Days earlier - 3 à 5 jours plus tôt; 1 Day earlier - 1 jour plus tôt; Days into my excuse - Jours depuis le début de mon excuse; After my excuse - Après mon excuse
- **1754403284826** (If this is part of your 3 days free pay-leave break for this semester is it your. Si cela fait partie de vos 3 jours de congé payé pour ce semestre, veuillez le confirmer.): 1st time requesting it/Demande de congé.; 2nd time requesting it/Demande de congé.; 3rd time requesting it/Demande de congé.; I have exceed my 3 days pay-leave for the semester/J’ai dépassé mes 3 jours de congé payé pour le semestre.; Count this as a non payment binding/Veuillez considérer cela comme une absence non rémunérée.; outside of my free 3 days/En dehors de mes 3 jours de congé payé.; I don't remember/Je ne me souviens pas

**Descriptions / placeholders**

- **1754400366403**: placeholder: Enter multi-select...
- **1754401719744**: placeholder: Enter multi-select...
- **1754402171621**: placeholder: Enter text input...
- **1754402244111**: placeholder: Enter text input...
- **1754402305480**: placeholder: Enter text input...
- **1754402396459**: placeholder: Enter text input...
- **1754402840684**: placeholder: Enter date...
- **1754402885007**: placeholder: Enter date...
- **1754402926724**: placeholder: Yes, No
- **1754402977293**: placeholder: Enter multi-select...
- **1754403200671**: placeholder: Enter text input...
- **1754403234621**: placeholder: Enter multi-select...
- **1754403284826**: placeholder: Enter multi-select...
- **1754403356959**: placeholder: Enter image upload...
- **1754403394893**: placeholder: Enter text input...

### Daily End of Shift form - CEO

- **Firestore**: `form_templates/85R0ZZdF4UWBEVkcSF2P`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754473430887` | Name | dropdown | yes |
| 2 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 3 | `1754473754870` | Days | dropdown | yes |
| 4 | `1754473834242` | Week | dropdown | yes |
| 5 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift. | long_text | yes |
| 6 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement | text | yes |
| 7 | `1754474096020` | For this week I am doing my shift for the: | dropdown |  |
| 8 | `1754474204210` | What Time Are You Reporting to work/shift today | text | yes |
| 9 | `1754474278156` | What Time Are Ending the work/shift today | text | yes |
| 10 | `1754474407345` | Total Hours worked today ? | text | yes |
| 11 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I | dropdown | yes |
| 12 | `1754474344242` | List All Your Challenges you experienced today | text | yes |
| 13 | `1754476043141` | For this week I missed working during my expected shift | dropdown | yes |
| 14 | `1754476189834` | This week I missed reporting submitting my end of shift | dropdown | yes |
| 15 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift | text | yes |
| 16 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift | text | yes |
| 17 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform | dropdown | yes |
| 18 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift | dropdown | yes |
| 19 | `1762032275336` | For today's shift did you review the following forms and take action where necessary? | multi_select | yes |
| 20 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete? | number | yes |
| 21 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. | long_text |  |

**Options (choice fields)**

- **1754473430887** (Name): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Abdi; Kadijatu Jalloh; Sulaiman
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754473754870** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday
- **1754473834242** (Week): Week1; Week2; Week3; Week4; N/A
- **1754474096020** (For this week I am doing my shift for the:): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time; 7th time
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I): Underperformed today; Overperformed today; Need to do better; Fairly Performed
- **1754476043141** (For this week I missed working during my expected shift): 1 time; 2 times; 3times; 4 times; 0 time; >5 times
- **1754476189834** (This week I missed reporting submitting my end of shift): 1 time; 2 times; 3 times; 4 times; >5 times; 0 time
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform): Yes; Today; Yes; something Last Week; Never yet
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift): Yes he answered my call; Left him 2 missed calls; I am too lazy to call him
- **1762032275336** (For today's shift did you review the following forms and take action where necessary?): None of the below; Readiness form; Fact-finding form; Excuse form; Student Application Form

**Descriptions / placeholders**

- **1754473430887**: placeholder: Name 
- **1754473570961**: placeholder: I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team
- **1754473754870**: placeholder: Days
- **1754473834242**: placeholder: Week 
- **1763928780219**: placeholder: Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift.
- **1754473916403**: placeholder: List your Achievements during your shift & add time you spent working on each listed achievement
- **1754474096020**: placeholder: For this week I am doing my shift for the: 
- **1754474204210**: placeholder: What Time Are You Reporting to work/shift today
- **1754474278156**: placeholder: What Time Are Ending the work/shift today
- **1754474407345**: placeholder: Total Hours worked today ?
- **1754474569443**: placeholder: Based on the total hours of work I am reporting for today's shift I 
- **1754474344242**: placeholder: List All Your Challenges you experienced today
- **1754476043141**: placeholder: For this week I missed working during my expected shift
- **1754476189834**: placeholder: This week I missed reporting submitting my end of shift
- **1754476306952**: placeholder: Enter the total number of new task you assigned to yourself during this shift 
- **1754476452166**: placeholder: Enter the total number of new task you assigned to other team members during this shift 
- **1754476605073**: placeholder: For today's shift did you innovate or improve any of our system or platform
- **1762032619153**: placeholder: Before submitting this form, i have called Chernor as my 5 mins check out call after every shift
- **1762032275336**: placeholder: For today's shift did you review the following forms and take action where necessary? 
- **1763175894707**: placeholder: As of the end of this shift, how many tasks do you have as overdue that are yet to complete?
- **1767596925135**: placeholder: Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. 

### Monthly Penalty/Repercussion Record Mamoudou/CEO

- **Firestore**: `form_templates/9brFmSdi0AVOCkLteVef`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754475667927` | Violation Type | multi_select |  |
| 2 | `1754475455754` | Who is this record about | multi_select | yes |
| 3 | `1754476164451` | Month The Month Violation Was Committed | multi_select | yes |
| 4 | `1754475806194` | Type of Repercussion | multi_select |  |
| 5 | `1754476060258` | Briefly explain the violator reaction the punishment | text |  |
| 6 | `1754476095426` | Who this person coach or mentor | multi_select |  |
| 7 | `1754475889796` | Amount cut | text |  |
| 8 | `1754475387446` | Name of leader submitting this form | multi_select | yes |
| 9 | `1754475990192` | Briefly explained what was this person's punishment about | text |  |
| 10 | `1754475912785` | For this semester, is this person | multi_select |  |

**Options (choice fields)**

- **1754475667927** (Violation Type): Not Giving Assessments; Meeting lateness; Class Absence; Class Lateness; False reporting; Behavioral Violation; Task/Project incompletion; Failure to comply with student works and grade expectation; Refuse to attend meeting; Other
- **1754475455754** (Who is this record about): Khadijah; Mamoudou; Abdulkarim; Abrahim Bah; Ayobami; Lubna; Siyam; Elham; Bano Bah; Kairullah; Ibn Mustapha; Abdullah Balde; Korka; Amadou Oury; Asma; Nasrullah; Arabieu; Ibrahim Bah; Kaiza; Kosiah…
- **1754476164451** (Month The Month Violation Was Committed): Jan; Feb; Mar; Apr; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1754475806194** (Type of Repercussion): Warning letter; Pay cut; Meeting hearing; Dismissal; Coaching; Other
- **1754476095426** (Who this person coach or mentor): Chernor; Salimatu; Mohammed Bah; Kadijatu Jalloh
- **1754475387446** (Name of leader submitting this form): Mamoudou; Salimatu; Abdi; Mohammed Bah; Kadijatu Jalloh
- **1754475912785** (For this semester, is this person): 1st Punishment; 2nd Punishment; 3rd Punishment; 4th Punishment; 5th Punishment; 6th Punishment

**Descriptions / placeholders**

- **1754475667927**: placeholder: Enter multi-select...
- **1754475455754**: placeholder: Enter multi-select...
- **1754476164451**: placeholder: Enter multi-select...
- **1754475806194**: placeholder: Enter multi-select...
- **1754476060258**: placeholder: Enter text input...
- **1754476095426**: placeholder: Enter multi-select...
- **1754475889796**: placeholder: Enter text input...
- **1754475387446**: placeholder: Enter multi-select...
- **1754475990192**: placeholder: Enter text input...
- **1754475912785**: placeholder: Enter multi-select...

### Resignation Form/Formulaire de demission

- **Firestore**: `form_templates/9zWeiewbh5IoRT2FrYPm`
- **Questions**: 7
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754610949591` | Can you tell us breifly the reason you are resigning/Pouvez-vous nous expliquer brièvement la raison pour laquelle vous démissionnez? | text | yes |
| 2 | `1754611239500` | The date you will be resigning { i.e a week after filling this form}/La date à laquelle vous démissionnerez { soit une semaine après avoir rempli ce formulaire} | date | yes |
| 3 | `1754611439235` | Will you be intrested in returning to us in the future/Serez-vous intéressé à revenir vers nous à l'avenir?Text Input | text | yes |
| 4 | `1754610908280` | Name in Full/Nom complet | text | yes |
| 5 | `1754611579116` | kindly upload your Resign Letter here/veuillez télécharger votre lettre de démission ici | text | yes |
| 6 | `1754611076612` | Resigning date [the date you're filling this form]/Date de démission [la date à laquelle vous remplissez ce formulaire] | date | yes |
| 7 | `1754611312550` | What feedback do you have for us as an institution/Quels retours avez-vous pour nous en tant qu'institution? | text | yes |

**Descriptions / placeholders**

- **1754610949591**: placeholder: Type here
- **1754611239500**: placeholder: Select Date
- **1754611439235**: placeholder: Type here
- **1754610908280**: placeholder: Type here
- **1754611579116**: placeholder: Enter image upload...
- **1754611076612**: placeholder: Select Date
- **1754611312550**: placeholder: Type here

### Forms/Facts Finding & Complains Report - leaders/CEO

- **Firestore**: `form_templates/BvssujZxYz2aAFlFvlYD`
- **Questions**: 13
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754483514511` | Week | dropdown | yes |
| 2 | `1754509820261` | What (title, form, or name) is your report about? | long_text | yes |
| 3 | `1754483719927` | Potential Repercussion for this complaint based on the bylaws | dropdown | yes |
| 4 | `1754483675790` | Mention the team leader(s) this report should concern | long_text | yes |
| 5 | `1754483410122` | Is this for | dropdown | yes |
| 6 | `1754483696467` | What findings are you reporting here: briefly explain | long_text | yes |
| 7 | `1754483819860` | Image Upload | text |  |
| 8 | `1754483281251` | Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it | dropdown | yes |
| 9 | `1754483452846` | Month | dropdown | yes |
| 10 | `1754483204692` | Your Name | dropdown | yes |
| 11 | `1754483797967` | What do you want for the leader to do about this report | long_text | yes |
| 12 | `1754483161194` | Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed | dropdown | yes |
| 13 | `1754483634804` | Who or what is this report/complaints ABOUT? | long_text | yes |

**Options (choice fields)**

- **1754483514511** (Week): Week1; Week2; Week3; Week4
- **1754483719927** (Potential Repercussion for this complaint based on the bylaws): $3-$9 paycut; $10-$19 paycut; $20 + paycut; Warning Letter; Suspension without payment; N/A
- **1754483410122** (Is this for): Complaint Againts An Issue; Just Awareness
- **1754483281251** (Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it): Yes I addressed it; No - it is outside my ability; I will address it later
- **1754483452846** (Month): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754483204692** (Your Name): Chernor; Hashim; Mohammed; Salimatu; Abdi; Khadijah; Mamoudou
- **1754483161194** (Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed): Yes; No

**Descriptions / placeholders**

- **1754483514511**: placeholder:  Week
- **1754509820261**: placeholder: Just mention the title ( such as "teacher audit" for example)
- **1754483719927**: placeholder: Verify the code of conduct to determine this
- **1754483675790**: placeholder: Who on our team need to take action about what you are reporting? 
- **1754483410122**: placeholder: fill in
- **1754483696467**: placeholder: Be accurate
- **1754483819860**: placeholder: Image report
- **1754483281251**: placeholder: Choose carefully
- **1754483452846**: placeholder: Month
- **1754483204692**: placeholder: Choose
- **1754483797967**: placeholder: Be clear and mention next course of action needed to be taken 
- **1754483161194**: placeholder: Enter dropdown...
- **1754483634804**: placeholder: Name the reason or person whom you are reporting/complaining about 

### Summer Plans (Teachers & Admins)

- **Firestore**: `form_templates/E94ldH6uHrvr3D8f8pkF`
- **Questions**: 6
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754616294003` | Will you teach or work with the hub this summer | radio | yes |
| 2 | `1754616792297` | If yes, how many additional hours would you like to commit, or how many more classes are you able to take? | text | yes |
| 3 | `1754616394560` | Are you willing to take more students or put in more hours this summer? | radio | yes |
| 4 | `1754615817761` | Position/TittleDropdown | dropdown | yes |
| 5 | `1754615643919` | Submitted by: | text | yes |
| 6 | `1754615968757` | Travelling Date | date | yes |

**Options (choice fields)**

- **1754615817761** (Position/TittleDropdown): Teacher; Admin

**Descriptions / placeholders**

- **1754616294003**: placeholder: Enter yes/no...
- **1754616792297**: placeholder: Enter text input...
- **1754616394560**: placeholder: Enter yes/no...
- **1754615817761**: placeholder: Enter dropdown...
- **1754615643919**: placeholder: Type Name
- **1754615968757**: placeholder: Enter date...

### Monthly Penalty/Repercussion Record Mamoudou/CEO

- **Firestore**: `form_templates/FEjhCvAr2sG1d57QuqOb`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754475387446` | Name of leader submitting this form | multi_select | yes |
| 2 | `1754475455754` | Who is this record about | multi_select | yes |
| 3 | `1754475667927` | Violation Type | multi_select |  |
| 4 | `1754475806194` | Type of Repercussion | multi_select |  |
| 5 | `1754475889796` | Amount cut | text |  |
| 6 | `1754475912785` | For this semester, is this person | multi_select |  |
| 7 | `1754475990192` | Briefly explained what was this person's punishment about | text |  |
| 8 | `1754476060258` | Briefly explain the violator reaction the punishment | text |  |
| 9 | `1754476095426` | Who this person coach or mentor | multi_select |  |
| 10 | `1754476164451` | Month The Month Violation Was Committed | multi_select | yes |

**Options (choice fields)**

- **1754475387446** (Name of leader submitting this form): Mamoudou; Salimatu; Abdi; Mohammed Bah; Kadijatu Jalloh
- **1754475455754** (Who is this record about): Khadijah; Mamoudou; Abdulkarim; Abrahim Bah; Ayobami; Lubna; Siyam; Elham; Bano Bah; Kairullah; Ibn Mustapha; Abdullah Balde; Korka; Amadou Oury; Asma; Nasrullah; Arabieu; Ibrahim Bah; Kaiza; Kosiah…
- **1754475667927** (Violation Type): Not Giving Assessments; Meeting lateness; Class Absence; Class Lateness; False reporting; Behavioral Violation; Task/Project incompletion; Failure to comply with student works and grade expectation; Refuse to attend meeting; Other
- **1754475806194** (Type of Repercussion): Warning letter; Pay cut; Meeting hearing; Dismissal; Coaching; Other
- **1754475912785** (For this semester, is this person): 1st Punishment; 2nd Punishment; 3rd Punishment; 4th Punishment; 5th Punishment; 6th Punishment
- **1754476095426** (Who this person coach or mentor): Chernor; Salimatu; Mohammed Bah; Kadijatu Jalloh
- **1754476164451** (Month The Month Violation Was Committed): Jan; Feb; Mar; Apr; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec

**Descriptions / placeholders**

- **1754475387446**: placeholder: Name of leader submitting this form
- **1754475455754**: placeholder: Who is this record about
- **1754475667927**: placeholder: Violation Type
- **1754475806194**: placeholder: Type of Repercussion
- **1754475889796**: placeholder: Amount cut
- **1754475912785**: placeholder: For this semester, is this person
- **1754475990192**: placeholder: Briefly explained what was this person's punishment about
- **1754476060258**: placeholder: Briefly explain the violator reaction the punishment
- **1754476095426**: placeholder: Who this person coach or mentor
- **1754476164451**: placeholder: Month The Month Violation Was Committed

### Daily End of Shift form - CEO

- **Firestore**: `form_templates/GvJwLp8p8YaKNo0XexJT`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754473430887` | Name | dropdown | yes |
| 2 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 3 | `1754473754870` | Days | dropdown | yes |
| 4 | `1754473834242` | Week | dropdown | yes |
| 5 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift. | long_text | yes |
| 6 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement | text | yes |
| 7 | `1754474096020` | For this week I am doing my shift for the: | dropdown |  |
| 8 | `1754474204210` | What Time Are You Reporting to work/shift today | text | yes |
| 9 | `1754474278156` | What Time Are Ending the work/shift today | text | yes |
| 10 | `1754474407345` | Total Hours worked today ? | text | yes |
| 11 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I | dropdown | yes |
| 12 | `1754474344242` | List All Your Challenges you experienced today | text | yes |
| 13 | `1754476043141` | For this week I missed working during my expected shift | dropdown | yes |
| 14 | `1754476189834` | This week I missed reporting submitting my end of shift | dropdown | yes |
| 15 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift | text | yes |
| 16 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift | text | yes |
| 17 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform | dropdown | yes |
| 18 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift | dropdown | yes |
| 19 | `1762032275336` | For today's shift did you review the following forms and take action where necessary? | multi_select | yes |
| 20 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete? | number | yes |
| 21 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. | long_text |  |

**Options (choice fields)**

- **1754473430887** (Name): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Mariama Cire Niane; Kadijatu Jalloh; Sulaiman A. Barry; Akan Marcellinus Ikongshull
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754473754870** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday
- **1754473834242** (Week): Week1; Week2; Week3; Week4; N/A
- **1754474096020** (For this week I am doing my shift for the:): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time; 7th time
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I): Underperformed today; Overperformed today; Need to do better; Fairly Performed
- **1754476043141** (For this week I missed working during my expected shift): 1 time; 2 times; 3times; 4 times; 0 time; >5 times
- **1754476189834** (This week I missed reporting submitting my end of shift): 1 time; 2 times; 3 times; 4 times; >5 times; 0 time
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform): Yes; Today; Yes; something Last Week; Never yet
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift): Yes he answered my call; Left him 2 missed calls; I am too lazy to call him
- **1762032275336** (For today's shift did you review the following forms and take action where necessary?): None of the below; Readiness form; Fact-finding form; Excuse form; Student Application Form

**Descriptions / placeholders**

- **1754473430887**: placeholder: Name 
- **1754473570961**: placeholder: I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team
- **1754473754870**: placeholder: Days
- **1754473834242**: placeholder: Week 
- **1763928780219**: placeholder: Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift.
- **1754473916403**: placeholder: List your Achievements during your shift & add time you spent working on each listed achievement
- **1754474096020**: placeholder: For this week I am doing my shift for the: 
- **1754474204210**: placeholder: What Time Are You Reporting to work/shift today
- **1754474278156**: placeholder: What Time Are Ending the work/shift today
- **1754474407345**: placeholder: Total Hours worked today ?
- **1754474569443**: placeholder: Based on the total hours of work I am reporting for today's shift I 
- **1754474344242**: placeholder: List All Your Challenges you experienced today
- **1754476043141**: placeholder: For this week I missed working during my expected shift
- **1754476189834**: placeholder: This week I missed reporting submitting my end of shift
- **1754476306952**: placeholder: Enter the total number of new task you assigned to yourself during this shift 
- **1754476452166**: placeholder: Enter the total number of new task you assigned to other team members during this shift 
- **1754476605073**: placeholder: For today's shift did you innovate or improve any of our system or platform
- **1762032619153**: placeholder: Before submitting this form, i have called Chernor as my 5 mins check out call after every shift
- **1762032275336**: placeholder: For today's shift did you review the following forms and take action where necessary? 
- **1763175894707**: placeholder: As of the end of this shift, how many tasks do you have as overdue that are yet to complete?
- **1767596925135**: placeholder: Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. 

### Payment Request/Advance CEO

- **Firestore**: `form_templates/ILMi0ShOhMvL6UUvXGLO`
- **Questions**: 11
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754612176642` | Your Name | text | yes |
| 2 | `1754612226604` | Who are you requesting this for? | text | yes |
| 3 | `1754612363426` | Over the past 6 months, this is my | dropdown | yes |
| 4 | `1754612493990` | What is this submission for ? | dropdown | yes |
| 5 | `1754612573403` | Why this request | text | yes |
| 6 | `1754612617191` | How giving you this creadit benefit/support the work you do with us and our institution ? | text | yes |
| 7 | `1754612720342` | Where would you want the payment of this prepayment to come from | dropdown | yes |
| 8 | `1754612938747` | How much do you need? | text | yes |
| 9 | `1754613040481` | When do you need this request | date | yes |
| 10 | `1754613101609` | I acknowledge that the transfer fees associated with this requests will be from this amount | dropdown | yes |
| 11 | `1754614840185` | You must commit to remind Chernor about it including ensuring you paiy it back on time | dropdown | yes |

**Options (choice fields)**

- **1754612363426** (Over the past 6 months, this is my): 1st time requesting advance payment; 2nd time requesting advance payment; 3rd time requesting advance payment; 4th time requesting advance payment; N/A
- **1754612493990** (What is this submission for ?): Salary PrePayment; Salary Save Keeping; Payment Update
- **1754612720342** (Where would you want the payment of this prepayment to come from): This month Salary; I refund it myself; Next Month Salary
- **1754613101609** (I acknowledge that the transfer fees associated with this requests will be from this amount): N/A; Yes
- **1754614840185** (You must commit to remind Chernor about it including ensuring you paiy it back on time): I will remind Chernor and ensure he subtract it from my next pay; I won't commit to paying this; Chernor must remember to pressure me

**Descriptions / placeholders**

- **1754612176642**: placeholder: Your Name
- **1754612226604**: placeholder: Who are you requesting this for?
- **1754612363426**: placeholder: Over the past 6 months, this is my
- **1754612493990**: placeholder: What is this submission for ?
- **1754612573403**: placeholder: Why this request
- **1754612617191**: placeholder: How giving you this creadit benefit/support the work you do with us and our institution ?
- **1754612720342**: placeholder: Where would you want the payment of this prepayment to come from
- **1754612938747**: placeholder: How much do you need?
- **1754613040481**: placeholder: When do you need this request
- **1754613101609**: placeholder: I acknowledge that the transfer fees associated with this requests will be from this amount
- **1754614840185**: placeholder: You must commit to remind Chernor about it including ensuring you paiy it back on time

### Task Assignments (For Leaders) - CEO

- **Firestore**: `form_templates/KYlCFFdoQiUvcwQCiOjZ`
- **Questions**: 11
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754649006671` | Is this a recurring task? | dropdown | yes |
| 2 | `1754649775505` | Task or Project Description | text |  |
| 3 | `1754649343961` | This task should be assigned to | dropdown | yes |
| 4 | `1754648907485` | Task creator | dropdown |  |
| 5 | `1754649609157` | Not in used) Estimated Deadline from today | dropdown |  |
| 6 | `1765045326068` | This task/project should be assigned on connecteam by? | date | yes |
| 7 | `1754649263260` | Assign this task to: | dropdown | yes |
| 8 | `1754649716088` | Not in used - This task/project should be assigned on connecteam by? | text |  |
| 9 | `1765045912075` | Estimated Deadline from today | date | yes |
| 10 | `1754649138032` | The Task is for | dropdown | yes |
| 11 | `1754648975979` | Name or Title of Task | text |  |

**Options (choice fields)**

- **1754649006671** (Is this a recurring task?): Yes pls make it recurring; No - dont make it; You decide
- **1754649343961** (This task should be assigned to): Decide; Marketing leader; All Teachers; Founder; Other; All leaders; CEO; Finance leader; Teacher coordinator; IT leader/team
- **1754648907485** (Task creator): Chernor; Mohammed Bah
- **1754649609157** (Not in used) Estimated Deadline from today): 1 day; 4 days; 1 week; 3 days; 2 weeks; 3 weeks; 4 weeks; 1 month +; 5 Days
- **1754649263260** (Assign this task to:): Alluwal Website; WhatsApp update
- **1754649138032** (The Task is for): Marketing leader; All Teachers; Founder; Other; All leaders; CEO; Finance leader; Teacher coordinator; IT leader/team

**Descriptions / placeholders**

- **1754649006671**: placeholder: Tap to select
- **1754649775505**: placeholder: Type here
- **1754649343961**: placeholder: Tap to select
- **1754648907485**: placeholder: Tap to select
- **1754649609157**: placeholder: Tap to select
- **1765045326068**: placeholder: Enter date...
- **1754649263260**: placeholder: Tap to select
- **1754649716088**: placeholder: Type here
- **1765045912075**: placeholder: Enter date...
- **1754649138032**: placeholder: Tap to select
- **1754648975979**: placeholder: Type here

### Students Break/Vacation Form - Kadijatu

- **Firestore**: `form_templates/L6LZyTv4AaNjHWI3esIL`
- **Questions**: 8
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754650289877` | When is the start date of the break | text | yes |
| 2 | `1754650343324` | When is the end date of the break? | text | yes |
| 3 | `1754650262494` | How long this student's break will last | text | yes |
| 4 | `1754650232044` | Have you informed the student's teacher | text | yes |
| 5 | `1754650171917` | Who is Student's Teacher | text | yes |
| 6 | `1754650057504` | Islamic Studies,  Pular, English, Math, Physics, | dropdown | yes |
| 7 | `1754650027059` | Student Name | text | yes |
| 8 | `1754649950948` | Submitted By: | dropdown | yes |

**Options (choice fields)**

- **1754649950948** (Submitted By:): Chernor; Mohammad Bah; Kadijatu Jalloh; Salimatu; Abdi; Mamoudou

**Descriptions / placeholders**

- **1754650289877**: placeholder: Type full date
- **1754650343324**: placeholder: Type full date
- **1754650262494**: placeholder: Type number of weeks or Month
- **1754650232044**: placeholder: Type here
- **1754650171917**: placeholder: Type here
- **1754650057504**: placeholder: Tap to select
- **1754650027059**: placeholder: Type here
- **1754649950948**: placeholder: Tap to select

### Daily End of Shift form - CEO

- **Firestore**: `form_templates/LyQtk2qVL6Uh9Rw70VIy`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754473430887` | Name | dropdown | yes |
| 2 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 3 | `1754473754870` | Days | dropdown | yes |
| 4 | `1754473834242` | Week | dropdown | yes |
| 5 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift. | long_text | yes |
| 6 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement | long_text | yes |
| 7 | `1754474096020` | For this week I am doing my shift for the: | dropdown |  |
| 8 | `1754474204210` | What Time Are You Reporting to work/shift today | text | yes |
| 9 | `1754474278156` | What Time Are Ending the work/shift today | text | yes |
| 10 | `1754474407345` | Total Hours worked today ? | text | yes |
| 11 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I | dropdown | yes |
| 12 | `1754474344242` | List All Your Challenges you experienced today | text | yes |
| 13 | `1754476043141` | For this week I missed working during my expected shift | dropdown | yes |
| 14 | `1754476189834` | This week I missed reporting submitting my end of shift | dropdown | yes |
| 15 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift | text | yes |
| 16 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift | text | yes |
| 17 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform | dropdown | yes |
| 18 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift | dropdown | yes |
| 19 | `1762032275336` | For today's shift did you review the following forms and take action where necessary? | multi_select | yes |
| 20 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete? | number | yes |
| 21 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. | long_text |  |

**Options (choice fields)**

- **1754473430887** (Name): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Sulaiman A. Barry; Kadijatu Jalloh; Mariama Cire Niane; Akan Marcellinus Ikongshull
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754473754870** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday
- **1754473834242** (Week): Week1; Week2; Week3; Week4; N/A
- **1754474096020** (For this week I am doing my shift for the:): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time; 7th time
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I): Underperformed today; Overperformed today; Need to do better; Fairly Performed
- **1754476043141** (For this week I missed working during my expected shift): 1 time; 2 times; 3times; 4 times; 0 time; >5 times
- **1754476189834** (This week I missed reporting submitting my end of shift): 1 time; 2 times; 3 times; 4 times; >5 times; 0 time
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform): Yes; Today; No; something Last Week; Never yet
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift): Yes he answered my call; Left him 2 missed calls; I am too lazy to call him
- **1762032275336** (For today's shift did you review the following forms and take action where necessary?): None of the below; Readiness form; Fact-finding form; Excuse form; Student Application Form

**Descriptions / placeholders**

- **1754473430887**: placeholder: Name
- **1754473570961**: placeholder: I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team
- **1754473754870**: placeholder: Days
- **1754473834242**: placeholder: Week 
- **1763928780219**: placeholder: Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift.
- **1754473916403**: placeholder: List your Achievements during your shift & add time you spent working on each listed achievement
- **1754474096020**: placeholder: For this week I am doing my shift for the: 
- **1754474204210**: placeholder: What Time Are You Reporting to work/shift today
- **1754474278156**: placeholder: What Time Are Ending the work/shift today
- **1754474407345**: placeholder: Total Hours worked today ?
- **1754474569443**: placeholder: Based on the total hours of work I am reporting for today's shift I 
- **1754474344242**: placeholder: List All Your Challenges you experienced today
- **1754476043141**: placeholder: For this week I missed working during my expected shift
- **1754476189834**: placeholder: This week I missed reporting submitting my end of shift
- **1754476306952**: placeholder: Enter the total number of new task you assigned to yourself during this shift 
- **1754476452166**: placeholder: Enter the total number of new task you assigned to other team members during this shift 
- **1754476605073**: placeholder: For today's shift did you innovate or improve any of our system or platform
- **1762032619153**: placeholder: Before submitting this form, i have called Chernor as my 5 mins check out call after every shift
- **1762032275336**: placeholder: For today's shift did you review the following forms and take action where necessary? 
- **1763175894707**: placeholder: As of the end of this shift, how many tasks do you have as overdue that are yet to complete?
- **1767596925135**: placeholder: Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. 

### Marketing Weekly Progress Summary Report

- **Firestore**: `form_templates/O74cBJ2XQS3CRojc7akg`
- **Questions**: 23
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1764197447609` | Have you approved all your teachers clock in hours for this week | dropdown |  |
| 2 | `1754420961705` | How many Posts you did this week? | number | yes |
| 3 | `1754420976840` | Achievement | long_text | yes |
| 4 | `1754421038728` | If this is the fourth week of the month, have completed auditing all your teachers work & sent in the outcome to each teacher? | radio | yes |
| 5 | `1754421007390` | Are your teacher schedules up to date - meaning their classes time, days are all correct? | dropdown | yes |
| 6 | `1754421137310` | This week i worked on or updated info/content on: | multi_select | yes |
| 7 | `1754421194649` | How many time you submitted the Zoom Hosting Form this week? | number | yes |
| 8 | `1754421253332` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | long_text | yes |
| 9 | `1754421089461` | List the names/titles of the forms you reviewed this week | long_text |  |
| 10 | `1754420784391` | What is your Name: | text |  |
| 11 | `1764197338442` | List the name of all your teachers whose clock in you have approve for this week | long_text |  |
| 12 | `1754420795708` | This week i feel | dropdown | yes |
| 13 | `1754420858912` | Last week i was late for zoom hosting | dropdown | yes |
| 14 | `1754421102825` | How many flyers made this week | number | yes |
| 15 | `1754421119537` | How many video edited this week | number | yes |
| 16 | `1754420990377` | Challenges | long_text | yes |
| 17 | `1754420898444` | Last week i was absence for zoom hosting | dropdown | yes |
| 18 | `1754421195861` | How many students did you directly and personally recruit this week? | number | yes |
| 19 | `1754421070183` | List how many task did you identify and assign to team members including teachers for this week ? | number | yes |
| 20 | `1754420830580` | Date | date |  |
| 21 | `1754420940618` | Last week i missed submitting my end of shit | dropdown | yes |
| 22 | `1754421226081` | How many time you submitted the End of Shift Form this week? | number | yes |
| 23 | `1754421278858` | As a leader, how much do you feel that you are in control of teachers, projects, students and personal tasks this week? | number | yes |

**Options (choice fields)**

- **1754421007390** (Are your teacher schedules up to date - meaning their classes time, days are all correct?): No Problem but I didn't check; Too lazy to check this week; I checked - no problem
- **1754421137310** (This week i worked on or updated info/content on:): The Newsletter; Facebook/IG; Tiktok/Youtube; Website
- **1754420795708** (This week i feel): Very productive ( achieved beyond expectation); Distracted/unproductive (no much achievement); Fairly Productive (did a little but must do better next week)
- **1754420858912** (Last week i was late for zoom hosting): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754420898444** (Last week i was absence for zoom hosting): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754420940618** (Last week i missed submitting my end of shit): 0 time; 1 time; 2 times; 3 times; >4 times

**Descriptions / placeholders**

- **1764197447609**: placeholder: Go approve it before submitting this week form
- **1754420961705**: placeholder: Enter number...
- **1754420976840**: placeholder: Enter long text...
- **1754421038728**: placeholder: Enter yes/no...
- **1754421007390**: placeholder: Enter dropdown...
- **1754421137310**: placeholder: Enter multi-select...
- **1754421194649**: placeholder: Enter number...
- **1754421253332**: placeholder: Enter long text...
- **1754421089461**: placeholder: Enter long text...
- **1754420784391**: placeholder: Enter text input...
- **1764197338442**: placeholder: You are required to approve the hours of each of your teacher for this week
- **1754420795708**: placeholder: Enter dropdown...
- **1754420858912**: placeholder: Enter dropdown...
- **1754421102825**: placeholder: Enter number...
- **1754421119537**: placeholder: Enter number...
- **1754420990377**: placeholder: Enter long text...
- **1754420898444**: placeholder: Enter dropdown...
- **1754421195861**: placeholder: Enter number...
- **1754421070183**: placeholder: Enter number...
- **1754420830580**: placeholder: Enter date...
- **1754420940618**: placeholder: Enter dropdown...
- **1754421226081**: placeholder: Enter number...
- **1754421278858**: placeholder: Enter number...

### All Students Database-CEO

- **Firestore**: `form_templates/RWIFq8TKXqLi7WokGCK9`
- **Questions**: 11
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754617334742` | This is for a | dropdown | yes |
| 2 | `1754617681730` | If non adult student, Parent Number | text |  |
| 3 | `1754617126245` | Submitted By: | dropdown | yes |
| 4 | `1754617500355` | Phone Number | number |  |
| 5 | `1754617547104` | Email | text |  |
| 6 | `1754617572722` | If a non adult student, Name of Parent | text |  |
| 7 | `1754617721757` | Coach name | text |  |
| 8 | `1754617666893` | If a non adult Student, Parent Email | text |  |
| 9 | `1754617638915` | Teacher Name | text |  |
| 10 | `1754617449097` | Current Country/State/City | text | yes |
| 11 | `1754617394374` | Name | text | yes |

**Options (choice fields)**

- **1754617334742** (This is for a): Leader; Teacher; Student
- **1754617126245** (Submitted By:): Chernor; Mamoudou Diallo; Mohammed Bah; Salimatu; Abdi; Kadijatu Jalloh; Intern

**Descriptions / placeholders**

- **1754617334742**: placeholder: Enter dropdown...
- **1754617681730**: placeholder: Enter text input...
- **1754617126245**: placeholder: Tap to select
- **1754617500355**: placeholder: Enter number...
- **1754617547104**: placeholder: Enter text input...
- **1754617572722**: placeholder: Enter text input...
- **1754617721757**: placeholder: Enter text input...
- **1754617666893**: placeholder: Enter text input...
- **1754617638915**: placeholder: Enter text input...
- **1754617449097**: placeholder: Enter text input...
- **1754617394374**: placeholder: Type here

### Weekly Overdues Data By Mamoudou/CEO

- **Firestore**: `form_templates/S0UADgFYC5iyvTnRbogT`
- **Questions**: 6
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754477459900` | Months | dropdown |  |
| 2 | `1754477409941` | Number of tasks overdues | text | yes |
| 3 | `1754477704630` | Evidence | text |  |
| 4 | `1754477648856` | Note | text |  |
| 5 | `1754477561003` | Week | dropdown |  |
| 6 | `1754477318327` | Leader Name | dropdown | yes |

**Options (choice fields)**

- **1754477459900** (Months): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754477561003** (Week): Week1; Week2; Week3; Week4
- **1754477318327** (Leader Name): Mamoudou; Chernor; Mohammed Bah; Roda Ahmed; Salimatu; Khadijatou

### Students Assessment/Grade Form/ Formulaire d’évaluation/de note des étudiants. Khadijatu/CEO

- **Firestore**: `form_templates/Sn0TEj7lFN1hJnLlfMBx`
- **Questions**: 15
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754431793304` | Teacher Name/Nom de l’enseignant | multi_select | yes |
| 2 | `1754432094698` | Who is your coach/Qui est votre coach? | multi_select | yes |
| 3 | `1762604477665` | The total number of students i have from all my classes is/Le nombre total d’élèves que j’ai dans toutes mes classes est : | dropdown | yes |
| 4 | `1754432189399` | Type of assessment here you choose what you are grading either assignment or quiz/Sélectionnez le nombre correspondant à tous vos élèves actifs ce mois-ci. Veillez à ce que les notes de chaque élève dans toutes les matières soient correctement mises à jour ici. | multi_select | yes |
| 5 | `1754432320167` | Your Department/Votre département ?? | multi_select | yes |
| 6 | `1754432415051` | Name of the Student you are grading/ Nom de l'étudiant. Please write here the full name of the student you grading/Veuillez écrire ici le nom complet de l'étudiant que vous notez. | text | yes |
| 7 | `1754432569137` | Assessment Subject/Sujet d'évaluation. Please select the subject from the below dropdown/Veuillez sélectionner le sujet dans le menu déroulant ci-dessous. | multi_select |  |
| 8 | `1754433370240` | Date you assigned this assessment to your student(s)/Date à laquelle vous avez donné cette évaluation à vos élèves ?? | text |  |
| 9 | `1754433402081` | Student Class Type/Type de classe d'étudiant? | multi_select | yes |
| 10 | `1754433471936` | Date your students completed this assessment/À quelle date vos élèves ont-ils terminé cette évaluation? | text | yes |
| 11 | `1754433518766` | What did the student score/Quel a été le score de l'élève? // Type N/A if the student failed to submit work Please add the full grade, For example: Assignment 9/10/ Veuillez ajouter la note complète, par exemple : Devoir 9/10. | text | yes |
| 12 | `1754433556573` | Can you upload a photo/screenshot of the assessment/Pouvez-vous télécharger une photo/capture d'écran de l'évaluation? If this is an assignment please add the image here if you can/S'il s'agit d'une Devoirs, veuillez ajouter l'image ici si vous le pouvez. | text |  |
| 13 | `1754433594818` | Are you satisfied with this student based on this assessment/Êtes-vous satisfait de cet étudiant sur cette évaluation? From 1 ( Being least satisfied to 5 ( Being more Satisfied), please rate this student/De 1 (Être le moins satisfait à 5 (Être plus satisfait), veuillez noter cet élève. | text | yes |
| 14 | `1754433683593` | Why did you give the student the above rating/Pourquoi avez-vous attribué à l'étudiant la note ci-dessus ? Please explain briefly why you gave the student this rating/ Veuillez expliquer brièvement pourquoi vous avez attribué cette note à l'étudiant. | text | yes |
| 15 | `1754433726138` | Any comment/Avez-vous des commentaires? Please add anything you woud like your coach/ the admin to know/Veuillez ajouter tout ce que vous aimeriez que votre coach/l'administrateur sache. | text |  |

**Options (choice fields)**

- **1754431793304** (Teacher Name/Nom de l’enseignant): Ibrahim Balde; Al-Hassan; Thiam; Abdullah; Rahmatoulaye; Kosiah; Nasrllah; Elham; Siyam; Khadijah; Abdourahmane Bano; Iberahim Bah; Sheriff; Alpha; Hulaimatu; AbdulKarim; Habibu Barry; Arabieu; Abdulwarith; Mamadou…
- **1754432094698** (Who is your coach/Qui est votre coach?): Chernor; Mamoudou; Mohammed; I don't know my coach; Sulaiman A. Barry; Salimatou; Kadijatu Jalloh
- **1762604477665** (The total number of students i have from all my classes is/Le nombre total d’élèves que j’ai dans toutes mes classes est :): 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16; 17; 18; 19; 20…
- **1754432189399** (Type of assessment here you choose what you are grading either assignment or quiz/Sélectionnez le nombre correspondant à tous vos élèves actifs ce mois-ci. Veillez à ce que les notes de chaque élève dans toutes les matières soient correctement mises à jour ici.): Assignment - Devoir; Quiz - Quiz; Midterm - Examen de mi-semestre; Final Exam - Examen final; Project - Projet; Class Work - Travail en classe
- **1754432320167** (Your Department/Votre département ??): Arabic; English; Pular
- **1754432569137** (Assessment Subject/Sujet d'évaluation. Please select the subject from the below dropdown/Veuillez sélectionner le sujet dans le menu déroulant ci-dessous.): Arabic/ Arabe; Al-Quran/ Le Coran; Hadith; Tafsir; Tawhid; Fiqw; Poular; English Learning; Math; Science; Social Studies; Reading; Speaking/writing; Class work; Quiz; Other
- **1754433402081** (Student Class Type/Type de classe d'étudiant?): One On One; Class Group Class

**Descriptions / placeholders**

- **1754431793304**: placeholder: Enter multi-select...
- **1754432094698**: placeholder: Enter multi-select...
- **1762604477665**: placeholder: Choose the number that represents all your active students for this month. Ensure each person grade in all subjects is update here/Choisissez le nombre qui représente tous vos élèves actifs pour ce mois. Assurez-vous que les notes de chaque élève dans toutes les matières soient mises à jour ici.
- **1754432189399**: placeholder: Enter multi-select...
- **1754432320167**: placeholder: Enter multi-select...
- **1754432415051**: placeholder: Enter text input...
- **1754432569137**: placeholder: Enter multi-select...
- **1754433370240**: placeholder: Enter text input...
- **1754433402081**: placeholder: Enter multi-select...
- **1754433471936**: placeholder: Enter text input...
- **1754433518766**: placeholder: Enter text input...
- **1754433556573**: placeholder: Enter image upload...
- **1754433594818**: placeholder: Enter text input...
- **1754433683593**: placeholder: Enter text input...
- **1754433726138**: placeholder: Enter text input...

### Teacher Complaints form. Khadijatu/CEO

- **Firestore**: `form_templates/T5WbHKpagWsUkeWaNWfK`
- **Questions**: 4
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754477344869` | Name/Nom | text | yes |
| 2 | `1754477368560` | Complaint/Recommendation?/Réclamation/Recommandation ? | multi_select | yes |
| 3 | `1754477446247` | what is your recommendation?/Quelle est votre recommandation ? | text | yes |
| 4 | `1754477490537` | Name of the Person you are complaining about and why?/Nom de la personne contre laquelle vous vous plaignez et pourquoi ? | text |  |

**Options (choice fields)**

- **1754477368560** (Complaint/Recommendation?/Réclamation/Recommandation ?): Complaint; Recomendation

**Descriptions / placeholders**

- **1754477344869**: placeholder: Enter text input...
- **1754477368560**: placeholder: Enter multi-select...
- **1754477446247**: placeholder: Enter text input...
- **1754477490537**: placeholder: Enter text input...

### Group BAYANA Attendance - Kadijatu

- **Firestore**: `form_templates/UsZpSINroY4iNpGJEDVC`
- **Questions**: 35
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754619835511` | Name of person submitting this form | dropdown | yes |
| 2 | `1754619929905` | What is the Name and WhatsApp number of this month guest speakers | text | yes |
| 3 | `1754619964623` | What is the topic of this Bayana? | text | yes |
| 4 | `1754620004349` | Month | dropdown | yes |
| 5 | `1754620091837` | List the full names of teachers who are present for this Bayana | text | yes |
| 6 | `1754620324365` | What is the total number of teachers' attendance this month | text | yes |
| 7 | `1754620216753` | Compare to last month, has students attendance incease or deacrease this month? | dropdown |  |
| 8 | `1754620495659` | Was the guest imam introduced by a student? | radio |  |
| 9 | `1754620527106` | Did Bayana start on time | radio | yes |
| 10 | `1754620555539` | In one to three sentences summarize your impression about the overall conduct of this Bayana | text |  |
| 11 | `1754620646568` | How was the last Bayana logistic? | dropdown | yes |
| 12 | `1754620720449` | Was the live launch on Facebook | radio | yes |
| 13 | `1754620762916` | Was the student Quran reciter present | radio | yes |
| 14 | `1754620895404` | ustaz korka's student | text | yes |
| 15 | `1754620922341` | Oustaz Abdullah Blade's Student | text | yes |
| 16 | `1754620948128` | Oustazah Nasrullah's students | text | yes |
| 17 | `1754621013154` | Oustazah Mama''s Student Student | text | yes |
| 18 | `1754621032326` | Oustaz Abdoullahi Yahya Student | text | yes |
| 19 | `1754621067604` | Oustaz Alhassan's StudentsText Input | text | yes |
| 20 | `1754621096578` | Oustaza Asma's Students | text | yes |
| 21 | `1754621120017` | Oustaz Cham Students | text | yes |
| 22 | `1754621156839` | Oustaz Habib's Students | text | yes |
| 23 | `1754621187243` | Oustazah Rahmatullah's Students | text | yes |
| 24 | `1754621207701` | Oustaz Ibrahim Blade's Students | text | yes |
| 25 | `1754621237073` | Oustaz Ibrahim Bah's Students | text | yes |
| 26 | `1754621321468` | Ustaz Sheriff's Students | text | yes |
| 27 | `1754621369198` | Oustaza Elham's Students | text | yes |
| 28 | `1754621415583` | Oustaz Saidou's Students | text | yes |
| 29 | `1754621482825` | Oustazah Fatima's Students | text |  |
| 30 | `1754621508602` | Oustaz Abdulai's Students | text | yes |
| 31 | `1754621537883` | Oustaz Arabieu's Students | text | yes |
| 32 | `1754621552106` | Oustaz Amadou Oury's Students | text |  |
| 33 | `1754621625942` | Did you reach out to parents whose students were absent from last month Bayana to find out why? | dropdown |  |
| 34 | `1754621663460` | Did you reach out to teachers whose students were absent from last month Bayana to find out why? | dropdown |  |
| 35 | `1754621709451` | Are all teacher names added to this form? | dropdown |  |

**Options (choice fields)**

- **1754619835511** (Name of person submitting this form): Chernor; Mamoudou; Mohammed Bah; Kadijatu Jalloh; Roda Ahmed
- **1754620004349** (Month): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754620216753** (Compare to last month, has students attendance incease or deacrease this month?): Yes - increase; No - decrease; No different
- **1754620646568** (How was the last Bayana logistic?): Excellent; Ok; Got some trouble
- **1754621625942** (Did you reach out to parents whose students were absent from last month Bayana to find out why?): Yes; No; I will
- **1754621663460** (Did you reach out to teachers whose students were absent from last month Bayana to find out why?): Yes; No; I will
- **1754621709451** (Are all teacher names added to this form?): Yes; No; I need to add a few teachers

**Descriptions / placeholders**

- **1754619835511**: placeholder: Enter dropdown...
- **1754619929905**: placeholder: E.g. Chernor - 00231836253
- **1754619964623**: placeholder: Type here
- **1754620004349**: placeholder: Tap to select
- **1754620091837**: placeholder: Type here
- **1754620324365**: placeholder: Enter text input...
- **1754620216753**: placeholder: Enter dropdown...
- **1754620495659**: placeholder: Enter yes/no...
- **1754620527106**: placeholder: Enter yes/no...
- **1754620555539**: placeholder: Focus on what happened and what would you need to improve going forward
- **1754620646568**: placeholder: Enter dropdown...
- **1754620720449**: placeholder: Enter yes/no...
- **1754620762916**: placeholder: Enter yes/no...
- **1754620895404**: placeholder: Enter text input...
- **1754620922341**: placeholder: Enter text input...
- **1754620948128**: placeholder: Enter text input...
- **1754621013154**: placeholder: Enter text input...
- **1754621032326**: placeholder: Enter text input...
- **1754621067604**: placeholder: Enter text input...
- **1754621096578**: placeholder: Enter text input...
- **1754621120017**: placeholder: Enter text input...
- **1754621156839**: placeholder: Enter text input...
- **1754621187243**: placeholder: Enter text input...
- **1754621207701**: placeholder: Enter text input...
- **1754621237073**: placeholder: Enter text input...
- **1754621321468**: placeholder: Enter text input...
- **1754621369198**: placeholder: Enter text input...
- **1754621415583**: placeholder: Enter text input...
- **1754621482825**: placeholder: Enter text input...
- **1754621508602**: placeholder: Enter text input...
- **1754621537883**: placeholder: Enter text input...
- **1754621552106**: placeholder: Enter text input...
- **1754621625942**: placeholder: Enter dropdown...
- **1754621663460**: placeholder: Enter dropdown...
- **1754621709451**: placeholder: Enter dropdown...

### Weekly Overdues Data By Mamoudou/CEO

- **Firestore**: `form_templates/VY5ChCJTREWXhJAmSqtX`
- **Questions**: 6
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754477318327` | Leader Name | dropdown | yes |
| 2 | `1754477409941` | Number of tasks overdues | text | yes |
| 3 | `1754477459900` | Months | dropdown |  |
| 4 | `1754477561003` | Week | dropdown |  |
| 5 | `1754477648856` | Note | text |  |
| 6 | `1754477704630` | Evidence | text |  |

**Options (choice fields)**

- **1754477318327** (Leader Name): Mamoudou; Chernor; Mohammed Bah; Roda Ahmed; Salimatu; Khadijatou; Akan Marcellinus Ikongshull; Mariama Cire Niane; Sulaiman A. Barry
- **1754477459900** (Months): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754477561003** (Week): Week1; Week2; Week3; Week4

**Descriptions / placeholders**

- **1754477318327**: placeholder: Leader Name 
- **1754477409941**: placeholder: Number of tasks overdues 
- **1754477459900**: placeholder: Months
- **1754477561003**: placeholder: Week
- **1754477648856**: placeholder: Note
- **1754477704630**: placeholder: Evidence

### Feedback for Leaders/Commentaires pour les dirigeants All Leaders

- **Firestore**: `form_templates/XXAujOa6kkwIXlIFS8GJ`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754650784701` | Can you suggest ways this leader/coach can improve/Pouvez-vous suggérer des façons dont ce leader/coach peut s’améliorer? | text | yes |
| 2 | `1754650680761` | How can scall of 1-5 can you describe your communication with this leader/coach/Sur une échelle de 1 à 5, pouvez-vous décrire votre communication avec ce leader/coach? | text | yes |
| 3 | `1754650873763` | Have you talked to the leader/coach about this issue before, if yes, what did they do/say/Avez-vous déjà parlé de ce problème au leader/entraîneur, si oui, qu'a-t-il fait/dit? | text | yes |
| 4 | `1754650625849` | What is the full name of the leader/coach/Quel est le nom complet du leader/entraîneur? | text | yes |
| 5 | `1754650917483` | On a scale of 1-5 how urgent is your concern/Sur une échelle de 1 à 5, quelle est l'urgence de votre préoccupation? | text | yes |
| 6 | `1754650956897` | Any comment/Avez-vous des commentaires? | text |  |
| 7 | `1754650583191` | Is this feedback for a specific leader/coach/S'agit-il d'un retour d'information destiné à un leader/coach spécifique? | radio | yes |
| 8 | `1754650533303` | What is your name/Quel est ton nom? | text | yes |
| 9 | `1754650835661` | What is this leader/coach been doing well/Qu’est-ce que ce leader/coach fait bien? | text |  |
| 10 | `1754650729312` | What concern do you have about the leader/coach/Quelle inquiétude avez-vous à propos du leader/coach?Text Input | text | yes |

**Descriptions / placeholders**

- **1754650784701**: placeholder: Please list ways that you think this leader/coach can follow to be able to fully support you/Veuillez énumérer les façons dont vous pensez que ce leader/coach peut suivre pour pouvoir vous soutenir pleinement.
- **1754650680761**: placeholder: How often does this person check on you? Do they reply to your message in time/À quelle fréquence cette personne vous surveille-t-elle ? Est-ce qu'ils répondent à votre message à temps?
- **1754650873763**: placeholder: Type here
- **1754650625849**: placeholder: Type here
- **1754650917483**: placeholder: This will allow us to follow up as soon as possible and get the problem sorted/Cela nous permettra de faire un suivi dans les plus brefs délais et de régler le problème.
- **1754650956897**: placeholder: If you have any comment, positive or negative please add it here/Si vous avez un commentaire, positif ou négatif, ajoutez-le ici.
- **1754650583191**: placeholder: Enter yes/no...
- **1754650533303**: placeholder: Please type you full name here/Veuillez saisir votre nom complet ici.
- **1754650835661**: placeholder: On the positive side, can you record what this person has been doing well and needs acknowledgement for/Du côté positif, pouvez-vous noter ce que cette personne a fait de bien et pour lequel elle a besoin d’être reconnue ?
- **1754650729312**: placeholder: Please describe in details the problem/concern you have with the leader/coach to/Veuillez décrire en détail le problème/préoccupation que vous avez avec le leader/coach pour

### Finance Weekly Update Form-Salimatu/CEO

- **Firestore**: `form_templates/YVA3i7czCuQDTvWnS2uH`
- **Questions**: 28
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1764198941300` | List the name of all your teachers whose clock in and Out you have approve for this week | long_text | yes |
| 2 | `1763608910027` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown |  |
| 3 | `1763609152579` | How many fact finding form were submitted about you and your role this week? | number |  |
| 4 | `1754618731269` | Have you sent an invoice to new parents | dropdown | yes |
| 5 | `1759677195598` | Month | dropdown | yes |
| 6 | `1763609378819` | How many parents did you check in on for the purpose of relationship building? | number |  |
| 7 | `1754618974860` | Have you assigned (to our website) Chernor to call parents who are note complying in the past 2 weeks? | dropdown | yes |
| 8 | `1754617928012` | Submitted by: | dropdown | yes |
| 9 | `1754618405871` | Submission Week | dropdown | yes |
| 10 | `1763608805905` | List the names/titles of all the forms you reviewed this week? | long_text |  |
| 11 | `1763608722396` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month | dropdown |  |
| 12 | `1754619204514` | What is the total number of pending receipts that are yet to be made even though the payment has been made? | text |  |
| 13 | `1754618586388` | Is the Canva receipts page well organize based on family names - alphatically? | dropdown | yes |
| 14 | `1754618523857` | Have you reviewed the WhatsApp number to determine reply all finance related texts? | dropdown | yes |
| 15 | `1754618501911` | Have you checked out the student Application form to spot any new students this week | radio |  |
| 16 | `1754619162098` | What is the total number of students owing fees as of today's date? | text | yes |
| 17 | `1754618481310` | Have you checked out the Student Status Form to find new student | radio |  |
| 18 | `1763608847642` | How many time you join Zoom Hosting late this week? | number |  |
| 19 | `1763608654693` | How many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional note | long_text |  |
| 20 | `1764198825045` | How many time did you check the Student Application Form this week | number | yes |
| 21 | `1763608859429` | How many time you were absence for Zoom Hosting this week? | number |  |
| 22 | `1754619526446` | Outline your step-by-step plan to fix or correct any concerns or problems you obseve while reviewing and submitting this form | text |  |
| 23 | `1754619555700` | Any challenges you are having with fees collections? Explain below | text |  |
| 24 | `1763608778231` | How many time you submitted the Zoom Hosting Form this week? | number |  |
| 25 | `1754619501808` | What is the total of new student this week? | text |  |
| 26 | `1763608972312` | How many task overdues are ending this week with? Check the Quick Tasks from the Site to be exact | number |  |
| 27 | `1754618707589` | As of this week, are all new students moved to the finance document | radio | yes |
| 28 | `1754618639860` | Are there a new students this week | dropdown | yes |

**Options (choice fields)**

- **1763608910027** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): No; Yes; Too lazy to that
- **1754618731269** (Have you sent an invoice to new parents): Yes to all new parents; To a few parents; No i am lazy to do it; No new student this week
- **1759677195598** (Month): JANUARY; FEBRUARY; MARCH; APRIL; MAY; JUNE; JULY; AUGUST; SEPTEMBER; OCTOBER; NOVEMBER; DECEMBER
- **1754618974860** (Have you assigned (to our website) Chernor to call parents who are note complying in the past 2 weeks?): Yes i have; No-I will do another round of follow-up; No everyone is comlying
- **1754617928012** (Submitted by:): Mohammad Bah; Mamoudou Diallo; Chernor A. Diallo; Intern; Salimatu
- **1754618405871** (Submission Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1763608722396** (How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month): 0; 3; 2; 1
- **1754618586388** (Is the Canva receipts page well organize based on family names - alphatically?): Yes 100% organize; Not organize; Very messy but i will fix it today
- **1754618523857** (Have you reviewed the WhatsApp number to determine reply all finance related texts?): Yes i have reviewed; No i am lazy to review; I will review later today; I reviwed yesterday
- **1754618639860** (Are there a new students this week): No; Yes; I did not check this week

**Descriptions / placeholders**

- **1764198941300**: placeholder: You are required to approve the hours of each of your teacher for this week
- **1763608910027**: placeholder: Enter dropdown...
- **1763609152579**: placeholder: Pls check the fact finding form to be sure
- **1754618731269**: placeholder: Enter dropdown...
- **1759677195598**: placeholder: Enter dropdown...
- **1763609378819**: placeholder: You are to contact at least 7 parents/students per week to show concern and support and update the student follow up form. 
- **1754618974860**: placeholder: Enter dropdown...
- **1754617928012**: placeholder: Enter dropdown...
- **1754618405871**: placeholder: Enter dropdown...
- **1763608805905**: placeholder: Enter long text...
- **1763608722396**: placeholder: Enter dropdown...
- **1754619204514**: placeholder: Type here
- **1754618586388**: placeholder: Enter dropdown...
- **1754618523857**: placeholder: Enter dropdown...
- **1754618501911**: placeholder: Enter yes/no...
- **1754619162098**: placeholder: Type here
- **1754618481310**: placeholder: Yes, No
- **1763608847642**: placeholder: Enter number...
- **1763608654693**: placeholder: List them here
- **1764198825045**: placeholder: Enter number...
- **1763608859429**: placeholder: Enter number...
- **1754619526446**: placeholder: Just list them (if no concern or problem ignore this question)
- **1754619555700**: placeholder: Enter text input...
- **1763608778231**: placeholder: Enter number...
- **1754619501808**: placeholder: Enter text input...
- **1763608972312**: placeholder: Enter it here but remember the goal is to finish & close all tasks due this week before the week ends
- **1754618707589**: placeholder: Yes, No
- **1754618639860**: placeholder: Enter dropdown...

### PayCheck Update Form

- **Firestore**: `form_templates/ajuPviaSXgAUv1WPLjPF`
- **Questions**: 9
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1761909346092` | Teachers Name | dropdown |  |
| 2 | `1761909953148` | Coach Name | dropdown |  |
| 3 | `1761910070813` | Months | dropdown | yes |
| 4 | `1761910174501` | Days | dropdown |  |
| 5 | `1761910713866` | Date | date |  |
| 6 | `1761910441392` | Amount | text |  |
| 7 | `1761911157885` | PayCut | text |  |
| 8 | `1761910906373` | Violation type | text |  |
| 9 | `1761910285241` | Notes | text |  |

**Options (choice fields)**

- **1761909346092** (Teachers Name): Oustaz Habibu Barry; Oustaz Ibrahim Balde; Oustaz Arabieu Bah; Oustaz Aliou Diallo; Oustaz Mohammed Yahaya Sheriff; Oustaz Ousmane Thiam; Oustaz Ibrahim Bah; Oustaz Mamadou Saidou Diallo; Usataza Asma Mugiu; Usataza Elham Ahmed Shifa; Usataza Mama S. Diallo; Usataza NasurLlah Jalloh; Oustaz Alhassan Diallo; Oustaz Ouniadon KhariaLlah; Oustaz Ahmed Korka Bah; Mohammed Bah; Mamoudou Diallo; Salimatou Diallo; Khadijah Jalloh
- **1761909953148** (Coach Name): Coach Mamoudou Diallo; Coach Mohammed Bah; Coach Khadijah Jalloh; Coach Salimatou Diallo
- **1761910070813** (Months): Jan; Feb; Mar; April; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1761910174501** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday

**Descriptions / placeholders**

- **1761909346092**: placeholder: Teachers Name 
- **1761909953148**: placeholder: Coach Name
- **1761910070813**: placeholder: Months 
- **1761910174501**: placeholder: Days 
- **1761910713866**: placeholder: Date
- **1761910441392**: placeholder: Amount
- **1761911157885**: placeholder: PayCut 
- **1761910906373**: placeholder: Violation type
- **1761910285241**: placeholder: Notes

### Students Status Form- CEO

- **Firestore**: `form_templates/b8wEkVRhdI5TxkA7Tep9`
- **Questions**: 40
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1755173875656` | Your name | dropdown | yes |
| 2 | `1755174213978` | Are you submitting this for | dropdown | yes |
| 3 | `1755174292489` | Department | dropdown |  |
| 4 | `1755174784818` | Class Type | dropdown | yes |
| 5 | `1755174942559` | Full Name of Student | text | yes |
| 6 | `1755175005332` | Parent Name | text | yes |
| 7 | `1755175104637` | Parent WhatsApp number | number | yes |
| 8 | `1755176417080` | Date the student started classes | text |  |
| 9 | `1755176475911` | How many days per week, the new student is taking | text | yes |
| 10 | `1755176676596` | How many hours per day the new student is taking | text | yes |
| 11 | `1755178654302` | What time does the class of this new student starts and what time does it end? | text | yes |
| 12 | `1755178872770` | If this is an existing student schedule adjustment, did his/her days/hrs per week | dropdown | yes |
| 13 | `1755179074515` | Who is the new student teacher | text | yes |
| 14 | `1755179346142` | If this is an existing student schedule adjustment, did his/her days/hrs per week | dropdown | yes |
| 15 | `1755179643141` | If this is for a current student schedule adjsutment, when the new date of adjust begins? | date |  |
| 16 | `1755179817809` | If this is for a current student schedule adjsutment, what new days and hrs per day (e.g.Monday 1 hrs class) | text |  |
| 17 | `1755180044697` | If this for a transfer student, why is this student being transfered? | text | yes |
| 18 | `1755180464820` | If this for student transfer, what is the name of the teacher this student is leaving | text |  |
| 19 | `1755182503423` | If this is for a student transfer, what is the name of the teacher this student is going to? | text |  |
| 20 | `1755182566884` | At the start of this student class pls indicate the student first starting Surah & Arabic first lesson | text |  |
| 21 | `1755191389193` | Have you added the student or their parent number to the Parents WhatsApp grouchat? If not add it before submitting this from | dropdown |  |
| 22 | `1755191442408` | Have you explained the fees breakdown to the studentDropdown | dropdown | yes |
| 23 | `1755191493960` | Have you sent the student his/her invoice for this month's fees? If not pls send it ASAP | dropdown | yes |
| 24 | `1755191553732` | If this is a new student, have you updated the parent number's decription with all relevant info: fees, total hrs, date of start, teacher name etc. | dropdown |  |
| 25 | `1755191708939` | Has the "The Admission Letter" been sent & explained to this new student parent?Dropdown | dropdown | yes |
| 26 | `1755191837550` | Have you created a schedule for this new student for his/her teacher to use to clock in during class? | dropdown | yes |
| 27 | `1755191969659` | If this is a new student, what this student Level? | dropdown |  |
| 28 | `1755192028648` | Department of student | dropdown |  |
| 29 | `1755192770073` | Student name & information added to the finance document? | dropdown |  |
| 30 | `1755192985402` | Reason for student Drop Out | text |  |
| 31 | `1755193049944` | If for drop out, has this student teacher been formally informed about this drop out | dropdown |  |
| 32 | `1755193113870` | If student reason for dropping is not known, have you contacted the students to determine the reason and if we can win them back? | dropdown |  |
| 33 | `1755193163158` | If this a for a drop out, have instructed the right teammate to delete/remove student from necessary areas on platform | dropdown | yes |
| 34 | `1757194402924` | If this is new student, have you sent the parent/student the class Zoom Link and explaimned how it works | dropdown | yes |
| 35 | `1755193492488` | Teacher Class the Student Drop Out From | text |  |
| 36 | `1757194664712` | If this is a new student, have explained and text this class final schedule to the parent/student | dropdown | yes |
| 37 | `1755193533983` | Is the student open to rejoin us one day | dropdown |  |
| 38 | `1755193584670` | Date Student Drop Out of our Program | date |  |
| 39 | `1755193616915` | Other information | text |  |
| 40 | `1757530332504` | If this is new student, have you updated "note" or description" of the parent number? | dropdown | yes |

**Options (choice fields)**

- **1755173875656** (Your name): Mohammed Bah; Chernor; Mamoudou; Intern; Kadijatu Jalloh; Salimatu; Abdi
- **1755174213978** (Are you submitting this for): New Student Enrollement; Old Student Drop Out; Student Schedule Adjustment; Student Tranfer to New Teacher
- **1755174292489** (Department): Arabic; After School Tutoring (English; Math; Physics; Chemistry etc.); Afrolingual
- **1755174784818** (Class Type): Individual Class; Group Class (Mixed Families); Family Group Class
- **1755178872770** (If this is an existing student schedule adjustment, did his/her days/hrs per week): N/A; Decrease; Increase
- **1755179346142** (If this is an existing student schedule adjustment, did his/her days/hrs per week): N/A; Decrease; Increase
- **1755191389193** (Have you added the student or their parent number to the Parents WhatsApp grouchat? If not add it before submitting this from): Yes; No; I am adding it now
- **1755191442408** (Have you explained the fees breakdown to the studentDropdown): Yes; No; N/A
- **1755191493960** (Have you sent the student his/her invoice for this month's fees? If not pls send it ASAP): Yes; No; N/A
- **1755191553732** (If this is a new student, have you updated the parent number's decription with all relevant info: fees, total hrs, date of start, teacher name etc.): Yes - already have; No - am lazy to do that
- **1755191708939** (Has the "The Admission Letter" been sent & explained to this new student parent?Dropdown): Yes - it's sent; No -but I am sending it now; No - am lazy to do that; N/A
- **1755191837550** (Have you created a schedule for this new student for his/her teacher to use to clock in during class?): Yes - I have created it; No but I assigned to someone; Well - I don't want to do either one
- **1755191969659** (If this is a new student, what this student Level?): Beginner; Intermediate; Advanced
- **1755192028648** (Department of student): Quran Studies; English; Pular; Math
- **1755192770073** (Student name & information added to the finance document?): Yes I have done it; No - I have assigned Mr. Bah & Mamoudou the task; No but I assign Mr. Bah or Mamoudou the task
- **1755193049944** (If for drop out, has this student teacher been formally informed about this drop out): Yes; No - but I just did; I will do it later
- **1755193113870** (If student reason for dropping is not known, have you contacted the students to determine the reason and if we can win them back?): Yes; No; N/A
- **1755193163158** (If this a for a drop out, have instructed the right teammate to delete/remove student from necessary areas on platform): Yes - i have remove him/her; No but i have assigned it; N/A
- **1757194402924** (If this is new student, have you sent the parent/student the class Zoom Link and explaimned how it works): Yes I have; No let me do it now; N/A
- **1757194664712** (If this is a new student, have explained and text this class final schedule to the parent/student): Yes I have; No but let me do it now; N/A
- **1755193533983** (Is the student open to rejoin us one day): Yes; No; Maybe
- **1757530332504** (If this is new student, have you updated "note" or description" of the parent number?): Yes; No i am lazy too do it; N/A

**Descriptions / placeholders**

- **1755173875656**: placeholder: Tap to select
- **1755174213978**: placeholder: Tap to select
- **1755174292489**: placeholder: Tap to select
- **1755174784818**: placeholder: Enter dropdown...
- **1755174942559**: placeholder: Type here
- **1755175005332**: placeholder: Type here
- **1755175104637**: placeholder: Type here
- **1755176417080**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755176475911**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755176676596**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755178654302**: placeholder: Give us a time range such as this: 2pm to 3pm.
- **1755178872770**: placeholder: Type to select
- **1755179074515**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755179346142**: placeholder: Tap to select
- **1755179643141**: placeholder: Tap to select.
- **1755179817809**: placeholder: Type N/A not applicable
- **1755180044697**: placeholder: be brief and precise
- **1755180464820**: placeholder: Type here
- **1755182503423**: placeholder: Type here
- **1755182566884**: placeholder: this information will allow us to eventually measure the student after 4-6 months
- **1755191389193**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755191442408**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755191493960**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755191553732**: placeholder: Pls do so now if you have not
- **1755191708939**: placeholder: If not, send it to the parent now before submitting this form.
- **1755191837550**: placeholder: If not, either do it now or assign it the right person before submitting this form.
- **1755191969659**: placeholder: Tap to select
- **1755192028648**: placeholder: Department of student
- **1755192770073**: placeholder: If not, have assigned Mr.Bah or Mamoudou to update finance doc before you submit this form
- **1755192985402**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755193049944**: placeholder: If not do that before submitting this form
- **1755193113870**: placeholder: If not please contact student first to get the info before submiting this form
- **1755193163158**: placeholder: example: schedule shift, groupchat class etc.
- **1757194402924**: placeholder: If not please send it now before submitting this form
- **1755193492488**: placeholder: Type here
- **1757194664712**: placeholder: If you must WhatsApp/text this before submitting this form
- **1755193533983**: placeholder: Tap to select
- **1755193584670**: placeholder: Type here
- **1755193616915**: placeholder: Any information you'd like to share
- **1757530332504**: placeholder: Ensure to add monthly fees, data started, teachers, class schedule e.c.t.

### Daily Class Report

- **Firestore**: `form_templates/daily_class_report`
- **Questions**: 5
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `actual_duration` | Actual class duration (hours) | number | yes |
| 2 | `lesson_covered` | What lesson/topic did you teach? | text | yes |
| 3 | `used_curriculum` | Did you use the official curriculum? | radio | yes |
| 4 | `session_quality` | How did the session go? | text | yes |
| 5 | `teacher_notes` | Additional notes or observations | long_text |  |

**Options (choice fields)**

- **used_curriculum** (Did you use the official curriculum?): Yes, Used Official Curriculum; No, Used Own Content; Partially Used; Not Sure

**Descriptions / placeholders**

- **actual_duration**: placeholder: Auto-filled from shift (editable if needed)
- **lesson_covered**: placeholder: e.g., Surah Al-Fatiha verses 1-3
- **teacher_notes**: placeholder: Any important observations, student progress, or concerns

### Mamoudou Week progress summary report

- **Firestore**: `form_templates/g8tcejPHJYs9nOe6z0Aa`
- **Questions**: 27
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754418891463` | List the names/titles of the forms you reviewed this week | text |  |
| 2 | `1754419454463` | If this is fourth week of the month have you completed auditng all your teachers and their work? | dropdown |  |
| 3 | `1754419277806` | How many times you review the excuse form for teachers and leaders this week ? | text |  |
| 4 | `1754419627087` | Did you help with new teacher interview this month ? | dropdown |  |
| 5 | `1754416232593` | If this is the 4th week of this month, have you sent the name of the best student of the month to Rodaa for publication? | dropdown |  |
| 6 | `1754418293442` | Do you daily scheme through all your teachers whatsApp groupchats | dropdown |  |
| 7 | `1754415396747` | Week | dropdown |  |
| 8 | `1762602517269` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown | yes |
| 9 | `1754417550424` | Have you read, understood & done with overdue tasks/project assigned to you as an administrator | radio |  |
| 10 | `1754417316736` | How many overdues tasks ( form connecteam ) do you have this week? | text |  |
| 11 | `1754417675591` | Have you completed all the assigned tasks & projects to you which are due this week? | radio |  |
| 12 | `1754420169982` | Do you have any idea that will help our students learn while having fun or any strategy that will improve the learning pace of our students? If yes please mention it and call the attention of the administratation for implementation | long_text | yes |
| 13 | `1754415687197` | Have you verify your teachers schedules and are they accurate: | text |  |
| 14 | `1754418482085` | How many new ideas or innovation did you recommend to improve our platform/team for this week ? | text |  |
| 15 | `1754417441532` | How many time you submitted the zoom hosting form this week? | text |  |
| 16 | `1754415829445` | If this is second and fourth week of the month, have you send and email and whatApp text to all parents who kids are absent | dropdown |  |
| 17 | `1754420118427` | If this is the fourthweek, have you completed the peer leadership | radio |  |
| 18 | `1754418597220` | How many time you submitted the end of shift report this week ? | text |  |
| 19 | `1754415478045` | Have you updated the student Attendance sheet for this week? | radio |  |
| 20 | `1754419935623` | How many time did you review the class readiness form for teachers coaching this week | text |  |
| 21 | `1754416455885` | Did you check to know if all teachers are working with their students for the end -of- semester student class project presentation? | radio |  |
| 22 | `1754420375933` | How many parents you make follow up on payment | text | yes |
| 23 | `1754416629252` | Have you checked on your coaches and their works and challenges for this week? | radio |  |
| 24 | `1754417786191` | All coaches needs to have at least 5 to 25 mins one on one meeting with at least 1 coachee per month to improve relationship are support teachers | text |  |
| 25 | `1754419773920` | How many students did you directly and personally recruit this week ? | text |  |
| 26 | `1754418983513` | How many teammates ( on the executive board ) did you support or with help with anything ? | text |  |
| 27 | `1754418724326` | How many time did you submit your Bi-weekly coachees performance review this month ? | text |  |

**Options (choice fields)**

- **1754419454463** (If this is fourth week of the month have you completed auditng all your teachers and their work?): Yes; No; N/A
- **1754419627087** (Did you help with new teacher interview this month ?): Yes; No; N/A
- **1754416232593** (If this is the 4th week of this month, have you sent the name of the best student of the month to Rodaa for publication?): Yes; No; N/A
- **1754418293442** (Do you daily scheme through all your teachers whatsApp groupchats): Yes; No; Sometimes
- **1754415396747** (Week): Week1; Week2; Week3; Week4
- **1762602517269** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): Yes I have approved it for all my teachers; Not yet; I am lazy employee
- **1754415829445** (If this is second and fourth week of the month, have you send and email and whatApp text to all parents who kids are absent): Yes; No; N/A

**Descriptions / placeholders**

- **1754418891463**: placeholder: Type 0 if you reviewed no form
- **1754419454463**: placeholder: Including the total hours each person work and recommending action for any violation 
- **1754419627087**: placeholder: Enter dropdown...
- **1754416232593**: placeholder: If not do that right now
- **1754418293442**: placeholder: Doing this regularly helps you know what is going on & how help
- **1754415396747**: placeholder: Tap to select
- **1762602517269**: placeholder: If not please do this now before submitting this form - this must be done at least once per week
- **1754417550424**: placeholder: Enter yes/no...
- **1754417675591**: placeholder: Enter yes/no...
- **1754415829445**: placeholder: Screenshot the student absentee email and whatsApp each parent corncerned
- **1754420118427**: placeholder: Enter yes/no...
- **1754415478045**: placeholder: Enter yes/no...
- **1754416455885**: placeholder: Enter yes/no...
- **1754420375933**: placeholder: Parents with outstanding payment
- **1754416629252**: placeholder: Enter yes/no...
- **1754417786191**: placeholder: Below list the name of the teacher(s) you had this mentorship call with for this month
- **1754419773920**: placeholder: All leaders are considered ambassadors and recruiters
- **1754418983513**: placeholder: If any, list the help you rendered 
- **1754418724326**: placeholder: Only answer this question once per month

### Pre Start and End of Semester Survey

- **Firestore**: `form_templates/izHpj0zJhDBHPmPYTlyk`
- **Questions**: 9
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754655702152` | How well does this student write Arabic letters before starting our program/classes | text | yes |
| 2 | `1754655817197` | How many hadith does this student know before joinning our program/classes | text | yes |
| 3 | `1754655754382` | What is the level of this student | dropdown | yes |
| 4 | `1754656097824` | How many hadith has this student learned in this semester | text | yes |
| 5 | `1754655671468` | How well does this student read Arabic letters,before starting our program/classes | text | yes |
| 6 | `1754656066306` | Rate this student writting skills from 1-5 | text | yes |
| 7 | `1754655874088` | How Many Surahs has this student learned in this semester | text | yes |
| 8 | `1754655639440` | How Many Surah does this student know before starting our program/classes | text | yes |
| 9 | `1754656002327` | Rate this student reading skills from 1-5 | text | yes |

**Options (choice fields)**

- **1754655754382** (What is the level of this student): Begginer; Intermediate; Advance

**Descriptions / placeholders**

- **1754655702152**: placeholder: Type here
- **1754655817197**: placeholder: Type here
- **1754655754382**: placeholder: Tap to select
- **1754656097824**: placeholder: Type here
- **1754655671468**: placeholder: Type here
- **1754656066306**: placeholder: Type here
- **1754655874088**: placeholder: Type here
- **1754655639440**: placeholder: Type here
- **1754656002327**: placeholder: Rate this student reading skills from 1-5

### PayCheck Update Form

- **Firestore**: `form_templates/jXxixrFPW3Y0IDbiiHSb`
- **Questions**: 9
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1761909346092` | Teachers Name | dropdown |  |
| 2 | `1761909953148` | Coach Name | dropdown |  |
| 3 | `1761910070813` | Months | dropdown | yes |
| 4 | `1761910174501` | Days | dropdown |  |
| 5 | `1761910713866` | Date | date |  |
| 6 | `1761910441392` | Amount | text |  |
| 7 | `1761911157885` | PayCut | text |  |
| 8 | `1761910906373` | Violation type | text |  |
| 9 | `1761910285241` | Notes | text |  |

**Options (choice fields)**

- **1761909346092** (Teachers Name): Oustaz Habibu Barry; Oustaz Ibrahim Balde; Oustaz Arabieu Bah; Oustaz Aliou Diallo; Oustaz Mohammed Yahaya Sheriff; Oustaz Ousmane Thiam; Oustaz Ibrahim Bah; Oustaz Mamadou Saidou Diallo; Usataza Asma Mugiu; Usataza Elham Ahmed Shifa; Usataza Mama S. Diallo; Usataza NasurLlah Jalloh; Oustaz Alhassan Diallo; Oustaz Ouniadon KhariaLlah; Oustaz Ahmed Korka Bah; Mohammed Bah; Mamoudou Diallo; Salimatou Diallo; Khadijah Jalloh
- **1761909953148** (Coach Name): Coach Mamoudou Diallo; Coach Mohammed Bah; Coach Khadijah Jalloh; Coach Salimatou Diallo
- **1761910070813** (Months): Jan; Feb; Mar; April; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1761910174501** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday

**Descriptions / placeholders**

- **1761909346092**: placeholder: Teachers Name 
- **1761909953148**: placeholder: Coach Name
- **1761910070813**: placeholder: Months 
- **1761910174501**: placeholder: Days 
- **1761910713866**: placeholder: Date
- **1761910441392**: placeholder: Amount
- **1761911157885**: placeholder: PayCut 
- **1761910906373**: placeholder: Violation type
- **1761910285241**: placeholder: Notes

### Teacher & Student Coordinator - Weekly Progress Report Form

- **Firestore**: `form_templates/l0NsJh446MruG8jVaRWO`
- **Questions**: 39
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754426048031` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month | text |  |
| 2 | `1754426014966` | As a coordinator of all teachers, how much do you feel that you are in control of teachers and their coaches? | text |  |
| 3 | `1754425917131` | How many teammates (on the executive board) did you support or with help with anything? If any, pls list the help | text |  |
| 4 | `1754424846146` | Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation? | multi_select |  |
| 5 | `1754425153906` | If this is the fourth week of the month, have you recommended to the Team the teacher of the month? | multi_select |  |
| 6 | `1762602801948` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown | yes |
| 7 | `1754425454734` | Based on supervision of all teachers, list the names of the 3 teachers least in compliance with the curriculum for this month Do this monthly | text |  |
| 8 | `1754424674211` | If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation | multi_select |  |
| 9 | `1754425516393` | How many new ideas or innovation did you reccomend to the team for this week ? If any list them under the Ledership Note Cell | radio | yes |
| 10 | `1754425225457` | Have you checked to ensure all your teachers have submitted their Paycheck Update Form for this month Answer this only once per month | multi_select |  |
| 11 | `1754424589570` | How many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional noteHow many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional note | text | yes |
| 12 | `1754425344476` | If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation | multi_select |  |
| 13 | `1763609680704` | How many parents did you contact this week for the purpose of relationship building? | number |  |
| 14 | `1754424934508` | Have you completed all the assigned tasks & projects to you AND due this week? | multi_select |  |
| 15 | `1754425957695` | How many times you review the "Excuse Form for teachers and leaders" this week? | text |  |
| 16 | `1754424792353` | How many task did you identify and assign to team members including teachers for this week ? If any list them under the Ledership Note Cell | text | yes |
| 17 | `1754425545371` | How many overdue project and tasks you have this week? | text | yes |
| 18 | `1754425887298` | List the names/titles of the forms you reviewed this week Type 0 if you reviewed no form | text |  |
| 19 | `1754426092855` | How many time you submitted the Zoom Hosting Form this week? | text |  |
| 20 | `1764101446375` | How many students dropped? | number | yes |
| 21 | `1754425816875` | How many excuses did you have this week? If any list below if it was a formal and accepted excuse or not | text |  |
| 22 | `1754425852244` | How many times did you review the Class Readiness Form for all teachers to have an ideas of what's going on? | text |  |
| 23 | `1754424764611` | Have you completed all the assigned tasks & projects to you (as a leader) which are due this week? | radio | yes |
| 24 | `1754425426630` | As our Teacher and Curriculum Coordinator, list the name of the 2 teachers who needs support the most this week | text |  |
| 25 | `1754425719151` | If this is the fourth week, have you completed the Peer Leadership Audit? | radio |  |
| 26 | `1754424524366` | Week | multi_select |  |
| 27 | `1754425451313` | How many overdue tasks (from Connecteam) do you have this week? | text | yes |
| 28 | `1754424734949` | Have you read the Bulletin Board, Readiness form FactFinding form, Resignation Form for this week & reminded Leader(s) that haven't read it? | radio | yes |
| 29 | `1754426103056` | List the names/titles of the forms you reviewed this week? | text |  |
| 30 | `1754424631141` | Have you checked on all teachers and review their work this week? | radio | yes |
| 31 | `1754426177674` | Any comment? I am adding comments here if I need to highlight anything outside the above questions and tasks. | text |  |
| 32 | `1764198529010` | List the name of all teachers whose clock in and out you have reviewed and approved this week | long_text | yes |
| 33 | `1754426176655` | How many time you join Zoom Hosting late this week? | text |  |
| 34 | `1754424979800` | How many time you submitted the the End of Shift Report form this week? | text |  |
| 35 | `1764101344557` | As of this week, how many active students do we have? | number | yes |
| 36 | `1754426103842` | As team member, have much do feel supported by the leadership this week? | text |  |
| 37 | `1754425756063` | Did you help with new teacher interview this month? Answer this only once per month | multi_select |  |
| 38 | `1754425283451` | How many students did you directly and personally recruit this week? All leaders are considered ambassadors and recruiters | multi_select |  |
| 39 | `1764101547943` | Why did they dropped, did you make any follow-up? | text | yes |

**Options (choice fields)**

- **1754424846146** (Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation?): Yes; No; N/A
- **1754425153906** (If this is the fourth week of the month, have you recommended to the Team the teacher of the month?): Yes; No; N/A
- **1762602801948** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): Yes I have approved it for all my teachers; Not yet; I am lazy employee
- **1754424674211** (If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation): Yes; No; N/A
- **1754425225457** (Have you checked to ensure all your teachers have submitted their Paycheck Update Form for this month Answer this only once per month): Yes; No
- **1754425344476** (If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation): Yes; No
- **1754424934508** (Have you completed all the assigned tasks & projects to you AND due this week?): Yes; No
- **1754424524366** (Week): Week 1; Week 2; Week 3; Week 4
- **1754425756063** (Did you help with new teacher interview this month? Answer this only once per month): Yes; No; N/A
- **1754425283451** (How many students did you directly and personally recruit this week? All leaders are considered ambassadors and recruiters): 0; 1; 2; 3; 4 +

**Descriptions / placeholders**

- **1754426048031**: placeholder: Enter text input...
- **1754426014966**: placeholder: Enter text input...
- **1754425917131**: placeholder: Enter text input...
- **1754424846146**: placeholder: Enter multi-select...
- **1754425153906**: placeholder: Enter multi-select...
- **1762602801948**: placeholder: If not please do this now before submitting this form - this must be done at least once per week
- **1754425454734**: placeholder: Enter text input...
- **1754424674211**: placeholder: Enter multi-select...
- **1754425516393**: placeholder: Enter yes/no...
- **1754425225457**: placeholder: Enter multi-select...
- **1754424589570**: placeholder: Enter text input...
- **1754425344476**: placeholder: Enter multi-select...
- **1763609680704**: placeholder: You must contact at least 7 parents/students every week to make friend, show concern and check their satisfaction - but pls submit the student follow up form every time you contact a parent.
- **1754424934508**: placeholder: Enter multi-select...
- **1754425957695**: placeholder: Enter text input...
- **1754424792353**: placeholder: Enter text input...
- **1754425545371**: placeholder: Enter text input...
- **1754425887298**: placeholder: Enter text input...
- **1754426092855**: placeholder: Enter text input...
- **1764101446375**: placeholder: Enter number...
- **1754425816875**: placeholder: Enter text input...
- **1754425852244**: placeholder: Enter text input...
- **1754424764611**: placeholder: Enter yes/no...
- **1754425426630**: placeholder: Enter text input...
- **1754425719151**: placeholder: Enter yes/no...
- **1754424524366**: placeholder: Enter multi-select...
- **1754425451313**: placeholder: Enter text input...
- **1754424734949**: placeholder: Enter yes/no...
- **1754426103056**: placeholder: Enter text input...
- **1754424631141**: placeholder: Enter yes/no...
- **1754426177674**: placeholder: Enter text input...
- **1764198529010**: placeholder: Enter their names here but go approve their hours first if that is not done yet
- **1754426176655**: placeholder: Enter text input...
- **1754424979800**: placeholder: Enter text input...
- **1764101344557**: placeholder: Please verify, no guessing!!
- **1754426103842**: placeholder: Enter text input...
- **1754425756063**: placeholder: Enter multi-select...
- **1754425283451**: placeholder: Enter multi-select...
- **1764101547943**: placeholder: Enter text input...

### Daily End of Shift form - CEO

- **Firestore**: `form_templates/lKymuqF9jDRRZMngFXyS`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754473430887` | Name | dropdown | yes |
| 2 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 3 | `1754473754870` | Days | dropdown | yes |
| 4 | `1754473834242` | Week | dropdown | yes |
| 5 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift. | long_text | yes |
| 6 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement | text | yes |
| 7 | `1754474096020` | For this week I am doing my shift for the: | dropdown |  |
| 8 | `1754474204210` | What Time Are You Reporting to work/shift today | text | yes |
| 9 | `1754474278156` | What Time Are Ending the work/shift today | text | yes |
| 10 | `1754474407345` | Total Hours worked today ? | text | yes |
| 11 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I | dropdown | yes |
| 12 | `1754474344242` | List All Your Challenges you experienced today | text | yes |
| 13 | `1754476043141` | For this week I missed working during my expected shift | dropdown | yes |
| 14 | `1754476189834` | This week I missed reporting submitting my end of shift | dropdown | yes |
| 15 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift | text | yes |
| 16 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift | text | yes |
| 17 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform | dropdown | yes |
| 18 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift | dropdown | yes |
| 19 | `1762032275336` | For today's shift did you review the following forms and take action where necessary? | multi_select | yes |
| 20 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete? | number | yes |
| 21 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. | long_text |  |

**Options (choice fields)**

- **1754473430887** (Name): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Abdi; Kadijatu Jalloh; Sulaiman
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754473754870** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday
- **1754473834242** (Week): Week1; Week2; Week3; Week4; N/A
- **1754474096020** (For this week I am doing my shift for the:): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time; 7th time
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I): Underperformed today; Overperformed today; Need to do better; Fairly Performed
- **1754476043141** (For this week I missed working during my expected shift): 1 time; 2 times; 3times; 4 times; 0 time; >5 times
- **1754476189834** (This week I missed reporting submitting my end of shift): 1 time; 2 times; 3 times; 4 times; >5 times; 0 time
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform): Yes; Today; Yes; something Last Week; Never yet
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift): Yes he answered my call; Left him 2 missed calls; I am too lazy to call him
- **1762032275336** (For today's shift did you review the following forms and take action where necessary?): None of the below; Readiness form; Fact-finding form; Excuse form; Student Application Form

**Descriptions / placeholders**

- **1754473430887**: placeholder: Name 
- **1754473570961**: placeholder: I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team
- **1754473754870**: placeholder: Days
- **1754473834242**: placeholder: Week 
- **1763928780219**: placeholder: Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift.
- **1754473916403**: placeholder: List your Achievements during your shift & add time you spent working on each listed achievement
- **1754474096020**: placeholder: For this week I am doing my shift for the: 
- **1754474204210**: placeholder: What Time Are You Reporting to work/shift today
- **1754474278156**: placeholder: What Time Are Ending the work/shift today
- **1754474407345**: placeholder: Total Hours worked today ?
- **1754474569443**: placeholder: Based on the total hours of work I am reporting for today's shift I 
- **1754474344242**: placeholder: List All Your Challenges you experienced today
- **1754476043141**: placeholder: For this week I missed working during my expected shift
- **1754476189834**: placeholder: This week I missed reporting submitting my end of shift
- **1754476306952**: placeholder: Enter the total number of new task you assigned to yourself during this shift 
- **1754476452166**: placeholder: Enter the total number of new task you assigned to other team members during this shift 
- **1754476605073**: placeholder: For today's shift did you innovate or improve any of our system or platform
- **1762032619153**: placeholder: Before submitting this form, i have called Chernor as my 5 mins check out call after every shift
- **1762032275336**: placeholder: For today's shift did you review the following forms and take action where necessary? 
- **1763175894707**: placeholder: As of the end of this shift, how many tasks do you have as overdue that are yet to complete?
- **1767596925135**: placeholder: Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. 

### Daily Zoom Hosting-CEO

- **Firestore**: `form_templates/m7zKkQCcqKtbQZ0OCWpi`
- **Questions**: 29
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754603841743` | Name/Nom | dropdown | yes |
| 2 | `1754604016904` | I hereby confirm that I will fulfill my shift responsibilities as expected and will not abuse the trust placed in me by the team. | dropdown |  |
| 3 | `1754604091069` | What Time Are You Reporting for hosting today/ | dropdown | yes |
| 4 | `1754605796428` | What Time Are You ending your hosting today/À quelle heure terminez-vous votre session d’animation aujourd’hui? | dropdown |  |
| 5 | `1754605883192` | Month - Mois | dropdown | yes |
| 6 | `1754606072045` | Day - Jour | dropdown | yes |
| 7 | `1754606157168` | Week -Semaine | dropdown | yes |
| 8 | `1754606316925` | In this week I am doing my hosting for the/Cette semaine, j’effectue mon animation pour le: | dropdown | yes |
| 9 | `1754606467464` | How was your internet today/Comment était votre connexion Internet aujourd’hui? | dropdown | yes |
| 10 | `1754606575657` | List the help you offered or what you did/achieving during your hosting today/Listez l’aide que vous avez apportée ou ce que vous avez accompli/realizé pendant votre animation Zoom aujourd’hui. | text | yes |
| 11 | `1754606712915` | Who preceded you or are you taking this hosting over from today/Qui vous a précédé ou de qui prenez-vous la relève pour l’animation aujourd’hui? | dropdown | yes |
| 12 | `1754606616554` | List Challenges you experienced today/Listez les défis que vous avez rencontrés aujourd’hui. | text |  |
| 13 | `1754606909119` | Did the person succeeding you or taking the hosting capacity from you join/La personne qui vous succède ou qui prend le relais pour l’animation a-t-elle rejoint? | dropdown |  |
| 14 | `1754607293454` | Who is succeeding you or hosting after your "hosting" time is over/Qui vous succède ou prend en charge l’animation après la fin de votre session? | dropdown | yes |
| 15 | `1754608066662` | Type the names and times of all teachers who are scheduled to teach during your time of hosting zoom today based on our schedule (ex: Ibrahim 2pm)/Tapez les noms et heures de tous les enseignants prévus pour enseigner pendant votre session Zoom aujourd’hui selon notre planning (ex : Ibrahim 14h) | long_text | yes |
| 16 | `1754608100383` | Of the list of teacher names you typed in the previous question, type the name of the teachers who are absent for class today (include the names their students before each teacher name (ex: Teacher Barry for Stu Mariam)/Parmi la liste des enseignants que vous avez tapée dans la question précédente, indiquez le nom des enseignants absents aujourd’hui (incluez le nom de leurs élèves avant chaque nom d’enseignant, par exemple : Enseignant Barry pour Élève Mariam). | long_text | yes |
| 17 | `1754608243308` | Type the name of the teachers that join class late today - indicate how many minute late they are/Tapez le nom des enseignants qui sont arrivés en retard aujourd’hui et indiquez de combien de minutes ils ont été en retard. | text | yes |
| 18 | `1754608315381` | If any teacher was late or absent during hosting time, have you WhatsApps/texted them about it/Si un(e) enseignant(e) a été en retard ou absent(e) pendant l’heure d’animation, lui avez-vous envoyé un message WhatsApp/SMS à ce sujet? | dropdown |  |
| 19 | `1754608452314` | If you reported any teacher late or absent, have you varified the "Excuse Form" to determine if they did not file a formal excuse for today' class/Si vous avez signalé un(e) enseignant(e) en retard ou absent(e), avez-vous vérifié le « Formulaire d’excuse » pour déterminer s’il/elle n’a pas soumis d’excuse officielle pour le cours d’aujourd’hui? | dropdown |  |
| 20 | `1754608646031` | What is the date of absence or lateness/Quelle est la date de l’absence ou du retard ? | date |  |
| 21 | `1754608692379` | Teacher name and time of absence or lateness/Nom de l’enseignant(e) et heure de l’absence ou du retard. | text |  |
| 22 | `1754608813395` | Did you start hosting today/Avez-vous commencé l’animation aujourd’hui? | dropdown | yes |
| 23 | `1754609203577` | How many time did you move to different rooms to observe how teachers are teaching/Combien de fois avez-vous changé de salle pour observer la façon dont les enseignants enseignent? | dropdown |  |
| 24 | `1754609312656` | List the name of student, student teacher and title of content (such as surah or hadith) you tested to determine if students are truly learning during this shift/Listez le nom de l’élève, de l’enseignant(e) et le titre du contenu (par exemple sourate ou hadith) que vous avez testé pour vérifier si les élèves apprennent réellement pendant ce service. | text |  |
| 25 | `1754609361758` | Teachers' Internet Stability if this is not for In and Out Zoom Hosting, type N/A/Stabilité de la connexion Internet des enseignants : si cela ne concerne pas l’hébergement Zoom (entrées et sorties), veuillez indiquer N/A. | dropdown | yes |
| 26 | `1759079619544` | Did you check the "All in One Sheet" (on google drive) to dertermine how many new students to expect today/Avez-vous consulté la « All in One Sheet » (sur Google Drive) pour déterminer combien de nouveaux élèves étaient attendus aujourd’hui? | dropdown | yes |
| 27 | `1759079396494` | How many NEW students did you have while hosting today/Combien de NOUVEAUX élèves avez-vous eus pendant votre session aujourd’hui? | long_text | yes |
| 28 | `1754609444030` | Shout Out any leaders/teachers that help you with anything today/Mentionnez les leaders/enseignants qui vous ont aidé(e) d’une manière ou d’une autre aujourd’hui. | text |  |
| 29 | `1754609480949` | Leave a comment - Laissez un commentaire | text |  |

**Options (choice fields)**

- **1754603841743** (Name/Nom): Mohammed Bah; Salimatu; Akan Marcellinus Ikongshull; Kadijatu Jalloh; Mamoudou Diallo; Intern; Sulaiman A. Barry; Mariama Cire Niane
- **1754604016904** (I hereby confirm that I will fulfill my shift responsibilities as expected and will not abuse the trust placed in me by the team.): Maybe - i am not sure; No; Yes
- **1754604091069** (What Time Are You Reporting for hosting today/): 10:00am; 10:30am; 11:00am; 11:30am; 12:00 AM; 12:15 AM; 12:30 AM; 12:45 AM; 1:00 AM; 1:15 AM; 1:30 AM; 1:45 AM; 2:00 AM; 2:15 AM; 2:30 AM; 2:45 AM; 3:00 AM; 3:15 AM; 3:30 AM; 3:45 AM…
- **1754605796428** (What Time Are You ending your hosting today/À quelle heure terminez-vous votre session d’animation aujourd’hui?): 12:00 AM; 12:15 AM; 12:30 AM; 12:45 AM; 1:00 AM; 1:15 AM; 1:30 AM; 1:45 AM; 2:00 AM; 2:15 AM; 2:30 AM; 2:45 AM; 3:00 AM; 3:15 AM; 3:30 AM; 3:45 AM; 4:00 AM; 4:15 AM; 4:30 AM; 4:45 AM…
- **1754605883192** (Month - Mois): Jan; Feb -Fév; Mar; Apr - Avr; May - Mai; Jun - Juin; Jul - Juil; Aug - Aout; Sept; Oct; Nov; Dec
- **1754606072045** (Day - Jour): Sun - Dem; Mon - Lun; Tues - Tues; Wed -  Mer; Thurs - Jeu; Fri - Ven; Sat - Sam
- **1754606157168** (Week -Semaine): Week -Semaine 1; Week -Semaine 2; Week -Semaine 3; Week -Semaine 4; Week -Semaine 5
- **1754606316925** (In this week I am doing my hosting for the/Cette semaine, j’effectue mon animation pour le:): 1st; 2nd; 3rd; 4th; 5th; 6th; 7th
- **1754606467464** (How was your internet today/Comment était votre connexion Internet aujourd’hui?): Stable; Unstable - Instable; Drop only twice - Déconnecté(e) seulement deux fois.
- **1754606712915** (Who preceded you or are you taking this hosting over from today/Qui vous a précédé ou de qui prenez-vous la relève pour l’animation aujourd’hui?): Mohammed Bah; Salimatu; Akan Marcellinus Ikongshull; Kadijatu Jalloh; Mamoudou Diallo; Intern; Sulaiman A. Barry; Mariama Cire Niane; N/A
- **1754606909119** (Did the person succeeding you or taking the hosting capacity from you join/La personne qui vous succède ou qui prend le relais pour l’animation a-t-elle rejoint?): Late - En retard (<10 mins); Very Late - Très en retard (>10 mins); On time - À l’heure.; Early - En avance.; N/A; Did not show up - N’est pas venu(e)
- **1754607293454** (Who is succeeding you or hosting after your "hosting" time is over/Qui vous succède ou prend en charge l’animation après la fin de votre session?): Mohammed Bah; Salimatu; Sulaiman; Kadijatu Jalloh; Mamoudou Diallo; Intern; N/A; I am the last person hosting; Mariam Cire Niane; Akan
- **1754608315381** (If any teacher was late or absent during hosting time, have you WhatsApps/texted them about it/Si un(e) enseignant(e) a été en retard ou absent(e) pendant l’heure d’animation, lui avez-vous envoyé un message WhatsApp/SMS à ce sujet?): I am too lazy to do that - Je suis trop paresseux(se) pour le faire.; Yes - Oui; I texted them about their absence or lateness/Je leur ai envoyé un message concernant leur; No i haven't texted about their absence or lateness/Non, je n’ai pas envoyé de message concernant leur retard ou leur absence.; I am texting them now - Je suis en train de leur envoyer un message maintenant.
- **1754608452314** (If you reported any teacher late or absent, have you varified the "Excuse Form" to determine if they did not file a formal excuse for today' class/Si vous avez signalé un(e) enseignant(e) en retard ou absent(e), avez-vous vérifié le « Formulaire d’excuse » pour déterminer s’il/elle n’a pas soumis d’excuse officielle pour le cours d’aujourd’hui?): I am too lazy to check - Je suis trop paresseux(se) pour vérifier.; There is no Excuse Form - I double-checked - Il n’y a pas de formulaire d’excuse – j’ai vérifié deux fois.; There is an Excuse Form - i double-checked - Il y a un formulaire d’excuse – j’ai vérifié deux fois.
- **1754608813395** (Did you start hosting today/Avez-vous commencé l’animation aujourd’hui?): Very late - Très en retard.; Late - En retard.; On time - À l’heure.; Early - En avance.; N/A
- **1754609203577** (How many time did you move to different rooms to observe how teachers are teaching/Combien de fois avez-vous changé de salle pour observer la façon dont les enseignants enseignent?): 0; 1; 2; 3-5; 5 +; N/A
- **1754609361758** (Teachers' Internet Stability if this is not for In and Out Zoom Hosting, type N/A/Stabilité de la connexion Internet des enseignants : si cela ne concerne pas l’hébergement Zoom (entrées et sorties), veuillez indiquer N/A.): Stable - Stable.; Unstable - Instable.; Dropped more than twice - Déconnecté(e) plus de deux fois.; N/A
- **1759079619544** (Did you check the "All in One Sheet" (on google drive) to dertermine how many new students to expect today/Avez-vous consulté la « All in One Sheet » (sur Google Drive) pour déterminer combien de nouveaux élèves étaient attendus aujourd’hui?): No - Non; Yes - Oui; Will do it later - Je le ferai plus tard.

**Descriptions / placeholders**

- **1754603841743**: placeholder: Name
- **1754604016904**: placeholder: I hereby confirm that I will fulfill my shift responsibilities as expected and will not abuse the trust placed in me by the team.
- **1754604091069**: placeholder: What Time Are You Reporting for hosting today/À quelle heure commencez-vous votre session d’animation aujourd’hui?
- **1754605796428**: placeholder: Select
- **1754605883192**: placeholder: Month - Mois
- **1754606072045**: placeholder: Day - Jour
- **1754606157168**: placeholder: Week -Semaine
- **1754606316925**: placeholder: Select
- **1754606467464**: placeholder: Select
- **1754606575657**: placeholder: State here - État ici
- **1754606712915**: placeholder: Select
- **1754606616554**: placeholder: State here - État ici
- **1754606909119**: placeholder: State here - État ici
- **1754607293454**: placeholder: Select
- **1754608066662**: placeholder: State here - État ici
- **1754608100383**: placeholder: State here - État ici
- **1754608243308**: placeholder: State here - État ici
- **1754608315381**: placeholder: Select
- **1754608452314**: placeholder: Select
- **1754608646031**: placeholder: Select
- **1754608692379**: placeholder: State here - État ici
- **1754608813395**: placeholder: Select
- **1754609203577**: placeholder: Select
- **1754609312656**: placeholder: State here - État ici
- **1754609361758**: placeholder: Select
- **1759079619544**: placeholder: Select
- **1759079396494**: placeholder: State here/État ici
- **1754609444030**: placeholder: State here - État ici
- **1754609480949**: placeholder: State here - État ici

### Monthly Review

- **Firestore**: `form_templates/monthly_review`
- **Questions**: 6
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `month_rating` | How would you rate this month? | radio | yes |
| 2 | `goals_met` | Were your teaching goals met? | radio | yes |
| 3 | `bayana_completed` | Did you have Group Bayana with students this month? | radio | yes |
| 4 | `student_attendance_summary` | Student attendance issues this month | long_text |  |
| 5 | `monthly_achievements` | Key achievements this month | long_text | yes |
| 6 | `comments_for_admin` | Comments for admin | long_text |  |

**Options (choice fields)**

- **month_rating** (How would you rate this month?): Excellent; Good; Average; Challenging
- **goals_met** (Were your teaching goals met?): Yes, All Goals; Most Goals; Some Goals; Few Goals
- **bayana_completed** (Did you have Group Bayana with students this month?): Yes; No; N/A

**Descriptions / placeholders**

- **student_attendance_summary**: placeholder: List students who were frequently absent or late, or who missed Bayana
- **monthly_achievements**: placeholder: Summarize progress, student improvements, etc.
- **comments_for_admin**: placeholder: Any feedback, requests, or concerns

### Award and Recognitions Tracker

- **Firestore**: `form_templates/pwASJZwzQZKM9csDYOzy`
- **Questions**: 7
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754610416286` | Has this winner been celebrated (posted) in all social media | radio |  |
| 2 | `1754610207342` | Name of Winner | text | yes |
| 3 | `1754610369613` | Title of Award/Recognition | text | yes |
| 4 | `1754610445849` | How many time has this person won any award this Semester? | dropdown |  |
| 5 | `1754610291498` | The Winner is a | dropdown | yes |
| 6 | `1754610550377` | Any note? | text |  |
| 7 | `1754610102115` | Name | dropdown |  |

**Options (choice fields)**

- **1754610445849** (How many time has this person won any award this Semester?): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time
- **1754610291498** (The Winner is a): Student; Teacher; Leader
- **1754610102115** (Name): Mohammed Bah; Mamoudou Diallo; Salimatu; Abdi; Kadijatu Jalloh; Intern

**Descriptions / placeholders**

- **1754610416286**: placeholder: Enter yes/no...
- **1754610207342**: placeholder: Enter text input...
- **1754610369613**: placeholder: Type here
- **1754610445849**: placeholder: Tap to Select
- **1754610291498**: placeholder: Enter dropdown...
- **1754610550377**: placeholder: Type here
- **1754610102115**: placeholder: Enter dropdown...

### Student Follow up - CEO

- **Firestore**: `form_templates/qQGJVFwS45QqrUJwJisK`
- **Questions**: 13
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754651227567` | Person Status | dropdown | yes |
| 2 | `1754651548347` | Based on your follow up, what the person dislike about their class/platform so far? | text | yes |
| 3 | `1754651576566` | Based on the follow up, what the person like about their class/platform so far? | text | yes |
| 4 | `1759082383326` | What Semester is this? | dropdown |  |
| 5 | `1754652211384` | How did you collect this feedback | dropdown | yes |
| 6 | `1754651144820` | Name of Person Submitting this | dropdown | yes |
| 7 | `1754651507108` | Name of the teacher whose student this form is being submitted for | text | yes |
| 8 | `1754651430169` | Is this person knows his/her duties and responsbilities | text | yes |
| 9 | `1759083998172` | Is this for a: | dropdown |  |
| 10 | `1754652282815` | As the person who contancted this person, what do you think or learn from your conversation with the student | text | yes |
| 11 | `1754651401186` | List the documents this persons need to submit | text | yes |
| 12 | `1754651360852` | What round of submission are you having for this student per this semester | dropdown | yes |
| 13 | `1754651287046` | Name of person/student who you are submitting this for | text |  |

**Options (choice fields)**

- **1754651227567** (Person Status): New; Old
- **1759082383326** (What Semester is this?): 1st Semester; 2nd Semester
- **1754652211384** (How did you collect this feedback): WhatsApp Call; WhatsApp text; WhatsApp Audio; Zoom Meeting
- **1754651144820** (Name of Person Submitting this): Chernor; Mamoudou; Kadijatu Jalloh; Roda Ahmed; Mohammad Bah
- **1759083998172** (Is this for a:): A student; A leader; A Teacher
- **1754651360852** (What round of submission are you having for this student per this semester): 1st Round; 2nd Round; 3rd Round; 4th Round; 5th Round; 6th

**Descriptions / placeholders**

- **1754651227567**: placeholder: Like is he/she a new or old teacher, student or leader
- **1754651548347**: placeholder: Type here
- **1754651576566**: placeholder: Explain in details
- **1759082383326**: placeholder: Enter dropdown...
- **1754652211384**: placeholder: Enter dropdown...
- **1754651144820**: placeholder: Tap to select
- **1754651507108**: placeholder: Type here
- **1754651430169**: placeholder: Type here
- **1759083998172**: placeholder: Select
- **1754652282815**: placeholder: Type here
- **1754651401186**: placeholder: Type here
- **1754651360852**: placeholder: Enter dropdown...
- **1754651287046**: placeholder: Type here

### Daily End of Shift form - CEO

- **Firestore**: `form_templates/r1jmV5rkGyqupyKNhEN7`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete? | number | yes |
| 2 | `1754476189834` | This week I missed reporting submitting my end of shift | dropdown | yes |
| 3 | `1754474204210` | What Time Are You Reporting to work/shift today | text | yes |
| 4 | `1754476043141` | For this week I missed working during my expected shift | dropdown | yes |
| 5 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. | long_text |  |
| 6 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift | dropdown | yes |
| 7 | `1754474278156` | What Time Are Ending the work/shift today | text | yes |
| 8 | `1754474407345` | Total Hours worked today ? | text | yes |
| 9 | `1754474096020` | For this week I am doing my shift for the: | dropdown |  |
| 10 | `1754473834242` | Week | dropdown | yes |
| 11 | `1762032275336` | For today's shift did you review the following forms and take action where necessary? | multi_select | yes |
| 12 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift. | long_text | yes |
| 13 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift | text | yes |
| 14 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement | text | yes |
| 15 | `1754473430887` | Name | dropdown | yes |
| 16 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I | dropdown | yes |
| 17 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 18 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform | dropdown | yes |
| 19 | `1754473754870` | Days | dropdown | yes |
| 20 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift | text | yes |
| 21 | `1754474344242` | List All Your Challenges you experienced today | text | yes |

**Options (choice fields)**

- **1754476189834** (This week I missed reporting submitting my end of shift): 1 time; 2 times; 3 times; 4 times; >5 times; 0 time
- **1754476043141** (For this week I missed working during my expected shift): 1 time; 2 times; 3times; 4 times; 0 time; >5 times
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift): Yes he answered my call; Left him 2 missed calls; I am too lazy to call him
- **1754474096020** (For this week I am doing my shift for the:): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time; 7th time
- **1754473834242** (Week): Week1; Week2; Week3; Week4; N/A
- **1762032275336** (For today's shift did you review the following forms and take action where necessary?): None of the below; Readiness form; Fact-finding form; Excuse form; Student Application Form
- **1754473430887** (Name): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Abdi; Kadijatu Jalloh
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I): Underperformed today; Overperformed today; Need to do better; Fairly Performed
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform): Yes; Today; Yes; something Last Week; Never yet
- **1754473754870** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday

**Descriptions / placeholders**

- **1763175894707**: placeholder: Be honest and enter the total number overdues - so check the website
- **1767596925135**: placeholder: List each task as it was titled in the task channel ex: Follw up with parent calls, Submit Status form ect... 
- **1762032619153**: placeholder: This call is required, pls call Chernor now before submitting this form.
- **1754474407345**: placeholder: To miaximize productivity ensure total hours worked commensurate with productivity & accomplishment
- **1762032275336**: placeholder: If not, pls go review them now before submitting this form
- **1763928780219**: placeholder: Past here, so that we can compare today's goals vs your eventual achievement today.
- **1754476306952**: placeholder: Please track these tasks for when chernor asks to show those them
- **1754473916403**: placeholder: For example: called 3 parents - 30min, drafted IG post 20 min, Checked WhatsApp dm 10 
- **1754474569443**: placeholder: Pls ensure the hour reported reflect your productivity - the number of task you completed
- **1754476605073**: placeholder: As a team it is part of your role to use your skills and experience to add value to our platform
- **1754476452166**: placeholder: Chernor will ask you proof  - so keep a record of those tasks

### Teachers Waitlist (Arabic, English, Aldam) Mamoudou/CEO

- **Firestore**: `form_templates/t8boDH58Cn9AsKemMsYs`
- **Questions**: 15
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754662648323` | Gender | dropdown | yes |
| 2 | `1754663172766` | Arabic Fluency | dropdown | yes |
| 3 | `1754663129944` | Quran Fluency | dropdown | yes |
| 4 | `1754662902101` | Days Availibility | text | yes |
| 5 | `1754662853038` | Languages Spoken | text | yes |
| 6 | `1754662555327` | Email | text | yes |
| 7 | `1754662608885` | WhatsApp | number | yes |
| 8 | `1754662514515` | Enter Teacher Name | text | yes |
| 9 | `1754662751411` | Country of residence | text | yes |
| 10 | `1754663223034` | Tech/Devices Access | dropdown | yes |
| 11 | `1754662693039` | Program | dropdown | yes |
| 12 | `1754663343717` | Status | dropdown | yes |
| 13 | `1754662800891` | Nationality | text | yes |
| 14 | `1754663019374` | Days Preferred | dropdown | yes |
| 15 | `1754663271563` | Priority Level | dropdown | yes |

**Options (choice fields)**

- **1754662648323** (Gender): Male; Female
- **1754663172766** (Arabic Fluency): Beginner; Intermediate; Advanced
- **1754663129944** (Quran Fluency): Beginner; Intermediate; Advanced
- **1754663223034** (Tech/Devices Access): Computer; Tablet; A Phone
- **1754662693039** (Program): Arabic; English; Adlam
- **1754663343717** (Status): Assigned; Unassigned
- **1754663019374** (Days Preferred): Weekends; Week days; Any day
- **1754663271563** (Priority Level): High Priority; Medium Priority; Low Priority; Not a Priority

**Descriptions / placeholders**

- **1754662648323**: placeholder: Tap to select
- **1754663172766**: placeholder: Tap to select
- **1754663129944**: placeholder: Tap to select
- **1754662902101**: placeholder: Type here
- **1754662853038**: placeholder: Type here
- **1754662555327**: placeholder: Type here
- **1754662608885**: placeholder: Type here
- **1754662514515**: placeholder: Type here
- **1754662751411**: placeholder: Type here
- **1754663223034**: placeholder: Tap to select
- **1754662693039**: placeholder: Tap to select
- **1754663343717**: placeholder: Tap to select
- **1754662800891**: placeholder: Type here
- **1754663019374**: placeholder: Tap to select
- **1754663271563**: placeholder: Tap to select

### Absences: meetings, classes and events Kadijatu

- **Firestore**: `form_templates/uckNLuKLeejUyMP0B72N`
- **Questions**: 15
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754428826191` | If this is for student(s) what is his/her name Type N/A if not applicable | text |  |
| 2 | `1754428397328` | Name of person submitting this | text |  |
| 3 | `1754428921209` | If this is for a student, how many times in this month is she/he being marked for the same reason | multi_select |  |
| 4 | `1754428770767` | Date of Lateness | text |  |
| 5 | `1754429986332` | If a reason for absence or lateness was given, type it here | text |  |
| 6 | `1754429531965` | Name of teacher or leader being reported if you are reporting a student absence (if not type N/A) | text |  |
| 7 | `1754429678423` | If this is for a teacher or leader, have you sent a brief WhatsApp text notifying this person about this lateness or absence? If not pls pause this form and quickly whatsApp him/her for the sake of evidence to prevent them from denying it at the end of the month. | multi_select |  |
| 8 | `1754430013333` | If this teacher sent in a formal excuse, who replaced him/her for class mention the name of the person, otherwise explain why is this class cancelled | text |  |
| 9 | `1754428767231` | Date of Absence | text |  |
| 10 | `1754429064606` | If this is for a student, has her/his parent been responsive with previous updates (text & audio)message about the problem | multi_select |  |
| 11 | `1762614371423` | Week | multi_select |  |
| 12 | `1754429834347` | Name of student(s) for whose class this teacher/leader was absent or late Just list the student name (s) | text |  |
| 13 | `1754428878221` | If this is for student(s) what is his/her teacher's name? | text |  |
| 14 | `1754429889309` | Have you notified him or her (or their Parents) about their absence, lateness to prevent future denial If not, pls send in the notification now thru a WhatsApp text | multi_select |  |
| 15 | `1754428437290` | Reason for submitting | multi_select | yes |

**Options (choice fields)**

- **1754428921209** (If this is for a student, how many times in this month is she/he being marked for the same reason): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6 times; N/A
- **1754429678423** (If this is for a teacher or leader, have you sent a brief WhatsApp text notifying this person about this lateness or absence? If not pls pause this form and quickly whatsApp him/her for the sake of evidence to prevent them from denying it at the end of the month.): Yes; No; I just did WhatsApp them; I will WhatsApp them later
- **1754429064606** (If this is for a student, has her/his parent been responsive with previous updates (text & audio)message about the problem): Yes-parents are responsive; Yes- parent respond but take no action; No-parents never respond; Sometimes parents respond; N/A
- **1762614371423** (Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1754429889309** (Have you notified him or her (or their Parents) about their absence, lateness to prevent future denial If not, pls send in the notification now thru a WhatsApp text): Yes; No; N/A
- **1754428437290** (Reason for submitting): Leader Meeting ABSENCE; Leader Meeting LATENESS; Leader Bayana ABSENCE; Zoom Hosting LATENESS- Leader; Zoom Hosting ABSENCE - Leader; Student Class ABSENCE; Student Class LATENESS; Student Bayana ABSENCE; Teacher Class ABSENCE; Teacher Class LATENESS; Teacher Meeting ABSENCE; Teacher meeting LATENESS; Teacher Bayana Absence

**Descriptions / placeholders**

- **1754428826191**: placeholder: Enter text input...
- **1754428397328**: placeholder: Enter text input...
- **1754428921209**: placeholder: Enter multi-select...
- **1754428770767**: placeholder: Enter text input...
- **1754429986332**: placeholder: Enter text input...
- **1754429531965**: placeholder: Enter text input...
- **1754429678423**: placeholder: Enter multi-select...
- **1754430013333**: placeholder: Enter text input...
- **1754428767231**: placeholder: Enter text input...
- **1754429064606**: placeholder: Enter multi-select...
- **1762614371423**: placeholder: Enter multi-select...
- **1754429834347**: placeholder: Enter text input...
- **1754428878221**: placeholder: Enter text input...
- **1754429889309**: placeholder: Enter multi-select...
- **1754428437290**: placeholder: Enter multi-select...

### IDEA SUGGESTION FORM-CEO

- **Firestore**: `form_templates/wShZmI2Jy7u5djt1Wnuy`
- **Questions**: 8
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754625118975` | SUGGESTER | text |  |
| 2 | `1754625289698` | Note | text |  |
| 3 | `1754625092661` | DESCRIPTION | text |  |
| 4 | `1754625153814` | Date | date | yes |
| 5 | `1754625273787` | Need for the implementation | text |  |
| 6 | `1754625053090` | IDEA | text | yes |
| 7 | `1754625240600` | implementation parties/members | text |  |
| 8 | `1754625176474` | Implementation Date | date |  |

**Descriptions / placeholders**

- **1754625118975**: placeholder: your name here
- **1754625289698**: placeholder: Type here
- **1754625092661**: placeholder: Pls explain more about your idea here
- **1754625153814**: placeholder: Select Date
- **1754625273787**: placeholder: Type here
- **1754625053090**: placeholder: topic of the idea
- **1754625240600**: placeholder: kindly mention who your idea involves
- **1754625176474**: placeholder: Select Date

### Weekly Summary

- **Firestore**: `form_templates/weekly_summary`
- **Questions**: 7
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `weekly_rating` | How would you rate this week overall? | radio | yes |
| 2 | `classes_taught` | How many classes did you teach this week? | number | yes |
| 3 | `absences_this_week` | How many classes did you miss this week? | radio | yes |
| 4 | `video_recording_done` | Did you complete your weekly post-class video recording? | radio | yes |
| 5 | `achievements` | Key achievements this week | long_text | yes |
| 6 | `challenges` | Any challenges or support needed? | long_text |  |
| 7 | `coach_helpfulness` | How helpful was your coach this week? | radio | yes |

**Options (choice fields)**

- **weekly_rating** (How would you rate this week overall?): Excellent; Good; Average; Challenging
- **absences_this_week** (How many classes did you miss this week?): 0 (None); 1 class; 2 classes; 3 classes; 4+ classes
- **video_recording_done** (Did you complete your weekly post-class video recording?): Yes; No; N/A
- **coach_helpfulness** (How helpful was your coach this week?): Very Helpful; Somewhat Helpful; Not Helpful; Please Change My Coach; N/A

**Descriptions / placeholders**

- **achievements**: placeholder: Summarize student progress, milestones reached, etc.
- **challenges**: placeholder: Leave empty if none

### CEO Weekly Progress Form

- **Firestore**: `form_templates/yuOxAyXQDoTaigyHUqId`
- **Questions**: 60
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754410322373` | Has the bi-semesterly teachers' & staff's feedback survey been ready & on course? (for this partner with Mamoudou)) | radio | yes |
| 2 | `1754410101303` | Have you seen & reviewed all Teachers' Performance Grade for this Month | radio | yes |
| 3 | `1754408437242` | How many times did you review the Class Readiness Form for all teachers to ascertain about what's going on this week? | text |  |
| 4 | `1754410372342` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | text |  |
| 5 | `1763814542230` | List the names and numbers of parents you contacted this week for the purpose of relationship building? | long_text | yes |
| 6 | `1754410414108` | Have all leaders and teachers updated their Paycheck Update Sheet for this month? Name those who did not comply this week. | radio |  |
| 7 | `1754408284136` | If this is the fourth week of the month, have you ensured that the Student of the month post is ready? | text |  |
| 8 | `1754407118736` | How many time you submitted the the End of Shift Report form this week? | text |  |
| 9 | `1763813799403` | Based of your review of the Marketing officer overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text |  |
| 10 | `1754405243207` | Month | dropdown | yes |
| 11 | `1762602290765` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown | yes |
| 12 | `1754406275785` | How many overdue assigned tasks do you have this week? | text | yes |
| 13 | `1754405891238` | Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation? | text |  |
| 14 | `1754407413333` | For your teamamtes (leaders) tasks , have you verified this week's tasks they claimed to have completed (done tasks)? | dropdown | yes |
| 15 | `1763813896780` | Based of your review of the Teaching and students coordinator overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text | yes |
| 16 | `1754414044090` | Did you review all the forms submitted by your mentees and corrected the mistake they made therein? | dropdown |  |
| 17 | `1754405345431` | Week | dropdown | yes |
| 18 | `1754407888209` | How many time you submitted the Zoom Hosting Form this week? | number |  |
| 19 | `1754407220630` | How many excuses did you have this week? | text |  |
| 20 | `1754406489614` | Have you reviewed your Teachers clock in & Class readiness form | radio | yes |
| 21 | `1764289722044` | If schedule for this week, were leadership, PTA and Teacher Meeting conducted | dropdown | yes |
| 22 | `1754414136280` | Have all leaders submitted all their required forms this week? | dropdown | yes |
| 23 | `1754409063401` | List of Teachers Class Absence for this week | text |  |
| 24 | `1754406178119` | How many overdues does each leader of your team member have for this week? | text | yes |
| 25 | `1754408200192` | Did you help with new teacher interview this month? | dropdown |  |
| 26 | `1754409828876` | If this is the 3rd week of the month, is the next monthly Bayana Ready? | radio | yes |
| 27 | `1754405993796` | List the names/titles of the forms you reviewed this week | text |  |
| 28 | `1764346748544` | For this week, I have checked & reviewed the Financier works and found that | multi_select | yes |
| 29 | `1764286771598` | Based on the previous question above, pls indicate the names of all teachers and their forms and work you reviewed | long_text | yes |
| 30 | `1754410057904` | If this the 3rd week of the month, have you completed the Teacher's Monthly Audit for all your teachers? | radio | yes |
| 31 | `1754409022283` | Have you reviewed previous PTA meeting suggestions and concerns and assigned tasks to teammates provide solutions | dropdown |  |
| 32 | `1754408768571` | List new ideas you have suggested or existing idea and system you have improved this week? | text |  |
| 33 | `1764286366053` | This week I reviewed all the work and forms submitted by: | multi_select | yes |
| 34 | `1754408347614` | How many students did you directly and personally recruit this week? | text |  |
| 35 | `1754406853292` | If this is the fourth week of the month, have you completed reviewing then audits all teachers and their work? | dropdown | yes |
| 36 | `1764291174356` | Select all that applies to every leaders for this week | multi_select | yes |
| 37 | `1754410563942` | If this is the fourth week, have you completed the Peer Leadership Audit? | dropdown |  |
| 38 | `1754410872577` | Reviewed previous weeks Leader's meetings & sent a reminder on assigned tasks & Goals? | dropdown | yes |
| 39 | `1763813845489` | Based of your review of the Finance officer overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text |  |
| 40 | `1763610204679` | Who is the most productive team member this week and why? | long_text |  |
| 41 | `1754410681968` | Have you reviewed all coaches Weekly report progress/job scheduling channel to determine if their teachers schedules are up to date? | dropdown | yes |
| 42 | `1754409470638` | If this fourht week of the month, pls mention the winner of the teacher of the month and student of the month (for this month | text | yes |
| 43 | `1763813998896` | Based of your review of these Interns overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text | yes |
| 44 | `1754410023333` | Have you checked in with all teachers about their students' progress/readiness for the end of semester "student class project"? | radio | yes |
| 45 | `1754406042126` | As a team leader list how many task did you identify and assign to team members including teachers for this week? | text |  |
| 46 | `1764287465735` | How many students did drop out/quited our program this week | number | yes |
| 47 | `1754410180989` | As team member, have much do feel supported by the leadership this week? | text |  |
| 48 | `1764289855579` | How is our financial standing this week | dropdown | yes |
| 49 | `1754410499465` | As the team leader, how much do you feel that you are in control of teachers, projects, students and tasks this week? | text | yes |
| 50 | `1754409969369` | Have you reviewed and evaluated the tasks, assignments, projects, and deadlines for all staff and leaders in your department for this month? | radio | yes |
| 51 | `1754410231666` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month? | text |  |
| 52 | `1754410812808` | Have all leaders reported their time in and time Out for hosting Zoom this month? | text |  |
| 53 | `1754405479773` | How many new students did our financier report joining us this week | number | yes |
| 54 | `1764197752276` | List the name of all your teachers whose clock in and Out you have approve for this week | long_text |  |
| 55 | `1754407061167` | Have you completed all the assigned tasks & projects to you AND due this week? | radio |  |
| 56 | `1754406544776` | List Coaches who have sent in excuses for meeting this week? | text | yes |
| 57 | `1764289459029` | For this week did the Marketing officer post | dropdown | yes |
| 58 | `1754408544827` | Email (weekly check and reply): did check out and reply all emails for this week? Yes | dropdown |  |
| 59 | `1754408485766` | How many teammates (on the executive board) did you support or help with anything this week? | text |  |
| 60 | `1754408636565` | How many Parents did you call this week? | text |  |

**Options (choice fields)**

- **1754405243207** (Month): Jan; Feb; Mar; Apr; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1762602290765** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): Yes I have approved it for all my teachers; Not yet; I am lazy employee
- **1754407413333** (For your teamamtes (leaders) tasks , have you verified this week's tasks they claimed to have completed (done tasks)?): No false claim there; i have reviewed it; some false claims - Some false claims; i have contacted them; I'm too lazy to check this week
- **1754414044090** (Did you review all the forms submitted by your mentees and corrected the mistake they made therein?): Yes; No; Review but not corrected; No mistakes; Will do later
- **1754405345431** (Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1764289722044** (If schedule for this week, were leadership, PTA and Teacher Meeting conducted): Yes; No - i take the blame; N/A
- **1754414136280** (Have all leaders submitted all their required forms this week?): Yes all leaders; No but fact finding form reported; Oops I am too lazy for this - blame me
- **1754408200192** (Did you help with new teacher interview this month?): Yes; No; N/A
- **1764346748544** (For this week, I have checked & reviewed the Financier works and found that): Canvas receipts well organized; Canvas receipts disorganized but I corrected them; Finance docs & tabs are well organized; Finance Docs are disorganized - but I corrected them; No unresponded whatsAppchat; WhatsApp chats about fees not responded but I course corrected
- **1754409022283** (Have you reviewed previous PTA meeting suggestions and concerns and assigned tasks to teammates provide solutions): Yes; No; N/A
- **1764286366053** (This week I reviewed all the work and forms submitted by:): The Marketing leader and and 3 of his teachers; The Financier & 3 of her teachers; The learning Coordinator & 3 of her teachers; the CEO and 3 of his teachers
- **1754406853292** (If this is the fourth week of the month, have you completed reviewing then audits all teachers and their work?): Yes; No - not yet; N/A
- **1764291174356** (Select all that applies to every leaders for this week): Marketing Officer - poor performance; Marketing Officer - excellent performance; Financier - excellent performance; Financier - poor performance; Learning Coordinator -  poor performance; Learning Coodinator - excellent performance
- **1754410563942** (If this is the fourth week, have you completed the Peer Leadership Audit?): Yes; No; N/A
- **1754410872577** (Reviewed previous weeks Leader's meetings & sent a reminder on assigned tasks & Goals?): Yes; No; N/A
- **1754410681968** (Have you reviewed all coaches Weekly report progress/job scheduling channel to determine if their teachers schedules are up to date?): I checked-no concern; No Problem but I didn't check; Too lazy to check this week
- **1764289855579** (How is our financial standing this week): Great - no debt; Okay - just few debt; Bad - > 5 persons owing
- **1764289459029** (For this week did the Marketing officer post): 0x on all platforms; 3x on all platforms; 2x on all platforms; 4x on all platforms; 1x on all platforms
- **1754408544827** (Email (weekly check and reply): did check out and reply all emails for this week? Yes): Yes; No; N/A

**Descriptions / placeholders**

- **1754410322373**: placeholder: Enter yes/no...
- **1754410101303**: placeholder: Enter yes/no...
- **1754408437242**: placeholder: Type here
- **1754410372342**: placeholder: Do this monthly
- **1763814542230**: placeholder: Just enter their names and numbers so that Chernor could verify with them if need be
- **1754410414108**: placeholder: Enter yes/no...
- **1754408284136**: placeholder: If not, handle this now
- **1754407118736**: placeholder: Type here
- **1763813799403**: placeholder: Briefly list the problem and feedback you offered this team member
- **1754405243207**: placeholder: Tap to select
- **1762602290765**: placeholder: If not please do this now before submitting this form - this must be done at least once per week
- **1754406275785**: placeholder: Go check your quick task to determine
- **1754405891238**: placeholder: Type here
- **1754407413333**: placeholder: Pls click on "done tasks" options; quickly scheme through to identify the authenticity of their claims
- **1763813896780**: placeholder: Briefly list the problem and feedback you offered this team member
- **1754414044090**: placeholder: Enter dropdown...
- **1754405345431**: placeholder: Tap to select
- **1754407888209**: placeholder: Type here 
- **1754407220630**: placeholder: If any, list it below and indicate if it was a formal and accepted excuse or not
- **1754406489614**: placeholder: Noticed any problem? Take Action Now
- **1764289722044**: placeholder: Enter dropdown...
- **1754414136280**: placeholder: If not report any non compliance to the fact finding form before proceeding to the next question
- **1754409063401**: placeholder: Type here
- **1754406178119**: placeholder: Type it below like: Mamoudou = 5, Salima = 2
- **1754408200192**: placeholder: Answer this only once per month
- **1754409828876**: placeholder: Who's the guest? is the flyer ready? Contact the relevant team member if you don't have answer to these questions
- **1754405993796**: placeholder: Type here
- **1764346748544**: placeholder: Select all that applies 
- **1764286771598**: placeholder: Write their names so that we can track it for evidence work. Feel to cite any concerns u noticed
- **1754410057904**: placeholder: Enter yes/no...
- **1754409022283**: placeholder: Enter dropdown...
- **1754408768571**: placeholder: Type here
- **1764286366053**: placeholder: At least deeply review the work of 2 team leaders and 3 teachers of the 2 leaders per week. Report fact findings and correct mistakes, errors and feedback immediately
- **1754408347614**: placeholder: All leaders are considered ambassadors and recruiters for our programs
- **1754406853292**: placeholder: Including the total hours each person work and recommending action for any violation
- **1764291174356**: placeholder: Verify their work before answering and make sure fact findings is submitted
- **1754410563942**: placeholder: Enter dropdown...
- **1754410872577**: placeholder: Enter dropdown...
- **1763813845489**: placeholder: Briefly list the problem and feedback you offered this team member
- **1763610204679**: placeholder: birefly explain this because we will rely on this to recognize and award leaders
- **1754410681968**: placeholder: Verify this each week to ensure it is all set
- **1754409470638**: placeholder: Type here
- **1763813998896**: placeholder: Briefly list the problem and feedback you offered to all interns - if there is anyone, add eacher person to their feedback 
- **1754410023333**: placeholder: Enter yes/no...
- **1754406042126**: placeholder: Type here
- **1764287465735**: placeholder: Verify the record before reporting here and take action to bring them back
- **1754410180989**: placeholder: Rate from 1 - 5
- **1764289855579**: placeholder: Contact the financier to dertermine or review their work before proceeding. But ensure it is resolved by next week or students are suspended
- **1754410499465**: placeholder: Rate from 1 - 5
- **1754409969369**: placeholder: Enter yes/no...
- **1754410231666**: placeholder: Only answer this question once per month
- **1754410812808**: placeholder: Name those who did not comply this month
- **1754405479773**: placeholder: Go check her Weekly Progress Report to find out
- **1764197752276**: placeholder: You are required to approve the hours of each of your teacher for this week
- **1754407061167**: placeholder: Enter yes/no...
- **1754406544776**: placeholder: Type here/NA if need be
- **1764289459029**: placeholder: Double Check online
- **1754408544827**: placeholder: Enter dropdown...
- **1754408485766**: placeholder: Type here
- **1754408636565**: placeholder: Update the outcome of these calls on the CEO Auditing Google Sheet

### Monthly Review

- **Firestore**: `form_templates/z0vXGjsllVFJAst0Nnuq`
- **Questions**: 3
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `goals_met` | Were your teaching goals met? | radio | yes |
| 2 | `comments` | Additional comments for admin | long_text |  |
| 3 | `month_rating` | How would you rate this month? | radio | yes |

**Options (choice fields)**

- **goals_met** (Were your teaching goals met?): Yes, all goals; Most goals; Some goals; Few goals
- **month_rating** (How would you rate this month?): Excellent; Good; Average; Challenging

**Descriptions / placeholders**

- **comments**: placeholder: Any feedback, requests, or concerns

## Legacy forms (`form`)

### Teachers Waitlist (Arabic, English, Aldam) Mamoudou/CEO

- **Firestore**: `form/2g3190jT1zmVPEVhEPop`
- **Questions**: 15
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754662514515` | Enter Teacher Name | text | yes |
| 2 | `1754662555327` | Email | text | yes |
| 3 | `1754662608885` | WhatsApp | number | yes |
| 4 | `1754662648323` | Gender | dropdown | yes |
| 5 | `1754662693039` | Program | dropdown | yes |
| 6 | `1754662751411` | Country of residence | text | yes |
| 7 | `1754662800891` | Nationality | text | yes |
| 8 | `1754662853038` | Languages Spoken | text | yes |
| 9 | `1754662902101` | Days Availibility | text | yes |
| 10 | `1754663019374` | Days Preferred | dropdown | yes |
| 11 | `1754663129944` | Quran Fluency | dropdown | yes |
| 12 | `1754663172766` | Arabic Fluency | dropdown | yes |
| 13 | `1754663223034` | Tech/Devices Access | dropdown | yes |
| 14 | `1754663271563` | Priority Level | dropdown | yes |
| 15 | `1754663343717` | Status | dropdown | yes |

**Options (choice fields)**

- **1754662648323** (Gender): Male; Female
- **1754662693039** (Program): Arabic; English; Adlam
- **1754663019374** (Days Preferred): Weekends; Week days; Any day
- **1754663129944** (Quran Fluency): Beginner; Intermediate; Advanced
- **1754663172766** (Arabic Fluency): Beginner; Intermediate; Advanced
- **1754663223034** (Tech/Devices Access): Computer; Tablet; A Phone
- **1754663271563** (Priority Level): High Priority; Medium Priority; Low Priority; Not a Priority
- **1754663343717** (Status): Assigned; Unassigned

**Descriptions / placeholders**

- **1754662514515**: placeholder: Type here
- **1754662555327**: placeholder: Type here
- **1754662608885**: placeholder: Type here
- **1754662648323**: placeholder: Tap to select
- **1754662693039**: placeholder: Tap to select
- **1754662751411**: placeholder: Type here
- **1754662800891**: placeholder: Type here
- **1754662853038**: placeholder: Type here
- **1754662902101**: placeholder: Type here
- **1754663019374**: placeholder: Tap to select
- **1754663129944**: placeholder: Tap to select
- **1754663172766**: placeholder: Tap to select
- **1754663223034**: placeholder: Tap to select
- **1754663271563**: placeholder: Tap to select
- **1754663343717**: placeholder: Tap to select

### Summer Plans (Teachers & Admins)

- **Firestore**: `form/3QphWY7dSrVgG4UJhCLi`
- **Questions**: 6
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754615643919` | Submitted by: | text | yes |
| 2 | `1754615817761` | Position/TittleDropdown | dropdown | yes |
| 3 | `1754615968757` | Travelling Date | date | yes |
| 4 | `1754616294003` | Will you teach or work with the hub this summer | radio | yes |
| 5 | `1754616394560` | Are you willing to take more students or put in more hours this summer? | radio | yes |
| 6 | `1754616792297` | If yes, how many additional hours would you like to commit, or how many more classes are you able to take? | text | yes |

**Options (choice fields)**

- **1754615817761** (Position/TittleDropdown): Teacher; Admin

**Descriptions / placeholders**

- **1754615643919**: placeholder: Type Name
- **1754615817761**: placeholder: Enter dropdown...
- **1754615968757**: placeholder: Enter date...
- **1754616294003**: placeholder: Enter yes/no...
- **1754616394560**: placeholder: Enter yes/no...
- **1754616792297**: placeholder: Enter text input...

### Forms/Facts Finding & Complains Report - leaders/CEO

- **Firestore**: `form/6HO5uWfYM4bTPl1LvJee`
- **Questions**: 13
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754483161194` | Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed | dropdown | yes |
| 2 | `1754483204692` | Your Name | dropdown | yes |
| 3 | `1754509820261` | What (title, form, or name) is your report about? | long_text | yes |
| 4 | `1754483410122` | Is this for | dropdown | yes |
| 5 | `1754483452846` | Month | dropdown | yes |
| 6 | `1754483514511` | Week | dropdown | yes |
| 7 | `1754483281251` | Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it | dropdown | yes |
| 8 | `1754483634804` | Who or what is this report/complaints ABOUT? | long_text | yes |
| 9 | `1754483675790` | Mention the team leader(s) this report should concern | long_text | yes |
| 10 | `1754483696467` | What findings are you reporting here: briefly explain | long_text | yes |
| 11 | `1754483719927` | Potential Repercussion for this complaint based on the bylaws | dropdown | yes |
| 12 | `1754483797967` | What do you want for the leader to do about this report | long_text | yes |
| 13 | `1754483819860` | Image Upload | image_upload |  |

**Options (choice fields)**

- **1754483161194** (Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed): Yes; No
- **1754483204692** (Your Name): Chernor; Hashim; Mohammed; Salimatu; Abdi; Khadijah; Mamoudou
- **1754483410122** (Is this for): Complaint Againts An Issue; Just Awareness
- **1754483452846** (Month): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754483514511** (Week): Week1; Week2; Week3; Week4
- **1754483281251** (Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it): Yes I addressed it; No - it is outside my ability; I will address it later
- **1754483719927** (Potential Repercussion for this complaint based on the bylaws): $3-$9 paycut; $10-$19 paycut; $20 + paycut; Warning Letter; Suspension without payment; N/A

**Descriptions / placeholders**

- **1754483161194**: placeholder: Enter dropdown...
- **1754483204692**: placeholder: Choose
- **1754509820261**: placeholder: Just mention the title ( such as "teacher audit" for example)
- **1754483410122**: placeholder: fill in
- **1754483452846**: placeholder: Month
- **1754483514511**: placeholder:  Week
- **1754483281251**: placeholder: Choose carefully
- **1754483634804**: placeholder: Name the reason or person whom you are reporting/complaining about 
- **1754483675790**: placeholder: Who on our team need to take action about what you are reporting? 
- **1754483696467**: placeholder: Be accurate
- **1754483719927**: placeholder: Verify the code of conduct to determine this
- **1754483797967**: placeholder: Be clear and mention next course of action needed to be taken 
- **1754483819860**: placeholder: Image report

### IDEA SUGGESTION FORM-CEO

- **Firestore**: `form/6LyKAHvUDp4rDF0jlg6a`
- **Questions**: 8
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754625053090` | IDEA | text | yes |
| 2 | `1754625092661` | DESCRIPTION | text |  |
| 3 | `1754625118975` | SUGGESTER | text |  |
| 4 | `1754625153814` | Date | date | yes |
| 5 | `1754625176474` | Implementation Date | date |  |
| 6 | `1754625240600` | implementation parties/members | text |  |
| 7 | `1754625273787` | Need for the implementation | text |  |
| 8 | `1754625289698` | Note | text |  |

**Descriptions / placeholders**

- **1754625053090**: placeholder: topic of the idea
- **1754625092661**: placeholder: Pls explain more about your idea here
- **1754625118975**: placeholder: your name here
- **1754625153814**: placeholder: Select Date
- **1754625176474**: placeholder: Select Date
- **1754625240600**: placeholder: kindly mention who your idea involves
- **1754625273787**: placeholder: Type here
- **1754625289698**: placeholder: Type here

### Finance Weekly Update Form-Salimatu/CEO

- **Firestore**: `form/7CLjMIOY0XiAxGj7wlGh`
- **Questions**: 28
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754617928012` | Submitted by: | dropdown | yes |
| 2 | `1754618405871` | Submission Week | dropdown | yes |
| 3 | `1754618481310` | Have you checked out the Student Status Form to find new student | radio |  |
| 4 | `1754618501911` | Have you checked out the student Application form to spot any new students this week | radio |  |
| 5 | `1754618523857` | Have you reviewed the WhatsApp number to determine reply all finance related texts? | dropdown | yes |
| 6 | `1754618586388` | Is the Canva receipts page well organize based on family names - alphatically? | dropdown | yes |
| 7 | `1754618639860` | Are there a new students this week | dropdown | yes |
| 8 | `1754618707589` | As of this week, are all new students moved to the finance document | radio | yes |
| 9 | `1754618731269` | Have you sent an invoice to new parents | dropdown | yes |
| 10 | `1754618974860` | Have you assigned (to our website) Chernor to call parents who are note complying in the past 2 weeks? | dropdown | yes |
| 11 | `1754619162098` | What is the total number of students owing fees as of today's date? | text | yes |
| 12 | `1754619204514` | What is the total number of pending receipts that are yet to be made even though the payment has been made? | text |  |
| 13 | `1754619501808` | What is the total of new student this week? | text |  |
| 14 | `1754619526446` | Outline your step-by-step plan to fix or correct any concerns or problems you obseve while reviewing and submitting this form | text |  |
| 15 | `1754619555700` | Any challenges you are having with fees collections? Explain below | text |  |
| 16 | `1759677195598` | Month | dropdown | yes |
| 17 | `1763608654693` | How many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional note | long_text |  |
| 18 | `1763608722396` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month | dropdown |  |
| 19 | `1763608778231` | How many time you submitted the Zoom Hosting Form this week? | number |  |
| 20 | `1763608805905` | List the names/titles of all the forms you reviewed this week? | long_text |  |
| 21 | `1763608847642` | How many time you join Zoom Hosting late this week? | number |  |
| 22 | `1763608859429` | How many time you were absence for Zoom Hosting this week? | number |  |
| 23 | `1763608910027` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown |  |
| 24 | `1763608972312` | How many task overdues are ending this week with? Check the Quick Tasks from the Site to be exact | number |  |
| 25 | `1763609152579` | How many fact finding form were submitted about you and your role this week? | number |  |
| 26 | `1763609378819` | How many parents did you check in on for the purpose of relationship building? | number |  |
| 27 | `1764198825045` | How many time did you check the Student Application Form this week | number | yes |
| 28 | `1764198941300` | List the name of all your teachers whose clock in and Out you have approve for this week | long_text | yes |

**Options (choice fields)**

- **1754617928012** (Submitted by:): Mohammad Bah; Mamoudou Diallo; Chernor A. Diallo; Intern; Salimatu
- **1754618405871** (Submission Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1754618523857** (Have you reviewed the WhatsApp number to determine reply all finance related texts?): Yes i have reviewed; No i am lazy to review; I will review later today; I reviwed yesterday
- **1754618586388** (Is the Canva receipts page well organize based on family names - alphatically?): Yes 100% organize; Not organize; Very messy but i will fix it today
- **1754618639860** (Are there a new students this week): No; Yes; I did not check this week
- **1754618731269** (Have you sent an invoice to new parents): Yes to all new parents; To a few parents; No i am lazy to do it; No new student this week
- **1754618974860** (Have you assigned (to our website) Chernor to call parents who are note complying in the past 2 weeks?): Yes i have; No-I will do another round of follow-up; No everyone is comlying
- **1759677195598** (Month): JANUARY; FEBRUARY; MARCH; APRIL; MAY; JUNE; JULY; AUGUST; SEPTEMBER; OCTOBER; NOVEMBER; DECEMBER
- **1763608722396** (How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month): 0; 3; 2; 1
- **1763608910027** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): No; Yes; Too lazy to that

**Descriptions / placeholders**

- **1754617928012**: placeholder: Enter dropdown...
- **1754618405871**: placeholder: Enter dropdown...
- **1754618481310**: placeholder: Yes, No
- **1754618501911**: placeholder: Enter yes/no...
- **1754618523857**: placeholder: Enter dropdown...
- **1754618586388**: placeholder: Enter dropdown...
- **1754618639860**: placeholder: Enter dropdown...
- **1754618707589**: placeholder: Yes, No
- **1754618731269**: placeholder: Enter dropdown...
- **1754618974860**: placeholder: Enter dropdown...
- **1754619162098**: placeholder: Type here
- **1754619204514**: placeholder: Type here
- **1754619501808**: placeholder: Enter text input...
- **1754619526446**: placeholder: Just list them (if no concern or problem ignore this question)
- **1754619555700**: placeholder: Enter text input...
- **1759677195598**: placeholder: Enter dropdown...
- **1763608654693**: placeholder: List them here
- **1763608722396**: placeholder: Enter dropdown...
- **1763608778231**: placeholder: Enter number...
- **1763608805905**: placeholder: Enter long text...
- **1763608847642**: placeholder: Enter number...
- **1763608859429**: placeholder: Enter number...
- **1763608910027**: placeholder: Enter dropdown...
- **1763608972312**: placeholder: Enter it here but remember the goal is to finish & close all tasks due this week before the week ends
- **1763609152579**: placeholder: Pls check the fact finding form to be sure
- **1763609378819**: placeholder: You are to contact at least 7 parents/students per week to show concern and support and update the student follow up form. 
- **1764198825045**: placeholder: Enter number...
- **1764198941300**: placeholder: You are required to approve the hours of each of your teacher for this week

### All Bi-Weely Coachees Performance

- **Firestore**: `form/A6syiQXSIlRnftoFfud9`
- **Questions**: 34
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754625570522` | Coach Name | dropdown | yes |
| 2 | `1754625657517` | What is the total number of teachers you are coaching this month? | number | yes |
| 3 | `1754625695824` | To help prevent potential infractions or violations that could impact teachers' salaries at the end of the month, it is essential to promptly address any mistakes you observe while reviewing this form by guiding the teacher in making corrections before the following week. Will you commit to taking immediate action when you notice any issues? | dropdown | yes |
| 4 | `1754851252144` | Date | date | yes |
| 5 | `1754625919184` | Week | dropdown | yes |
| 6 | `1754625964834` | Coachee | dropdown |  |
| 7 | `1754646589540` | Is this the 1st or 2nd time you are submitting this form this teacher in this month? | dropdown | yes |
| 8 | `1754646633544` | Are this coachee Clock in & Out Hours correctly entered for the past 2 weeks? | radio | yes |
| 9 | `1754646704061` | Is this teacher schedule up to date as of today? | dropdown | yes |
| 10 | `1754646772880` | Based on your careful review, how often does this coach edit his or her hours before submitting his or her clock in & out. | dropdown |  |
| 11 | `1754646853504` | What is the number of times this teacher left comments on his/her readiness for the past 2 week? | dropdown |  |
| 12 | `1754646906866` | How many of those comments you needed to address? | dropdown |  |
| 13 | `1754646952991` | As the coach, have you addressed those comments? | dropdown |  |
| 14 | `1754646984814` | So far does the clock in pattern correctly reflect this teacher's weekly schedule on the Connecteam Channel? | dropdown | yes |
| 15 | `1754647396475` | Does this teacher number of readiness form submitted match the number of time the clock in submisson? | dropdown |  |
| 16 | `1754647635467` | How many times this teacher did their post class video recording for the past 2 weeks? | dropdown |  |
| 17 | `1754647696457` | As the coach, have you been checking the general performance of this teacher's students by sometimes randonmly testing them, checking their grades or asking the teachers about them | dropdown |  |
| 18 | `1754647852703` | How many times this teacher join class late the past 2 weeks? | dropdown |  |
| 19 | `1754647920053` | Did this teacher's students attend last Month Bayana based on the readiness form record? | dropdown |  |
| 20 | `1754647985504` | If the previous question is not 100% attendance, have you contacted this teacher to know why | dropdown |  |
| 21 | `1754648035001` | In the past month, how many interactions did you have with this teacher (interaction include: call, meeting and chats) | dropdown |  |
| 22 | `1754648121895` | If applicable how many time has this teacher conducted students midterm? | dropdown |  |
| 23 | `1754648183894` | How many Quizzes did this teacher give the past 2 weeks? | dropdown |  |
| 24 | `1754648245467` | How many Assignment did this teacher give in the past 2 weeks? | dropdown |  |
| 25 | `1754648319664` | How many absences does this teacher incur in the past 2 weeks? | dropdown |  |
| 26 | `1754648359902` | If applicable how many exam this teacher give this semester? | dropdown |  |
| 27 | `1754648408096` | If applicable has this teacher update his/her Paycheck Form for the previous month? | radio |  |
| 28 | `1754648429149` | List the names of students who have been absent from class for the past 2 weeks? | text |  |
| 29 | `1754648459627` | If you listed any student in the previous question have you updated the Student Learning Coordinator (Kadijatu) about the students absences | dropdown |  |
| 30 | `1754648539104` | How many formal excuses did this teacher requested for last month? | dropdown |  |
| 31 | `1754648607874` | If any student has been absent for more than 2 weeks, did you make sure the teacher is not attending this classDropdown | dropdown |  |
| 32 | `1754648658350` | Any comment additional comment about this teacher and his/her class | text |  |
| 33 | `1754648697271` | Rate the overall performance of this teacher for the last 2 weeks | text |  |
| 34 | `1762603006992` | Have you reviewed and approved the clock in and out for this teacher for the past 2 weeks | dropdown | yes |

**Options (choice fields)**

- **1754625570522** (Coach Name): Mamoudou; Mohammed Bah; Kadijatu Jalloh; Salimatu; Intern
- **1754625695824** (To help prevent potential infractions or violations that could impact teachers' salaries at the end of the month, it is essential to promptly address any mistakes you observe while reviewing this form by guiding the teacher in making corrections before the following week. Will you commit to taking immediate action when you notice any issues?): Yes I will; No I won't; I will try; I am unfocus rn
- **1754625919184** (Week): Week 1; Week 3
- **1754625964834** (Coachee): Rahmatulahi Balde; Aliou Diallo; Ustada Lubna; Ustadha Siyam; Thieno Abdul; Abdoulai Yayah; Abdulai Diallo; Ustadha Elham; Ustadha NasruLlah; Ustaz Abu Faruk; Ustaz Al-hassan; Ustaz Arabieu; Ustaz Abdullah; Ustaz Abdulwarith; Ustaz Abdulkarim; Uataz Mohammed Jan; Ustaz Abdurahmane; Ustaz Ibrahim Bah; Ustaz Ibrahim Balde; Ustaz Kosiah…
- **1754646589540** (Is this the 1st or 2nd time you are submitting this form this teacher in this month?): 1st Time; 2nd Time; N/A
- **1754646704061** (Is this teacher schedule up to date as of today?): No i will go fix it now; No -but i have fixed now; Yes it is all good
- **1754646772880** (Based on your careful review, how often does this coach edit his or her hours before submitting his or her clock in & out.): Often; Never - this teacher is a pro Always; Rarely; N/A
- **1754646853504** (What is the number of times this teacher left comments on his/her readiness for the past 2 week?): 0; 1; 2-4; 5-7
- **1754646906866** (How many of those comments you needed to address?): None; A couple; All
- **1754646952991** (As the coach, have you addressed those comments?): Yes; No; I will this week
- **1754646984814** (So far does the clock in pattern correctly reflect this teacher's weekly schedule on the Connecteam Channel?): Yes it is alright - I checked; No - there is mismatch- but I engaged the teacher already; No - many mismatches - but will contact this teacher; No time for me fix anything
- **1754647396475** (Does this teacher number of readiness form submitted match the number of time the clock in submisson?): I am lazy to check it out; Yes - this teacher has no problem with it; No - yes this teacher has a mismatch; I will check it out later
- **1754647635467** (How many times this teacher did their post class video recording for the past 2 weeks?): 0; 1; 3; 4 +; Teacher is exempted
- **1754647696457** (As the coach, have you been checking the general performance of this teacher's students by sometimes randonmly testing them, checking their grades or asking the teachers about them): Yes - 100% sure; Maybe - not sure cuz i don't often check; No - 0% learning; To some extent - 40 to 70 % learning; I need to improve my oversight
- **1754647852703** (How many times this teacher join class late the past 2 weeks?): 0; 1; 2; 3; 4; 5 +
- **1754647920053** (Did this teacher's students attend last Month Bayana based on the readiness form record?): N/A; Yes - 100% attended; No - 0% attended; Just > 50% attended; Just < 50% attended
- **1754647985504** (If the previous question is not 100% attendance, have you contacted this teacher to know why): Yes - I have; No - I have not; I will later
- **1754648035001** (In the past month, how many interactions did you have with this teacher (interaction include: call, meeting and chats)): 0; 1; 2; 3; 4-6; 7 +
- **1754648121895** (If applicable how many time has this teacher conducted students midterm?): 0; 1; 2; 3 - 5; 6 +; N/A
- **1754648183894** (How many Quizzes did this teacher give the past 2 weeks?): 0; 1 - 2; 3 - 5; 7 +
- **1754648245467** (How many Assignment did this teacher give in the past 2 weeks?): 0; 1; 2; 3-5; 6 +
- **1754648319664** (How many absences does this teacher incur in the past 2 weeks?): 0; 1; 2; 3; 4; 5 +
- **1754648359902** (If applicable how many exam this teacher give this semester?): 0; 1; 2; 3
- **1754648459627** (If you listed any student in the previous question have you updated the Student Learning Coordinator (Kadijatu) about the students absences): Yes; No; I will
- **1754648539104** (How many formal excuses did this teacher requested for last month?): 0; 1; 2; 3; 4 - 6; 7 +
- **1754648607874** (If any student has been absent for more than 2 weeks, did you make sure the teacher is not attending this classDropdown): Yes; No; I will double check
- **1762603006992** (Have you reviewed and approved the clock in and out for this teacher for the past 2 weeks): Yes I have approved it for this teacher; Not yet; I am lazy employee

**Descriptions / placeholders**

- **1754625570522**: placeholder: Enter dropdown...
- **1754625657517**: placeholder: Type here
- **1754625695824**: placeholder: Tap to select
- **1754851252144**: placeholder: Enter date...
- **1754625919184**: placeholder: Enter dropdown...
- **1754625964834**: placeholder: Enter dropdown...
- **1754646589540**: placeholder: Enter dropdown...
- **1754646633544**: placeholder: Verify this from the Time Sheet located in the Time Clock 
- **1754646704061**: placeholder: Go to the Schedule channel to fix any inaccurate or incomplete schedule...
- **1754646772880**: placeholder: Be sure to double check, do not guess because Chernor will know if you do
- **1754646853504**: placeholder: Enter dropdown...
- **1754646906866**: placeholder: Enter dropdown...
- **1754646952991**: placeholder: Enter dropdown...
- **1754646984814**: placeholder: pls verify it and don't be lazy
- **1754647396475**: placeholder: Pls go verify and demand the teacher to fix it if there is a problem, otherwise, waiting for the end of month to verify would have you equally responsible for any mistmatch
- **1754647635467**: placeholder: Enter dropdown...
- **1754647696457**: placeholder: Do you really know if this teacher's students are truly learning?
- **1754647852703**: placeholder: Check out the In and Out Zoom hosting form to find this information
- **1754647920053**: placeholder: Enter dropdown...
- **1754647985504**: placeholder: Enter dropdown...
- **1754648035001**: placeholder: Answer this question once per month.
- **1754648121895**: placeholder: Enter dropdown...
- **1754648183894**: placeholder: Enter dropdown...
- **1754648245467**: placeholder: Enter dropdown...
- **1754648319664**: placeholder: Check the In and Out Zoom hosting form to determine
- **1754648359902**: placeholder: Enter dropdown...
- **1754648408096**: placeholder: Enter yes/no...
- **1754648429149**: placeholder: Check this teacher readiness form to student names
- **1754648459627**: placeholder: Enter dropdown...
- **1754648539104**: placeholder: Answer this only once a month
- **1754648607874**: placeholder: This applies only to one - on - one class or if a whole group class stopped attending
- **1754648658350**: placeholder: Type here
- **1754648697271**: placeholder: 1 - 5, with 5 being the highest
- **1762603006992**: placeholder: If not please do this now before submitting this form 

### PayCheck Update Form

- **Firestore**: `form/Bj7ybPsgB2muH2Yq6Y2y`
- **Questions**: 9
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1761909346092` | Teachers Name | dropdown |  |
| 2 | `1761909953148` | Coach Name | dropdown |  |
| 3 | `1761910070813` | Months | dropdown | yes |
| 4 | `1761910174501` | Days | dropdown |  |
| 5 | `1761910713866` | Date | date |  |
| 6 | `1761910441392` | Amount | text |  |
| 7 | `1761911157885` | PayCut | text |  |
| 8 | `1761910906373` | Violation type | text |  |
| 9 | `1761910285241` | Notes | text |  |

**Options (choice fields)**

- **1761909346092** (Teachers Name): Oustaz Habibu Barry; Oustaz Ibrahim Balde; Oustaz Arabieu Bah; Oustaz Aliou Diallo; Oustaz Mohammed Yahaya Sheriff; Oustaz Ousmane Thiam; Oustaz Ibrahim Bah; Oustaz Mamadou Saidou Diallo; Usataza Asma Mugiu; Usataza Elham Ahmed Shifa; Usataza Mama S. Diallo; Usataza NasurLlah Jalloh; Oustaz Alhassan Diallo; Oustaz Ouniadon KhariaLlah; Oustaz Ahmed Korka Bah; Mohammed Bah; Mamoudou Diallo; Salimatou Diallo; Khadijah Jalloh
- **1761909953148** (Coach Name): Coach Mamoudou Diallo; Coach Mohammed Bah; Coach Khadijah Jalloh; Coach Salimatou Diallo
- **1761910070813** (Months): Jan; Feb; Mar; April; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1761910174501** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday

**Descriptions / placeholders**

- **1761909346092**: placeholder: Enter dropdown...
- **1761909953148**: placeholder: Enter dropdown...
- **1761910070813**: placeholder: Enter dropdown...
- **1761910174501**: placeholder: Enter dropdown...
- **1761910713866**: placeholder: Enter date...
- **1761910441392**: placeholder: Enter text input...
- **1761911157885**: placeholder: Enter text input...
- **1761910906373**: placeholder: Enter text input...
- **1761910285241**: placeholder: Enter text input...

### Award and Recognitions Tracker

- **Firestore**: `form/E7tiXonhFedTg9UsUqMa`
- **Questions**: 7
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754610102115` | Name | dropdown |  |
| 2 | `1754610207342` | Name of Winner | text | yes |
| 3 | `1754610291498` | The Winner is a | dropdown | yes |
| 4 | `1754610369613` | Title of Award/Recognition | text | yes |
| 5 | `1754610416286` | Has this winner been celebrated (posted) in all social media | radio |  |
| 6 | `1754610445849` | How many time has this person won any award this Semester? | dropdown |  |
| 7 | `1754610550377` | Any note? | text |  |

**Options (choice fields)**

- **1754610102115** (Name): Mohammed Bah; Mamoudou Diallo; Salimatu; Abdi; Kadijatu Jalloh; Intern
- **1754610291498** (The Winner is a): Student; Teacher; Leader
- **1754610445849** (How many time has this person won any award this Semester?): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time

**Descriptions / placeholders**

- **1754610102115**: placeholder: Enter dropdown...
- **1754610207342**: placeholder: Enter text input...
- **1754610291498**: placeholder: Enter dropdown...
- **1754610369613**: placeholder: Type here
- **1754610416286**: placeholder: Enter yes/no...
- **1754610445849**: placeholder: Tap to Select
- **1754610550377**: placeholder: Type here

### Pre Start and End of Semester Survey

- **Firestore**: `form/EWBg4aIEQZ8jsHWEfLdM`
- **Questions**: 9
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754655639440` | How Many Surah does this student know before starting our program/classes | text | yes |
| 2 | `1754655671468` | How well does this student read Arabic letters,before starting our program/classes | text | yes |
| 3 | `1754655702152` | How well does this student write Arabic letters before starting our program/classes | text | yes |
| 4 | `1754655754382` | What is the level of this student | dropdown | yes |
| 5 | `1754655817197` | How many hadith does this student know before joinning our program/classes | text | yes |
| 6 | `1754655874088` | How Many Surahs has this student learned in this semester | text | yes |
| 7 | `1754656002327` | Rate this student reading skills from 1-5 | text | yes |
| 8 | `1754656066306` | Rate this student writting skills from 1-5 | text | yes |
| 9 | `1754656097824` | How many hadith has this student learned in this semester | text | yes |

**Options (choice fields)**

- **1754655754382** (What is the level of this student): Begginer; Intermediate; Advance

**Descriptions / placeholders**

- **1754655639440**: placeholder: Type here
- **1754655671468**: placeholder: Type here
- **1754655702152**: placeholder: Type here
- **1754655754382**: placeholder: Tap to select
- **1754655817197**: placeholder: Type here
- **1754655874088**: placeholder: Type here
- **1754656002327**: placeholder: Rate this student reading skills from 1-5
- **1754656066306**: placeholder: Type here
- **1754656097824**: placeholder: Type here

### Mamoudou Week progress summary report

- **Firestore**: `form/EyILKY2aaGuVFpv8uYrg`
- **Questions**: 27
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754415396747` | Week | dropdown |  |
| 2 | `1754415478045` | Have you updated the student Attendance sheet for this week? | radio |  |
| 3 | `1754415829445` | If this is second and fourth week of the month, have you send and email and whatApp text to all parents who kids are absent | dropdown |  |
| 4 | `1754415687197` | Have you verify your teachers schedules and are they accurate: | text |  |
| 5 | `1754416232593` | If this is the 4th week of this month, have you sent the name of the best student of the month to Rodaa for publication? | dropdown |  |
| 6 | `1754416455885` | Did you check to know if all teachers are working with their students for the end -of- semester student class project presentation? | radio |  |
| 7 | `1754416629252` | Have you checked on your coaches and their works and challenges for this week? | radio |  |
| 8 | `1754417316736` | How many overdues tasks ( form connecteam ) do you have this week? | text |  |
| 9 | `1754417441532` | How many time you submitted the zoom hosting form this week? | text |  |
| 10 | `1754417550424` | Have you read, understood & done with overdue tasks/project assigned to you as an administrator | radio |  |
| 11 | `1754417675591` | Have you completed all the assigned tasks & projects to you which are due this week? | radio |  |
| 12 | `1754417786191` | All coaches needs to have at least 5 to 25 mins one on one meeting with at least 1 coachee per month to improve relationship are support teachers | text |  |
| 13 | `1754418293442` | Do you daily scheme through all your teachers whatsApp groupchats | dropdown |  |
| 14 | `1754418482085` | How many new ideas or innovation did you recommend to improve our platform/team for this week ? | text |  |
| 15 | `1754418597220` | How many time you submitted the end of shift report this week ? | text |  |
| 16 | `1754418724326` | How many time did you submit your Bi-weekly coachees performance review this month ? | text |  |
| 17 | `1754418891463` | List the names/titles of the forms you reviewed this week | text |  |
| 18 | `1754418983513` | How many teammates ( on the executive board ) did you support or with help with anything ? | text |  |
| 19 | `1754419277806` | How many times you review the excuse form for teachers and leaders this week ? | text |  |
| 20 | `1754419454463` | If this is fourth week of the month have you completed auditng all your teachers and their work? | dropdown |  |
| 21 | `1754419627087` | Did you help with new teacher interview this month ? | dropdown |  |
| 22 | `1754419773920` | How many students did you directly and personally recruit this week ? | text |  |
| 23 | `1754419935623` | How many time did you review the class readiness form for teachers coaching this week | text |  |
| 24 | `1754420118427` | If this is the fourthweek, have you completed the peer leadership | radio |  |
| 25 | `1754420169982` | Do you have any idea that will help our students learn while having fun or any strategy that will improve the learning pace of our students? If yes please mention it and call the attention of the administratation for implementation | long_text | yes |
| 26 | `1754420375933` | How many parents you make follow up on payment | text | yes |
| 27 | `1762602517269` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown | yes |

**Options (choice fields)**

- **1754415396747** (Week): Week1; Week2; Week3; Week4
- **1754415829445** (If this is second and fourth week of the month, have you send and email and whatApp text to all parents who kids are absent): Yes; No; N/A
- **1754416232593** (If this is the 4th week of this month, have you sent the name of the best student of the month to Rodaa for publication?): Yes; No; N/A
- **1754418293442** (Do you daily scheme through all your teachers whatsApp groupchats): Yes; No; Sometimes
- **1754419454463** (If this is fourth week of the month have you completed auditng all your teachers and their work?): Yes; No; N/A
- **1754419627087** (Did you help with new teacher interview this month ?): Yes; No; N/A
- **1762602517269** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): Yes I have approved it for all my teachers; Not yet; I am lazy employee

**Descriptions / placeholders**

- **1754415396747**: placeholder: Tap to select
- **1754415478045**: placeholder: Enter yes/no...
- **1754415829445**: placeholder: Screenshot the student absentee email and whatsApp each parent corncerned
- **1754416232593**: placeholder: If not do that right now
- **1754416455885**: placeholder: Enter yes/no...
- **1754416629252**: placeholder: Enter yes/no...
- **1754417550424**: placeholder: Enter yes/no...
- **1754417675591**: placeholder: Enter yes/no...
- **1754417786191**: placeholder: Below list the name of the teacher(s) you had this mentorship call with for this month
- **1754418293442**: placeholder: Doing this regularly helps you know what is going on & how help
- **1754418724326**: placeholder: Only answer this question once per month
- **1754418891463**: placeholder: Type 0 if you reviewed no form
- **1754418983513**: placeholder: If any, list the help you rendered 
- **1754419454463**: placeholder: Including the total hours each person work and recommending action for any violation 
- **1754419627087**: placeholder: Enter dropdown...
- **1754419773920**: placeholder: All leaders are considered ambassadors and recruiters
- **1754420118427**: placeholder: Enter yes/no...
- **1754420375933**: placeholder: Parents with outstanding payment
- **1762602517269**: placeholder: If not please do this now before submitting this form - this must be done at least once per week

### Teacher Complaints form. Khadijatu/CEO

- **Firestore**: `form/GropmW5MFfVQMD710Sw0`
- **Questions**: 4
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754477344869` | Name/Nom | text | yes |
| 2 | `1754477368560` | Complaint/Recommendation?/Réclamation/Recommandation ? | multi_select | yes |
| 3 | `1754477446247` | what is your recommendation?/Quelle est votre recommandation ? | text | yes |
| 4 | `1754477490537` | Name of the Person you are complaining about and why?/Nom de la personne contre laquelle vous vous plaignez et pourquoi ? | text |  |

**Options (choice fields)**

- **1754477368560** (Complaint/Recommendation?/Réclamation/Recommandation ?): Complaint; Recomendation

**Descriptions / placeholders**

- **1754477344869**: placeholder: Enter text input...
- **1754477368560**: placeholder: Enter multi-select...
- **1754477446247**: placeholder: Enter text input...
- **1754477490537**: placeholder: Enter text input...

### Monthly Penalty/Repercussion Record Mamoudou/CEO

- **Firestore**: `form/KbVHEqepuiEMTmtqZyfe`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754475387446` | Name of leader submitting this form | multi_select | yes |
| 2 | `1754475455754` | Who is this record about | multi_select | yes |
| 3 | `1754475667927` | Violation Type | multi_select |  |
| 4 | `1754475806194` | Type of Repercussion | multi_select |  |
| 5 | `1754475889796` | Amount cut | text |  |
| 6 | `1754475912785` | For this semester, is this person | multi_select |  |
| 7 | `1754475990192` | Briefly explained what was this person's punishment about | text |  |
| 8 | `1754476060258` | Briefly explain the violator reaction the punishment | text |  |
| 9 | `1754476095426` | Who this person coach or mentor | multi_select |  |
| 10 | `1754476164451` | Month The Month Violation Was Committed | multi_select | yes |

**Options (choice fields)**

- **1754475387446** (Name of leader submitting this form): Mamoudou; Salimatu; Abdi; Mohammed Bah; Kadijatu Jalloh
- **1754475455754** (Who is this record about): Khadijah; Mamoudou; Abdulkarim; Abrahim Bah; Ayobami; Lubna; Siyam; Elham; Bano Bah; Kairullah; Ibn Mustapha; Abdullah Balde; Korka; Amadou Oury; Asma; Nasrullah; Arabieu; Ibrahim Bah; Kaiza; Kosiah…
- **1754475667927** (Violation Type): Not Giving Assessments; Meeting lateness; Class Absence; Class Lateness; False reporting; Behavioral Violation; Task/Project incompletion; Failure to comply with student works and grade expectation; Refuse to attend meeting; Other
- **1754475806194** (Type of Repercussion): Warning letter; Pay cut; Meeting hearing; Dismissal; Coaching; Other
- **1754475912785** (For this semester, is this person): 1st Punishment; 2nd Punishment; 3rd Punishment; 4th Punishment; 5th Punishment; 6th Punishment
- **1754476095426** (Who this person coach or mentor): Chernor; Salimatu; Mohammed Bah; Kadijatu Jalloh
- **1754476164451** (Month The Month Violation Was Committed): Jan; Feb; Mar; Apr; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec

**Descriptions / placeholders**

- **1754475387446**: placeholder: Enter multi-select...
- **1754475455754**: placeholder: Enter multi-select...
- **1754475667927**: placeholder: Enter multi-select...
- **1754475806194**: placeholder: Enter multi-select...
- **1754475889796**: placeholder: Enter text input...
- **1754475912785**: placeholder: Enter multi-select...
- **1754475990192**: placeholder: Enter text input...
- **1754476060258**: placeholder: Enter text input...
- **1754476095426**: placeholder: Enter multi-select...
- **1754476164451**: placeholder: Enter multi-select...

### Student Follow up - CEO

- **Firestore**: `form/LdIvdtPcMBgIDYFxYkKy`
- **Questions**: 13
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754651507108` | Name of the teacher whose student this form is being submitted for | text | yes |
| 2 | `1754651548347` | Based on your follow up, what the person dislike about their class/platform so far? | text | yes |
| 3 | `1754652282815` | As the person who contancted this person, what do you think or learn from your conversation with the student | text | yes |
| 4 | `1754651576566` | Based on the follow up, what the person like about their class/platform so far? | text | yes |
| 5 | `1759082383326` | What Semester is this? | dropdown |  |
| 6 | `1759083998172` | Is this for a: | dropdown |  |
| 7 | `1754652211384` | How did you collect this feedback | dropdown | yes |
| 8 | `1754651287046` | Name of person/student who you are submitting this for | text |  |
| 9 | `1754651430169` | Is this person knows his/her duties and responsbilities | text | yes |
| 10 | `1754651227567` | Person Status | dropdown | yes |
| 11 | `1754651360852` | What round of submission are you having for this student per this semester | dropdown | yes |
| 12 | `1754651144820` | Name of Person Submitting this | dropdown | yes |
| 13 | `1754651401186` | List the documents this persons need to submit | text | yes |

**Options (choice fields)**

- **1759082383326** (What Semester is this?): 1st Semester; 2nd Semester
- **1759083998172** (Is this for a:): A student; A leader; A Teacher
- **1754652211384** (How did you collect this feedback): WhatsApp Call; WhatsApp text; WhatsApp Audio; Zoom Meeting
- **1754651227567** (Person Status): New; Old
- **1754651360852** (What round of submission are you having for this student per this semester): 1st Round; 2nd Round; 3rd Round; 4th Round; 5th Round; 6th
- **1754651144820** (Name of Person Submitting this): Chernor; Mamoudou; Kadijatu Jalloh; Roda Ahmed; Mohammad Bah

**Descriptions / placeholders**

- **1754651507108**: placeholder: Type here
- **1754651548347**: placeholder: Type here
- **1754652282815**: placeholder: Type here
- **1754651576566**: placeholder: Explain in details
- **1759082383326**: placeholder: Enter dropdown...
- **1759083998172**: placeholder: Select
- **1754652211384**: placeholder: Enter dropdown...
- **1754651287046**: placeholder: Type here
- **1754651430169**: placeholder: Type here
- **1754651227567**: placeholder: Like is he/she a new or old teacher, student or leader
- **1754651360852**: placeholder: Enter dropdown...
- **1754651144820**: placeholder: Tap to select
- **1754651401186**: placeholder: Type here

### Weekly Overdues Data By Mamoudou/CEO

- **Firestore**: `form/Ls6w3JEj2aj9qAQwas2D`
- **Questions**: 6
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754477318327` | Leader Name | dropdown | yes |
| 2 | `1754477409941` | Number of tasks overdues | text | yes |
| 3 | `1754477459900` | Months | dropdown |  |
| 4 | `1754477561003` | Week | dropdown |  |
| 5 | `1754477648856` | Note | text |  |
| 6 | `1754477704630` | Evidence | image_upload |  |

**Options (choice fields)**

- **1754477318327** (Leader Name): Mamoudou; Chernor; Mohammed Bah; Roda Ahmed; Salimatu; Khadijatou
- **1754477459900** (Months): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754477561003** (Week): Week1; Week2; Week3; Week4

### Task Assignments (For Leaders) - CEO

- **Firestore**: `form/MUUJOVxcUN7KHJmg07cM`
- **Questions**: 11
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754648907485` | Task creator | dropdown |  |
| 2 | `1754648975979` | Name or Title of Task | text |  |
| 3 | `1754649006671` | Is this a recurring task? | dropdown | yes |
| 4 | `1754649138032` | The Task is for | dropdown | yes |
| 5 | `1754649263260` | Assign this task to: | dropdown | yes |
| 6 | `1754649343961` | This task should be assigned to | dropdown | yes |
| 7 | `1754649775505` | Task or Project Description | text |  |
| 8 | `1765045326068` | This task/project should be assigned on connecteam by? | date | yes |
| 9 | `1765045912075` | Estimated Deadline from today | date | yes |
| 10 | `1754649716088` | Not in used - This task/project should be assigned on connecteam by? | text |  |
| 11 | `1754649609157` | Not in used) Estimated Deadline from today | dropdown |  |

**Options (choice fields)**

- **1754648907485** (Task creator): Chernor; Mohammed Bah
- **1754649006671** (Is this a recurring task?): Yes pls make it recurring; No - dont make it; You decide
- **1754649138032** (The Task is for): Marketing leader; All Teachers; Founder; Other; All leaders; CEO; Finance leader; Teacher coordinator; IT leader/team
- **1754649263260** (Assign this task to:): Alluwal Website; WhatsApp update
- **1754649343961** (This task should be assigned to): Decide; Marketing leader; All Teachers; Founder; Other; All leaders; CEO; Finance leader; Teacher coordinator; IT leader/team
- **1754649609157** (Not in used) Estimated Deadline from today): 1 day; 4 days; 1 week; 3 days; 2 weeks; 3 weeks; 4 weeks; 1 month +; 5 Days

**Descriptions / placeholders**

- **1754648907485**: placeholder: Tap to select
- **1754648975979**: placeholder: Type here
- **1754649006671**: placeholder: Tap to select
- **1754649138032**: placeholder: Tap to select
- **1754649263260**: placeholder: Tap to select
- **1754649343961**: placeholder: Tap to select
- **1754649775505**: placeholder: Type here
- **1765045326068**: placeholder: Enter date...
- **1765045912075**: placeholder: Enter date...
- **1754649716088**: placeholder: Type here
- **1754649609157**: placeholder: Tap to select

### Students Status Form- CEO

- **Firestore**: `form/OyPHoveL2sNPQcxl70HE`
- **Questions**: 40
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1755173875656` | Your name | dropdown | yes |
| 2 | `1755174213978` | Are you submitting this for | dropdown | yes |
| 3 | `1755174292489` | Department | dropdown |  |
| 4 | `1755174784818` | Class Type | dropdown | yes |
| 5 | `1755174942559` | Full Name of Student | text | yes |
| 6 | `1755175005332` | Parent Name | text | yes |
| 7 | `1755175104637` | Parent WhatsApp number | number | yes |
| 8 | `1755176417080` | Date the student started classes | text |  |
| 9 | `1755176475911` | How many days per week, the new student is taking | text | yes |
| 10 | `1755176676596` | How many hours per day the new student is taking | text | yes |
| 11 | `1755178654302` | What time does the class of this new student starts and what time does it end? | text | yes |
| 12 | `1755178872770` | If this is an existing student schedule adjustment, did his/her days/hrs per week | dropdown | yes |
| 13 | `1755179074515` | Who is the new student teacher | text | yes |
| 14 | `1755179346142` | If this is an existing student schedule adjustment, did his/her days/hrs per week | dropdown | yes |
| 15 | `1755179643141` | If this is for a current student schedule adjsutment, when the new date of adjust begins? | date |  |
| 16 | `1755179817809` | If this is for a current student schedule adjsutment, what new days and hrs per day (e.g.Monday 1 hrs class) | text |  |
| 17 | `1755180044697` | If this for a transfer student, why is this student being transfered? | text | yes |
| 18 | `1755180464820` | If this for student transfer, what is the name of the teacher this student is leaving | text |  |
| 19 | `1755182503423` | If this is for a student transfer, what is the name of the teacher this student is going to? | text |  |
| 20 | `1755182566884` | At the start of this student class pls indicate the student first starting Surah & Arabic first lesson | text |  |
| 21 | `1755191389193` | Have you added the student or their parent number to the Parents WhatsApp grouchat? If not add it before submitting this from | dropdown |  |
| 22 | `1755191442408` | Have you explained the fees breakdown to the studentDropdown | dropdown | yes |
| 23 | `1755191493960` | Have you sent the student his/her invoice for this month's fees? If not pls send it ASAP | dropdown | yes |
| 24 | `1755191553732` | If this is a new student, have you updated the parent number's decription with all relevant info: fees, total hrs, date of start, teacher name etc. | dropdown |  |
| 25 | `1755191708939` | Has the "The Admission Letter" been sent & explained to this new student parent?Dropdown | dropdown | yes |
| 26 | `1755191837550` | Have you created a schedule for this new student for his/her teacher to use to clock in during class? | dropdown | yes |
| 27 | `1755191969659` | If this is a new student, what this student Level? | dropdown |  |
| 28 | `1755192028648` | Department of student | dropdown |  |
| 29 | `1755192770073` | Student name & information added to the finance document? | dropdown |  |
| 30 | `1755192985402` | Reason for student Drop Out | text |  |
| 31 | `1755193049944` | If for drop out, has this student teacher been formally informed about this drop out | dropdown |  |
| 32 | `1755193113870` | If student reason for dropping is not known, have you contacted the students to determine the reason and if we can win them back? | dropdown |  |
| 33 | `1755193163158` | If this a for a drop out, have instructed the right teammate to delete/remove student from necessary areas on platform | dropdown | yes |
| 34 | `1757194402924` | If this is new student, have you sent the parent/student the class Zoom Link and explaimned how it works | dropdown | yes |
| 35 | `1755193492488` | Teacher Class the Student Drop Out From | text |  |
| 36 | `1757194664712` | If this is a new student, have explained and text this class final schedule to the parent/student | dropdown | yes |
| 37 | `1755193533983` | Is the student open to rejoin us one day | dropdown |  |
| 38 | `1755193584670` | Date Student Drop Out of our Program | date |  |
| 39 | `1755193616915` | Other information | text |  |
| 40 | `1757530332504` | If this is new student, have you updated "note" or description" of the parent number? | dropdown | yes |

**Options (choice fields)**

- **1755173875656** (Your name): Mohammed Bah; Chernor; Mamoudou; Intern; Kadijatu Jalloh; Salimatu; Abdi
- **1755174213978** (Are you submitting this for): New Student Enrollement; Old Student Drop Out; Student Schedule Adjustment; Student Tranfer to New Teacher
- **1755174292489** (Department): Arabic; After School Tutoring (English; Math; Physics; Chemistry etc.); Afrolingual
- **1755174784818** (Class Type): Individual Class; Group Class (Mixed Families); Family Group Class
- **1755178872770** (If this is an existing student schedule adjustment, did his/her days/hrs per week): N/A; Decrease; Increase
- **1755179346142** (If this is an existing student schedule adjustment, did his/her days/hrs per week): N/A; Decrease; Increase
- **1755191389193** (Have you added the student or their parent number to the Parents WhatsApp grouchat? If not add it before submitting this from): Yes; No; I am adding it now
- **1755191442408** (Have you explained the fees breakdown to the studentDropdown): Yes; No; N/A
- **1755191493960** (Have you sent the student his/her invoice for this month's fees? If not pls send it ASAP): Yes; No; N/A
- **1755191553732** (If this is a new student, have you updated the parent number's decription with all relevant info: fees, total hrs, date of start, teacher name etc.): Yes - already have; No - am lazy to do that
- **1755191708939** (Has the "The Admission Letter" been sent & explained to this new student parent?Dropdown): Yes - it's sent; No -but I am sending it now; No - am lazy to do that; N/A
- **1755191837550** (Have you created a schedule for this new student for his/her teacher to use to clock in during class?): Yes - I have created it; No but I assigned to someone; Well - I don't want to do either one
- **1755191969659** (If this is a new student, what this student Level?): Beginner; Intermediate; Advanced
- **1755192028648** (Department of student): Quran Studies; English; Pular; Math
- **1755192770073** (Student name & information added to the finance document?): Yes I have done it; No - I have assigned Mr. Bah & Mamoudou the task; No but I assign Mr. Bah or Mamoudou the task
- **1755193049944** (If for drop out, has this student teacher been formally informed about this drop out): Yes; No - but I just did; I will do it later
- **1755193113870** (If student reason for dropping is not known, have you contacted the students to determine the reason and if we can win them back?): Yes; No; N/A
- **1755193163158** (If this a for a drop out, have instructed the right teammate to delete/remove student from necessary areas on platform): Yes - i have remove him/her; No but i have assigned it
- **1757194402924** (If this is new student, have you sent the parent/student the class Zoom Link and explaimned how it works): Yes I have; No let me do it now; N/A
- **1757194664712** (If this is a new student, have explained and text this class final schedule to the parent/student): Yes I have; No but let me do it now; N/A
- **1755193533983** (Is the student open to rejoin us one day): Yes; No; Maybe
- **1757530332504** (If this is new student, have you updated "note" or description" of the parent number?): Yes; No i am lazy too do it; N/A

**Descriptions / placeholders**

- **1755173875656**: placeholder: Tap to select
- **1755174213978**: placeholder: Tap to select
- **1755174292489**: placeholder: Tap to select
- **1755174784818**: placeholder: Enter dropdown...
- **1755174942559**: placeholder: Type here
- **1755175005332**: placeholder: Type here
- **1755175104637**: placeholder: Type here
- **1755176417080**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755176475911**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755176676596**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755178654302**: placeholder: Give us a time range such as this: 2pm to 3pm.
- **1755178872770**: placeholder: Type to select
- **1755179074515**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755179346142**: placeholder: Tap to select
- **1755179643141**: placeholder: Tap to select.
- **1755179817809**: placeholder: Type N/A not applicable
- **1755180044697**: placeholder: be brief and precise
- **1755180464820**: placeholder: Type here
- **1755182503423**: placeholder: Type here
- **1755182566884**: placeholder: this information will allow us to eventually measure the student after 4-6 months
- **1755191389193**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755191442408**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755191493960**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755191553732**: placeholder: Pls do so now if you have not
- **1755191708939**: placeholder: If not, send it to the parent now before submitting this form.
- **1755191837550**: placeholder: If not, either do it now or assign it the right person before submitting this form.
- **1755191969659**: placeholder: Tap to select
- **1755192028648**: placeholder: Department of student
- **1755192770073**: placeholder: If not, have assigned Mr.Bah or Mamoudou to update finance doc before you submit this form
- **1755192985402**: placeholder: If you are submitting this form for a Drop Out, TYPE N/A
- **1755193049944**: placeholder: If not do that before submitting this form
- **1755193113870**: placeholder: If not please contact student first to get the info before submiting this form
- **1755193163158**: placeholder: example: schedule shift, groupchat class etc.
- **1757194402924**: placeholder: If not please send it now before submitting this form
- **1755193492488**: placeholder: Type here
- **1757194664712**: placeholder: If you must WhatsApp/text this before submitting this form
- **1755193533983**: placeholder: Tap to select
- **1755193584670**: placeholder: Type here
- **1755193616915**: placeholder: Any information you'd like to share
- **1757530332504**: placeholder: Ensure to add monthly fees, data started, teachers, class schedule e.c.t.

### Marketing Weekly Progress Summary Report

- **Firestore**: `form/Q2lb6AVdxxzeBBgvJIgY`
- **Questions**: 23
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754420784391` | What is your Name: | text |  |
| 2 | `1754420795708` | This week i feel | dropdown | yes |
| 3 | `1754420830580` | Date | date |  |
| 4 | `1754420858912` | Last week i was late for zoom hosting | dropdown | yes |
| 5 | `1754420898444` | Last week i was absence for zoom hosting | dropdown | yes |
| 6 | `1754420940618` | Last week i missed submitting my end of shit | dropdown | yes |
| 7 | `1754420961705` | How many Posts you did this week? | number | yes |
| 8 | `1754420976840` | Achievement | long_text | yes |
| 9 | `1754420990377` | Challenges | long_text | yes |
| 10 | `1754421007390` | Are your teacher schedules up to date - meaning their classes time, days are all correct? | dropdown | yes |
| 11 | `1754421038728` | If this is the fourth week of the month, have completed auditing all your teachers work & sent in the outcome to each teacher? | radio | yes |
| 12 | `1754421070183` | List how many task did you identify and assign to team members including teachers for this week ? | number | yes |
| 13 | `1754421089461` | List the names/titles of the forms you reviewed this week | long_text |  |
| 14 | `1754421102825` | How many flyers made this week | number | yes |
| 15 | `1754421119537` | How many video edited this week | number | yes |
| 16 | `1754421137310` | This week i worked on or updated info/content on: | multi_select | yes |
| 17 | `1754421194649` | How many time you submitted the Zoom Hosting Form this week? | number | yes |
| 18 | `1754421195861` | How many students did you directly and personally recruit this week? | number | yes |
| 19 | `1754421226081` | How many time you submitted the End of Shift Form this week? | number | yes |
| 20 | `1754421253332` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | long_text | yes |
| 21 | `1754421278858` | As a leader, how much do you feel that you are in control of teachers, projects, students and personal tasks this week? | number | yes |
| 22 | `1764197338442` | List the name of all your teachers whose clock in you have approve for this week | long_text |  |
| 23 | `1764197447609` | Have you approved all your teachers clock in hours for this week | dropdown |  |

**Options (choice fields)**

- **1754420795708** (This week i feel): Very productive ( achieved beyond expectation); Distracted/unproductive (no much achievement); Fairly Productive (did a little but must do better next week)
- **1754420858912** (Last week i was late for zoom hosting): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754420898444** (Last week i was absence for zoom hosting): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754420940618** (Last week i missed submitting my end of shit): 0 time; 1 time; 2 times; 3 times; >4 times
- **1754421007390** (Are your teacher schedules up to date - meaning their classes time, days are all correct?): No Problem but I didn't check; Too lazy to check this week; I checked - no problem
- **1754421137310** (This week i worked on or updated info/content on:): The Newsletter; Facebook/IG; Tiktok/Youtube; Website

**Descriptions / placeholders**

- **1754420784391**: placeholder: Enter text input...
- **1754420795708**: placeholder: Enter dropdown...
- **1754420830580**: placeholder: Enter date...
- **1754420858912**: placeholder: Enter dropdown...
- **1754420898444**: placeholder: Enter dropdown...
- **1754420940618**: placeholder: Enter dropdown...
- **1754420961705**: placeholder: Enter number...
- **1754420976840**: placeholder: Enter long text...
- **1754420990377**: placeholder: Enter long text...
- **1754421007390**: placeholder: Enter dropdown...
- **1754421038728**: placeholder: Enter yes/no...
- **1754421070183**: placeholder: Enter number...
- **1754421089461**: placeholder: Enter long text...
- **1754421102825**: placeholder: Enter number...
- **1754421119537**: placeholder: Enter number...
- **1754421137310**: placeholder: Enter multi-select...
- **1754421194649**: placeholder: Enter number...
- **1754421195861**: placeholder: Enter number...
- **1754421226081**: placeholder: Enter number...
- **1754421253332**: placeholder: Enter long text...
- **1754421278858**: placeholder: Enter number...
- **1764197338442**: placeholder: You are required to approve the hours of each of your teacher for this week
- **1764197447609**: placeholder: Go approve it before submitting this week form

### Test

- **Firestore**: `form/RKbFDR3tKq4nIfI6wYSC`
- **Questions**: 1
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1768791727060` | 1768791727060 | text |  |

### Teacher & Student Coordinator - Weekly Progress Report Form

- **Firestore**: `form/Rwk10OZoeQl84lDtISQQ`
- **Questions**: 39
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754424524366` | Week | multi_select |  |
| 2 | `1754424589570` | How many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional noteHow many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional note | text | yes |
| 3 | `1754424631141` | Have you checked on all teachers and review their work this week? | radio | yes |
| 4 | `1754424674211` | If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation | multi_select |  |
| 5 | `1754424734949` | Have you read the Bulletin Board, Readiness form FactFinding form, Resignation Form for this week & reminded Leader(s) that haven't read it? | radio | yes |
| 6 | `1754424764611` | Have you completed all the assigned tasks & projects to you (as a leader) which are due this week? | radio | yes |
| 7 | `1754424792353` | How many task did you identify and assign to team members including teachers for this week ? If any list them under the Ledership Note Cell | text | yes |
| 8 | `1754424846146` | Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation? | multi_select |  |
| 9 | `1754424934508` | Have you completed all the assigned tasks & projects to you AND due this week? | multi_select |  |
| 10 | `1754424979800` | How many time you submitted the the End of Shift Report form this week? | text |  |
| 11 | `1754425153906` | If this is the fourth week of the month, have you recommended to the Team the teacher of the month? | multi_select |  |
| 12 | `1754425225457` | Have you checked to ensure all your teachers have submitted their Paycheck Update Form for this month Answer this only once per month | multi_select |  |
| 13 | `1754425283451` | How many students did you directly and personally recruit this week? All leaders are considered ambassadors and recruiters | multi_select |  |
| 14 | `1754425344476` | If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation | multi_select |  |
| 15 | `1754425426630` | As our Teacher and Curriculum Coordinator, list the name of the 2 teachers who needs support the most this week | text |  |
| 16 | `1754425451313` | How many overdue tasks (from Connecteam) do you have this week? | text | yes |
| 17 | `1754425454734` | Based on supervision of all teachers, list the names of the 3 teachers least in compliance with the curriculum for this month Do this monthly | text |  |
| 18 | `1754425516393` | How many new ideas or innovation did you reccomend to the team for this week ? If any list them under the Ledership Note Cell | radio | yes |
| 19 | `1754425545371` | How many overdue project and tasks you have this week? | text | yes |
| 20 | `1754425719151` | If this is the fourth week, have you completed the Peer Leadership Audit? | radio |  |
| 21 | `1754425756063` | Did you help with new teacher interview this month? Answer this only once per month | multi_select |  |
| 22 | `1754425816875` | How many excuses did you have this week? If any list below if it was a formal and accepted excuse or not | text |  |
| 23 | `1754425852244` | How many times did you review the Class Readiness Form for all teachers to have an ideas of what's going on? | text |  |
| 24 | `1754425887298` | List the names/titles of the forms you reviewed this week Type 0 if you reviewed no form | text |  |
| 25 | `1754425917131` | How many teammates (on the executive board) did you support or with help with anything? If any, pls list the help | text |  |
| 26 | `1754425957695` | How many times you review the "Excuse Form for teachers and leaders" this week? | text |  |
| 27 | `1754426014966` | As a coordinator of all teachers, how much do you feel that you are in control of teachers and their coaches? | text |  |
| 28 | `1754426048031` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month | text |  |
| 29 | `1754426092855` | How many time you submitted the Zoom Hosting Form this week? | text |  |
| 30 | `1754426103056` | List the names/titles of the forms you reviewed this week? | text |  |
| 31 | `1754426103842` | As team member, have much do feel supported by the leadership this week? | text |  |
| 32 | `1754426176655` | How many time you join Zoom Hosting late this week? | text |  |
| 33 | `1754426177674` | Any comment? I am adding comments here if I need to highlight anything outside the above questions and tasks. | text |  |
| 34 | `1762602801948` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown | yes |
| 35 | `1764198529010` | List the name of all teachers whose clock in and out you have reviewed and approved this week | long_text | yes |
| 36 | `1763609680704` | How many parents did you contact this week for the purpose of relationship building? | number |  |
| 37 | `1764101344557` | As of this week, how many active students do we have? | number | yes |
| 38 | `1764101446375` | How many students dropped? | number | yes |
| 39 | `1764101547943` | Why did they dropped, did you make any follow-up? | text | yes |

**Options (choice fields)**

- **1754424524366** (Week): Week 1; Week 2; Week 3; Week 4
- **1754424674211** (If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation): Yes; No; N/A
- **1754424846146** (Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation?): Yes; No; N/A
- **1754424934508** (Have you completed all the assigned tasks & projects to you AND due this week?): Yes; No
- **1754425153906** (If this is the fourth week of the month, have you recommended to the Team the teacher of the month?): Yes; No; N/A
- **1754425225457** (Have you checked to ensure all your teachers have submitted their Paycheck Update Form for this month Answer this only once per month): Yes; No
- **1754425283451** (How many students did you directly and personally recruit this week? All leaders are considered ambassadors and recruiters): 0; 1; 2; 3; 4 +
- **1754425344476** (If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation): Yes; No
- **1754425756063** (Did you help with new teacher interview this month? Answer this only once per month): Yes; No; N/A
- **1762602801948** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): Yes I have approved it for all my teachers; Not yet; I am lazy employee

**Descriptions / placeholders**

- **1754424524366**: placeholder: Enter multi-select...
- **1754424589570**: placeholder: Enter text input...
- **1754424631141**: placeholder: Enter yes/no...
- **1754424674211**: placeholder: Enter multi-select...
- **1754424734949**: placeholder: Enter yes/no...
- **1754424764611**: placeholder: Enter yes/no...
- **1754424792353**: placeholder: Enter text input...
- **1754424846146**: placeholder: Enter multi-select...
- **1754424934508**: placeholder: Enter multi-select...
- **1754424979800**: placeholder: Enter text input...
- **1754425153906**: placeholder: Enter multi-select...
- **1754425225457**: placeholder: Enter multi-select...
- **1754425283451**: placeholder: Enter multi-select...
- **1754425344476**: placeholder: Enter multi-select...
- **1754425426630**: placeholder: Enter text input...
- **1754425451313**: placeholder: Enter text input...
- **1754425454734**: placeholder: Enter text input...
- **1754425516393**: placeholder: Enter yes/no...
- **1754425545371**: placeholder: Enter text input...
- **1754425719151**: placeholder: Enter yes/no...
- **1754425756063**: placeholder: Enter multi-select...
- **1754425816875**: placeholder: Enter text input...
- **1754425852244**: placeholder: Enter text input...
- **1754425887298**: placeholder: Enter text input...
- **1754425917131**: placeholder: Enter text input...
- **1754425957695**: placeholder: Enter text input...
- **1754426014966**: placeholder: Enter text input...
- **1754426048031**: placeholder: Enter text input...
- **1754426092855**: placeholder: Enter text input...
- **1754426103056**: placeholder: Enter text input...
- **1754426103842**: placeholder: Enter text input...
- **1754426176655**: placeholder: Enter text input...
- **1754426177674**: placeholder: Enter text input...
- **1762602801948**: placeholder: If not please do this now before submitting this form - this must be done at least once per week
- **1764198529010**: placeholder: Enter their names here but go approve their hours first if that is not done yet
- **1763609680704**: placeholder: You must contact at least 7 parents/students every week to make friend, show concern and check their satisfaction - but pls submit the student follow up form every time you contact a parent.
- **1764101344557**: placeholder: Please verify, no guessing!!
- **1764101446375**: placeholder: Enter number...
- **1764101547943**: placeholder: Enter text input...

### Readiness Form / Formulaire de préparation

- **Firestore**: `form/Ur1oW7SmFsMyNniTf6jS`
- **Questions**: 24
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754407218568` | Student Work / Travail des élèves | multi_select | yes |
| 2 | `1754407509366` | Teacher's Note / Note du professeur | text |  |
| 3 | `1754406288023` | Class Day / Jour de classe | multi_select | yes |
| 4 | `1754406625835` | Punctuality / Ponctualité | multi_select | yes |
| 5 | `1754406414139` | Duration (Hrs) / Durée (h) | text | yes |
| 6 | `1754406115874` | Class Type / Type de cours | multi_select | yes |
| 7 | `1762629945642` | Teacher Name / Nom du professeur | dropdown | yes |
| 8 | `1754406487572` | Absent Students / Élèves absents | text | yes |
| 9 | `1754406914911` | Clock-Out Status / Heure de départ | multi_select |  |
| 10 | `1754406826688` | Clock-In Status / Heure d'arrivée | multi_select |  |
| 11 | `1754407016623` | Monthly Bayana / Bayana mensuel | multi_select | yes |
| 12 | `1754407184691` | Topics Taught / Sujets enseignés | text | yes |
| 13 | `1754407079872` | Off-Schedule? / Hors horaire? | radio |  |
| 14 | `1756564707506` | Class Category / Catégorie de cours | dropdown |  |
| 15 | `1754407141413` | Missed Bayana / Bayana manqué | text |  |
| 16 | `1754407417507` | Coach Support / Soutien du coach | multi_select | yes |
| 17 | `1754406512129` | Late Students / Élèves en retard | text | yes |
| 18 | `1754406729715` | Weekly Status / Statut hebdomadaire | multi_select | yes |
| 19 | `1754407297953` | Curriculum Used / Programme utilisé | multi_select | yes |
| 20 | `1764288691217` | Zoom Host / Animateur Zoom | dropdown | yes |
| 21 | `1754407111959` | Off-Schedule Reason / Raison hors horaire | text |  |
| 22 | `1754406537658` | Weekly Video Rec / Enregistrement vidéo hebdo | multi_select | yes |
| 23 | `1754405971187` | Equipment Used / Équipement utilisé | multi_select | yes |
| 24 | `1754406457284` | Present Students / Élèves présents | text | yes |

**Options (choice fields)**

- **1754407218568** (Student Work / Travail des élèves): Yes - always / Oui — toujours; Never / Jamais; Sometimes / Parfois; N/A
- **1754406288023** (Class Day / Jour de classe): Mon/Lundi; Tues/mardi; Wed/Mercredi; Thur/jeudi; Fri/vendredi; Sat/Samedi; Sun/Dimanche
- **1754406625835** (Punctuality / Ponctualité): Late/En retard; On time/À temps; Early/Tôt; N/A /N'est pas applicable
- **1754406115874** (Class Type / Type de cours): A make up for my student(s) missed class // Un rattrapage pour le(s) cours manqué(s) de mon/mes étudiant(s); Covering up this class for another teacher // Assurer ce cours pour un autre enseignant; My regular class (during regular schedule) // Mon cours habituel (pendant l'horaire normal)
- **1762629945642** (Teacher Name / Nom du professeur): Teacher 1; Ustaz 1; Elham; NasrulAllah; Abdullah Balde; Arabieu; Asma; Ibrahim Balde; Aliou Diallo; Mama; Iberahim Bah; Thiam; Abdulai Diallo; Rahmatulah; Chernor Ahmadu; Habibu; Sheriff; Korka; Saidou; Al-hassan…
- **1754406914911** (Clock-Out Status / Heure de départ): Right On Time/Juste à temps; Late - After the end of this class time/En retard - Après la fin de ce cours; Early - Before the end of class the time/Tôt - Avant la fin des cours; l'heure
- **1754406826688** (Clock-In Status / Heure d'arrivée): Right OnTime; Early; - Before the start of this class time; Late; - After the start of this Class Time
- **1754407016623** (Monthly Bayana / Bayana mensuel): Yes/Oui; No/Non; N/A/ N'est pas applicable
- **1756564707506** (Class Category / Catégorie de cours): Arabic; English; AfroLanguage
- **1754407417507** (Coach Support / Soutien du coach): Very helpful/Très utile; Less helpful/Moins utile; Not helpful/Pas utile; Very bad - pls change my coach/Très mauvais - s'il vous plaît; changez mon entraîneur; N/A I am Not sure / Je ne suis pas sûr
- **1754406729715** (Weekly Status / Statut hebdomadaire): 1 class Absence // 1 classe Absence 2 class Absences // 2 classe Absence; 0 Class Absences // 0 classe Absence; 3 Class Absences // 3 classe Absence; 4+ Class Absences // 4+ classe Absence
- **1754407297953** (Curriculum Used / Programme utilisé): I don't know // Je ne sais pas; Yes - it helpful // Oui; c’est utile; I just improvised today // J’ai juste improvisé aujourd’hui; No - i used my own content // Non – j’ai utilisé mon propre contenu
- **1764288691217** (Zoom Host / Animateur Zoom): Mamoud; Mr Bah; Kadijah; Salima; No host
- **1754406537658** (Weekly Video Rec / Enregistrement vidéo hebdo): Yes /Oui; No/Non; N/A; /N'est pas applicable
- **1754405971187** (Equipment Used / Équipement utilisé): My phone - i don't have coach consent; My phone - i've coach consent; My Tablet -  i've coach consent; My Tablet I don't have a coach consent; My computer; WhatsApp Call

**Descriptions / placeholders**

- **1754407218568**: placeholder: Enter multi-select...
- **1754407509366**: placeholder: Enter text input...
- **1754406288023**: placeholder: Enter multi-select...
- **1754406625835**: placeholder: Enter multi-select...
- **1754406414139**: placeholder: Enter text input...
- **1754406115874**: placeholder: Enter multi-select...
- **1762629945642**: placeholder: If you don't find your name select one of the 3 options. But contact your coach to add you for next time.
- **1754406487572**: placeholder: Enter text input...
- **1754406914911**: placeholder: Enter multi-select...
- **1754406826688**: placeholder: Enter multi-select...
- **1754407016623**: placeholder: Enter multi-select...
- **1754407184691**: placeholder: Enter text input...
- **1754407079872**: placeholder: Enter yes/no...
- **1756564707506**: placeholder: Enter class type
- **1754407141413**: placeholder: Enter text input...
- **1754407417507**: placeholder: Enter multi-select...
- **1754406512129**: placeholder: Enter text input...
- **1754406729715**: placeholder: Enter multi-select...
- **1754407297953**: placeholder: Enter multi-select...
- **1764288691217**: placeholder: Enter dropdown...
- **1754407111959**: placeholder: Enter text input...
- **1754406537658**: placeholder: Enter multi-select...
- **1754405971187**: placeholder: Enter multi-select...
- **1754406457284**: placeholder: Enter text input...

### CEO Weekly Progress Form

- **Firestore**: `form/WxcWfEvKoAJ6XJE19k0f`
- **Questions**: 60
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754405243207` | Month | dropdown | yes |
| 2 | `1754405345431` | Week | dropdown | yes |
| 3 | `1754405479773` | How many new students did our financier report joining us this week | number | yes |
| 4 | `1764287465735` | How many students did drop out/quited our program this week | number | yes |
| 5 | `1754405891238` | Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation? | text |  |
| 6 | `1754405993796` | List the names/titles of the forms you reviewed this week | text |  |
| 7 | `1754406042126` | As a team leader list how many task did you identify and assign to team members including teachers for this week? | text |  |
| 8 | `1754406178119` | How many overdues does each leader of your team member have for this week? | text | yes |
| 9 | `1754406275785` | How many overdue assigned tasks do you have this week? | text | yes |
| 10 | `1754406489614` | Have you reviewed your Teachers clock in & Class readiness form | radio | yes |
| 11 | `1754406544776` | List Coaches who have sent in excuses for meeting this week? | text | yes |
| 12 | `1754406853292` | If this is the fourth week of the month, have you completed reviewing then audits all teachers and their work? | dropdown | yes |
| 13 | `1754407061167` | Have you completed all the assigned tasks & projects to you AND due this week? | radio |  |
| 14 | `1754407118736` | How many time you submitted the the End of Shift Report form this week? | text |  |
| 15 | `1754407220630` | How many excuses did you have this week? | text |  |
| 16 | `1754407413333` | For your teamamtes (leaders) tasks , have you verified this week's tasks they claimed to have completed (done tasks)? | dropdown | yes |
| 17 | `1754407888209` | How many time you submitted the Zoom Hosting Form this week? | number |  |
| 18 | `1754408200192` | Did you help with new teacher interview this month? | dropdown |  |
| 19 | `1754408284136` | If this is the fourth week of the month, have you ensured that the Student of the month post is ready? | text |  |
| 20 | `1754408347614` | How many students did you directly and personally recruit this week? | text |  |
| 21 | `1754408437242` | How many times did you review the Class Readiness Form for all teachers to ascertain about what's going on this week? | text |  |
| 22 | `1754408485766` | How many teammates (on the executive board) did you support or help with anything this week? | text |  |
| 23 | `1754408544827` | Email (weekly check and reply): did check out and reply all emails for this week? Yes | dropdown |  |
| 24 | `1754408636565` | How many Parents did you call this week? | text |  |
| 25 | `1754408768571` | List new ideas you have suggested or existing idea and system you have improved this week? | text |  |
| 26 | `1754409022283` | Have you reviewed previous PTA meeting suggestions and concerns and assigned tasks to teammates provide solutions | dropdown |  |
| 27 | `1754409063401` | List of Teachers Class Absence for this week | text |  |
| 28 | `1754409470638` | If this fourht week of the month, pls mention the winner of the teacher of the month and student of the month (for this month | text | yes |
| 29 | `1754409828876` | If this is the 3rd week of the month, is the next monthly Bayana Ready? | radio | yes |
| 30 | `1754409969369` | Have you reviewed and evaluated the tasks, assignments, projects, and deadlines for all staff and leaders in your department for this month? | radio | yes |
| 31 | `1754410023333` | Have you checked in with all teachers about their students' progress/readiness for the end of semester "student class project"? | radio | yes |
| 32 | `1754410057904` | If this the 3rd week of the month, have you completed the Teacher's Monthly Audit for all your teachers? | radio | yes |
| 33 | `1754410101303` | Have you seen & reviewed all Teachers' Performance Grade for this Month | radio | yes |
| 34 | `1754410180989` | As team member, have much do feel supported by the leadership this week? | text |  |
| 35 | `1754410231666` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month? | text |  |
| 36 | `1754410322373` | Has the bi-semesterly teachers' & staff's feedback survey been ready & on course? (for this partner with Mamoudou)) | radio | yes |
| 37 | `1754410372342` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | text |  |
| 38 | `1754410414108` | Have all leaders and teachers updated their Paycheck Update Sheet for this month? Name those who did not comply this week. | radio |  |
| 39 | `1754410499465` | As the team leader, how much do you feel that you are in control of teachers, projects, students and tasks this week? | text | yes |
| 40 | `1754410563942` | If this is the fourth week, have you completed the Peer Leadership Audit? | dropdown |  |
| 41 | `1754410681968` | Have you reviewed all coaches Weekly report progress/job scheduling channel to determine if their teachers schedules are up to date? | dropdown | yes |
| 42 | `1754410812808` | Have all leaders reported their time in and time Out for hosting Zoom this month? | text |  |
| 43 | `1754410872577` | Reviewed previous weeks Leader's meetings & sent a reminder on assigned tasks & Goals? | dropdown | yes |
| 44 | `1754414044090` | Did you review all the forms submitted by your mentees and corrected the mistake they made therein? | dropdown |  |
| 45 | `1754414136280` | Have all leaders submitted all their required forms this week? | dropdown | yes |
| 46 | `1762602290765` | Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week? | dropdown | yes |
| 47 | `1764197752276` | List the name of all your teachers whose clock in and Out you have approve for this week | long_text |  |
| 48 | `1763610204679` | Who is the most productive team member this week and why? | long_text |  |
| 49 | `1763813799403` | Based of your review of the Marketing officer overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text |  |
| 50 | `1763813845489` | Based of your review of the Finance officer overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text |  |
| 51 | `1763813896780` | Based of your review of the Teaching and students coordinator overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text | yes |
| 52 | `1763813998896` | Based of your review of these Interns overall work/job including their End of Shift, Progress report, Biweekly forms among others what did you find out and corrected | long_text | yes |
| 53 | `1763814542230` | List the names and numbers of parents you contacted this week for the purpose of relationship building? | long_text | yes |
| 54 | `1764286366053` | This week I reviewed all the work and forms submitted by: | multi_select | yes |
| 55 | `1764286771598` | Based on the previous question above, pls indicate the names of all teachers and their forms and work you reviewed | long_text | yes |
| 56 | `1764289459029` | For this week did the Marketing officer post | dropdown | yes |
| 57 | `1764289722044` | If schedule for this week, were leadership, PTA and Teacher Meeting conducted | dropdown | yes |
| 58 | `1764289855579` | How is our financial standing this week | dropdown | yes |
| 59 | `1764291174356` | Select all that applies to every leaders for this week | multi_select | yes |
| 60 | `1764346748544` | For this week, I have checked & reviewed the Financier works and found that | multi_select | yes |

**Options (choice fields)**

- **1754405243207** (Month): Jan; Feb; Mar; Apr; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1754405345431** (Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1754406853292** (If this is the fourth week of the month, have you completed reviewing then audits all teachers and their work?): Yes; No - not yet; N/A
- **1754407413333** (For your teamamtes (leaders) tasks , have you verified this week's tasks they claimed to have completed (done tasks)?): No false claim there; i have reviewed it; some false claims - Some false claims; i have contacted them; I'm too lazy to check this week
- **1754408200192** (Did you help with new teacher interview this month?): Yes; No; N/A
- **1754408544827** (Email (weekly check and reply): did check out and reply all emails for this week? Yes): Yes; No; N/A
- **1754409022283** (Have you reviewed previous PTA meeting suggestions and concerns and assigned tasks to teammates provide solutions): Yes; No; N/A
- **1754410563942** (If this is the fourth week, have you completed the Peer Leadership Audit?): Yes; No; N/A
- **1754410681968** (Have you reviewed all coaches Weekly report progress/job scheduling channel to determine if their teachers schedules are up to date?): I checked-no concern; No Problem but I didn't check; Too lazy to check this week
- **1754410872577** (Reviewed previous weeks Leader's meetings & sent a reminder on assigned tasks & Goals?): Yes; No; N/A
- **1754414044090** (Did you review all the forms submitted by your mentees and corrected the mistake they made therein?): Yes; No; Review but not corrected; No mistakes; Will do later
- **1754414136280** (Have all leaders submitted all their required forms this week?): Yes all leaders; No but fact finding form reported; Oops I am too lazy for this - blame me
- **1762602290765** (Have you reviewed and approved the clock in and out (teachers hours) for all your teachers this week?): Yes I have approved it for all my teachers; Not yet; I am lazy employee
- **1764286366053** (This week I reviewed all the work and forms submitted by:): The Marketing leader and and 3 of his teachers; The Financier & 3 of her teachers; The learning Coordinator & 3 of her teachers; the CEO and 3 of his teachers
- **1764289459029** (For this week did the Marketing officer post): 0x on all platforms; 3x on all platforms; 2x on all platforms; 4x on all platforms; 1x on all platforms
- **1764289722044** (If schedule for this week, were leadership, PTA and Teacher Meeting conducted): Yes; No - i take the blame; N/A
- **1764289855579** (How is our financial standing this week): Great - no debt; Okay - just few debt; Bad - > 5 persons owing
- **1764291174356** (Select all that applies to every leaders for this week): Marketing Officer - poor performance; Marketing Officer - excellent performance; Financier - excellent performance; Financier - poor performance; Learning Coordinator -  poor performance; Learning Coodinator - excellent performance
- **1764346748544** (For this week, I have checked & reviewed the Financier works and found that): Canvas receipts well organized; Canvas receipts disorganized but I corrected them; Finance docs & tabs are well organized; Finance Docs are disorganized - but I corrected them; No unresponded whatsAppchat; WhatsApp chats about fees not responded but I course corrected

**Descriptions / placeholders**

- **1754405243207**: placeholder: Tap to select
- **1754405345431**: placeholder: Tap to select
- **1754405479773**: placeholder: Go check her Weekly Progress Report to find out
- **1764287465735**: placeholder: Verify the record before reporting here and take action to bring them back
- **1754405891238**: placeholder: Type here
- **1754405993796**: placeholder: Type here
- **1754406042126**: placeholder: Type here
- **1754406178119**: placeholder: Type it below like: Mamoudou = 5, Salima = 2
- **1754406275785**: placeholder: Go check your quick task to determine
- **1754406489614**: placeholder: Noticed any problem? Take Action Now
- **1754406544776**: placeholder: Type here/NA if need be
- **1754406853292**: placeholder: Including the total hours each person work and recommending action for any violation
- **1754407061167**: placeholder: Enter yes/no...
- **1754407118736**: placeholder: Type here
- **1754407220630**: placeholder: If any, list it below and indicate if it was a formal and accepted excuse or not
- **1754407413333**: placeholder: Pls click on "done tasks" options; quickly scheme through to identify the authenticity of their claims
- **1754407888209**: placeholder: Type here 
- **1754408200192**: placeholder: Answer this only once per month
- **1754408284136**: placeholder: If not, handle this now
- **1754408347614**: placeholder: All leaders are considered ambassadors and recruiters for our programs
- **1754408437242**: placeholder: Type here
- **1754408485766**: placeholder: Type here
- **1754408544827**: placeholder: Enter dropdown...
- **1754408636565**: placeholder: Update the outcome of these calls on the CEO Auditing Google Sheet
- **1754408768571**: placeholder: Type here
- **1754409022283**: placeholder: Enter dropdown...
- **1754409063401**: placeholder: Type here
- **1754409470638**: placeholder: Type here
- **1754409828876**: placeholder: Who's the guest? is the flyer ready? Contact the relevant team member if you don't have answer to these questions
- **1754409969369**: placeholder: Enter yes/no...
- **1754410023333**: placeholder: Enter yes/no...
- **1754410057904**: placeholder: Enter yes/no...
- **1754410101303**: placeholder: Enter yes/no...
- **1754410180989**: placeholder: Rate from 1 - 5
- **1754410231666**: placeholder: Only answer this question once per month
- **1754410322373**: placeholder: Enter yes/no...
- **1754410372342**: placeholder: Do this monthly
- **1754410414108**: placeholder: Enter yes/no...
- **1754410499465**: placeholder: Rate from 1 - 5
- **1754410563942**: placeholder: Enter dropdown...
- **1754410681968**: placeholder: Verify this each week to ensure it is all set
- **1754410812808**: placeholder: Name those who did not comply this month
- **1754410872577**: placeholder: Enter dropdown...
- **1754414044090**: placeholder: Enter dropdown...
- **1754414136280**: placeholder: If not report any non compliance to the fact finding form before proceeding to the next question
- **1762602290765**: placeholder: If not please do this now before submitting this form - this must be done at least once per week
- **1764197752276**: placeholder: You are required to approve the hours of each of your teacher for this week
- **1763610204679**: placeholder: birefly explain this because we will rely on this to recognize and award leaders
- **1763813799403**: placeholder: Briefly list the problem and feedback you offered this team member
- **1763813845489**: placeholder: Briefly list the problem and feedback you offered this team member
- **1763813896780**: placeholder: Briefly list the problem and feedback you offered this team member
- **1763813998896**: placeholder: Briefly list the problem and feedback you offered to all interns - if there is anyone, add eacher person to their feedback 
- **1763814542230**: placeholder: Just enter their names and numbers so that Chernor could verify with them if need be
- **1764286366053**: placeholder: At least deeply review the work of 2 team leaders and 3 teachers of the 2 leaders per week. Report fact findings and correct mistakes, errors and feedback immediately
- **1764286771598**: placeholder: Write their names so that we can track it for evidence work. Feel to cite any concerns u noticed
- **1764289459029**: placeholder: Double Check online
- **1764289722044**: placeholder: Enter dropdown...
- **1764289855579**: placeholder: Contact the financier to dertermine or review their work before proceeding. But ensure it is resolved by next week or students are suspended
- **1764291174356**: placeholder: Verify their work before answering and make sure fact findings is submitted
- **1764346748544**: placeholder: Select all that applies 

### Daily End of Shift form - CEO

- **Firestore**: `form/XxgGuLqV5XaqVDUE7KbY`
- **Questions**: 21
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754473430887` | Name | dropdown | yes |
| 2 | `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | yes |
| 3 | `1754473754870` | Days | dropdown | yes |
| 4 | `1754473834242` | Week | dropdown | yes |
| 5 | `1763928780219` | Copy and Paste today's shift goals you shared in the Eboard group at the beginning of this shift. | long_text | yes |
| 6 | `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement | text | yes |
| 7 | `1754474096020` | For this week I am doing my shift for the: | dropdown |  |
| 8 | `1754474204210` | What Time Are You Reporting to work/shift today | text | yes |
| 9 | `1754474278156` | What Time Are Ending the work/shift today | text | yes |
| 10 | `1754474407345` | Total Hours worked today ? | text | yes |
| 11 | `1754474569443` | Based on the total hours of work I am reporting for today's shift I | dropdown | yes |
| 12 | `1754474344242` | List All Your Challenges you experienced today | text | yes |
| 13 | `1754476043141` | For this week I missed working during my expected shift | dropdown | yes |
| 14 | `1754476189834` | This week I missed reporting submitting my end of shift | dropdown | yes |
| 15 | `1754476306952` | Enter the total number of new task you assigned to yourself during this shift | text | yes |
| 16 | `1754476452166` | Enter the total number of new task you assigned to other team members during this shift | text | yes |
| 17 | `1754476605073` | For today's shift did you innovate or improve any of our system or platform | dropdown | yes |
| 18 | `1762032619153` | Before submitting this form, i have called Chernor as my 5 mins check out call after every shift | dropdown | yes |
| 19 | `1762032275336` | For today's shift did you review the following forms and take action where necessary? | multi_select | yes |
| 20 | `1763175894707` | As of the end of this shift, how many tasks do you have as overdue that are yet to complete? | number | yes |
| 21 | `1767596925135` | Based off your total assigned tasks on the website, list the title of all the tasks you completed and closed during today shift. | long_text |  |

**Options (choice fields)**

- **1754473430887** (Name): Hassimiou; Mamoudou; Mohammed Bah; Chernor; Salimatu; Abdi; Kadijatu Jalloh
- **1754473570961** (I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team): Maybe - I am not sure; No; Yes
- **1754473754870** (Days): Monday; Tuesday; Wednesday; Thursday; Friday; Saturday; Sunday
- **1754473834242** (Week): Week1; Week2; Week3; Week4; N/A
- **1754474096020** (For this week I am doing my shift for the:): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6th time; 7th time
- **1754474569443** (Based on the total hours of work I am reporting for today's shift I): Underperformed today; Overperformed today; Need to do better; Fairly Performed
- **1754476043141** (For this week I missed working during my expected shift): 1 time; 2 times; 3times; 4 times; 0 time; >5 times
- **1754476189834** (This week I missed reporting submitting my end of shift): 1 time; 2 times; 3 times; 4 times; >5 times; 0 time
- **1754476605073** (For today's shift did you innovate or improve any of our system or platform): Yes; Today; Yes; something Last Week; Never yet
- **1762032619153** (Before submitting this form, i have called Chernor as my 5 mins check out call after every shift): Yes he answered my call; Left him 2 missed calls; I am too lazy to call him
- **1762032275336** (For today's shift did you review the following forms and take action where necessary?): None of the below; Readiness form; Fact-finding form; Excuse form; Student Application Form

**Descriptions / placeholders**

- **1763928780219**: placeholder: Past here, so that we can compare today's goals vs your eventual achievement today.
- **1754473916403**: placeholder: For example: called 3 parents - 30min, drafted IG post 20 min, Checked WhatsApp dm 10 
- **1754474407345**: placeholder: To miaximize productivity ensure total hours worked commensurate with productivity & accomplishment
- **1754474569443**: placeholder: Pls ensure the hour reported reflect your productivity - the number of task you completed
- **1754476306952**: placeholder: Please track these tasks for when chernor asks to show those them
- **1754476452166**: placeholder: Chernor will ask you proof  - so keep a record of those tasks
- **1754476605073**: placeholder: As a team it is part of your role to use your skills and experience to add value to our platform
- **1762032619153**: placeholder: This call is required, pls call Chernor now before submitting this form.
- **1762032275336**: placeholder: If not, pls go review them now before submitting this form
- **1763175894707**: placeholder: Be honest and enter the total number overdues - so check the website
- **1767596925135**: placeholder: List each task as it was titled in the task channel ex: Follw up with parent calls, Submit Status form ect... 

### Feedback for Leaders/Commentaires pour les dirigeants All Leaders

- **Firestore**: `form/YLTIvKu2HH8g43LhZu6d`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754650533303` | What is your name/Quel est ton nom? | text | yes |
| 2 | `1754650583191` | Is this feedback for a specific leader/coach/S'agit-il d'un retour d'information destiné à un leader/coach spécifique? | radio | yes |
| 3 | `1754650625849` | What is the full name of the leader/coach/Quel est le nom complet du leader/entraîneur? | text | yes |
| 4 | `1754650680761` | How can scall of 1-5 can you describe your communication with this leader/coach/Sur une échelle de 1 à 5, pouvez-vous décrire votre communication avec ce leader/coach? | text | yes |
| 5 | `1754650729312` | What concern do you have about the leader/coach/Quelle inquiétude avez-vous à propos du leader/coach?Text Input | text | yes |
| 6 | `1754650784701` | Can you suggest ways this leader/coach can improve/Pouvez-vous suggérer des façons dont ce leader/coach peut s’améliorer? | text | yes |
| 7 | `1754650835661` | What is this leader/coach been doing well/Qu’est-ce que ce leader/coach fait bien? | text |  |
| 8 | `1754650873763` | Have you talked to the leader/coach about this issue before, if yes, what did they do/say/Avez-vous déjà parlé de ce problème au leader/entraîneur, si oui, qu'a-t-il fait/dit? | text | yes |
| 9 | `1754650917483` | On a scale of 1-5 how urgent is your concern/Sur une échelle de 1 à 5, quelle est l'urgence de votre préoccupation? | text | yes |
| 10 | `1754650956897` | Any comment/Avez-vous des commentaires? | text |  |

**Descriptions / placeholders**

- **1754650533303**: placeholder: Please type you full name here/Veuillez saisir votre nom complet ici.
- **1754650583191**: placeholder: Enter yes/no...
- **1754650625849**: placeholder: Type here
- **1754650680761**: placeholder: How often does this person check on you? Do they reply to your message in time/À quelle fréquence cette personne vous surveille-t-elle ? Est-ce qu'ils répondent à votre message à temps?
- **1754650729312**: placeholder: Please describe in details the problem/concern you have with the leader/coach to/Veuillez décrire en détail le problème/préoccupation que vous avez avec le leader/coach pour
- **1754650784701**: placeholder: Please list ways that you think this leader/coach can follow to be able to fully support you/Veuillez énumérer les façons dont vous pensez que ce leader/coach peut suivre pour pouvoir vous soutenir pleinement.
- **1754650835661**: placeholder: On the positive side, can you record what this person has been doing well and needs acknowledgement for/Du côté positif, pouvez-vous noter ce que cette personne a fait de bien et pour lequel elle a besoin d’être reconnue ?
- **1754650873763**: placeholder: Type here
- **1754650917483**: placeholder: This will allow us to follow up as soon as possible and get the problem sorted/Cela nous permettra de faire un suivi dans les plus brefs délais et de régler le problème.
- **1754650956897**: placeholder: If you have any comment, positive or negative please add it here/Si vous avez un commentaire, positif ou négatif, ajoutez-le ici.

### Students Break/Vacation Form - Kadijatu

- **Firestore**: `form/ZZPhTtASIc6t7KtnZ0D2`
- **Questions**: 8
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754649950948` | Submitted By: | dropdown | yes |
| 2 | `1754650027059` | Student Name | text | yes |
| 3 | `1754650057504` | Islamic Studies,  Pular, English, Math, Physics, | dropdown | yes |
| 4 | `1754650171917` | Who is Student's Teacher | text | yes |
| 5 | `1754650232044` | Have you informed the student's teacher | text | yes |
| 6 | `1754650262494` | How long this student's break will last | text | yes |
| 7 | `1754650289877` | When is the start date of the break | text | yes |
| 8 | `1754650343324` | When is the end date of the break? | text | yes |

**Options (choice fields)**

- **1754649950948** (Submitted By:): Chernor; Mohammad Bah; Kadijatu Jalloh; Salimatu; Abdi; Mamoudou

**Descriptions / placeholders**

- **1754649950948**: placeholder: Tap to select
- **1754650027059**: placeholder: Type here
- **1754650057504**: placeholder: Tap to select
- **1754650171917**: placeholder: Type here
- **1754650232044**: placeholder: Type here
- **1754650262494**: placeholder: Type number of weeks or Month
- **1754650289877**: placeholder: Type full date
- **1754650343324**: placeholder: Type full date

### Group BAYANA Attendance - Kadijatu

- **Firestore**: `form/bQuQ6ymY4KocKUXhrQPM`
- **Questions**: 36
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754619835511` | Name of person submitting this form | dropdown | yes |
| 2 | `1754619929905` | What is the Name and WhatsApp number of this month guest speakers | text | yes |
| 3 | `1754619964623` | What is the topic of this Bayana? | text | yes |
| 4 | `1754620004349` | Month | dropdown | yes |
| 5 | `1754620091837` | List the full names of teachers who are present for this Bayana | text | yes |
| 6 | `1754620216753` | Compare to last month, has students attendance incease or deacrease this month? | dropdown |  |
| 7 | `1754620324365` | What is the total number of teachers' attendance this month | text | yes |
| 8 | `1754620495659` | Was the guest imam introduced by a student? | radio |  |
| 9 | `1754620527106` | Did Bayana start on time | radio | yes |
| 10 | `1754620555539` | In one to three sentences summarize your impression about the overall conduct of this Bayana | text |  |
| 11 | `1754620646568` | How was the last Bayana logistic? | dropdown | yes |
| 12 | `1754620720449` | Was the live launch on Facebook | radio | yes |
| 13 | `1754620762916` | Was the student Quran reciter present | radio | yes |
| 14 | `1754620895404` | ustaz korka's student | text | yes |
| 15 | `1754620922341` | Oustaz Abdullah Blade's Student | text | yes |
| 16 | `1754620948128` | Oustazah Nasrullah's students | text | yes |
| 17 | `1754621013154` | Oustaz Abdul Warith's Student Student | text | yes |
| 18 | `1754621032326` | Oustaz Abdirahman's Student | text | yes |
| 19 | `1754621067604` | Oustaz Alhassan's StudentsText Input | text | yes |
| 20 | `1754621096578` | Oustaza Asma's Students | text | yes |
| 21 | `1754621120017` | Oustaz Cham Students | text | yes |
| 22 | `1754621156839` | Oustaz Habib's Students | text | yes |
| 23 | `1754621187243` | Oustaz Hardees Students | text | yes |
| 24 | `1754621207701` | Oustaz Ibrahim Blade's Students | text | yes |
| 25 | `1754621237073` | Oustaz Ibrahim Bah's Students | text | yes |
| 26 | `1754621278129` | Oustaz Kosiah's Students | text | yes |
| 27 | `1754621321468` | Ustaz Sheriff's Students | text | yes |
| 28 | `1754621369198` | Oustaza Elham's Students | text | yes |
| 29 | `1754621415583` | Oustaz Saidou's Students | text | yes |
| 30 | `1754621482825` | Oustaz kaiza's Students | text |  |
| 31 | `1754621508602` | Oustaz Siyam's Students | text | yes |
| 32 | `1754621537883` | Oustaz Arabieu's Students | text | yes |
| 33 | `1754621552106` | Oustaz Amadou Oury's Students | text |  |
| 34 | `1754621625942` | Did you reach out to parents whose students were absent from last month Bayana to find out why? | dropdown |  |
| 35 | `1754621663460` | Did you reach out to teachers whose students were absent from last month Bayana to find out why? | dropdown |  |
| 36 | `1754621709451` | Are all teacher names added to this form? | dropdown |  |

**Options (choice fields)**

- **1754619835511** (Name of person submitting this form): Chernor; Mamoudou; Mohammed Bah; Kadijatu Jalloh; Roda Ahmed
- **1754620004349** (Month): Jan; Feb; March; April; May; June; July; Aug; Sept; Oct; Nov; Dec
- **1754620216753** (Compare to last month, has students attendance incease or deacrease this month?): Yes - increase; No - decrease; No different
- **1754620646568** (How was the last Bayana logistic?): Excellent; Ok; Got some trouble
- **1754621625942** (Did you reach out to parents whose students were absent from last month Bayana to find out why?): Yes; No; I will
- **1754621663460** (Did you reach out to teachers whose students were absent from last month Bayana to find out why?): Yes; No; I will
- **1754621709451** (Are all teacher names added to this form?): Yes; No; I need to add a few teachers

**Descriptions / placeholders**

- **1754619835511**: placeholder: Enter dropdown...
- **1754619929905**: placeholder: E.g. Chernor - 00231836253
- **1754619964623**: placeholder: Type here
- **1754620004349**: placeholder: Tap to select
- **1754620091837**: placeholder: Type here
- **1754620216753**: placeholder: Enter dropdown...
- **1754620324365**: placeholder: Enter text input...
- **1754620495659**: placeholder: Enter yes/no...
- **1754620527106**: placeholder: Enter yes/no...
- **1754620555539**: placeholder: Focus on what happened and what would you need to improve going forward
- **1754620646568**: placeholder: Enter dropdown...
- **1754620720449**: placeholder: Enter yes/no...
- **1754620762916**: placeholder: Enter yes/no...
- **1754620895404**: placeholder: Enter text input...
- **1754620922341**: placeholder: Enter text input...
- **1754620948128**: placeholder: Enter text input...
- **1754621013154**: placeholder: Enter text input...
- **1754621032326**: placeholder: Enter text input...
- **1754621067604**: placeholder: Enter text input...
- **1754621096578**: placeholder: Enter text input...
- **1754621120017**: placeholder: Enter text input...
- **1754621156839**: placeholder: Enter text input...
- **1754621187243**: placeholder: Enter text input...
- **1754621207701**: placeholder: Enter text input...
- **1754621237073**: placeholder: Enter text input...
- **1754621278129**: placeholder: Enter text input...
- **1754621321468**: placeholder: Enter text input...
- **1754621369198**: placeholder: Enter text input...
- **1754621415583**: placeholder: Enter text input...
- **1754621482825**: placeholder: Enter text input...
- **1754621508602**: placeholder: Enter text input...
- **1754621537883**: placeholder: Enter text input...
- **1754621552106**: placeholder: Enter text input...
- **1754621625942**: placeholder: Enter dropdown...
- **1754621663460**: placeholder: Enter dropdown...
- **1754621709451**: placeholder: Enter dropdown...

### All Students Database-CEO

- **Firestore**: `form/cV9SHjYFNMfsjL9hjUgH`
- **Questions**: 11
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754617126245` | Submitted By: | dropdown | yes |
| 2 | `1754617334742` | This is for a | dropdown | yes |
| 3 | `1754617394374` | Name | text | yes |
| 4 | `1754617449097` | Current Country/State/City | text | yes |
| 5 | `1754617500355` | Phone Number | number |  |
| 6 | `1754617547104` | Email | text |  |
| 7 | `1754617572722` | If a non adult student, Name of Parent | text |  |
| 8 | `1754617638915` | Teacher Name | text |  |
| 9 | `1754617666893` | If a non adult Student, Parent Email | text |  |
| 10 | `1754617681730` | If non adult student, Parent Number | text |  |
| 11 | `1754617721757` | Coach name | text |  |

**Options (choice fields)**

- **1754617126245** (Submitted By:): Chernor; Mamoudou Diallo; Mohammed Bah; Salimatu; Abdi; Kadijatu Jalloh; Intern
- **1754617334742** (This is for a): Leader; Teacher; Student

**Descriptions / placeholders**

- **1754617126245**: placeholder: Tap to select
- **1754617334742**: placeholder: Enter dropdown...
- **1754617394374**: placeholder: Type here
- **1754617449097**: placeholder: Enter text input...
- **1754617500355**: placeholder: Enter number...
- **1754617547104**: placeholder: Enter text input...
- **1754617572722**: placeholder: Enter text input...
- **1754617638915**: placeholder: Enter text input...
- **1754617666893**: placeholder: Enter text input...
- **1754617681730**: placeholder: Enter text input...
- **1754617721757**: placeholder: Enter text input...

### Excuse Form for teachers & leaders/Formulaire d'excuse des enseignants CEO/Khadijatu

- **Firestore**: `form/lo88vXRPGQb5P0qhXUIU`
- **Questions**: 16
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754399726889` | What is your name/Quel est ton nom?Please add your name as it appears in our records/Veuillez ajouter votre nom tel qu'il apparaît dans nos dossiers | text | yes |
| 2 | `1754400366403` | Who is sumitting this form? | multi_select |  |
| 3 | `1754401719744` | If you are a teacher, how many student do you have now/ Combien d’élèves avez-vous actuellement ?? Please select from the dropdown the number of students you have/Veuillez sélectionner dans la liste déroulante le nombre d'étudiants que vous avez. | multi_select |  |
| 4 | `1754402171621` | If you are an admin or an intern, type below why do you want to be excused from mention name of tasks, works or role you need this excuse for | text |  |
| 5 | `1754402244111` | If you are an admin list the title/names of your projects and tasks due during your excuse period so that the team can handle them while you are away | text |  |
| 6 | `1754402305480` | Why do you want to be excused/Pourquoi veux-tu être excusé ? This document is accessible to admins so your information is save as per your constitution and data policy/Ce document est accessible aux administrateurs afin que vos informations soient enregistrées conformément à votre constitution et à votre politique de données. | text | yes |
| 7 | `1754402396459` | How many days are you asking for/Combien de jours demandez-vous ? | text | yes |
| 8 | `1754402840684` | Which date would you like to be excused/Quand souhaiteriez-vous être excusé ? Please specify the exalt date you will be unavailable/Veuillez préciser la date d'exaltation à laquelle vous ne serez pas disponible. | date | yes |
| 9 | `1754402885007` | Which date will you be back to work/Quand seras-tu de retour? The exalt date you will be returning to work/Quelle est la date à laquelle vous retournerez au travail ? | date | yes |
| 10 | `1754402926724` | Is this part of your pay leave/Est-ce que cela fait partie de votre congé payé ? If no, please know you won't be paid for the hours you are missing/Si non, sachez que vous ne serez pas payé pour les heures manquantes. | radio | yes |
| 11 | `1754402977293` | Have you arranged with another teacher/leader to cover your class or task while you are  You can find a teacher/leader to do this or we will assign your student to a teacher for the duration of your leave, and they will be paid for the additional hours/Vous pouvez trouver un enseignant pour le faire ou nous assignerons votre élève à un enseignant pour la durée de votre congé, et celui-ci sera rémunéré pour les heures supplémentaires. | multi_select | yes |
| 12 | `1754403200671` | If you answered yes to previous question, or you have found someone to replace you or to teach your class or do your task while you are away, pls write the person's name below. Ignore this question if you have not found anyone | text |  |
| 13 | `1754403234621` | As per our Bylaws, you must be submit this excuse at least (2 days) before the main date of your excuse. So how soon are you submitting this form? Anything less than 2 days for a foreseeable excuse will be penalized | multi_select | yes |
| 14 | `1754403284826` | If this is part of your 3 days free pay-leave break for this semester is it your | multi_select | yes |
| 15 | `1754403356959` | Sure! Here’s a shoAlert: If this is not part of your 3 paid leave days, valid evidence must be uploaded for this excuse to be considered Upload any reasonable evidence - without which your excuse might not be granted | image_upload |  |
| 16 | `1754403394893` | Any comment/Avez-vous des commentaires. | text |  |

**Options (choice fields)**

- **1754400366403** (Who is sumitting this form?): A Teacher; An admin; An Intern
- **1754401719744** (If you are a teacher, how many student do you have now/ Combien d’élèves avez-vous actuellement ?? Please select from the dropdown the number of students you have/Veuillez sélectionner dans la liste déroulante le nombre d'étudiants que vous avez.): 1; 2-3; Above 5/Au-dessus de 5
- **1754402977293** (Have you arranged with another teacher/leader to cover your class or task while you are  You can find a teacher/leader to do this or we will assign your student to a teacher for the duration of your leave, and they will be paid for the additional hours/Vous pouvez trouver un enseignant pour le faire ou nous assignerons votre élève à un enseignant pour la durée de votre congé, et celui-ci sera rémunéré pour les heures supplémentaires.): Yes; No; Help me found one; No need
- **1754403234621** (As per our Bylaws, you must be submit this excuse at least (2 days) before the main date of your excuse. So how soon are you submitting this form? Anything less than 2 days for a foreseeable excuse will be penalized): 2 days earlier; Less than a day earlier; 3 - 5 Days earlier; 1 Day earlier; Days into my exuse; After my excuse
- **1754403284826** (If this is part of your 3 days free pay-leave break for this semester is it your): 1st time requesting it; 2nd time requesting it; 3rd time requesting it; I have exceed my 3 days pay-leave for the semester; count this as a non payment binding; outside of my free 3 days; I don't remember

**Descriptions / placeholders**

- **1754400366403**: placeholder: Enter multi-select...
- **1754401719744**: placeholder: Enter multi-select...
- **1754402171621**: placeholder: Enter text input...
- **1754402244111**: placeholder: Enter text input...
- **1754402305480**: placeholder: Enter text input...
- **1754402396459**: placeholder: Enter text input...
- **1754402840684**: placeholder: Enter date...
- **1754402885007**: placeholder: Enter date...
- **1754402926724**: placeholder: Yes, No
- **1754402977293**: placeholder: Enter multi-select...
- **1754403200671**: placeholder: Enter text input...
- **1754403234621**: placeholder: Enter multi-select...
- **1754403284826**: placeholder: Enter multi-select...
- **1754403356959**: placeholder: Enter image upload...
- **1754403394893**: placeholder: Enter text input...

### X Progress Summary Report

- **Firestore**: `form/pp8PEpBaoF0ujGXsW0A3`
- **Questions**: 10
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1763638075534` | Name | text | yes |
| 2 | `1763638106920` | Days | dropdown | yes |
| 3 | `1763638190823` | Weeks | multi_select | yes |
| 4 | `1763638285875` | How many times did you submit the finance update this week? | dropdown | yes |
| 5 | `1763638433884` | How often did you verify the bank account this week? | dropdown | yes |
| 6 | `1763638822522` | How many receipts were issued to parents by you this week? | text | yes |
| 7 | `1763638908346` | Did you verify your teachers schudule this week? | radio | yes |
| 8 | `1763639124381` | How many times did you submit the End-of-Shift report this week? | multi_select | yes |
| 9 | `1763639419218` | How many times did you submit the Zoom Hosting report this week? | multi_select |  |
| 10 | `1763639639755` | Note | long_text |  |

**Options (choice fields)**

- **1763638106920** (Days): Sunday; Monday; Tuesday; Wednesday; Thursday; Friday; Saturday
- **1763638190823** (Weeks): Week1; Week2; Week3; Week4
- **1763638285875** (How many times did you submit the finance update this week?): Week1; Week2; Week3; Week4
- **1763638433884** (How often did you verify the bank account this week?): 1 time; 2 time; 3 time; 4 time; 0 time; 5 time; 6 time; 7 time
- **1763639124381** (How many times did you submit the End-of-Shift report this week?): 1 Time; 2 Time; 3 Time; 4 Time; 5 Time; 0 Time; 6 time; 7 Time
- **1763639419218** (How many times did you submit the Zoom Hosting report this week?): 1 Time; 2 Time; 3 Time; 4 Time; 5 Time; 0 Time; 6 time; 7 Time

**Descriptions / placeholders**

- **1763638075534**: placeholder: Enter text input...
- **1763638106920**: placeholder: Enter dropdown...
- **1763638190823**: placeholder: Enter multi-select...
- **1763638285875**: placeholder: Enter dropdown...
- **1763638433884**: placeholder: Enter dropdown...
- **1763638822522**: placeholder: Enter text input...
- **1763638908346**: placeholder: Yes, No, N/A
- **1763639124381**: placeholder: Enter multi-select...
- **1763639419218**: placeholder: Enter multi-select...
- **1763639639755**: placeholder: Enter long text...

### Daily Zoom Hosting-CEO

- **Firestore**: `form/qzAwKYDS9gI5qp9xpwlw`
- **Questions**: 29
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754603841743` | Name | dropdown | yes |
| 2 | `1754604016904` | I hereby confirm that I will fulfill my shift responsibilities as expected and will not abuse the trust placed in me by the team. | dropdown |  |
| 3 | `1754604091069` | What Time Are You Reporting for hosting today | dropdown | yes |
| 4 | `1754605796428` | What Time Are You ending your hosting today? | dropdown |  |
| 5 | `1754605883192` | Month | dropdown | yes |
| 6 | `1754606072045` | Day | dropdown | yes |
| 7 | `1754606157168` | Week | dropdown | yes |
| 8 | `1754606316925` | In this week I am doing my hosting for the: | dropdown | yes |
| 9 | `1754606467464` | How was your internet today | dropdown | yes |
| 10 | `1754606575657` | List the help you offered or what you did/achieving during your zoom hosting today | text | yes |
| 11 | `1754606616554` | List Challenges you experienced today | text |  |
| 12 | `1754606712915` | Who preceded you or are you taking this zoom hosting over from today? | dropdown | yes |
| 13 | `1754606909119` | Did the person succeeding you or taking the hosting capacity from you join | dropdown |  |
| 14 | `1754607293454` | Who is succeeding you or hosting zoom after your "hosting" time is over | dropdown | yes |
| 15 | `1754608066662` | Type the names and times of all teachers who are scheduled to teach during your time of hosting zoom today based on our schedule (ex: Ibrahim 2pm) | text | yes |
| 16 | `1754608100383` | Of the list of teacher names you typed in the previous question, type the name of the teachers who are absent for class today (include the names their students before each teacher name (ex: Teacher Barry for Stu Mariam) | text | yes |
| 17 | `1754608243308` | Type the name of the teachers that join class late today - indicate how many minute late they are | text | yes |
| 18 | `1754608315381` | If any teacher was late or absent during hosting time, have you WhatsApps/texted them about it? | dropdown |  |
| 19 | `1754608452314` | If you reported any teacher late or absent, have you varified the "Excuse Form" to determine if they did not file a formal excuse for today' class | dropdown |  |
| 20 | `1754608646031` | What is the date of absence or lateness | date |  |
| 21 | `1754608692379` | Teacher name and time of absence or lateness | text |  |
| 22 | `1754608813395` | Did you join zoom hosting today | dropdown | yes |
| 23 | `1754609203577` | How many time did you move to different zoom rooms to observe how teachers are teaching? | dropdown |  |
| 24 | `1754609312656` | List the name of student, student teacher and title of content (such as surah or hadith) you tested to determine if students are truly learning during this shift | text |  |
| 25 | `1754609361758` | Teachers' Internet Stability if this is not for In and Out Zoom Hosting, type N/A | dropdown |  |
| 26 | `1759079619544` | Did you check the "All in One Sheet" (on google drive) to dertermine how many new students to expect today? | dropdown | yes |
| 27 | `1759079396494` | How many NEW students did you have while hosting today? | long_text | yes |
| 28 | `1754609444030` | Shout Out any leaders/teachers that help you with anything today | text |  |
| 29 | `1754609480949` | Leave a commentText Input | text |  |

**Options (choice fields)**

- **1754603841743** (Name): Mohammed Bah; Salimatu; Abdi; Kadijatu Jalloh; Mamoudou Diallo; Intern; Amadou Oury
- **1754604016904** (I hereby confirm that I will fulfill my shift responsibilities as expected and will not abuse the trust placed in me by the team.): Maybe - i am not sure; No; Yes
- **1754604091069** (What Time Are You Reporting for hosting today): 10:00am; 10:30am; 11:00am; 11:30am; 12:00 AM; 12:15 AM; 12:30 AM; 12:45 AM; 1:00 AM; 1:15 AM; 1:30 AM; 1:45 AM; 2:00 AM; 2:15 AM; 2:30 AM; 2:45 AM; 3:00 AM; 3:15 AM; 3:30 AM; 3:45 AM…
- **1754605796428** (What Time Are You ending your hosting today?): 12:00 AM; 12:15 AM; 12:30 AM; 12:45 AM; 1:00 AM; 1:15 AM; 1:30 AM; 1:45 AM; 2:00 AM; 2:15 AM; 2:30 AM; 2:45 AM; 3:00 AM; 3:15 AM; 3:30 AM; 3:45 AM; 4:00 AM; 4:15 AM; 4:30 AM; 4:45 AM…
- **1754605883192** (Month): Jan; Feb; Mar; Apr; May; Jun; Jul; Aug; Sept; Oct; Nov; Dec
- **1754606072045** (Day): Sun; Mon; Tues; Wed; Thurs; Fri; Sat
- **1754606157168** (Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1754606316925** (In this week I am doing my hosting for the:): 1st; 2nd; 3rd; 4th; 5th; 6th; 7th
- **1754606467464** (How was your internet today): Stable; Unstable; Drop only twice
- **1754606712915** (Who preceded you or are you taking this zoom hosting over from today?): Mohammed Bah; Salimatu; Abdi; Kadijatu Jalloh; Mamoudou Diallo; Intern; N/A
- **1754606909119** (Did the person succeeding you or taking the hosting capacity from you join): Late (<10 mins); Very Late (>10 mins); On time; Early; N/A; Did not show up
- **1754607293454** (Who is succeeding you or hosting zoom after your "hosting" time is over): Mohammed Bah; Salimatu; Abdi; Kadijatu Jalloh; Mamoudou Diallo; Intern; N/A; I am the last person hosting
- **1754608315381** (If any teacher was late or absent during hosting time, have you WhatsApps/texted them about it?): I am too lazy to do that; Yes; i texted them about their absence or lateness; No i haven't texted about their absence or lateness; I am texting them now
- **1754608452314** (If you reported any teacher late or absent, have you varified the "Excuse Form" to determine if they did not file a formal excuse for today' class): I am too lazy to check; There is no Excuse Form - I double-checked; There is an Excuse Form - i double-checked
- **1754608813395** (Did you join zoom hosting today): Very late; Late; On time; Early; N/A
- **1754609203577** (How many time did you move to different zoom rooms to observe how teachers are teaching?): 0; 1; 2; 3-5; 5 +; N/A
- **1754609361758** (Teachers' Internet Stability if this is not for In and Out Zoom Hosting, type N/A): Stable; Unstable; Dropped more than twice; N/A
- **1759079619544** (Did you check the "All in One Sheet" (on google drive) to dertermine how many new students to expect today?): No; Yes; Will do it later - I am too lazy rn

**Descriptions / placeholders**

- **1754603841743**: placeholder: Tap to selcet
- **1754604016904**: placeholder: Enter dropdown...
- **1754604091069**: placeholder: Select time
- **1754605796428**: placeholder: Select time
- **1754605883192**: placeholder: Tap to Select
- **1754606072045**: placeholder: Tap to Select
- **1754606316925**: placeholder: Enter dropdown...
- **1754606467464**: placeholder: Enter dropdown...
- **1754606575657**: placeholder: Type here
- **1754606616554**: placeholder: Enter text input...
- **1754606712915**: placeholder: N/A if not needed
- **1754606909119**: placeholder: If this is not for zoom hosting, type N/A
- **1754607293454**: placeholder: Enter dropdown...
- **1754608066662**: placeholder: If this is not for ZOOM hosting type N/A // (ex: Ibrahim 2pm - 3pm)
- **1754608100383**: placeholder: Type N/A if this is not for zoom hosting
- **1754608243308**: placeholder: Also inbox them a WhatsApp text about the lateness so that they wont deny it
- **1754608315381**: placeholder: You must text them now for us to use it as an evident should the teacher deny it
- **1754608452314**: placeholder: Pls don't be lazy to check, it might be considered false reporting if you don't double check.
- **1754608646031**: placeholder: Enter date...
- **1754608692379**: placeholder: Enter text input...
- **1754608813395**: placeholder: Enter dropdown...
- **1754609203577**: placeholder: If this is not for zoom hosting, Type N/A
- **1754609312656**: placeholder: You are expect to randomly test at least 2 students per month by randomly asking them to read/lecture any past lessons with their teachers
- **1754609361758**: placeholder: Enter dropdown...
- **1759079619544**: placeholder: If not go there now and review it so that you are prepare to support each new student before they join
- **1759079396494**: placeholder: Carefully list the new student names and their teachers names 
- **1754609444030**: placeholder: If anyone supported you today with anything drop their name down with an appreciation note.
- **1754609480949**: placeholder: Type here

### Absences: meetings, classes and events Kadijatu

- **Firestore**: `form/sbh7pLCQnnreGIzKiuik`
- **Questions**: 15
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754428397328` | Name of person submitting this | text |  |
| 2 | `1754428437290` | Reason for submitting | multi_select | yes |
| 3 | `1754428767231` | Date of Absence | text |  |
| 4 | `1754428770767` | Date of Lateness | text |  |
| 5 | `1762614371423` | Week | multi_select |  |
| 6 | `1754428826191` | If this is for student(s) what is his/her name Type N/A if not applicable | text |  |
| 7 | `1754428878221` | If this is for student(s) what is his/her teacher's name? | text |  |
| 8 | `1754428921209` | If this is for a student, how many times in this month is she/he being marked for the same reason | multi_select |  |
| 9 | `1754429064606` | If this is for a student, has her/his parent been responsive with previous updates (text & audio)message about the problem | multi_select |  |
| 10 | `1754429531965` | Name of teacher or leader being reported if you are reporting a student absence (if not type N/A) | text |  |
| 11 | `1754429678423` | If this is for a teacher or leader, have you sent a brief WhatsApp text notifying this person about this lateness or absence? If not pls pause this form and quickly whatsApp him/her for the sake of evidence to prevent them from denying it at the end of the month. | multi_select |  |
| 12 | `1754429834347` | Name of student(s) for whose class this teacher/leader was absent or late Just list the student name (s) | text |  |
| 13 | `1754429889309` | Have you notified him or her (or their Parents) about their absence, lateness to prevent future denial If not, pls send in the notification now thru a WhatsApp text | multi_select |  |
| 14 | `1754429986332` | If a reason for absence or lateness was given, type it here | text |  |
| 15 | `1754430013333` | If this teacher sent in a formal excuse, who replaced him/her for class mention the name of the person, otherwise explain why is this class cancelled | text |  |

**Options (choice fields)**

- **1754428437290** (Reason for submitting): Leader Meeting ABSENCE; Leader Meeting LATENESS; Leader Bayana ABSENCE; Zoom Hosting LATENESS- Leader; Zoom Hosting ABSENCE - Leader; Student Class ABSENCE; Student Class LATENESS; Student Bayana ABSENCE; Teacher Class ABSENCE; Teacher Class LATENESS; Teacher Meeting ABSENCE; Teacher meeting LATENESS; Teacher Bayana Absence
- **1762614371423** (Week): Week 1; Week 2; Week 3; Week 4; Week 5
- **1754428921209** (If this is for a student, how many times in this month is she/he being marked for the same reason): 1st time; 2nd time; 3rd time; 4th time; 5th time; 6 times; N/A
- **1754429064606** (If this is for a student, has her/his parent been responsive with previous updates (text & audio)message about the problem): Yes-parents are responsive; Yes- parent respond but take no action; No-parents never respond; Sometimes parents respond; N/A
- **1754429678423** (If this is for a teacher or leader, have you sent a brief WhatsApp text notifying this person about this lateness or absence? If not pls pause this form and quickly whatsApp him/her for the sake of evidence to prevent them from denying it at the end of the month.): Yes; No; I just did WhatsApp them; I will WhatsApp them later
- **1754429889309** (Have you notified him or her (or their Parents) about their absence, lateness to prevent future denial If not, pls send in the notification now thru a WhatsApp text): Yes; No; N/A

**Descriptions / placeholders**

- **1754428397328**: placeholder: Enter text input...
- **1754428437290**: placeholder: Enter multi-select...
- **1754428767231**: placeholder: Enter text input...
- **1754428770767**: placeholder: Enter text input...
- **1762614371423**: placeholder: Enter multi-select...
- **1754428826191**: placeholder: Enter text input...
- **1754428878221**: placeholder: Enter text input...
- **1754428921209**: placeholder: Enter multi-select...
- **1754429064606**: placeholder: Enter multi-select...
- **1754429531965**: placeholder: Enter text input...
- **1754429678423**: placeholder: Enter multi-select...
- **1754429834347**: placeholder: Enter text input...
- **1754429889309**: placeholder: Enter multi-select...
- **1754429986332**: placeholder: Enter text input...
- **1754430013333**: placeholder: Enter text input...

### Students Assessment/Grade Form/ Formulaire d’évaluation/de note des étudiants. Khadijatu/CEO

- **Firestore**: `form/wxaLkeDOhZXyVqlT8UBI`
- **Questions**: 15
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754431793304` | Teacher Name | multi_select | yes |
| 2 | `1754432094698` | Who is your coach | multi_select | yes |
| 3 | `1762604477665` | The total number of students i have from all my classes is | dropdown | yes |
| 4 | `1754432189399` | Type of assessment here you choose what you are grading either assignment or quiz | multi_select | yes |
| 5 | `1754432320167` | Your Department/Votre département ?? | multi_select | yes |
| 6 | `1754432415051` | Name of the Student you are grading/ Nom de l'étudiant. Please write here the full name of the student you grading/Veuillez écrire ici le nom complet de l'étudiant que vous notez. | text | yes |
| 7 | `1754432569137` | Assessment Subject/Sujet d'évaluation. Please select the subject from the below dropdown/Veuillez sélectionner le sujet dans le menu déroulant ci-dessous. | multi_select |  |
| 8 | `1754433370240` | Date you assigned this assessment to your student(s)? | text |  |
| 9 | `1754433402081` | Student Class Type/Type de classe d'étudiant? | multi_select | yes |
| 10 | `1754433471936` | Date your students completed this assessment? | text | yes |
| 11 | `1754433518766` | What did the student score/Quel a été le score de l'élève? // Type N/A if the student failed to submit work Please add the full grade, For example: Assignment 9/10/ Veuillez ajouter la note complète, par exemple : Devoir 9/10. | text | yes |
| 12 | `1754433556573` | Can you upload a photo/screenshot of the assessment/Pouvez-vous télécharger une photo/capture d'écran de l'évaluation? If this is an assignment please add the image here if you can/S'il s'agit d'une Devoirs, veuillez ajouter l'image ici si vous le pouvez. | image_upload |  |
| 13 | `1754433594818` | Are you satisfied with this student based on this assessment/Êtes-vous satisfait de cet étudiant sur cette évaluation? From 1 ( Being least satisfied to 5 ( Being more Satisfied), please rate this student/De 1 (Être le moins satisfait à 5 (Être plus satisfait), veuillez noter cet élève. | text | yes |
| 14 | `1754433683593` | Why did you give the student the above rating/Pourquoi avez-vous attribué à l'étudiant la note ci-dessus ? Please explain briefly why you gave the student this rating/ Veuillez expliquer brièvement pourquoi vous avez attribué cette note à l'étudiant. | text | yes |
| 15 | `1754433726138` | Any comment/Avez-vous des commentaires? Please add anything you woud like your coach/ the admin to know/Veuillez ajouter tout ce que vous aimeriez que votre coach/l'administrateur sache. | text |  |

**Options (choice fields)**

- **1754431793304** (Teacher Name): brahim Balde; Al-Hassan; Thiam; Abdullah; Rahmatoulaye; Kosiah; Nasrllah; Elham; Siyam; Khadijah; Abdourahmane Bano; Iberahim Bah; Sheriff; Abdulai Diallo; Abdoullahi Yaya; AbdulKarim; Habibu Barry; Arabieu; Abdulwarith; Mamadou…
- **1754432094698** (Who is your coach): Chernor; Mamoudou; Mohammed; I don't know my coach; Harirata Bah; Salimatou; Kadijatu Jalloh
- **1762604477665** (The total number of students i have from all my classes is): 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16; 17; 18; 19; 20…
- **1754432189399** (Type of assessment here you choose what you are grading either assignment or quiz): Assignment; Quiz; Midterm; Final Exam; Project; Class Work
- **1754432320167** (Your Department/Votre département ??): Arabic; English; Pular
- **1754432569137** (Assessment Subject/Sujet d'évaluation. Please select the subject from the below dropdown/Veuillez sélectionner le sujet dans le menu déroulant ci-dessous.): Arabic/ Arabe; Al-Quran/ Le Coran; Hadith; Tafsir; Tawhid; Fiqw; Poular; English Learning; Math; Science; Social Studies; Reading; Speaking/writing; Class work; Quiz; Other
- **1754433402081** (Student Class Type/Type de classe d'étudiant?): One On One; Class Group Class

**Descriptions / placeholders**

- **1754431793304**: placeholder: Enter multi-select...
- **1754432094698**: placeholder: Enter multi-select...
- **1762604477665**: placeholder: Choose the number that represents all your active students for this month. Ensure each person grade in all subjects is update here.
- **1754432189399**: placeholder: Enter multi-select...
- **1754432320167**: placeholder: Enter multi-select...
- **1754432415051**: placeholder: Enter text input...
- **1754432569137**: placeholder: Enter multi-select...
- **1754433370240**: placeholder: Enter text input...
- **1754433402081**: placeholder: Enter multi-select...
- **1754433471936**: placeholder: Enter text input...
- **1754433518766**: placeholder: Enter text input...
- **1754433556573**: placeholder: Enter image upload...
- **1754433594818**: placeholder: Enter text input...
- **1754433683593**: placeholder: Enter text input...
- **1754433726138**: placeholder: Enter text input...

### Payment Request/Advance CEO

- **Firestore**: `form/yembcgXXaQoEQSTbDPHR`
- **Questions**: 11
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754612176642` | Your Name | text | yes |
| 2 | `1754612226604` | Who are you requesting this for? | text | yes |
| 3 | `1754612363426` | Over the past 6 months, this is my | dropdown | yes |
| 4 | `1754612493990` | What is this submission for ? | dropdown | yes |
| 5 | `1754612573403` | Why this request | text | yes |
| 6 | `1754612617191` | How giving you this creadit benefit/support the work you do with us and our institution ? | text | yes |
| 7 | `1754612720342` | Where would you want the payment of this prepayment to come from | dropdown | yes |
| 8 | `1754612938747` | How much do you need? | text | yes |
| 9 | `1754613040481` | When do you need this request | date | yes |
| 10 | `1754613101609` | I acknowledge that the transfer fees associated with this requests will be from this amount | dropdown | yes |
| 11 | `1754614840185` | You must commit to remind Chernor about it including ensuring you paiy it back on time | dropdown | yes |

**Options (choice fields)**

- **1754612363426** (Over the past 6 months, this is my): 1st time requesting advance payment; 2nd time requesting advance payment; 3rd time requesting advance payment; 4th time requesting advance payment; N/A
- **1754612493990** (What is this submission for ?): Salary PrePayment; Salary Save Keeping; Payment Update
- **1754612720342** (Where would you want the payment of this prepayment to come from): This month Salary; I refund it myself; Next Month Salary
- **1754613101609** (I acknowledge that the transfer fees associated with this requests will be from this amount): N/A; Yes
- **1754614840185** (You must commit to remind Chernor about it including ensuring you paiy it back on time): I will remind Chernor and ensure he subtract it from my next pay; I won't commit to paying this; Chernor must remember to pressure me

**Descriptions / placeholders**

- **1754612176642**: placeholder: Type here
- **1754612226604**: placeholder: Type here
- **1754612363426**: placeholder: 3 requests is the maximum acceptable request per 6 months
- **1754612493990**: placeholder: Enter dropdown...
- **1754612573403**: placeholder: Type here
- **1754612617191**: placeholder: briefly explain
- **1754612720342**: placeholder: Enter dropdown...
- **1754612938747**: placeholder: Type here
- **1754613040481**: placeholder: Select Date
- **1754613101609**: placeholder: Enter dropdown...
- **1754614840185**: placeholder: Enter dropdown...

### Resignation Form/Formulaire de demission

- **Firestore**: `form/zwUzEVaYxJX7aRhAIxlf`
- **Questions**: 7
- **Full raw definition**: see JSON `completeDocument` for this form (all builder fields, nested options, etc.).

| # | fieldId | label | type | required |
|---|---------|-------|------|----------|
| 1 | `1754610908280` | Name in Full/Nom complet | text | yes |
| 2 | `1754610949591` | Can you tell us breifly the reason you are resigning/Pouvez-vous nous expliquer brièvement la raison pour laquelle vous démissionnez? | text | yes |
| 3 | `1754611076612` | Resigning date [the date you're filling this form]/Date de démission [la date à laquelle vous remplissez ce formulaire] | date | yes |
| 4 | `1754611239500` | The date you will be resigning { i.e a week after filling this form}/La date à laquelle vous démissionnerez { soit une semaine après avoir rempli ce formulaire} | date | yes |
| 5 | `1754611312550` | What feedback do you have for us as an institution/Quels retours avez-vous pour nous en tant qu'institution? | text | yes |
| 6 | `1754611439235` | Will you be intrested in returning to us in the future/Serez-vous intéressé à revenir vers nous à l'avenir?Text Input | text | yes |
| 7 | `1754611579116` | kindly upload your Resign Letter here/veuillez télécharger votre lettre de démission ici | image_upload | yes |

**Descriptions / placeholders**

- **1754610908280**: placeholder: Type here
- **1754610949591**: placeholder: Type here
- **1754611076612**: placeholder: Select Date
- **1754611239500**: placeholder: Select Date
- **1754611312550**: placeholder: Type here
- **1754611439235**: placeholder: Type here
- **1754611579116**: placeholder: Enter image upload...

## Response samples (by template / form)

### form:Ur1oW7SmFsMyNniTf6jS (2252 docs)

- sample `00g30g1LFCdSDpPza1MT`: 24 keys
- sample `02geYzseQrwGe7EEh9Ui`: 24 keys

### template:daily_class_report (380 docs)

- sample `0DoeB74yYj8PXS7u5tHn`: 5 keys
- sample `0LvvapcWKvrzkifchQOa`: 5 keys

### form:wxaLkeDOhZXyVqlT8UBI (363 docs)

- sample `0Lwr75ccNT3oWtXQuMyd`: 14 keys
- sample `0Rw3lWWjtoFJBp4uX3ES`: 14 keys

### form:XxgGuLqV5XaqVDUE7KbY (242 docs)

- sample `00d8CAM54gRBlRNaRgyA`: 19 keys
- sample `12x2YBdnRReB8Citpm3r`: 19 keys

### form:A6syiQXSIlRnftoFfud9 (130 docs)

- sample `09nFNKc37u8jjsmKPa5I`: 33 keys
- sample `0FRJTQgsQe1rWU1jRdo8`: 33 keys

### form:qzAwKYDS9gI5qp9xpwlw (118 docs)

- sample `03DEH2ImIhKdzudODMt1`: 28 keys
- sample `0jm8puhTD2IMIUzBbVpU`: 29 keys

### form:sbh7pLCQnnreGIzKiuik (85 docs)

- sample `0EEqdkxx6b5Smsvtz5cK`: 14 keys
- sample `0IFSrfvGumngAoIDgaPA`: 14 keys

### form:6HO5uWfYM4bTPl1LvJee (56 docs)

- sample `083yriTbESg9xOWEM7d2`: 13 keys
- sample `1e2297PACzAJW86miEN9`: 13 keys

### form:lo88vXRPGQb5P0qhXUIU (44 docs)

- sample `0es521YBc0EsPvdc3TZV`: 16 keys
- sample `1FHpqbPD5UijxA4KIFMm`: 16 keys

### form:OyPHoveL2sNPQcxl70HE (40 docs)

- sample `09hGpDwzE0bJcyE1rQFT`: 40 keys
- sample `1UsNESDizb1KTwqzpjnA`: 39 keys

### form:MUUJOVxcUN7KHJmg07cM (39 docs)

- sample `1cyJTWaREoTPy0ZR05pG`: 9 keys
- sample `3QptbPPDL0EJBDH71Ih2`: 11 keys

### form:KbVHEqepuiEMTmtqZyfe (38 docs)

- sample `59PaZH6OCHHe4fOvVdMe`: 10 keys
- sample `59ka75i7of8n3Zsw0V0R`: 10 keys

### form:cV9SHjYFNMfsjL9hjUgH (36 docs)

- sample `05ulFfoAg92vER93hdHn`: 11 keys
- sample `0qL1TC9b7NylN4SenU4n`: 11 keys

### template:4G0oKBSTA8l0780cQ2Vx (23 docs)

- sample `1kxGITe6EXoD6QFKckaM`: 21 keys
- sample `34d0DXL1DeMontTGArcq`: 21 keys

### form:Ls6w3JEj2aj9qAQwas2D (21 docs)

- sample `5FZa6Mb5yraR9XpWjk4j`: 6 keys
- sample `6nVAKZncDMgIgC3zJve1`: 6 keys

### form:Rwk10OZoeQl84lDtISQQ (20 docs)

- sample `4KRd76ghuvRrbo5Wf8PW`: 39 keys
- sample `5WF92e51je5WPL2Pm3eY`: 33 keys

### form:LdIvdtPcMBgIDYFxYkKy (13 docs)

- sample `7aThKq6JbFeBLsSSaa9e`: 13 keys
- sample `9luVexa9QJ5dBHLopoCl`: 13 keys

### form:7CLjMIOY0XiAxGj7wlGh (11 docs)

- sample `5gSsEimmB0oGStvbaoMl`: 28 keys
- sample `6OpHBFuwfV0bh6BE5bxY`: 16 keys

### template:student_assessment (10 docs)

- sample `38VW3ga10FbF9nPe7kgm`: 10 keys
- sample `74QyS5oZlzXkU0pMcXmI`: 10 keys

### form:EyILKY2aaGuVFpv8uYrg (10 docs)

- sample `ApPf62WaMJDarhEhITdv`: 26 keys
- sample `Eq1xgH3tqrRVoyxjyF2a`: 26 keys

### template:m7zKkQCcqKtbQZ0OCWpi (9 docs)

- sample `06MRfdwP1uZrUXrG3dnd`: 29 keys
- sample `0huP8niWDs3VvG0A08sC`: 29 keys

### template:6YBwJQoLQ5tNU3RjDp7f (7 docs)

- sample `50BHF1eyQLrGqM9Nw9H9`: 16 keys
- sample `CQV376tNcrzJ9vRXcCB8`: 16 keys

### form:WxcWfEvKoAJ6XJE19k0f (6 docs)

- sample `0MKjJj8FUXluiZ6SF7YM`: 48 keys
- sample `FfcNRgfPnMsYzChkH1pw`: 48 keys

### template:b8wEkVRhdI5TxkA7Tep9 (6 docs)

- sample `2CduD2NEOY1JiKASEMJV`: 40 keys
- sample `I155T6Nj9fTxl4swK6EU`: 40 keys

### form:E7tiXonhFedTg9UsUqMa (5 docs)

- sample `2mhuM6UPStY5PwxJeRtL`: 7 keys
- sample `5BoCRRhzMZCWQWboJtJU`: 7 keys

### form:Bj7ybPsgB2muH2Yq6Y2y (5 docs)

- sample `7sCPvKiluIYdXjVCNkXg`: 9 keys
- sample `Kt4k8vv2zHRODBPvHCNz`: 9 keys

### template:Sn0TEj7lFN1hJnLlfMBx (4 docs)

- sample `2qqQDHhavrFzThwcwsqd`: 15 keys
- sample `8m9E7H02qJzBnGmS9v7x`: 15 keys

### template:uckNLuKLeejUyMP0B72N (4 docs)

- sample `4wvUXlw4uix5j0baK8hQ`: 15 keys
- sample `GWaNnMdY04rg426LzYTz`: 15 keys

### form:Q2lb6AVdxxzeBBgvJIgY (4 docs)

- sample `PCA9xc1l30mgAvDAA2iM`: 21 keys
- sample `YE60NjYGYZERPoU1cRQH`: 21 keys

### template:5aXUrmtZnRGC5lj0bx7a (3 docs)

- sample `4cP4k5dhuWopuwX19AHS`: 13 keys
- sample `aUlyGXXl4ArpbYPQas9J`: 13 keys

### template:VY5ChCJTREWXhJAmSqtX (3 docs)

- sample `8ssO19hUMtJSMJMfdmKV`: 6 keys
- sample `YyVIAdvxS0exZxi9Evem`: 6 keys

### template:weekly_summary (3 docs)

- sample `F4auRdVBQrxB2fxLu9ri`: 7 keys
- sample `QKyhYDWEgEFQ06EcD6oN`: 7 keys

### form:GropmW5MFfVQMD710Sw0 (2 docs)

- sample `NCIYiXx3u4DMe42Sf2GE`: 4 keys
- sample `iJwMzeE1LyyD8xWjVUtT`: 4 keys

### template:3MB3jxkjcCdD11us9q4N (1 docs)

- sample `5MLLi5XBWZChuBShh2rE`: 23 keys

### form:RKbFDR3tKq4nIfI6wYSC (1 docs)

- sample `7oF2PL1Y8ur0zZmpOpft`: 1 keys

### template:4RDaZtzNDgizrydeDCS5 (1 docs)

- sample `AzRlpyDfUTEajMMuhzhN`: 4 keys

### form:bQuQ6ymY4KocKUXhrQPM (1 docs)

- sample `IJ8gxjvvrTFjJx9EWZRI`: 36 keys

### form:yembcgXXaQoEQSTbDPHR (1 docs)

- sample `IKM6ze9PSWJWmsQee6x2`: 11 keys

### form:6LyKAHvUDp4rDF0jlg6a (1 docs)

- sample `UEWNpRIdhmQVJyJeUqoF`: 8 keys

### template:teacher_feedback (1 docs)

- sample `ZopLYfWqZrEZUvg3os3R`: 5 keys

### template:ILMi0ShOhMvL6UUvXGLO (1 docs)

- sample `bEzaw1ZIYEDM8zV1JK6X`: 11 keys

## Global fieldId index (merge labels across forms)

| fieldId | labels (distinct) | types | #forms |
|---------|-------------------|-------|--------|
| `1754399726889` | What is your name/Quel est ton nom?Please add your name as it appears in our records/Veuillez ajouter votre nom tel qu'il apparaît dans nos dossiers | text | 2 |
| `1754400366403` | Who is submitting this form/Qui remplit ce formulaire ?? / Who is sumitting this form? | multi_select | 2 |
| `1754401719744` | If you are a teacher, how many student do you have now/ Combien d’élèves avez-vous actuellement ?? Please select from the dropdown the number of students you have/Veuillez sélectionner dans la liste déroulante le nombre d'étudiants que vous avez. | multi_select | 2 |
| `1754402171621` | If you are an admin or an intern, type below why do you want to be excused from mention name of tasks, works or role you need this excuse for / If you are an admin or an intern, type below why do you want to be excused from mention name of tasks, works or role you need this excuse for/Si vous êtes administrateur ou stagiaire, indiquez ci-dessous pourquoi vous demandez cette excuse, en précisant le nom des tâches, travaux ou responsabilités pour lesquels vous avez besoin de cette absence. | text | 2 |
| `1754402244111` | If you are an admin list the title/names of your projects and tasks due during your excuse period so that the team can handle them while you are away / If you are an admin list the title/names of your projects and tasks due during your excuse period so that the team can handle them while you are away/Si vous êtes un administrateur, veuillez lister les titres/noms de vos projets et tâches prévus pendant votre période d’absence afin que l’équipe puisse les gérer en votre absence. | text | 2 |
| `1754402305480` | Why do you want to be excused/Pourquoi veux-tu être excusé ? This document is accessible to admins so your information is save as per your constitution and data policy/Ce document est accessible aux administrateurs afin que vos informations soient enregistrées conformément à votre constitution et à votre politique de données. | text | 2 |
| `1754402396459` | How many days are you asking for/Combien de jours demandez-vous ? | text | 2 |
| `1754402840684` | Which date would you like to be excused/Quand souhaiteriez-vous être excusé ? Please specify the exalt date you will be unavailable/Veuillez préciser la date d'exaltation à laquelle vous ne serez pas disponible. | date | 2 |
| `1754402885007` | Which date will you be back to work/Quand seras-tu de retour? The exalt date you will be returning to work/Quelle est la date à laquelle vous retournerez au travail ? | date | 2 |
| `1754402926724` | Is this part of your pay leave/Est-ce que cela fait partie de votre congé payé ? If no, please know you won't be paid for the hours you are missing/Si non, sachez que vous ne serez pas payé pour les heures manquantes. | radio | 2 |
| `1754402977293` | Have you arranged with another teacher/leader to cover your class or task while you are  You can find a teacher/leader to do this or we will assign your student to a teacher for the duration of your leave, and they will be paid for the additional hours/Vous pouvez trouver un enseignant pour le faire ou nous assignerons votre élève à un enseignant pour la durée de votre congé, et celui-ci sera rémunéré pour les heures supplémentaires. | multi_select | 2 |
| `1754403200671` | If you answered yes to previous question, or you have found someone to replace you or to teach your class or do your task while you are away, pls write the person's name below. Ignore this question if you have not found anyone / If you answered yes to previous question, or you have found someone to replace you or to teach your class or do your task while you are away, pls write the person's name below. Ignore this question if you have not found anyone. Si vous avez répondu « oui » à la question précédente, ou si vous avez trouvé quelqu’un pour vous remplacer, assurer votre cours ou accomplir votre tâche pendant votre absence, veuillez indiquer son nom ci-dessous. Ignorez cette question si vous n’avez trouvé personne. | text | 2 |
| `1754403234621` | As per our Bylaws, you must be submit this excuse at least (2 days) before the main date of your excuse. So how soon are you submitting this form? Anything less than 2 days for a foreseeable excuse will be penalized / As per our Bylaws, you must be submit this excuse at least (2 days) before the main date of your excuse. So how soon are you submitting this form? Anything less than 2 days for a foreseeable excuse will be penalized/Selon nos règlements, toute demande d’excuse doit être soumise au moins 2 jours à l’avance. Tout délai inférieur à 2 jours pour une absence prévisible entraînera une pénalité. | multi_select | 2 |
| `1754403284826` | If this is part of your 3 days free pay-leave break for this semester is it your / If this is part of your 3 days free pay-leave break for this semester is it your. Si cela fait partie de vos 3 jours de congé payé pour ce semestre, veuillez le confirmer. | multi_select | 2 |
| `1754403356959` | Sure! Here’s a shoAlert: If this is not part of your 3 paid leave days, valid evidence must be uploaded for this excuse to be considered Upload any reasonable evidence - without which your excuse might not be granted / Sure! Here’s a shoAlert: If this is not part of your 3 paid leave days, valid evidence must be uploaded for this excuse to be considered Upload any reasonable evidence - without which your excuse might not be granted. Si cette absence ne fait pas partie de vos 3 jours de congé payé, vous devez télécharger une preuve valable pour qu’elle soit prise en considération. À défaut de justificatif raisonnable, votre demande pourrait être refusée. | image_upload,text | 2 |
| `1754403394893` | Any comment/Avez-vous des commentaires. | text | 2 |
| `1754405243207` | Month | dropdown | 2 |
| `1754405345431` | Week | dropdown | 2 |
| `1754405479773` | How many new students did our financier report joining us this week | number | 2 |
| `1754405891238` | Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation? | text | 2 |
| `1754405971187` | Equipment Used / Équipement utilisé | multi_select | 1 |
| `1754405993796` | List the names/titles of the forms you reviewed this week | text | 2 |
| `1754406042126` | As a team leader list how many task did you identify and assign to team members including teachers for this week? | text | 2 |
| `1754406115874` | Class Type / Type de cours | multi_select | 1 |
| `1754406178119` | How many overdues does each leader of your team member have for this week? | text | 2 |
| `1754406275785` | How many overdue assigned tasks do you have this week? | text | 2 |
| `1754406288023` | Class Day / Jour de classe | multi_select | 1 |
| `1754406414139` | Duration (Hrs) / Durée (h) | text | 1 |
| `1754406457284` | Present Students / Élèves présents | text | 1 |
| `1754406487572` | Absent Students / Élèves absents | text | 1 |
| `1754406489614` | Have you reviewed your Teachers clock in & Class readiness form | radio | 2 |
| `1754406512129` | Late Students / Élèves en retard | text | 1 |
| `1754406537658` | Weekly Video Rec / Enregistrement vidéo hebdo | multi_select | 1 |
| `1754406544776` | List Coaches who have sent in excuses for meeting this week? | text | 2 |
| `1754406625835` | Punctuality / Ponctualité | multi_select | 1 |
| `1754406729715` | Weekly Status / Statut hebdomadaire | multi_select | 1 |
| `1754406826688` | Clock-In Status / Heure d'arrivée | multi_select | 1 |
| `1754406853292` | If this is the fourth week of the month, have you completed reviewing then audits all teachers and their work? | dropdown | 2 |
| `1754406914911` | Clock-Out Status / Heure de départ | multi_select | 1 |
| `1754407016623` | Monthly Bayana / Bayana mensuel | multi_select | 1 |
| `1754407061167` | Have you completed all the assigned tasks & projects to you AND due this week? | radio | 2 |
| `1754407079872` | Off-Schedule? / Hors horaire? | radio | 1 |
| `1754407111959` | Off-Schedule Reason / Raison hors horaire | text | 1 |
| `1754407118736` | How many time you submitted the the End of Shift Report form this week? | text | 2 |
| `1754407141413` | Missed Bayana / Bayana manqué | text | 1 |
| `1754407184691` | Topics Taught / Sujets enseignés | text | 1 |
| `1754407218568` | Student Work / Travail des élèves | multi_select | 1 |
| `1754407220630` | How many excuses did you have this week? | text | 2 |
| `1754407297953` | Curriculum Used / Programme utilisé | multi_select | 1 |
| `1754407413333` | For your teamamtes (leaders) tasks , have you verified this week's tasks they claimed to have completed (done tasks)? | dropdown | 2 |
| `1754407417507` | Coach Support / Soutien du coach | multi_select | 1 |
| `1754407509366` | Teacher's Note / Note du professeur | text | 1 |
| `1754407888209` | How many time you submitted the Zoom Hosting Form this week? | number | 2 |
| `1754408200192` | Did you help with new teacher interview this month? | dropdown | 2 |
| `1754408284136` | If this is the fourth week of the month, have you ensured that the Student of the month post is ready? | text | 2 |
| `1754408347614` | How many students did you directly and personally recruit this week? | text | 2 |
| `1754408437242` | How many times did you review the Class Readiness Form for all teachers to ascertain about what's going on this week? | text | 2 |
| `1754408485766` | How many teammates (on the executive board) did you support or help with anything this week? | text | 2 |
| `1754408544827` | Email (weekly check and reply): did check out and reply all emails for this week? Yes | dropdown | 2 |
| `1754408636565` | How many Parents did you call this week? | text | 2 |
| `1754408768571` | List new ideas you have suggested or existing idea and system you have improved this week? | text | 2 |
| `1754409022283` | Have you reviewed previous PTA meeting suggestions and concerns and assigned tasks to teammates provide solutions | dropdown | 2 |
| `1754409063401` | List of Teachers Class Absence for this week | text | 2 |
| `1754409470638` | If this fourht week of the month, pls mention the winner of the teacher of the month and student of the month (for this month | text | 2 |
| `1754409828876` | If this is the 3rd week of the month, is the next monthly Bayana Ready? | radio | 2 |
| `1754409969369` | Have you reviewed and evaluated the tasks, assignments, projects, and deadlines for all staff and leaders in your department for this month? | radio | 2 |
| `1754410023333` | Have you checked in with all teachers about their students' progress/readiness for the end of semester "student class project"? | radio | 2 |
| `1754410057904` | If this the 3rd week of the month, have you completed the Teacher's Monthly Audit for all your teachers? | radio | 2 |
| `1754410101303` | Have you seen & reviewed all Teachers' Performance Grade for this Month | radio | 2 |
| `1754410180989` | As team member, have much do feel supported by the leadership this week? | text | 2 |
| `1754410231666` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month? | text | 2 |
| `1754410322373` | Has the bi-semesterly teachers' & staff's feedback survey been ready & on course? (for this partner with Mamoudou)) | radio | 2 |
| `1754410372342` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | text | 2 |
| `1754410414108` | Have all leaders and teachers updated their Paycheck Update Sheet for this month? Name those who did not comply this week. | radio | 2 |
| `1754410499465` | As the team leader, how much do you feel that you are in control of teachers, projects, students and tasks this week? | text | 2 |
| `1754410563942` | If this is the fourth week, have you completed the Peer Leadership Audit? | dropdown | 2 |
| `1754410681968` | Have you reviewed all coaches Weekly report progress/job scheduling channel to determine if their teachers schedules are up to date? | dropdown | 2 |
| `1754410812808` | Have all leaders reported their time in and time Out for hosting Zoom this month? | text | 2 |
| `1754410872577` | Reviewed previous weeks Leader's meetings & sent a reminder on assigned tasks & Goals? | dropdown | 2 |
| `1754414044090` | Did you review all the forms submitted by your mentees and corrected the mistake they made therein? | dropdown | 2 |
| `1754414136280` | Have all leaders submitted all their required forms this week? | dropdown | 2 |
| `1754415396747` | Week | dropdown | 2 |
| `1754415478045` | Have you updated the student Attendance sheet for this week? | radio | 2 |
| `1754415687197` | Have you verify your teachers schedules and are they accurate: | text | 2 |
| `1754415829445` | If this is second and fourth week of the month, have you send and email and whatApp text to all parents who kids are absent | dropdown | 2 |
| `1754416232593` | If this is the 4th week of this month, have you sent the name of the best student of the month to Rodaa for publication? | dropdown | 2 |
| `1754416455885` | Did you check to know if all teachers are working with their students for the end -of- semester student class project presentation? | radio | 2 |
| `1754416629252` | Have you checked on your coaches and their works and challenges for this week? | radio | 2 |
| `1754417316736` | How many overdues tasks ( form connecteam ) do you have this week? | text | 2 |
| `1754417441532` | How many time you submitted the zoom hosting form this week? | text | 2 |
| `1754417550424` | Have you read, understood & done with overdue tasks/project assigned to you as an administrator | radio | 2 |
| `1754417675591` | Have you completed all the assigned tasks & projects to you which are due this week? | radio | 2 |
| `1754417786191` | All coaches needs to have at least 5 to 25 mins one on one meeting with at least 1 coachee per month to improve relationship are support teachers | text | 2 |
| `1754418293442` | Do you daily scheme through all your teachers whatsApp groupchats | dropdown | 2 |
| `1754418482085` | How many new ideas or innovation did you recommend to improve our platform/team for this week ? | text | 2 |
| `1754418597220` | How many time you submitted the end of shift report this week ? | text | 2 |
| `1754418724326` | How many time did you submit your Bi-weekly coachees performance review this month ? | text | 2 |
| `1754418891463` | List the names/titles of the forms you reviewed this week | text | 2 |
| `1754418983513` | How many teammates ( on the executive board ) did you support or with help with anything ? | text | 2 |
| `1754419277806` | How many times you review the excuse form for teachers and leaders this week ? | text | 2 |
| `1754419454463` | If this is fourth week of the month have you completed auditng all your teachers and their work? | dropdown | 2 |
| `1754419627087` | Did you help with new teacher interview this month ? | dropdown | 2 |
| `1754419773920` | How many students did you directly and personally recruit this week ? | text | 2 |
| `1754419935623` | How many time did you review the class readiness form for teachers coaching this week | text | 2 |
| `1754420118427` | If this is the fourthweek, have you completed the peer leadership | radio | 2 |
| `1754420169982` | Do you have any idea that will help our students learn while having fun or any strategy that will improve the learning pace of our students? If yes please mention it and call the attention of the administratation for implementation | long_text | 2 |
| `1754420375933` | How many parents you make follow up on payment | text | 2 |
| `1754420784391` | What is your Name: | text | 3 |
| `1754420795708` | This week i feel | dropdown | 3 |
| `1754420830580` | Date | date | 3 |
| `1754420858912` | Last week i was late for zoom hosting | dropdown | 3 |
| `1754420898444` | Last week i was absence for zoom hosting | dropdown | 3 |
| `1754420940618` | Last week i missed submitting my end of shit | dropdown | 3 |
| `1754420961705` | How many Posts you did this week? | number | 3 |
| `1754420976840` | Achievement | long_text | 3 |
| `1754420990377` | Challenges | long_text | 3 |
| `1754421007390` | Are your teacher schedules up to date - meaning their classes time, days are all correct? | dropdown | 3 |
| `1754421038728` | If this is the fourth week of the month, have completed auditing all your teachers work & sent in the outcome to each teacher? | radio | 3 |
| `1754421070183` | List how many task did you identify and assign to team members including teachers for this week ? | number | 3 |
| `1754421089461` | List the names/titles of the forms you reviewed this week | long_text | 3 |
| `1754421102825` | How many flyers made this week | number | 3 |
| `1754421119537` | How many video edited this week | number | 3 |
| `1754421137310` | This week i worked on or updated info/content on: | multi_select | 3 |
| `1754421194649` | How many time you submitted the Zoom Hosting Form this week? | number | 3 |
| `1754421195861` | How many students did you directly and personally recruit this week? | number | 3 |
| `1754421226081` | How many time you submitted the End of Shift Form this week? | number | 3 |
| `1754421253332` | Based on supervision of all staff and students, list the names the 2 teachers least in compliance with the curriculum for this month, has 1 or more urgent challenges that need immediate correction | long_text | 3 |
| `1754421278858` | As a leader, how much do you feel that you are in control of teachers, projects, students and personal tasks this week? | number | 3 |
| `1754424524366` | Week | multi_select | 2 |
| `1754424589570` | How many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional noteHow many new ideas you have suggested or existing idea and system you have improved this week: if any, mention it as additional note | text | 2 |
| `1754424631141` | Have you checked on all teachers and review their work this week? | radio | 2 |
| `1754424674211` | If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation | multi_select | 2 |
| `1754424734949` | Have you read the Bulletin Board, Readiness form FactFinding form, Resignation Form for this week & reminded Leader(s) that haven't read it? | radio | 2 |
| `1754424764611` | Have you completed all the assigned tasks & projects to you (as a leader) which are due this week? | radio | 2 |
| `1754424792353` | How many task did you identify and assign to team members including teachers for this week ? If any list them under the Ledership Note Cell | text | 2 |
| `1754424846146` | Did you check to know if all teachers are working with their students for the end-of-semester student class project presentation? | multi_select | 2 |
| `1754424934508` | Have you completed all the assigned tasks & projects to you AND due this week? | multi_select | 2 |
| `1754424979800` | How many time you submitted the the End of Shift Report form this week? | text | 2 |
| `1754425153906` | If this is the fourth week of the month, have you recommended to the Team the teacher of the month? | multi_select | 2 |
| `1754425225457` | Have you checked to ensure all your teachers have submitted their Paycheck Update Form for this month Answer this only once per month | multi_select | 2 |
| `1754425283451` | How many students did you directly and personally recruit this week? All leaders are considered ambassadors and recruiters | multi_select | 2 |
| `1754425344476` | If this is the fourth week of the month, have completed auditing all your teachers and their work? Including the total hours each person work and recommending action for any violation | multi_select | 2 |
| `1754425426630` | As our Teacher and Curriculum Coordinator, list the name of the 2 teachers who needs support the most this week | text | 2 |
| `1754425451313` | How many overdue tasks (from Connecteam) do you have this week? | text | 2 |
| `1754425454734` | Based on supervision of all teachers, list the names of the 3 teachers least in compliance with the curriculum for this month Do this monthly | text | 2 |
| `1754425516393` | How many new ideas or innovation did you reccomend to the team for this week ? If any list them under the Ledership Note Cell | radio | 2 |
| `1754425545371` | How many overdue project and tasks you have this week? | text | 2 |
| `1754425719151` | If this is the fourth week, have you completed the Peer Leadership Audit? | radio | 2 |
| `1754425756063` | Did you help with new teacher interview this month? Answer this only once per month | multi_select | 2 |
| `1754425816875` | How many excuses did you have this week? If any list below if it was a formal and accepted excuse or not | text | 2 |
| `1754425852244` | How many times did you review the Class Readiness Form for all teachers to have an ideas of what's going on? | text | 2 |
| `1754425887298` | List the names/titles of the forms you reviewed this week Type 0 if you reviewed no form | text | 2 |
| `1754425917131` | How many teammates (on the executive board) did you support or with help with anything? If any, pls list the help | text | 2 |
| `1754425957695` | How many times you review the "Excuse Form for teachers and leaders" this week? | text | 2 |
| `1754426014966` | As a coordinator of all teachers, how much do you feel that you are in control of teachers and their coaches? | text | 2 |
| `1754426048031` | How many time did you submit your Bi-Weekly Coachees Performance Review this Month ? Only answer this question once per month | text | 2 |
| `1754426092855` | How many time you submitted the Zoom Hosting Form this week? | text | 2 |
| `1754426103056` | List the names/titles of the forms you reviewed this week? | text | 2 |
| `1754426103842` | As team member, have much do feel supported by the leadership this week? | text | 2 |
| `1754426176655` | How many time you join Zoom Hosting late this week? | text | 2 |
| `1754426177674` | Any comment? I am adding comments here if I need to highlight anything outside the above questions and tasks. | text | 2 |
| `1754428397328` | Name of person submitting this | text | 2 |
| `1754428437290` | Reason for submitting | multi_select | 2 |
| `1754428767231` | Date of Absence | text | 2 |
| `1754428770767` | Date of Lateness | text | 2 |
| `1754428826191` | If this is for student(s) what is his/her name Type N/A if not applicable | text | 2 |
| `1754428878221` | If this is for student(s) what is his/her teacher's name? | text | 2 |
| `1754428921209` | If this is for a student, how many times in this month is she/he being marked for the same reason | multi_select | 2 |
| `1754429064606` | If this is for a student, has her/his parent been responsive with previous updates (text & audio)message about the problem | multi_select | 2 |
| `1754429531965` | Name of teacher or leader being reported if you are reporting a student absence (if not type N/A) | text | 2 |
| `1754429678423` | If this is for a teacher or leader, have you sent a brief WhatsApp text notifying this person about this lateness or absence? If not pls pause this form and quickly whatsApp him/her for the sake of evidence to prevent them from denying it at the end of the month. | multi_select | 2 |
| `1754429834347` | Name of student(s) for whose class this teacher/leader was absent or late Just list the student name (s) | text | 2 |
| `1754429889309` | Have you notified him or her (or their Parents) about their absence, lateness to prevent future denial If not, pls send in the notification now thru a WhatsApp text | multi_select | 2 |
| `1754429986332` | If a reason for absence or lateness was given, type it here | text | 2 |
| `1754430013333` | If this teacher sent in a formal excuse, who replaced him/her for class mention the name of the person, otherwise explain why is this class cancelled | text | 2 |
| `1754431793304` | Teacher Name / Teacher Name/Nom de l’enseignant | multi_select | 2 |
| `1754432094698` | Who is your coach / Who is your coach/Qui est votre coach? | multi_select | 2 |
| `1754432189399` | Type of assessment here you choose what you are grading either assignment or quiz / Type of assessment here you choose what you are grading either assignment or quiz/Sélectionnez le nombre correspondant à tous vos élèves actifs ce mois-ci. Veillez à ce que les notes de chaque élève dans toutes les matières soient correctement mises à jour ici. | multi_select | 2 |
| `1754432320167` | Your Department/Votre département ?? | multi_select | 2 |
| `1754432415051` | Name of the Student you are grading/ Nom de l'étudiant. Please write here the full name of the student you grading/Veuillez écrire ici le nom complet de l'étudiant que vous notez. | text | 2 |
| `1754432569137` | Assessment Subject/Sujet d'évaluation. Please select the subject from the below dropdown/Veuillez sélectionner le sujet dans le menu déroulant ci-dessous. | multi_select | 2 |
| `1754433370240` | Date you assigned this assessment to your student(s)/Date à laquelle vous avez donné cette évaluation à vos élèves ?? / Date you assigned this assessment to your student(s)? | text | 2 |
| `1754433402081` | Student Class Type/Type de classe d'étudiant? | multi_select | 2 |
| `1754433471936` | Date your students completed this assessment/À quelle date vos élèves ont-ils terminé cette évaluation? / Date your students completed this assessment? | text | 2 |
| `1754433518766` | What did the student score/Quel a été le score de l'élève? // Type N/A if the student failed to submit work Please add the full grade, For example: Assignment 9/10/ Veuillez ajouter la note complète, par exemple : Devoir 9/10. | text | 2 |
| `1754433556573` | Can you upload a photo/screenshot of the assessment/Pouvez-vous télécharger une photo/capture d'écran de l'évaluation? If this is an assignment please add the image here if you can/S'il s'agit d'une Devoirs, veuillez ajouter l'image ici si vous le pouvez. | image_upload,text | 2 |
| `1754433594818` | Are you satisfied with this student based on this assessment/Êtes-vous satisfait de cet étudiant sur cette évaluation? From 1 ( Being least satisfied to 5 ( Being more Satisfied), please rate this student/De 1 (Être le moins satisfait à 5 (Être plus satisfait), veuillez noter cet élève. | text | 2 |
| `1754433683593` | Why did you give the student the above rating/Pourquoi avez-vous attribué à l'étudiant la note ci-dessus ? Please explain briefly why you gave the student this rating/ Veuillez expliquer brièvement pourquoi vous avez attribué cette note à l'étudiant. | text | 2 |
| `1754433726138` | Any comment/Avez-vous des commentaires? Please add anything you woud like your coach/ the admin to know/Veuillez ajouter tout ce que vous aimeriez que votre coach/l'administrateur sache. | text | 2 |
| `1754473430887` | Name / Name/Nom | dropdown | 7 |
| `1754473570961` | I hereby confrim that i will fulfill my shift responsibilities as exected with no distraction and not abuse the trust placed in me by the team | dropdown | 7 |
| `1754473754870` | Days / Days - Jour | dropdown | 7 |
| `1754473834242` | Week / Week - Semaine | dropdown | 7 |
| `1754473916403` | List your Achievements during your shift & add time you spent working on each listed achievement / List your Achievements during your shift & add time you spent working on each listed achievement/Copiez et collez les objectifs de votre shift d’aujourd’hui que vous avez partagés dans le groupe Eboard au début de ce shift. | long_text,text | 7 |
| `1754474096020` | For this week I am doing my shift for the/Pour cette semaine, j’effectue mon service pour le: / For this week I am doing my shift for the: | dropdown | 7 |
| `1754474204210` | What Time Are You Reporting to work/shift today / What Time Are You Reporting to work/shift today/Septième fois | text,time | 7 |
| `1754474278156` | What Time Are Ending the work/shift today / What Time Are Ending the work/shift today/À quelle heure terminez-vous votre travail/shift aujourd’hui? | text | 7 |
| `1754474344242` | List All Your Challenges you experienced today / List All Your Challenges you experienced today/Listez tous les défis que vous avez rencontrés aujourd’hui. | text | 7 |
| `1754474407345` | Total Hours worked today ? / Total Hours worked today/Nombre total d’heures travaillées aujourd’hui ? | text | 7 |
| `1754474569443` | Based on the total hours of work I am reporting for today's shift I / Based on the total hours of work I am reporting for today's shift I/En fonction du total d’heures de travail que je rapporte pour le service d’aujourd’hui, je… | dropdown | 7 |
| `1754475387446` | Name of leader submitting this form | multi_select | 3 |
| `1754475455754` | Who is this record about | multi_select | 3 |
| `1754475667927` | Violation Type | multi_select | 3 |
| `1754475806194` | Type of Repercussion | multi_select | 3 |
| `1754475889796` | Amount cut | text | 3 |
| `1754475912785` | For this semester, is this person | multi_select | 3 |
| `1754475990192` | Briefly explained what was this person's punishment about | text | 3 |
| `1754476043141` | For this week I missed working during my expected shift / For this week I missed working during my expected shift/Cette semaine, j’ai manqué mon service prévu. | dropdown | 7 |
| `1754476060258` | Briefly explain the violator reaction the punishment | text | 3 |
| `1754476095426` | Who this person coach or mentor | multi_select | 3 |
| `1754476164451` | Month The Month Violation Was Committed | multi_select | 3 |
| `1754476189834` | This week I missed reporting submitting my end of shift / This week I missed reporting submitting my end of shift/Cette semaine, je n’ai pas soumis mon rapport de fin de service | dropdown | 7 |
| `1754476306952` | Enter the total number of new task you assigned to yourself during this shift / Enter the total number of new task you assigned to yourself during this shift/Veuillez indiquer le nombre total de nouvelles tâches que vous vous êtes attribuées pendant ce service | text | 7 |
| `1754476452166` | Enter the total number of new task you assigned to other team members during this shift / Enter the total number of new task you assigned to other team members during this shift/Indiquez le nombre total de nouvelles tâches que vous avez assignées aux autres membres de l'équipe pendant ce quart de travail. | text | 7 |
| `1754476605073` | For today's shift did you innovate or improve any of our system or platform / For today's shift did you innovate or improve any of our system or platform/Au cours du service d’aujourd’hui, avez-vous innové ou apporté des améliorations à notre système ou plateforme | dropdown | 7 |
| `1754477318327` | Leader Name | dropdown | 3 |
| `1754477344869` | Name/Nom | text | 2 |
| `1754477368560` | Complaint/Recommendation?/Réclamation/Recommandation ? | multi_select | 2 |
| `1754477409941` | Number of tasks overdues | text | 3 |
| `1754477446247` | what is your recommendation?/Quelle est votre recommandation ? | text | 2 |
| `1754477459900` | Months | dropdown | 3 |
| `1754477490537` | Name of the Person you are complaining about and why?/Nom de la personne contre laquelle vous vous plaignez et pourquoi ? | text | 2 |
| `1754477561003` | Week | dropdown | 3 |
| `1754477648856` | Note | text | 3 |
| `1754477704630` | Evidence | image_upload,text | 3 |
| `1754483161194` | Note that, it is your responsility to leran about what your colleagues are reporting here by daily reviewing this form AND submit it as needed | dropdown | 3 |
| `1754483204692` | Your Name | dropdown | 3 |
| `1754483281251` | Is what you reported in the previous question, something you are able to address by yourself? If yes, have you addressed it | dropdown | 3 |
| `1754483410122` | Is this for | dropdown | 3 |
| `1754483452846` | Month | dropdown | 3 |
| `1754483514511` | Week | dropdown | 3 |
| `1754483634804` | Who or what is this report/complaints ABOUT? | long_text | 3 |
| `1754483675790` | Mention the team leader(s) this report should concern | long_text | 3 |
| `1754483696467` | What findings are you reporting here: briefly explain | long_text | 3 |
| `1754483719927` | Potential Repercussion for this complaint based on the bylaws | dropdown | 3 |
| `1754483797967` | What do you want for the leader to do about this report | long_text | 3 |
| `1754483819860` | Image Upload | image_upload,text | 3 |
| `1754509820261` | What (title, form, or name) is your report about? | long_text | 3 |
| `1754603841743` | Name / Name/Nom | dropdown | 2 |
| `1754604016904` | I hereby confirm that I will fulfill my shift responsibilities as expected and will not abuse the trust placed in me by the team. | dropdown | 2 |
| `1754604091069` | What Time Are You Reporting for hosting today / What Time Are You Reporting for hosting today/ | dropdown | 2 |
| `1754605796428` | What Time Are You ending your hosting today/À quelle heure terminez-vous votre session d’animation aujourd’hui? / What Time Are You ending your hosting today? | dropdown | 2 |
| `1754605883192` | Month / Month - Mois | dropdown | 2 |
| `1754606072045` | Day / Day - Jour | dropdown | 2 |
| `1754606157168` | Week / Week -Semaine | dropdown | 2 |
| `1754606316925` | In this week I am doing my hosting for the/Cette semaine, j’effectue mon animation pour le: / In this week I am doing my hosting for the: | dropdown | 2 |
| `1754606467464` | How was your internet today / How was your internet today/Comment était votre connexion Internet aujourd’hui? | dropdown | 2 |
| `1754606575657` | List the help you offered or what you did/achieving during your hosting today/Listez l’aide que vous avez apportée ou ce que vous avez accompli/realizé pendant votre animation Zoom aujourd’hui. / List the help you offered or what you did/achieving during your zoom hosting today | text | 2 |
| `1754606616554` | List Challenges you experienced today / List Challenges you experienced today/Listez les défis que vous avez rencontrés aujourd’hui. | text | 2 |
| `1754606712915` | Who preceded you or are you taking this hosting over from today/Qui vous a précédé ou de qui prenez-vous la relève pour l’animation aujourd’hui? / Who preceded you or are you taking this zoom hosting over from today? | dropdown | 2 |
| `1754606909119` | Did the person succeeding you or taking the hosting capacity from you join / Did the person succeeding you or taking the hosting capacity from you join/La personne qui vous succède ou qui prend le relais pour l’animation a-t-elle rejoint? | dropdown | 2 |
| `1754607293454` | Who is succeeding you or hosting after your "hosting" time is over/Qui vous succède ou prend en charge l’animation après la fin de votre session? / Who is succeeding you or hosting zoom after your "hosting" time is over | dropdown | 2 |
| `1754608066662` | Type the names and times of all teachers who are scheduled to teach during your time of hosting zoom today based on our schedule (ex: Ibrahim 2pm) / Type the names and times of all teachers who are scheduled to teach during your time of hosting zoom today based on our schedule (ex: Ibrahim 2pm)/Tapez les noms et heures de tous les enseignants prévus pour enseigner pendant votre session Zoom aujourd’hui selon notre planning (ex : Ibrahim 14h) | long_text,text | 2 |
| `1754608100383` | Of the list of teacher names you typed in the previous question, type the name of the teachers who are absent for class today (include the names their students before each teacher name (ex: Teacher Barry for Stu Mariam) / Of the list of teacher names you typed in the previous question, type the name of the teachers who are absent for class today (include the names their students before each teacher name (ex: Teacher Barry for Stu Mariam)/Parmi la liste des enseignants que vous avez tapée dans la question précédente, indiquez le nom des enseignants absents aujourd’hui (incluez le nom de leurs élèves avant chaque nom d’enseignant, par exemple : Enseignant Barry pour Élève Mariam). | long_text,text | 2 |
| `1754608243308` | Type the name of the teachers that join class late today - indicate how many minute late they are / Type the name of the teachers that join class late today - indicate how many minute late they are/Tapez le nom des enseignants qui sont arrivés en retard aujourd’hui et indiquez de combien de minutes ils ont été en retard. | text | 2 |
| `1754608315381` | If any teacher was late or absent during hosting time, have you WhatsApps/texted them about it/Si un(e) enseignant(e) a été en retard ou absent(e) pendant l’heure d’animation, lui avez-vous envoyé un message WhatsApp/SMS à ce sujet? / If any teacher was late or absent during hosting time, have you WhatsApps/texted them about it? | dropdown | 2 |
| `1754608452314` | If you reported any teacher late or absent, have you varified the "Excuse Form" to determine if they did not file a formal excuse for today' class / If you reported any teacher late or absent, have you varified the "Excuse Form" to determine if they did not file a formal excuse for today' class/Si vous avez signalé un(e) enseignant(e) en retard ou absent(e), avez-vous vérifié le « Formulaire d’excuse » pour déterminer s’il/elle n’a pas soumis d’excuse officielle pour le cours d’aujourd’hui? | dropdown | 2 |
| `1754608646031` | What is the date of absence or lateness / What is the date of absence or lateness/Quelle est la date de l’absence ou du retard ? | date | 2 |
| `1754608692379` | Teacher name and time of absence or lateness / Teacher name and time of absence or lateness/Nom de l’enseignant(e) et heure de l’absence ou du retard. | text | 2 |
| `1754608813395` | Did you join zoom hosting today / Did you start hosting today/Avez-vous commencé l’animation aujourd’hui? | dropdown | 2 |
| `1754609203577` | How many time did you move to different rooms to observe how teachers are teaching/Combien de fois avez-vous changé de salle pour observer la façon dont les enseignants enseignent? / How many time did you move to different zoom rooms to observe how teachers are teaching? | dropdown | 2 |
| `1754609312656` | List the name of student, student teacher and title of content (such as surah or hadith) you tested to determine if students are truly learning during this shift / List the name of student, student teacher and title of content (such as surah or hadith) you tested to determine if students are truly learning during this shift/Listez le nom de l’élève, de l’enseignant(e) et le titre du contenu (par exemple sourate ou hadith) que vous avez testé pour vérifier si les élèves apprennent réellement pendant ce service. | text | 2 |
| `1754609361758` | Teachers' Internet Stability if this is not for In and Out Zoom Hosting, type N/A / Teachers' Internet Stability if this is not for In and Out Zoom Hosting, type N/A/Stabilité de la connexion Internet des enseignants : si cela ne concerne pas l’hébergement Zoom (entrées et sorties), veuillez indiquer N/A. | dropdown | 2 |
| `1754609444030` | Shout Out any leaders/teachers that help you with anything today / Shout Out any leaders/teachers that help you with anything today/Mentionnez les leaders/enseignants qui vous ont aidé(e) d’une manière ou d’une autre aujourd’hui. | text | 2 |
| `1754609480949` | Leave a comment - Laissez un commentaire / Leave a commentText Input | text | 2 |
| `1754610102115` | Name | dropdown | 2 |
| `1754610207342` | Name of Winner | text | 2 |
| `1754610291498` | The Winner is a | dropdown | 2 |
| `1754610369613` | Title of Award/Recognition | text | 2 |
| `1754610416286` | Has this winner been celebrated (posted) in all social media | radio | 2 |
| `1754610445849` | How many time has this person won any award this Semester? | dropdown | 2 |
| `1754610550377` | Any note? | text | 2 |
| `1754610908280` | Name in Full/Nom complet | text | 2 |
| `1754610949591` | Can you tell us breifly the reason you are resigning/Pouvez-vous nous expliquer brièvement la raison pour laquelle vous démissionnez? | text | 2 |
| `1754611076612` | Resigning date [the date you're filling this form]/Date de démission [la date à laquelle vous remplissez ce formulaire] | date | 2 |
| `1754611239500` | The date you will be resigning { i.e a week after filling this form}/La date à laquelle vous démissionnerez { soit une semaine après avoir rempli ce formulaire} | date | 2 |
| `1754611312550` | What feedback do you have for us as an institution/Quels retours avez-vous pour nous en tant qu'institution? | text | 2 |
| `1754611439235` | Will you be intrested in returning to us in the future/Serez-vous intéressé à revenir vers nous à l'avenir?Text Input | text | 2 |
| `1754611579116` | kindly upload your Resign Letter here/veuillez télécharger votre lettre de démission ici | image_upload,text | 2 |
| `1754612176642` | Your Name | text | 2 |
| `1754612226604` | Who are you requesting this for? | text | 2 |
| `1754612363426` | Over the past 6 months, this is my | dropdown | 2 |
| `1754612493990` | What is this submission for ? | dropdown | 2 |
| `1754612573403` | Why this request | text | 2 |
| `1754612617191` | How giving you this creadit benefit/support the work you do with us and our institution ? | text | 2 |
| `1754612720342` | Where would you want the payment of this prepayment to come from | dropdown | 2 |
| `1754612938747` | How much do you need? | text | 2 |
| `1754613040481` | When do you need this request | date | 2 |
| `1754613101609` | I acknowledge that the transfer fees associated with this requests will be from this amount | dropdown | 2 |
| `1754614840185` | You must commit to remind Chernor about it including ensuring you paiy it back on time | dropdown | 2 |
| `1754615643919` | Submitted by: | text | 2 |
| `1754615817761` | Position/TittleDropdown | dropdown | 2 |
| `1754615968757` | Travelling Date | date | 2 |
| `1754616294003` | Will you teach or work with the hub this summer | radio | 2 |
| `1754616394560` | Are you willing to take more students or put in more hours this summer? | radio | 2 |
| `1754616792297` | If yes, how many additional hours would you like to commit, or how many more classes are you able to take? | text | 2 |
| `1754617126245` | Submitted By: | dropdown | 2 |
| `1754617334742` | This is for a | dropdown | 2 |
| `1754617394374` | Name | text | 2 |
| `1754617449097` | Current Country/State/City | text | 2 |
| `1754617500355` | Phone Number | number | 2 |
| `1754617547104` | Email | text | 2 |
| `1754617572722` | If a non adult student, Name of Parent | text | 2 |
| `1754617638915` | Teacher Name | text | 2 |
| `1754617666893` | If a non adult Student, Parent Email | text | 2 |
| `1754617681730` | If non adult student, Parent Number | text | 2 |
| `1754617721757` | Coach name | text | 2 |
| `1754617928012` | Submitted by: | dropdown | 2 |
| `1754618405871` | Submission Week | dropdown | 2 |
| `1754618481310` | Have you checked out the Student Status Form to find new student | radio | 2 |
| `1754618501911` | Have you checked out the student Application form to spot any new students this week | radio | 2 |
| `1754618523857` | Have you reviewed the WhatsApp number to determine reply all finance related texts? | dropdown | 2 |
| `1754618586388` | Is the Canva receipts page well organize based on family names - alphatically? | dropdown | 2 |
| `1754618639860` | Are there a new students this week | dropdown | 2 |
| `1754618707589` | As of this week, are all new students moved to the finance document | radio | 2 |
| `1754618731269` | Have you sent an invoice to new parents | dropdown | 2 |
| `1754618974860` | Have you assigned (to our website) Chernor to call parents who are note complying in the past 2 weeks? | dropdown | 2 |
| `1754619162098` | What is the total number of students owing fees as of today's date? | text | 2 |
| `1754619204514` | What is the total number of pending receipts that are yet to be made even though the payment has been made? | text | 2 |
| `1754619501808` | What is the total of new student this week? | text | 2 |
| `1754619526446` | Outline your step-by-step plan to fix or correct any concerns or problems you obseve while reviewing and submitting this form | text | 2 |
| `1754619555700` | Any challenges you are having with fees collections? Explain below | text | 2 |
| `1754619835511` | Name of person submitting this form | dropdown | 2 |
| `1754619929905` | What is the Name and WhatsApp number of this month guest speakers | text | 2 |
| `1754619964623` | What is the topic of this Bayana? | text | 2 |
| `1754620004349` | Month | dropdown | 2 |
| `1754620091837` | List the full names of teachers who are present for this Bayana | text | 2 |
| `1754620216753` | Compare to last month, has students attendance incease or deacrease this month? | dropdown | 2 |
| `1754620324365` | What is the total number of teachers' attendance this month | text | 2 |
| `1754620495659` | Was the guest imam introduced by a student? | radio | 2 |
| `1754620527106` | Did Bayana start on time | radio | 2 |
| `1754620555539` | In one to three sentences summarize your impression about the overall conduct of this Bayana | text | 2 |
| `1754620646568` | How was the last Bayana logistic? | dropdown | 2 |
| `1754620720449` | Was the live launch on Facebook | radio | 2 |
| `1754620762916` | Was the student Quran reciter present | radio | 2 |
| `1754620895404` | ustaz korka's student | text | 2 |
| `1754620922341` | Oustaz Abdullah Blade's Student | text | 2 |
| `1754620948128` | Oustazah Nasrullah's students | text | 2 |
| `1754621013154` | Oustaz Abdul Warith's Student Student / Oustazah Mama''s Student Student | text | 2 |
| `1754621032326` | Oustaz Abdirahman's Student / Oustaz Abdoullahi Yahya Student | text | 2 |
| `1754621067604` | Oustaz Alhassan's StudentsText Input | text | 2 |
| `1754621096578` | Oustaza Asma's Students | text | 2 |
| `1754621120017` | Oustaz Cham Students | text | 2 |
| `1754621156839` | Oustaz Habib's Students | text | 2 |
| `1754621187243` | Oustaz Hardees Students / Oustazah Rahmatullah's Students | text | 2 |
| `1754621207701` | Oustaz Ibrahim Blade's Students | text | 2 |
| `1754621237073` | Oustaz Ibrahim Bah's Students | text | 2 |
| `1754621278129` | Oustaz Kosiah's Students | text | 1 |
| `1754621321468` | Ustaz Sheriff's Students | text | 2 |
| `1754621369198` | Oustaza Elham's Students | text | 2 |
| `1754621415583` | Oustaz Saidou's Students | text | 2 |
| `1754621482825` | Oustaz kaiza's Students / Oustazah Fatima's Students | text | 2 |
| `1754621508602` | Oustaz Abdulai's Students / Oustaz Siyam's Students | text | 2 |
| `1754621537883` | Oustaz Arabieu's Students | text | 2 |
| `1754621552106` | Oustaz Amadou Oury's Students | text | 2 |
| `1754621625942` | Did you reach out to parents whose students were absent from last month Bayana to find out why? | dropdown | 2 |
| `1754621663460` | Did you reach out to teachers whose students were absent from last month Bayana to find out why? | dropdown | 2 |
| `1754621709451` | Are all teacher names added to this form? | dropdown | 2 |
| `1754625053090` | IDEA | text | 2 |
| `1754625092661` | DESCRIPTION | text | 2 |
| `1754625118975` | SUGGESTER | text | 2 |
| `1754625153814` | Date | date | 2 |
| `1754625176474` | Implementation Date | date | 2 |
| `1754625240600` | implementation parties/members | text | 2 |
| `1754625273787` | Need for the implementation | text | 2 |
| `1754625289698` | Note | text | 2 |
| `1754625570522` | Coach Name | dropdown | 2 |
| `1754625657517` | What is the total number of teachers you are coaching this month? | number | 2 |
| `1754625695824` | To help prevent potential infractions or violations that could impact teachers' salaries at the end of the month, it is essential to promptly address any mistakes you observe while reviewing this form by guiding the teacher in making corrections before the following week. Will you commit to taking immediate action when you notice any issues? | dropdown | 2 |
| `1754625919184` | Week | dropdown | 2 |
| `1754625964834` | Coachee | dropdown | 2 |
| `1754646589540` | Is this the 1st or 2nd time you are submitting this form this teacher in this month? | dropdown | 2 |
| `1754646633544` | Are this coachee Clock in & Out Hours correctly entered for the past 2 weeks? | radio | 2 |
| `1754646704061` | Is this teacher schedule up to date as of today? | dropdown | 2 |
| `1754646772880` | Based on your careful review, how often does this coach edit his or her hours before submitting his or her clock in & out. | dropdown | 2 |
| `1754646853504` | What is the number of times this teacher left comments on his/her readiness for the past 2 week? | dropdown | 2 |
| `1754646906866` | How many of those comments you needed to address? | dropdown | 2 |
| `1754646952991` | As the coach, have you addressed those comments? | dropdown | 2 |
| `1754646984814` | So far does the clock in pattern correctly reflect this teacher's weekly schedule on the Connecteam Channel? | dropdown | 2 |
| `1754647396475` | Does this teacher number of readiness form submitted match the number of time the clock in submisson? | dropdown | 2 |
| `1754647635467` | How many times this teacher did their post class video recording for the past 2 weeks? | dropdown | 2 |
| `1754647696457` | As the coach, have you been checking the general performance of this teacher's students by sometimes randonmly testing them, checking their grades or asking the teachers about them | dropdown | 2 |
| `1754647852703` | How many times this teacher join class late the past 2 weeks? | dropdown | 2 |
| `1754647920053` | Did this teacher's students attend last Month Bayana based on the readiness form record? | dropdown | 2 |
| `1754647985504` | If the previous question is not 100% attendance, have you contacted this teacher to know why | dropdown | 2 |
| `1754648035001` | In the past month, how many interactions did you have with this teacher (interaction include: call, meeting and chats) | dropdown | 2 |
| `1754648121895` | If applicable how many time has this teacher conducted students midterm? | dropdown | 2 |
| `1754648183894` | How many Quizzes did this teacher give the past 2 weeks? | dropdown | 2 |
| `1754648245467` | How many Assignment did this teacher give in the past 2 weeks? | dropdown | 2 |
| `1754648319664` | How many absences does this teacher incur in the past 2 weeks? | dropdown | 2 |
| `1754648359902` | If applicable how many exam this teacher give this semester? | dropdown | 2 |
| `1754648408096` | If applicable has this teacher update his/her Paycheck Form for the previous month? | radio | 2 |
| `1754648429149` | List the names of students who have been absent from class for the past 2 weeks? | text | 2 |
| `1754648459627` | If you listed any student in the previous question have you updated the Student Learning Coordinator (Kadijatu) about the students absences | dropdown | 2 |
| `1754648539104` | How many formal excuses did this teacher requested for last month? | dropdown | 2 |
| `1754648607874` | If any student has been absent for more than 2 weeks, did you make sure the teacher is not attending this classDropdown | dropdown | 2 |
| `1754648658350` | Any comment additional comment about this teacher and his/her class | text | 2 |
| `1754648697271` | Rate the overall performance of this teacher for the last 2 weeks | text | 2 |
| `1754648907485` | Task creator | dropdown | 2 |
| `1754648975979` | Name or Title of Task | text | 2 |
| … | 199 more in JSON | | |
