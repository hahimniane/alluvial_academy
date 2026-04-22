#!/usr/bin/env python3
"""Merge unified programs ARB keys into app_en.arb, app_fr.arb, app_ar.arb."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "lib" / "l10n"


def p(slug: str, title: str, desc: str, age: str, f1: str, f2: str, f3: str) -> dict:
    return {
        f"unifiedProg{slug}Title": title,
        f"unifiedProg{slug}Desc": desc,
        f"unifiedProg{slug}Age": age,
        f"unifiedProg{slug}Feat1": f1,
        f"unifiedProg{slug}Feat2": f2,
        f"unifiedProg{slug}Feat3": f3,
    }


def build_en() -> dict:
    m = {
        "unifiedProgramsTitle": "Explore our programs",
        "unifiedProgramsSubtitle": "Choose a program, preview pricing by hours per week, then continue to enrollment — all in one place.",
        "unifiedProgramsDeselect": "Clear selection",
        "unifiedProgramsEnroll": "Continue to enrollment",
        "unifiedProgramsHoursPerWeek": "Hours per week",
        "unifiedProgramsPriceLine": "{hours} hrs/wk × ${rate}/hr · ≈ ${monthly}/mo",
        "@unifiedProgramsPriceLine": {
            "placeholders": {"hours": {}, "rate": {}, "monthly": {}}
        },
        "unifiedCatIslamicTitle": "Islamic studies",
        "unifiedCatLanguagesTitle": "Languages",
        "unifiedCatEnglishTitle": "English & literacy",
        "unifiedCatMathTitle": "Mathematics",
        "unifiedCatProgrammingTitle": "Coding & technology",
        "unifiedCatAfterSchoolTitle": "After-school tutoring",
    }
    m.update(
        p(
            "IslamQuran",
            "Quran",
            "Complete Quran learning program including recitation, memorization, and understanding.",
            "All ages",
            "Proper recitation with Tajweed rules",
            "Memorization techniques for Hifz",
            "Understanding the meanings",
        )
    )
    m.update(
        p(
            "IslamHadith",
            "Hadith",
            "Study the sayings and teachings of Prophet Muhammad (PBUH).",
            "Ages 10+",
            "Authentic Hadith collections",
            "Understanding Hadith sciences",
            "Practical application in daily life",
        )
    )
    m.update(
        p(
            "IslamArabic",
            "Arabic language",
            "Learn the language of the Quran from basics to fluency.",
            "Ages 7+",
            "Arabic alphabet and writing",
            "Grammar (Nahw) and morphology",
            "Vocabulary building",
        )
    )
    m.update(
        p(
            "IslamTawhid",
            "Tawhid",
            "Understanding the oneness of Allah and core Islamic beliefs.",
            "Ages 8+",
            "Fundamentals of Islamic faith",
            "Understanding Allah's attributes",
            "Pillars of faith (Iman)",
        )
    )
    m.update(
        p(
            "IslamTafsir",
            "Tafsir",
            "Deep understanding and interpretation of the Holy Quran.",
            "Ages 12+",
            "Verse by verse explanation",
            "Historical context",
            "Practical life applications",
        )
    )
    m.update(
        p(
            "IslamFiqh",
            "Fiqh",
            "Understanding Islamic law and practical worship.",
            "Ages 10+",
            "Rules of prayer and fasting",
            "Halal and Haram guidelines",
            "Islamic business ethics",
        )
    )
    m.update(
        p(
            "LangEnglish",
            "English",
            "Complete support for reading, writing, grammar, vocabulary, and exam prep.",
            "Global",
            "Homework help and comprehension",
            "Grammar and vocabulary",
            "Exam preparation",
        )
    )
    m.update(
        p(
            "LangFrench",
            "French",
            "Master French language skills including conversation, grammar, and cultural understanding.",
            "Global",
            "Conversation practice",
            "Grammar and writing",
            "Cultural context",
        )
    )
    m.update(
        p(
            "LangAdlam",
            "Adlam",
            "Learn the Adlam script for writing Fulani (Fulfulde/Pular)—a modern alphabet for this West African language.",
            "West Africa",
            "Script and reading fundamentals",
            "Fulfulde/Pular connection",
            "Cultural preservation focus",
        )
    )
    m.update(
        p(
            "LangSwahili",
            "Swahili",
            "East African Swahili with authentic instruction.",
            "East Africa",
            "Speaking and listening",
            "Reading and writing",
            "Cultural immersion",
        )
    )
    m.update(
        p(
            "LangYoruba",
            "Yoruba",
            "West African Yoruba with structured lessons.",
            "West Africa",
            "Pronunciation and tones",
            "Everyday conversation",
            "Reading practice",
        )
    )
    m.update(
        p(
            "LangAmharic",
            "Amharic",
            "Horn of Africa Amharic with clear progression.",
            "Horn of Africa",
            "Ge'ez script introduction",
            "Conversation skills",
            "Cultural context",
        )
    )
    m.update(
        p(
            "LangWolof",
            "Wolof",
            "West African Wolof for learners at any level.",
            "West Africa",
            "Greetings and daily speech",
            "Grammar essentials",
            "Listening practice",
        )
    )
    m.update(
        p(
            "LangHausa",
            "Hausa",
            "Hausa across West and Central Africa.",
            "West & Central Africa",
            "Core vocabulary",
            "Conversation",
            "Reading support",
        )
    )
    m.update(
        p(
            "LitGrammar",
            "Grammar & vocabulary",
            "Master English grammar rules, sentence structure, and expand your vocabulary.",
            "All levels",
            "Clear grammar explanations",
            "Sentence patterns",
            "Vocabulary expansion",
        )
    )
    m.update(
        p(
            "LitReading",
            "Reading comprehension",
            "Develop critical reading skills and analyze texts across various genres.",
            "Elementary to advanced",
            "Close reading strategies",
            "Genre variety",
            "Discussion and reflection",
        )
    )
    m.update(
        p(
            "LitCreative",
            "Creative writing",
            "Express yourself through stories, poetry, and creative narratives.",
            "Grades 3–12",
            "Story structure",
            "Voice and style",
            "Peer feedback",
        )
    )
    m.update(
        p(
            "LitAcademic",
            "Academic writing",
            "Master essays, research papers, and formal academic composition.",
            "High school & college",
            "Thesis and argumentation",
            "Research skills",
            "Citation basics",
        )
    )
    m.update(
        p(
            "LitLiterature",
            "Literature analysis",
            "Explore classic and contemporary literature with in-depth analysis.",
            "High school",
            "Themes and symbolism",
            "Textual evidence",
            "Discussion skills",
        )
    )
    m.update(
        p(
            "LitTestprep",
            "Test preparation",
            "Prepare for standardized tests including SAT, ACT, IELTS, and TOEFL.",
            "All ages",
            "Timed practice",
            "Strategy coaching",
            "Weak-area focus",
        )
    )
    m.update(
        p(
            "MathElem",
            "Elementary math",
            "Building a strong foundation in arithmetic, shapes, and problem-solving.",
            "Grades K–5",
            "Number sense",
            "Word problems",
            "Confidence building",
        )
    )
    m.update(
        p(
            "MathAlgebra",
            "Pre-algebra & algebra",
            "Mastering variables, equations, functions, and graphing.",
            "Grades 6–9",
            "Equation solving",
            "Functions and graphs",
            "Real-world modeling",
        )
    )
    m.update(
        p(
            "MathGeometry",
            "Geometry",
            "Exploring shapes, sizes, relative positions, and properties of space.",
            "Grades 8–10",
            "Proofs and reasoning",
            "Area and volume",
            "Spatial thinking",
        )
    )
    m.update(
        p(
            "MathTrig",
            "Trigonometry",
            "Understanding relationships between side lengths and angles of triangles.",
            "Grades 10–11",
            "Unit circle",
            "Identities",
            "Applications",
        )
    )
    m.update(
        p(
            "MathCalc",
            "Calculus",
            "Limits, derivatives, integrals, and infinite series.",
            "Grades 11–12+",
            "Conceptual understanding",
            "Problem sets",
            "Exam readiness",
        )
    )
    m.update(
        p(
            "MathStats",
            "Statistics",
            "Analyzing data, probability, distributions, and inference.",
            "High school & college",
            "Data literacy",
            "Probability models",
            "Interpretation skills",
        )
    )
    m.update(
        p(
            "CodeKids",
            "Coding for kids",
            "Introduction to logic, algorithms, and creativity through Scratch and Python basics.",
            "Ages 7–12",
            "Games and stories",
            "Logical thinking",
            "Safe, paced lessons",
        )
    )
    m.update(
        p(
            "CodeWeb",
            "Web development",
            "Build responsive websites using HTML, CSS, JavaScript, and modern frameworks.",
            "Teens & adults",
            "Layout and design",
            "Interactivity",
            "Portfolio projects",
        )
    )
    m.update(
        p(
            "CodeMobile",
            "Mobile app development",
            "Create iOS and Android apps with Flutter and Dart.",
            "Teens & adults",
            "UI basics",
            "State and navigation",
            "Ship a small app",
        )
    )
    m.update(
        p(
            "CodePython",
            "Python programming",
            "Data science, automation, and backend development with Python.",
            "All ages",
            "Syntax and structures",
            "Projects and scripts",
            "Career-relevant skills",
        )
    )
    m.update(
        p(
            "CodeGame",
            "Game development",
            "Design and code your own video games using Unity or Godot.",
            "Teens",
            "Game loops",
            "Assets and levels",
            "Playtesting",
        )
    )
    m.update(
        p(
            "CodeCs",
            "Intro to computer science",
            "Preparation for AP Computer Science and university-level studies.",
            "High school",
            "Algorithms",
            "Complexity intuition",
            "Exam alignment",
        )
    )
    m.update(
        p(
            "AsElem",
            "Elementary (K–5)",
            "Foundational support across subjects with caring tutors.",
            "Grades K–5",
            "Homework help",
            "Skill gaps",
            "Confidence",
        )
    )
    m.update(
        p(
            "AsMiddle",
            "Middle school (6–8)",
            "Support through middle grades with structured study habits.",
            "Grades 6–8",
            "Study strategies",
            "Core subjects",
            "Organization",
        )
    )
    m.update(
        p(
            "AsHigh",
            "High school (9–12)",
            "Rigorous support for high school courses and exams.",
            "Grades 9–12",
            "AP/IB readiness",
            "Time management",
            "Subject depth",
        )
    )
    return m


def build_fr(en: dict) -> dict:
    out = dict(en)
    out.update(
        {
            "unifiedProgramsTitle": "Découvrez nos programmes",
            "unifiedProgramsSubtitle": "Choisissez un programme, estimez le tarif selon les heures par semaine, puis poursuivez l'inscription — tout au même endroit.",
            "unifiedProgramsDeselect": "Effacer la sélection",
            "unifiedProgramsEnroll": "Continuer vers l'inscription",
            "unifiedProgramsHoursPerWeek": "Heures par semaine",
            "unifiedProgramsPriceLine": "{hours} h/sem × ${rate}/h · ≈ ${monthly}/mois",
            "unifiedCatIslamicTitle": "Études islamiques",
            "unifiedCatLanguagesTitle": "Langues",
            "unifiedCatEnglishTitle": "Anglais & alphabétisation",
            "unifiedCatMathTitle": "Mathématiques",
            "unifiedCatProgrammingTitle": "Programmation & technologie",
            "unifiedCatAfterSchoolTitle": "Soutien scolaire",
        }
    )
    return out


def build_ar(en: dict) -> dict:
    out = dict(en)
    out.update(
        {
            "unifiedProgramsTitle": "استكشف برامجنا",
            "unifiedProgramsSubtitle": "اختر برنامجًا، واطّلع على التسعير حسب الساعات أسبوعيًا، ثم تابع التسجيل — في مكان واحد.",
            "unifiedProgramsDeselect": "إلغاء الاختيار",
            "unifiedProgramsEnroll": "متابعة التسجيل",
            "unifiedProgramsHoursPerWeek": "ساعات أسبوعيًا",
            "unifiedProgramsPriceLine": "{hours} س/أسبوع × ${rate}/ساعة · ≈ ${monthly}/شهر",
            "unifiedCatIslamicTitle": "الدراسات الإسلامية",
            "unifiedCatLanguagesTitle": "اللغات",
            "unifiedCatEnglishTitle": "الإنجليزية والمحو الأمية",
            "unifiedCatMathTitle": "الرياضيات",
            "unifiedCatProgrammingTitle": "البرمجة والتقنية",
            "unifiedCatAfterSchoolTitle": "الدروس بعد المدرسة",
        }
    )
    return out


def merge(path: Path, extra: dict) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for k, v in extra.items():
        data[k] = v
    text = json.dumps(data, ensure_ascii=False, indent=2)
    path.write_text(text + "\n", encoding="utf-8")


def main() -> None:
    en = build_en()
    merge(L10N / "app_en.arb", en)
    merge(L10N / "app_fr.arb", build_fr(en))
    merge(L10N / "app_ar.arb", build_ar(en))
    print("Merged unified programs keys into app_en.arb, app_fr.arb, app_ar.arb")


if __name__ == "__main__":
    main()
