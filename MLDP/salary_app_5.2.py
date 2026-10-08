"""salarycalc — developer salary estimator."""

from pathlib import Path

import altair as alt
import joblib
import numpy as np
import pandas as pd
import streamlit as st


APP_TITLE = "Salarycalc"
MODEL_PATH = Path(__file__).with_name("salary_5.2.pkl")

USER_NUMERIC_FEATURES = [
    "WorkExp",
    "YearsCode",
    "ToolCountWork",
    "ToolCountPersonal",
]

FIELD_LABELS = {
    "WorkExp": "Professional experience",
    "YearsCode": "Total years coding",
    "ToolCountWork": "Tools used at work",
    "ToolCountPersonal": "Tools used personally",
    "Country": "Country",
    "Age": "Age range",
    "EdLevel": "Education",
    "PrimaryDevType": "Primary role",
    "OrgSize": "Organisation size",
    "ICorPM": "Role level",
    "RemoteWork": "Work arrangement",
    "Industry": "Industry",
    "PurchaseInfluence": "Purchase influence",
    "NewRole": "Career change interest",
    "MainBranch": "Developer status",
}

TECH_SOURCE_LABELS = {
    "LanguageHaveWorkedWith": "Languages used",
    "DatabaseHaveWorkedWith": "Databases used",
    "PlatformHaveWorkedWith": "Platforms and tools used",
    "WebframeHaveWorkedWith": "Web frameworks used",
}

NUMERIC_SETTINGS = {
    "WorkExp": {
        "min_value": 0,
        "max_value": 50,
        "value": 5,
        "help": "Years in a paid professional role.",
    },
    "YearsCode": {
        "min_value": 0,
        "max_value": 50,
        "value": 8,
        "help": "All coding experience, including study and personal projects.",
    },
    "ToolCountWork": {
        "min_value": 0,
        "max_value": 30,
        "value": 8,
        "help": "Approximate number of technologies used in your job.",
    },
    "ToolCountPersonal": {
        "min_value": 0,
        "max_value": 30,
        "value": 5,
        "help": "Approximate number of technologies used outside work.",
    },
}

DISPLAY_NAMES = {
    "Country": {
        "United Kingdom of Great Britain and Northern Ireland": "United Kingdom",
        "United States of America": "United States",
        "Other": "Other / not listed",
    },
    "Age": {
        "18-24 years old": "18–24",
        "25-34 years old": "25–34",
        "35-44 years old": "35–44",
        "45-54 years old": "45–54",
        "55-64 years old": "55–64",
        "65 years or older": "65+",
    },
    "EdLevel": {
        "Associate degree (A.A., A.S., etc.)": "Associate degree",
        "Bachelor’s degree (B.A., B.S., B.Eng., etc.)": "Bachelor's degree",
        "Master’s degree (M.A., M.S., M.Eng., MBA, etc.)": "Master's degree",
        "Professional degree (JD, MD, Ph.D, Ed.D, etc.)": "Professional / doctoral degree",
        "Primary/elementary school": "Primary school",
        "Secondary school (e.g. American high school, German Realschule or Gymnasium, etc.)": "Secondary school",
        "Some college/university study without earning a degree": "Some university, no degree",
        "Other (please specify):": "Other education",
    },
    "PrimaryDevType": {
        "Other": "Other / grouped role",
        "Other (please specify):": "Other role",
        "Senior executive (C-suite, VP, etc.)": "Senior executive",
        "Architect, software or solutions": "Software / solutions architect",
        "DevOps engineer or professional": "DevOps engineer",
    },
    "OrgSize": {
        "Just me - I am a freelancer, sole proprietor, etc.": "Freelancer / sole proprietor",
        "Less than 20 employees": "Under 20 employees",
        "I don’t know": "Not sure",
    },
    "ICorPM": {
        "Individual contributor": "Individual contributor",
        "People manager": "People manager",
    },
    "RemoteWork": {
        "Hybrid (some in-person, leans heavy to flexibility)": "Hybrid, mostly flexible",
        "Hybrid (some remote, leans heavy to in-person)": "Hybrid, mostly in-person",
        "Your choice (very flexible, you can come in when you want or just as needed)": "Fully flexible",
    },
    "Industry": {
        "Internet, Telecomm or Information Services": "Internet / telecom / information services",
        "Retail and Consumer Services": "Retail / consumer services",
        "Transportation, or Supply Chain": "Transport / supply chain",
        "Other": "Other / grouped industry",
        "Other:": "Other industry",
    },
    "PurchaseInfluence": {
        "No": "No influence",
        "Yes, I influenced the purchase of a substantial addition to the tech stack": "Influenced a major purchase",
        "Yes, I influenced the purchase of a tool that more than five colleagues use but it is not a substantial addition to the tech stack": "Influenced a team tool",
        "Yes, I endorsed a tool that was open-source and is currently used by more than just myself but no purchase was made": "Recommended an open-source tool",
        "Yes, I endorsed a tool that was ultimately not purchased or used at my organization": "Recommended a tool that was not adopted",
    },
    "NewRole": {
        "I have neither consider or transitioned into a new career or industry": "Not considering a change",
        "I have somewhat considered changing my career and/or the industry I work in": "Somewhat considering a change",
        "I have strongly considered changing my career and/or the industry I work in": "Strongly considering a change",
        "I have transitioned into a new career and/or industry voluntarily": "Changed career by choice",
        "I have transitioned into a new career and/or industry involuntarily": "Changed career, not by choice",
    },
}

MAX_WORK_EXP_BY_AGE = {
    "18-24 years old": 8,
    "25-34 years old": 18,
    "35-44 years old": 28,
    "45-54 years old": 38,
    "55-64 years old": 48,
    "65 years or older": 50,
}

st.set_page_config(
    page_title=f"{APP_TITLE} | Developer Salary Estimator",
    page_icon="↗",
    layout="wide",
    initial_sidebar_state="collapsed",
)


def apply_styles():
    st.markdown(
        """
        <style>
            /* 1. FONTS & DESIGN TOKENS ---------------------------------- */
            @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600;700&display=swap');

            :root {
                --bg: #f1efe6;
                --ink: #0f201c;
                --forest: #16443a;
                --forest-2: #1e5748;
                --lime: #c2f75d;
                --lime-2: #b1ee44;
                --coral: #ff7a5c;
                --paper: #fffdf7;
                --line: #e1e4da;
                --line-2: #d5dacf;
                --muted: #53625c;
                --font-display: "Space Grotesk", "Aptos", "Segoe UI", sans-serif;
                --font-body: "Inter", "Aptos", "Segoe UI", Arial, sans-serif;
                --radius-xl: 28px;
                --radius-lg: 22px;
                --radius-md: 16px;
                --radius-sm: 12px;
                --field-h: 3rem;
                --shadow-card: 0 14px 40px rgba(15, 32, 28, 0.08);
                --shadow-soft: 0 6px 18px rgba(15, 32, 28, 0.05);
                --shadow-pop: 0 22px 55px rgba(15, 32, 28, 0.20);
            }

            /* 2. APP SHELL + BACKGROUND --------------------------------- */
            .stApp {
                background:
                    radial-gradient(38rem 30rem at 88% -6%, rgba(194, 247, 93, 0.22), transparent 70%),
                    radial-gradient(34rem 28rem at -8% 12%, rgba(255, 122, 92, 0.08), transparent 70%),
                    var(--bg);
                color: var(--ink);
            }

            [data-testid="stHeader"] { background: transparent; }
            [data-testid="stToolbar"] { right: 1rem; }

            /* 3. CONTENT WIDTH & BASE TYPE ------------------------------ */
            html, body, [class*="css"], .stApp, p, span, div, label, input {
                font-family: var(--font-body);
            }

            .block-container {
                max-width: 1280px;
                margin-left: auto;
                margin-right: auto;
                padding-top: 1.6rem;
                padding-bottom: 4.5rem;
                padding-left: clamp(1rem, 3vw, 2.5rem);
                padding-right: clamp(1rem, 3vw, 2.5rem);
            }

            .block-container > div [data-testid="stVerticalBlock"] { gap: 1.2rem; }

            h1, h2, h3, .display { font-family: var(--font-display); }

            /* 4. HERO HOOK ---------------------------------------------- */
            .hero {
                position: relative;
                overflow: hidden;
                border-radius: var(--radius-xl);
                padding: clamp(1.9rem, 3.6vw, 3.1rem);
                background:
                    radial-gradient(26rem 22rem at 98% -20%, rgba(194, 247, 93, 0.18), transparent 70%),
                    linear-gradient(140deg, #123128 0%, var(--ink) 72%);
                color: #fff;
                box-shadow: var(--shadow-pop);
            }

            .hero-grid {
                position: relative;
                z-index: 1;
                display: grid;
                grid-template-columns: 1.12fr 0.88fr;
                gap: clamp(1.5rem, 3vw, 3rem);
                align-items: center;
            }

            .hero-eyebrow {
                display: inline-flex;
                align-items: center;
                gap: 0.5rem;
                color: var(--lime);
                font-size: 0.8rem;
                font-weight: 700;
                letter-spacing: 0.16em;
                text-transform: uppercase;
            }
            .hero-eyebrow::before {
                content: "";
                width: 1.6rem;
                height: 2px;
                background: var(--lime);
                display: inline-block;
            }

            .hero-title {
                font-family: var(--font-display);
                font-weight: 700;
                font-size: clamp(2.1rem, 4.2vw, 3.55rem);
                line-height: 1.03;
                letter-spacing: -0.03em;
                margin: 0.9rem 0 0.85rem;
                max-width: 15ch;
            }
            .hero-title .accent {
                color: var(--lime);
                position: relative;
            }

            .hero-lead {
                color: #d5ded9;
                font-size: 1.08rem;
                line-height: 1.6;
                margin: 0 0 1.6rem;
                max-width: 46ch;
            }

            .hero-cta-row {
                display: flex;
                flex-wrap: wrap;
                align-items: center;
                gap: 1rem;
                margin-bottom: 1.7rem;
            }
            .hero-cta {
                display: inline-flex;
                align-items: center;
                gap: 0.55rem;
                background: var(--lime);
                color: var(--ink);
                font-weight: 700;
                font-size: 1rem;
                text-decoration: none;
                padding: 0.85rem 1.6rem;
                border-radius: 999px;
                box-shadow: 0 10px 26px rgba(194, 247, 93, 0.35);
                transition: transform 0.16s ease, box-shadow 0.16s ease, background 0.16s ease;
            }
            .hero-cta:hover {
                background: var(--lime-2);
                transform: translateY(-2px);
                box-shadow: 0 16px 34px rgba(194, 247, 93, 0.5);
            }
            .hero-cta-note { color: #9fb3ab; font-size: 0.9rem; }

            .hero-pills { display: flex; flex-wrap: wrap; gap: 0.7rem; }
            .hero-pill {
                background: rgba(255, 255, 255, 0.07);
                border: 1px solid rgba(255, 255, 255, 0.16);
                border-radius: 999px;
                color: #eef4f0;
                font-size: 0.9rem;
                padding: 0.5rem 1.05rem;
            }
            .hero-pill strong { color: var(--lime); font-weight: 700; }

            /* --- layered glass "salary growth" visual --- */
            .hero-visual { position: relative; min-height: 300px; }

            .glass-back {
                position: absolute;
                inset: 18px 8px 6px 34px;
                background: linear-gradient(150deg, rgba(194, 247, 93, 0.16), rgba(194, 247, 93, 0.02));
                border: 1px solid rgba(194, 247, 93, 0.22);
                border-radius: var(--radius-lg);
                transform: rotate(-4deg);
            }

            .glass-card {
                position: relative;
                background: rgba(255, 255, 255, 0.08);
                border: 1px solid rgba(255, 255, 255, 0.18);
                border-radius: var(--radius-lg);
                backdrop-filter: blur(14px);
                -webkit-backdrop-filter: blur(14px);
                padding: 1.5rem 1.6rem 1.35rem;
                box-shadow: 0 20px 50px rgba(0, 0, 0, 0.28);
            }

            .glass-head {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 1.2rem;
            }
            .glass-head .label {
                color: #eaf1ec;
                font-family: var(--font-display);
                font-weight: 600;
                font-size: 1.02rem;
            }
            .glass-badge {
                display: inline-flex;
                align-items: center;
                gap: 0.4rem;
                background: rgba(194, 247, 93, 0.15);
                border: 1px solid rgba(194, 247, 93, 0.4);
                color: var(--lime);
                font-size: 0.72rem;
                font-weight: 700;
                letter-spacing: 0.08em;
                text-transform: uppercase;
                padding: 0.28rem 0.7rem;
                border-radius: 999px;
            }
            .glass-badge .dot {
                width: 0.45rem; height: 0.45rem; border-radius: 50%;
                background: var(--lime); display: inline-block;
            }

            .bars {
                display: flex;
                align-items: flex-end;
                gap: 0.6rem;
                height: 130px;
                margin-bottom: 1.1rem;
            }
            .bar {
                flex: 1;
                border-radius: 7px 7px 3px 3px;
                background: rgba(255, 255, 255, 0.16);
                position: relative;
            }
            .bar.peak {
                background: linear-gradient(180deg, var(--lime), rgba(194, 247, 93, 0.55));
            }
            .bar.peak::after {
                content: "";
                position: absolute;
                top: -9px; left: 50%;
                width: 11px; height: 11px;
                transform: translateX(-50%);
                background: var(--coral);
                border: 2px solid #fff;
                border-radius: 50%;
                box-shadow: 0 4px 10px rgba(255, 122, 92, 0.6);
            }

            .glass-caption {
                color: #cdd8d2;
                font-size: 0.9rem;
                line-height: 1.5;
                border-top: 1px solid rgba(255, 255, 255, 0.12);
                padding-top: 0.95rem;
            }
            .glass-caption b { color: #fff; font-weight: 700; }

            .glass-float {
                position: absolute;
                top: -14px; right: -10px;
                background: var(--paper);
                color: var(--ink);
                border-radius: var(--radius-sm);
                padding: 0.6rem 0.9rem;
                box-shadow: var(--shadow-pop);
                z-index: 2;
            }
            .glass-float .n {
                font-family: var(--font-display);
                font-weight: 700;
                font-size: 1.15rem;
                line-height: 1;
            }
            .glass-float .l {
                color: var(--muted);
                font-size: 0.68rem;
                letter-spacing: 0.08em;
                text-transform: uppercase;
            }

            /* 5. STAT BAND ---------------------------------------------- */
            .stat-band {
                display: grid;
                grid-template-columns: repeat(4, 1fr);
                gap: 1rem;
                margin-top: 1.4rem;
            }
            .stat-tile {
                background: var(--paper);
                border: 1px solid var(--line);
                border-radius: var(--radius-md);
                padding: 1.15rem 1.3rem;
                box-shadow: var(--shadow-soft);
            }
            .stat-tile .num {
                font-family: var(--font-display);
                font-weight: 700;
                font-size: 1.65rem;
                color: var(--forest);
                letter-spacing: -0.02em;
                line-height: 1;
            }
            .stat-tile .lab {
                color: var(--muted);
                font-size: 0.82rem;
                font-weight: 500;
                margin-top: 0.4rem;
            }

            /* 6. SECTION HEADINGS & ANCHORS ----------------------------- */
            .anchor { position: relative; top: -1.5rem; display: block; height: 0; }

            .section-heading { margin: 2.6rem 0 1.35rem; }
            .section-heading .number {
                color: var(--coral);
                font-size: 0.82rem;
                font-weight: 700;
                letter-spacing: 0.12em;
                text-transform: uppercase;
            }
            .section-heading h2 {
                font-family: var(--font-display);
                color: var(--ink);
                font-size: clamp(1.7rem, 2.6vw, 2.25rem);
                font-weight: 700;
                letter-spacing: -0.03em;
                margin: 0.35rem 0;
            }
            .section-heading p { color: var(--muted); font-size: 1.02rem; margin: 0; }

            /* 7. FORM CARD & SUBSECTIONS -------------------------------- */
            [data-testid="stForm"] {
                background: var(--paper);
                border: 1px solid var(--line);
                border-radius: var(--radius-lg);
                box-shadow: var(--shadow-card);
                padding: clamp(1.4rem, 2.4vw, 2.15rem);
            }
            [data-testid="stForm"] [data-testid="stVerticalBlock"] { gap: 0.9rem; }
            [data-testid="stForm"] hr { border-color: var(--line); margin: 1.4rem 0 1.15rem; }

            [data-testid="stForm"] h3 {
                font-family: var(--font-display);
                color: var(--forest);
                font-size: 1.2rem;
                font-weight: 600;
                letter-spacing: -0.01em;
                margin: 0.15rem 0 0.9rem;
                padding-left: 0.8rem;
                position: relative;
            }
            [data-testid="stForm"] h3::before {
                content: "";
                position: absolute;
                left: 0; top: 0.15rem; bottom: 0.15rem;
                width: 4px; border-radius: 4px;
                background: var(--lime);
            }

            [data-testid="stWidgetLabel"] p {
                color: var(--ink);
                font-size: 0.95rem;
                font-weight: 600;
            }

            /* 8. INPUTS ------------------------------------------------- */
            div[data-baseweb="select"] > div {
                background: #fbfcf7;
                border-color: var(--line-2);
                border-radius: var(--radius-sm);
                min-height: var(--field-h);
                color: var(--ink) !important;
                transition: border-color 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
            }
            div[data-baseweb="select"] > div:hover { border-color: var(--forest); background: #fff; }
            div[data-baseweb="select"] > div:focus-within {
                border-color: var(--forest);
                box-shadow: 0 0 0 3px rgba(194, 247, 93, 0.45);
                background: #fff;
            }
            [data-testid="stForm"] div[data-baseweb="select"] span { color: var(--ink) !important; }

            /* --- number input: one unified rounded control -------------
               Default steppers render as detached near-black boxes; here
               they become slim buttons flush inside the same rounded
               bordered box as the input, with a lime hover state. */
            [data-testid="stNumberInput"] div[data-baseweb="input"],
            [data-testid="stNumberInput"] div[data-baseweb="base-input"] {
                background: #fbfcf7;
                border: 1px solid var(--line-2);
                border-radius: var(--radius-sm);
                overflow: hidden;
                transition: border-color 0.18s ease, box-shadow 0.18s ease;
            }
            [data-testid="stNumberInput"] div[data-baseweb="input"]:focus-within,
            [data-testid="stNumberInput"] div[data-baseweb="base-input"]:focus-within {
                border-color: var(--forest);
                box-shadow: 0 0 0 3px rgba(194, 247, 93, 0.45);
            }
            [data-testid="stNumberInput"] input {
                background: transparent !important;
                border: none !important;
                box-shadow: none !important;
                color: var(--ink) !important;
                -webkit-text-fill-color: var(--ink) !important;
                height: var(--field-h);
                padding-left: 0.9rem;
            }
            [data-testid="stNumberInputStepUp"],
            [data-testid="stNumberInputStepDown"] {
                background: #edf0e6 !important;
                border: none !important;
                border-left: 1px solid var(--line-2) !important;
                border-radius: 0 !important;
                color: var(--forest) !important;
                width: 2.3rem !important;
                min-width: 2.3rem !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                margin: 0 !important;
                transition: background 0.15s ease, color 0.15s ease !important;
            }
            [data-testid="stNumberInputStepUp"]:hover,
            [data-testid="stNumberInputStepDown"]:hover {
                background: var(--lime) !important;
                color: var(--ink) !important;
            }
            [data-testid="stNumberInputStepUp"] svg,
            [data-testid="stNumberInputStepDown"] svg { height: 1rem; width: 1rem; }

            /* 9. SUBMIT BUTTON ------------------------------------------ */
            .stFormSubmitButton button {
                background: var(--lime);
                border: 0;
                border-radius: 999px;
                box-shadow: 0 10px 24px rgba(194, 247, 93, 0.4);
                color: var(--ink);
                font-family: var(--font-display);
                font-size: 1.08rem;
                font-weight: 600;
                min-height: 3.6rem;
                margin-top: 0.5rem;
                width: 100%;
                transition: transform 0.16s ease, box-shadow 0.16s ease, background 0.16s ease;
            }
            .stFormSubmitButton button:hover {
                background: var(--lime-2);
                box-shadow: 0 16px 34px rgba(194, 247, 93, 0.55);
                color: var(--ink);
                transform: translateY(-2px);
            }
            .stFormSubmitButton button:active { transform: translateY(0); }

            /* 10. RESULT CARD + INTERPRETATION -------------------------- */
            .result-card {
                position: relative;
                overflow: hidden;
                border-radius: var(--radius-lg);
                background: radial-gradient(24rem 18rem at 108% -10%, rgba(194, 247, 93, 0.18), transparent 70%), linear-gradient(155deg, var(--forest-2), var(--forest));
                color: #fff;
                padding: clamp(1.6rem, 3vw, 2.35rem);
                box-shadow: var(--shadow-pop);
            }
            .result-card::before {
                content: "";
                position: absolute;
                top: 0; left: 0; right: 0;
                height: 6px;
                background: var(--lime);
            }
            .result-label {
                color: var(--lime);
                font-size: 0.8rem;
                font-weight: 700;
                letter-spacing: 0.13em;
                text-transform: uppercase;
            }
            .result-value {
                font-family: var(--font-display);
                color: #fff;
                font-size: clamp(2.5rem, 5vw, 3.85rem);
                font-weight: 700;
                letter-spacing: -0.04em;
                line-height: 1.02;
                margin: 0.55rem 0 0.3rem;
                overflow-wrap: anywhere;
            }
            .result-subline { color: #cdd8d2; font-size: 1.05rem; }
            .result-insight {
                display: flex;
                gap: 0.6rem;
                align-items: flex-start;
                margin-top: 1.3rem;
                color: #eaf1ec;
                font-size: 0.98rem;
                line-height: 1.55;
            }
            .result-insight .dot {
                flex: none;
                width: 0.6rem; height: 0.6rem;
                margin-top: 0.4rem;
                border-radius: 50%;
                background: var(--coral);
            }
            .result-range {
                background: rgba(255, 255, 255, 0.10);
                border: 1px solid rgba(255, 255, 255, 0.14);
                border-radius: var(--radius-sm);
                color: #eef4f0;
                font-size: 0.95rem;
                line-height: 1.6;
                margin-top: 1.1rem;
                padding: 1rem 1.2rem;
            }

            .result-subhead {
                font-family: var(--font-display);
                color: var(--ink);
                font-size: 1.2rem;
                font-weight: 600;
                margin: 1.6rem 0 0.2rem;
            }

            /* 11. EXPERIENCE-CURVE CHART CARD --------------------------- */
            [data-testid="stVegaLiteChart"] {
                background: var(--paper);
                border: 1px solid var(--line);
                border-radius: var(--radius-md);
                box-shadow: var(--shadow-soft);
                box-sizing: border-box;
                overflow: hidden;
                padding: 0.5rem;
                width: 100%;
            }
            [data-testid="stVegaLiteChart"] > * { max-width: 100% !important; }

            /* 12. EMPTY STATE ------------------------------------------- */
            .empty-state {
                background: var(--paper);
                border: 1.5px dashed var(--line-2);
                border-radius: var(--radius-lg);
                min-height: 300px;
                padding: 2rem;
            }
            .empty-state .eyebrow {
                color: var(--coral);
                font-size: 0.8rem;
                font-weight: 700;
                letter-spacing: 0.12em;
                text-transform: uppercase;
            }
            .empty-state h3 {
                font-family: var(--font-display);
                color: var(--ink);
                font-size: 1.75rem;
                font-weight: 600;
                letter-spacing: -0.02em;
                margin: 0.7rem 0;
            }
            .empty-state p { color: var(--muted); font-size: 1rem; line-height: 1.65; }

            /* 13. INSIGHT / METHODOLOGY CARDS --------------------------- */
            .info-grid {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 1rem;
            }
            .info-card {
                background: var(--paper);
                border: 1px solid var(--line);
                border-radius: var(--radius-md);
                padding: 1.4rem 1.5rem;
                box-shadow: var(--shadow-soft);
            }
            .info-card .ic {
                display: inline-flex;
                align-items: center;
                justify-content: center;
                width: 2.4rem; height: 2.4rem;
                border-radius: 10px;
                background: rgba(194, 247, 93, 0.22);
                color: var(--forest);
                font-family: var(--font-display);
                font-weight: 700;
                margin-bottom: 0.85rem;
            }
            .info-card h4 {
                font-family: var(--font-display);
                color: var(--ink);
                font-size: 1.1rem;
                font-weight: 600;
                margin: 0 0 0.45rem;
            }
            .info-card p { color: var(--muted); font-size: 0.95rem; line-height: 1.6; margin: 0; }

            /* 14. FOOTNOTE ---------------------------------------------- */
            .small-note {
                color: var(--muted);
                font-size: 0.86rem;
                line-height: 1.55;
                border-top: 1px solid var(--line);
                padding-top: 1.2rem;
                margin-top: 2rem;
            }

            /* 15. FLOATING SALARY WIDGET -------------------------------- */
            .salary-float {
                position: fixed;
                right: 1.25rem;
                bottom: 1.25rem;
                z-index: 999;
                display: block;
                width: min(290px, calc(100vw - 2rem));
                box-sizing: border-box;
                padding: 1rem 1.15rem;
                border: 1px solid rgba(194, 247, 93, 0.45);
                border-radius: 18px;
                background:
                    radial-gradient(circle at top right, rgba(194, 247, 93, 0.22), transparent 48%),
                    linear-gradient(145deg, #173e31, #0d2f25);
                box-shadow: 0 18px 45px rgba(7, 35, 27, 0.28);
                color: #fff !important;
                text-decoration: none !important;
                animation: salary-float-in 0.28s ease-out;
            }
            .salary-float:hover {
                border-color: rgba(194, 247, 93, 0.8);
                box-shadow: 0 22px 52px rgba(7, 35, 27, 0.34);
                transform: translateY(-2px);
            }
            .salary-float-label {
                display: block;
                color: var(--lime);
                font-size: 0.72rem;
                font-weight: 750;
                letter-spacing: 0.11em;
                text-transform: uppercase;
            }
            .salary-float-value {
                display: block;
                margin-top: 0.22rem;
                font-family: var(--font-display);
                font-size: 1.65rem;
                font-weight: 700;
                letter-spacing: -0.03em;
                line-height: 1.1;
            }
            .salary-float-monthly {
                display: block;
                margin-top: 0.22rem;
                color: #d5e3dc;
                font-size: 0.86rem;
            }
            .salary-float-hint {
                display: block;
                margin-top: 0.65rem;
                color: #eef7f1;
                font-size: 0.78rem;
                font-weight: 650;
            }
            @keyframes salary-float-in {
                from { opacity: 0; transform: translateY(12px); }
                to { opacity: 1; transform: translateY(0); }
            }

            /* 16. RESPONSIVE BREAKPOINTS -------------------------------- */
            @media (max-width: 992px) {
                .hero-grid { grid-template-columns: 1fr; }
                .hero-visual { min-height: 240px; margin-top: 0.5rem; }
                .glass-back { inset: 14px 6px 6px 24px; }
                .stat-band { grid-template-columns: repeat(2, 1fr); }
                .info-grid { grid-template-columns: 1fr; }
            }
            @media (max-width: 640px) {
                .block-container { padding-left: 1rem; padding-right: 1rem; }
                .hero { padding: 1.5rem; }
                .stat-band { grid-template-columns: 1fr 1fr; }
                .result-value { font-size: clamp(2.1rem, 9vw, 2.7rem); }
                .salary-float {
                    right: 0.75rem;
                    bottom: 0.75rem;
                    width: min(260px, calc(100vw - 1.5rem));
                }
                [data-testid="stNumberInputStepUp"],
                [data-testid="stNumberInputStepDown"] { width: 2rem !important; min-width: 2rem !important; }
            }
        </style>
        """,
        unsafe_allow_html=True,
    )


@st.cache_resource(show_spinner=False)
def load_model_package(model_path):
    return joblib.load(model_path)


def validate_model_package(package):
    required = {
        "model",
        "model_name",
        "col_x",
        "col_x_numeric",
        "col_x_categorical",
        "col_encoded",
        "col_options",
        "numeric_medians",
        "category_top_values",
        "tech_count_sources",
        "tech_flags",
        "tech_options",
        "best_params",
        "test_mae",
        "test_rmse",
        "test_r2",
        "salary_floor",
        "salary_ceiling",
        "training_rows",
    }
    missing = sorted(required.difference(package))
    if missing:
        raise ValueError("Missing model information: " + ", ".join(missing))


def display_name(feature, value):
    return DISPLAY_NAMES.get(feature, {}).get(value, value)


def visible_options(package, feature):
    return [
        value
        for value in package["col_options"][feature]
        if str(value) not in {"Unknown", "NA", "nan"}
    ]


def preprocess_profiles(profiles, package):
    frame = pd.DataFrame(profiles).copy()

    frame["ToolCountTotal"] = (
        frame["ToolCountWork"] + frame["ToolCountPersonal"]
    )
    frame["CodingBeforeWork"] = (
        frame["YearsCode"] - frame["WorkExp"]
    ).clip(lower=0)

    for feature, source_column in package["tech_count_sources"].items():
        frame[feature] = frame[source_column].apply(
            lambda selected: len(selected) if isinstance(selected, list) else 0
        )

    for feature, (source_column, technology) in package["tech_flags"].items():
        frame[feature] = frame[source_column].apply(
            lambda selected, item=technology: int(
                isinstance(selected, list) and item in selected
            )
        )

    for column in package["col_x_numeric"]:
        frame[column] = pd.to_numeric(frame[column], errors="coerce").fillna(
            package["numeric_medians"][column]
        )

    for column in package["col_x_categorical"]:
        frame[column] = frame[column].fillna("Unknown")
        top_values = package["category_top_values"].get(column, [])
        if top_values:
            frame[column] = frame[column].where(
                frame[column].isin(top_values),
                "Other",
            )

        allowed = package["col_options"][column]
        frame[column] = pd.Categorical(frame[column], categories=allowed)

    encoded = pd.get_dummies(
        frame[package["col_x"]],
        drop_first=True,
        dtype=int,
    )
    return encoded.reindex(columns=package["col_encoded"], fill_value=0)


def predict_profiles(profiles, package):
    encoded = preprocess_profiles(profiles, package)
    predictions = np.asarray(package["model"].predict(encoded), dtype=float)
    return np.clip(
        predictions,
        package["salary_floor"],
        package["salary_ceiling"],
    )


def validate_profile(profile):
    errors = []

    if profile["WorkExp"] > profile["YearsCode"]:
        errors.append(
            "Professional experience cannot be greater than total coding experience."
        )

    age_limit = MAX_WORK_EXP_BY_AGE.get(profile["Age"])
    if age_limit is not None and profile["WorkExp"] > age_limit:
        errors.append(
            f"The selected age range supports at most {age_limit} years "
            "of professional experience."
        )

    return errors


def build_experience_curve(profile, package):
    age_limit = MAX_WORK_EXP_BY_AGE.get(profile["Age"], 50)
    years = np.arange(0, age_limit + 1)
    rows = []

    for year in years:
        row = dict(profile)
        row["WorkExp"] = int(year)
        row["YearsCode"] = max(int(year), int(profile["YearsCode"]))
        rows.append(row)

    predictions = predict_profiles(rows, package)
    return pd.DataFrame(
        {"Estimated salary": predictions},
        index=pd.Index(years, name="Years of experience"),
    )


def build_experience_chart(curve_df, current_exp, current_salary):
    """Palette-matched experience curve: forest line, lime gradient fill,
    and a coral marker for the user's current experience."""
    data = curve_df.reset_index()
    data.columns = ["years", "salary"]

    ink = "#10231f"
    forest = "#173d34"
    lime = "#b9f45f"
    coral = "#ff7657"
    muted = "#60706b"
    grid = "#e7e9e1"

    x_axis = alt.X(
        "years:Q",
        title="Years of professional experience",
        axis=alt.Axis(
            grid=False,
            tickCount=6,
            labelColor=muted,
            titleColor=muted,
            domainColor="#d8ddd3",
            tickColor="#d8ddd3",
            labelFontSize=13,
            titleFontSize=13,
            titlePadding=14,
        ),
    )
    y_axis = alt.Y(
        "salary:Q",
        title=None,
        scale=alt.Scale(nice=True, zero=False),
        axis=alt.Axis(
            format="$,.0f",
            grid=True,
            gridColor=grid,
            tickCount=5,
            domainOpacity=0,
            tickSize=0,
            labelColor=muted,
            labelFontSize=13,
            labelPadding=8,
        ),
    )

    base = alt.Chart(data)

    area = base.mark_area(
        interpolate="monotone",
        line={"color": forest, "strokeWidth": 3},
        color=alt.Gradient(
            gradient="linear",
            stops=[
                alt.GradientStop(color=lime, offset=0),
                alt.GradientStop(color="#f4f1e8", offset=1),
            ],
            x1=0,
            x2=0,
            y1=0,
            y2=1,
        ),
        opacity=0.55,
    ).encode(x=x_axis, y=y_axis)

    layers = [area]

    marker_data = pd.DataFrame(
        {"years": [current_exp], "salary": [current_salary]}
    )
    rule = (
        alt.Chart(marker_data)
        .mark_rule(color=coral, strokeDash=[4, 4], strokeWidth=1.5)
        .encode(x="years:Q")
    )
    point = (
        alt.Chart(marker_data)
        .mark_point(
            color=coral,
            fill=coral,
            size=140,
            stroke="#ffffff",
            strokeWidth=2,
        )
        .encode(x="years:Q", y="salary:Q")
    )
    label = (
        alt.Chart(marker_data)
        .mark_text(
            text="You",
            dy=-16,
            color=ink,
            fontSize=13,
            fontWeight="bold",
        )
        .encode(x="years:Q", y="salary:Q")
    )
    layers.extend([rule, point, label])

    chart = (
        alt.layer(*layers)
        .properties(
            height=300,
            # "fit" + contained padding keeps the whole chart (axes,
            # labels and margins) inside the width Streamlit assigns via
            # use_container_width, so it can never overflow the card or
            # trigger horizontal scrolling.
            autosize={"type": "fit", "contains": "padding"},
            padding={"left": 6, "right": 16, "top": 12, "bottom": 6},
        )
        .configure_view(strokeWidth=0, fill=None)
        .configure(background="transparent")
    )
    return chart


def render_selectbox(feature, package, key):
    options = visible_options(package, feature)
    return st.selectbox(
        FIELD_LABELS[feature],
        options=options,
        index=None,
        placeholder="Choose an option",
        format_func=lambda value: display_name(feature, value),
        key=key,
    )


def render_technology_multiselect(source_column, package, key):
    return st.multiselect(
        TECH_SOURCE_LABELS[source_column],
        options=package["tech_options"][source_column],
        default=[],
        placeholder="Choose all that apply",
        key=key,
    )


apply_styles()

try:
    model_package = load_model_package(MODEL_PATH)
    validate_model_package(model_package)
except FileNotFoundError:
    st.error(
        "`salary_5.2.pkl` was not found. Keep it in the same folder "
        f"as `{Path(__file__).name}` and restart the app."
    )
    st.stop()
except Exception as error:
    st.error(f"The salary model could not be loaded: {error}")
    st.stop()


# --- Presentation-only values pulled from the loaded model package.
#     These are real model facts (not predictions) used to dress the hero
#     and stat band; none of them affect the prediction pipeline.
hero_rows = model_package["training_rows"]
hero_r2 = model_package["test_r2"]
hero_mae = model_package["test_mae"]
hero_rmse = model_package["test_rmse"]
hero_floor = model_package["salary_floor"]
hero_ceiling = model_package["salary_ceiling"]
hero_model = model_package["model_name"]

st.markdown(
    f"""
    <section class="hero">
        <div class="hero-grid">
            <div class="hero-left">
                <span class="hero-eyebrow">Developer salary benchmark</span>
                <h1 class="hero-title">Know what your <span class="accent">code</span> is worth.</h1>
                <p class="hero-lead">
                    A machine-learning benchmark trained on real Stack Overflow
                    survey data. Describe your background and workplace, and get a
                    grounded annual-salary estimate with the experience curve behind it.
                </p>
                <div class="hero-pills">
                    <span class="hero-pill"><strong>{hero_rows:,}</strong> survey records</span>
                    <span class="hero-pill">Test R² <strong>{hero_r2:.3f}</strong></span>
                    <span class="hero-pill">Test MAE <strong>USD {hero_mae:,.0f}</strong></span>
                </div>
            </div>
            <div class="hero-visual">
                <div class="glass-float">
                    <div class="n">{hero_r2:.3f}</div>
                    <div class="l">Test R²</div>
                </div>
                <div class="glass-back"></div>
                <div class="glass-card">
                    <div class="glass-head">
                        <span class="label">Salary growth</span>
                    </div>
                    <div class="bars">
                        <div class="bar" style="height:26%"></div>
                        <div class="bar" style="height:38%"></div>
                        <div class="bar" style="height:50%"></div>
                        <div class="bar" style="height:61%"></div>
                        <div class="bar" style="height:73%"></div>
                        <div class="bar" style="height:86%"></div>
                        <div class="bar peak" style="height:100%"></div>
                    </div>
                    <div class="glass-caption">
                        Benchmarks span <b>USD {hero_floor:,.0f}</b> to
                        <b>USD {hero_ceiling:,.0f}</b> across the modelled range —
                        rising with experience, tooling and role.
                    </div>
                </div>
            </div>
        </div>
    </section>
    """,
    unsafe_allow_html=True,
)

st.markdown(
    f"""
    <div class="stat-band">
        <div class="stat-tile">
            <div class="num">{hero_rows:,}</div>
            <div class="lab">Survey records trained on</div>
        </div>
        <div class="stat-tile">
            <div class="num">{hero_r2:.3f}</div>
            <div class="lab">Model fit · test R²</div>
        </div>
        <div class="stat-tile">
            <div class="num">USD {hero_mae:,.0f}</div>
            <div class="lab">Typical error · test MAE</div>
        </div>
        <div class="stat-tile">
            <div class="num">${hero_floor/1000:,.0f}k–${hero_ceiling/1000:,.0f}k</div>
            <div class="lab">Salary range modelled</div>
        </div>
    </div>
    """,
    unsafe_allow_html=True,
)

st.markdown(
    """
    <span class="anchor" id="calculator"></span>
    <div class="section-heading">
        <div class="number">01 · Build your profile</div>
        <h2>Tell the model what matters.</h2>
        <p>Your profile and technology choices are converted into the model features automatically.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

form_column, result_column = st.columns([3, 2], gap="large")

with form_column:
    with st.form("salary_profile_form"):
        st.markdown("### Experience")
        experience_columns = st.columns(2)
        numeric_values = {}

        for index, feature in enumerate(USER_NUMERIC_FEATURES):
            settings = NUMERIC_SETTINGS[feature]
            with experience_columns[index % 2]:
                numeric_values[feature] = st.number_input(
                    FIELD_LABELS[feature],
                    min_value=settings["min_value"],
                    max_value=settings["max_value"],
                    value=settings["value"],
                    step=1,
                    help=settings["help"],
                    key=f"num_{feature}",
                )

        st.divider()
        st.markdown("### Background")
        background_columns = st.columns(2)
        categorical_values = {}

        with background_columns[0]:
            categorical_values["Country"] = render_selectbox(
                "Country", model_package, "cat_Country"
            )
            categorical_values["EdLevel"] = render_selectbox(
                "EdLevel", model_package, "cat_EdLevel"
            )

        with background_columns[1]:
            categorical_values["Age"] = render_selectbox(
                "Age", model_package, "cat_Age"
            )
            categorical_values["PrimaryDevType"] = render_selectbox(
                "PrimaryDevType", model_package, "cat_PrimaryDevType"
            )
            categorical_values["MainBranch"] = render_selectbox(
                "MainBranch", model_package, "cat_MainBranch"
            )

        st.divider()
        st.markdown("### Workplace")
        workplace_columns = st.columns(2)

        with workplace_columns[0]:
            categorical_values["OrgSize"] = render_selectbox(
                "OrgSize", model_package, "cat_OrgSize"
            )
            categorical_values["RemoteWork"] = render_selectbox(
                "RemoteWork", model_package, "cat_RemoteWork"
            )
            categorical_values["PurchaseInfluence"] = render_selectbox(
                "PurchaseInfluence", model_package, "cat_PurchaseInfluence"
            )

        with workplace_columns[1]:
            categorical_values["ICorPM"] = render_selectbox(
                "ICorPM", model_package, "cat_ICorPM"
            )
            categorical_values["Industry"] = render_selectbox(
                "Industry", model_package, "cat_Industry"
            )
            categorical_values["NewRole"] = render_selectbox(
                "NewRole", model_package, "cat_NewRole"
            )

        st.divider()
        st.markdown("### Technologies")
        st.caption(
            "Choose the technologies you have worked with. "
            "The model converts these choices into counts and yes/no features."
        )
        technology_columns = st.columns(2)
        technology_values = {}

        for index, source_column in enumerate(TECH_SOURCE_LABELS):
            with technology_columns[index % 2]:
                technology_values[source_column] = (
                    render_technology_multiselect(
                        source_column,
                        model_package,
                        f"tech_{source_column}",
                    )
                )

        button_label = (
            "Recalculate salary  →"
            if "salary_result" in st.session_state
            else "Calculate salary  →"
        )
        submitted = st.form_submit_button(
            button_label,
            type="primary",
            use_container_width=True,
        )


if submitted:
    missing = [
        FIELD_LABELS[feature]
        for feature, value in categorical_values.items()
        if value is None
    ]

    if missing:
        with form_column:
            st.error("Complete these fields first: " + ", ".join(missing) + ".")
    else:
        profile = {
            **numeric_values,
            **categorical_values,
            **technology_values,
        }
        profile_errors = validate_profile(profile)

        if profile_errors:
            with form_column:
                for message in profile_errors:
                    st.error(message)
        else:
            with st.spinner("Comparing your profile with the survey..."):
                annual_salary = float(
                    predict_profiles([profile], model_package)[0]
                )
                experience_curve = build_experience_curve(
                    profile, model_package
                )

            st.session_state["salary_result"] = {
                "profile": profile,
                "annual_salary": annual_salary,
                "experience_curve": experience_curve,
            }

            with form_column:
                st.success(
                    f"Estimate ready: USD {annual_salary:,.0f} per year. "
                    "The full result and experience curve are in the result panel."
                )


with result_column:
    if "salary_result" in st.session_state:
        result = st.session_state["salary_result"]
        annual_salary = result["annual_salary"]
        test_mae = float(model_package["test_mae"])
        lower_range = max(
            model_package["salary_floor"],
            annual_salary - test_mae,
        )
        upper_range = min(
            model_package["salary_ceiling"],
            annual_salary + test_mae,
        )

        # Derived (not hard-coded) framing: where this estimate falls
        # within the model's own salary range. Purely presentational.
        range_span = (
            model_package["salary_ceiling"] - model_package["salary_floor"]
        )
        if range_span > 0:
            position_pct = (
                (annual_salary - model_package["salary_floor"]) / range_span * 100
            )
        else:
            position_pct = 0.0
        position_pct = min(100.0, max(0.0, position_pct))
        if position_pct >= 66:
            band_text = "the upper part"
        elif position_pct >= 33:
            band_text = "the middle"
        else:
            band_text = "the lower part"

        st.markdown(
            f"""
            <section class="result-card">
                <div class="result-label">Estimated annual salary</div>
                <div class="result-value">USD {annual_salary:,.0f}</div>
                <div class="result-subline">
                    About USD {annual_salary / 12:,.0f} per month
                </div>
                <div class="result-insight">
                    <span class="dot"></span>
                    <span>
                        This lands in <strong>{band_text}</strong> of the modelled
                        salary range (about {position_pct:.0f}%). The curve below
                        shows how it shifts as professional experience grows.
                    </span>
                </div>
                <div class="result-range">
                    <strong>Model context:</strong>
                    USD {lower_range:,.0f}–{upper_range:,.0f}.
                    This uses the test MAE around the estimate and is not a
                    personal confidence interval.
                </div>
            </section>
            """,
            unsafe_allow_html=True,
        )

        st.markdown(
            '<div class="result-subhead">Experience curve</div>',
            unsafe_allow_html=True,
        )
        current_exp = int(result["profile"]["WorkExp"])
        curve = result["experience_curve"]
        if current_exp in curve.index:
            current_point_salary = float(curve.loc[current_exp, "Estimated salary"])
        else:
            current_point_salary = annual_salary
        try:
            st.altair_chart(
                build_experience_chart(curve, current_exp, current_point_salary),
                use_container_width=True,
            )
        except Exception:
            # Never let a chart hiccup break the result; fall back to a
            # bright lime line that stays visible on any theme.
            st.line_chart(curve, color="#b9f45f")
        st.caption(
            "The curve changes professional experience and raises total coding "
            "experience when needed. It is limited by the selected age range. "
            "The coral marker shows where you sit today."
        )
    else:
        st.markdown(
            f"""
            <section class="empty-state">
                <div class="eyebrow">Your result</div>
                <h3>Ready when you are.</h3>
                <p>
                    Complete the form to see your estimated annual salary and
                    how it changes with professional experience.
                </p>
                <p>
                    {model_package["model_name"]} was trained on
                    {model_package["training_rows"]:,} survey records with
                    salaries from USD {model_package["salary_floor"]:,.0f} to
                    USD {model_package["salary_ceiling"]:,.0f}. Its test MAE is
                    USD {model_package["test_mae"]:,.0f}, its test RMSE is
                    USD {model_package["test_rmse"]:,.0f}, and its test R2 is
                    {model_package["test_r2"]:.3f}.
                </p>
            </section>
            """,
            unsafe_allow_html=True,
        )


if "salary_result" in st.session_state:
    floating_salary = float(
        st.session_state["salary_result"]["annual_salary"]
    )
    st.markdown(
        (
            '<a class="salary-float" href="#calculator" '
            'aria-label="View the full salary estimate">'
            '<span class="salary-float-label">Your predicted salary</span>'
            f'<span class="salary-float-value">USD {floating_salary:,.0f}</span>'
            '<span class="salary-float-monthly">'
            f'About USD {floating_salary / 12:,.0f} per month'
            '</span>'
            '<span class="salary-float-hint">View full result ↑</span>'
            '</a>'
        ),
        unsafe_allow_html=True,
    )
else:
    st.markdown(
        (
            '<a class="salary-float" href="#calculator" '
            'aria-label="Go to the salary calculator">'
            '<span class="salary-float-label">Salary estimator</span>'
            '<span class="salary-float-value">Calculate your result</span>'
            '<span class="salary-float-monthly">'
            'Complete your profile to get an estimate'
            '</span>'
            '<span class="salary-float-hint">Start estimate ↓</span>'
            '</a>'
        ),
        unsafe_allow_html=True,
    )


st.markdown(
    """
    <div class="section-heading">
        <div class="number">02 · How to read it</div>
        <h2>An estimate, with its reasoning shown.</h2>
        <p>A benchmark is a starting point for a conversation, not a verdict.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

st.markdown(
    f"""
    <div class="info-grid">
        <div class="info-card">
            <div class="ic">≈</div>
            <h4>It's a benchmark</h4>
            <p>
                The figure is what the model expects for a profile like yours,
                learned from {hero_rows:,} real survey responses — not an offer or a
                guarantee for any single person.
            </p>
        </div>
        <div class="info-card">
            <div class="ic">±</div>
            <h4>Read the range</h4>
            <p>
                Typical error (test MAE) is about USD {hero_mae:,.0f}, so treat the
                context band around the number as the honest margin rather than the
                exact figure.
            </p>
        </div>
        <div class="info-card">
            <div class="ic">↗</div>
            <h4>Follow the curve</h4>
            <p>
                The experience curve holds everything else fixed and varies
                professional experience, so you can see the trajectory your profile
                is on — capped by your age range.
            </p>
        </div>
    </div>
    """,
    unsafe_allow_html=True,
)
