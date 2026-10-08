"""
AnalyseTS - Stock Watchlist Dashboard
Reads processed_stock_results.csv and displays a single-page Streamlit dashboard.

Run: streamlit run scripts/stock_dashboard.py
UiPath launches this after the Python processing step.
"""

import html
import os

import pandas as pd
import plotly.graph_objects as go
import streamlit as st


# ---------------------------------------------------------------------------
# App configuration and design tokens
# ---------------------------------------------------------------------------
st.set_page_config(
    page_title="AnalyseTS Intelligence Console",
    layout="wide",
    initial_sidebar_state="collapsed",
)

CSV_PATH = os.path.join("output", "processed_stock_results.csv")
if not os.path.exists(CSV_PATH) and os.path.exists("processed_stock_results.csv"):
    CSV_PATH = "processed_stock_results.csv"

POSITIVE = "#15803D"
NEGATIVE = "#C62828"
WARNING = "#B45309"
ACCENT = "#1E40AF"
INDIGO = "#4F46E5"
NEUTRAL = "#64748B"
TEXT = "#0F172A"
MUTED = "#475569"
GRID = "#E8EEF6"


# ---------------------------------------------------------------------------
# Shared styling
# ---------------------------------------------------------------------------
st.markdown(
    """
    <style>
    :root {
        color-scheme: light;
        --page: #F6F8FC;
        --surface: #FFFFFF;
        --soft: #F8FAFC;
        --navy: #0F172A;
        --primary: #1E40AF;
        --blue: #3B82F6;
        --indigo: #4F46E5;
        --positive: #15803D;
        --negative: #C62828;
        --warning: #B45309;
        --muted: #475569;
        --subtle: #64748B;
        --border: #DCE4F0;
        --blue-soft: #EFF6FF;
        --green-soft: #F0FDF4;
        --red-soft: #FEF2F2;
        --amber-soft: #FFFBEB;
        --radius: 16px;
        --radius-sm: 12px;
        --shadow: 0 8px 24px rgba(15, 23, 42, 0.055);
        --shadow-strong: 0 14px 36px rgba(30, 64, 175, 0.11);
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }

    html, body, .stApp {
        font-family: Inter, ui-sans-serif, system-ui, -apple-system,
            BlinkMacSystemFont, "Segoe UI", sans-serif;
        color: var(--navy);
    }

    body, .stApp, [data-testid="stAppViewContainer"], [data-testid="stMain"] {
        background: var(--page) !important;
        color: var(--navy) !important;
        overflow-x: hidden !important;
    }

    [data-testid="stToolbar"], #MainMenu, [data-testid="stFooter"],
    [data-testid="stDecoration"] {
        display: none !important;
    }

    [data-testid="stHeader"] {
        height: 0 !important;
        min-height: 0 !important;
        background: transparent !important;
    }

    .block-container {
        width: min(100%, 1560px) !important;
        max-width: 1560px !important;
        padding: 14px 28px 28px !important;
        margin-inline: auto !important;
    }

    .stMarkdown, .stPlotlyChart, [data-testid="stVerticalBlock"],
    [data-testid="stHorizontalBlock"] { min-width: 0; }
    [data-testid="stHorizontalBlock"] { gap: 14px; }
    p { font-size: 14px; line-height: 1.55; }
    a, button, summary { touch-action: manipulation; }
    button:focus-visible, summary:focus-visible, a:focus-visible {
        outline: 3px solid #2563EB !important;
        outline-offset: 3px !important;
    }

    .ats-sr-only {
        position: absolute !important;
        width: 1px !important;
        height: 1px !important;
        padding: 0 !important;
        margin: -1px !important;
        overflow: hidden !important;
        clip: rect(0, 0, 0, 0) !important;
        white-space: nowrap !important;
        border: 0 !important;
    }

    .ats-icon {
        display: inline-block;
        width: 1em;
        height: 1em;
        flex: 0 0 auto;
        stroke: currentColor;
        vertical-align: -0.14em;
    }

    /* Ultra-compact hero: prioritises dashboard content in the presentation view. */
    .ats-hero {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 24px;
        min-height: 104px;
        padding: 13px 18px;
        margin-bottom: 10px;
        overflow: hidden;
        background:
            radial-gradient(circle at 12% 8%, rgba(59,130,246,.10), transparent 28%),
            var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        box-shadow: var(--shadow-strong);
    }

    .ats-hero-copy {
        display: flex;
        align-items: center;
        flex: 1 1 auto;
        min-width: 0;
    }

    .ats-brand-mark {
        display: grid;
        place-items: center;
        width: 48px;
        height: 48px;
        margin-right: 14px;
        flex: 0 0 auto;
        color: #FFF;
        background: var(--primary);
        border-radius: 13px;
        box-shadow: 0 10px 24px rgba(30,64,175,.22);
    }
    .ats-brand-mark .ats-icon { width: 26px; height: 26px; }
    .ats-brand-copy { min-width: 0; }
    .ats-eyebrow {
        margin: 0 0 1px;
        color: var(--primary) !important;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: .09em;
        text-transform: uppercase;
    }
    .ats-title-line {
        display: flex;
        align-items: baseline;
        flex-wrap: wrap;
        gap: 4px 12px;
    }
    .ats-hero h1 {
        margin: 0;
        color: var(--navy) !important;
        font-size: clamp(27px, 2vw, 33px);
        line-height: 1.04;
        font-weight: 850;
        letter-spacing: -.045em;
    }
    .ats-hero-subtitle {
        color: var(--muted) !important;
        font-size: clamp(14px, 1vw, 16px);
        font-weight: 650;
    }
    .ats-hero-value {
        margin-top: 2px;
        color: var(--subtle) !important;
        font-size: 13px;
        line-height: 1.35;
    }
    .ats-hero-meta {
        display: flex;
        flex: 0 0 auto;
        flex-direction: column;
        align-items: flex-end;
        justify-content: center;
        gap: 6px;
        min-width: 235px;
        padding-left: 20px;
        border-left: 1px solid var(--border);
        color: var(--muted) !important;
        font-size: 12px;
        font-variant-numeric: tabular-nums;
    }
    .ats-meta-item, .ats-ready {
        display: inline-flex;
        align-items: center;
        gap: 6px;
    }
    .ats-ready {
        padding: 5px 10px;
        color: #166534 !important;
        background: #DCFCE7;
        border: 1px solid #BBF7D0;
        border-radius: 999px;
        font-size: 12px;
        font-weight: 800;
        white-space: nowrap;
    }
    .ats-ready-dot {
        width: 7px; height: 7px;
        background: var(--positive);
        border-radius: 50%;
    }

    /* UiPath workflow strip */
    .ats-workflow {
        padding: 13px 15px 12px;
        margin-bottom: 12px;
        overflow: hidden;
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        box-shadow: var(--shadow);
    }
    .ats-workflow-head {
        display: flex;
        align-items: baseline;
        justify-content: space-between;
        gap: 12px;
        margin-bottom: 10px;
    }
    .ats-workflow-title {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        margin: 0;
        color: var(--navy) !important;
        font-size: 14px;
        font-weight: 800;
    }
    .ats-workflow-caption {
        margin: 0;
        color: var(--subtle) !important;
        font-size: 12px;
    }
    .ats-workflow-scroll {
        max-width: 100%;
        overflow-x: auto;
        scrollbar-width: thin;
        scrollbar-color: #CBD5E1 transparent;
    }
    .ats-steps {
        display: grid;
        grid-template-columns: repeat(6, minmax(136px, 1fr));
        min-width: 820px;
        gap: 8px;
    }
    .ats-step {
        display: grid;
        grid-template-columns: 34px minmax(0,1fr);
        align-items: center;
        gap: 8px;
        min-width: 0;
        padding: 8px 9px;
        background: var(--soft);
        border: 1px solid #E7EDF5;
        border-radius: 11px;
    }
    .ats-step.current {
        background: var(--blue-soft);
        border-color: #93C5FD;
        box-shadow: inset 0 0 0 1px rgba(59,130,246,.12);
    }
    .ats-step.upcoming { background: #FAFAFB; border-style: dashed; }
    .ats-step-icon {
        display: grid;
        place-items: center;
        width: 34px; height: 34px;
        color: var(--primary);
        background: #E8F0FE;
        border-radius: 10px;
    }
    .ats-step.upcoming .ats-step-icon {
        color: var(--subtle);
        background: #F1F5F9;
    }
    .ats-step-name {
        overflow-wrap: anywhere;
        color: var(--navy) !important;
        font-size: 12px;
        line-height: 1.2;
        font-weight: 750;
    }
    .ats-step-state {
        margin-top: 2px;
        color: var(--subtle) !important;
        font-size: 12px;
        line-height: 1.2;
    }
    .ats-step.current .ats-step-state {
        color: var(--primary) !important;
        font-weight: 750;
    }

    /* Overall mood */
    .ats-mood {
        --mood-accent: var(--subtle);
        --mood-bg: #F1F5F9;
        display: grid;
        grid-template-columns: 46px minmax(0,1fr) auto;
        align-items: center;
        gap: 14px;
        min-height: 92px;
        padding: 14px 17px;
        margin-bottom: 12px;
        background: var(--mood-bg);
        border: 1px solid var(--border);
        border-left: 5px solid var(--mood-accent);
        border-radius: var(--radius-sm);
    }
    .ats-mood.bullish { --mood-accent: var(--positive); --mood-bg: var(--green-soft); }
    .ats-mood.bearish { --mood-accent: var(--negative); --mood-bg: var(--red-soft); }
    .ats-mood.mixed { --mood-accent: var(--warning); --mood-bg: var(--amber-soft); }
    .ats-mood-icon {
        display: grid;
        place-items: center;
        width: 44px; height: 44px;
        color: var(--mood-accent);
        background: rgba(255,255,255,.72);
        border: 1px solid rgba(148,163,184,.22);
        border-radius: 12px;
    }
    .ats-mood-label, .ats-card-label {
        color: var(--subtle) !important;
        font-size: 12px;
        font-weight: 800;
        letter-spacing: .075em;
        text-transform: uppercase;
    }
    .ats-mood-value {
        margin-top: 1px;
        color: var(--navy) !important;
        font-size: 23px;
        line-height: 1.15;
        font-weight: 850;
    }
    .ats-mood-note {
        margin-top: 3px;
        color: var(--muted) !important;
        font-size: 13px;
        line-height: 1.35;
    }
    .ats-mood-stats {
        display: grid;
        grid-template-columns: repeat(3,minmax(66px,1fr));
        gap: 8px;
    }
    .ats-mood-stat {
        min-width: 72px;
        padding: 8px 10px;
        text-align: center;
        background: rgba(255,255,255,.72);
        border: 1px solid rgba(148,163,184,.22);
        border-radius: 10px;
    }
    .ats-mood-stat strong {
        display: block;
        color: var(--navy) !important;
        font-size: 18px;
        line-height: 1.1;
        font-weight: 850;
        font-variant-numeric: tabular-nums;
    }
    .ats-mood-stat span {
        color: var(--subtle) !important;
        font-size: 12px;
        font-weight: 700;
        text-transform: uppercase;
    }

    /* Movement and processing cards */
    .ats-card {
        --card-accent: var(--primary);
        --card-soft: var(--blue-soft);
        position: relative;
        height: 100%;
        overflow: hidden;
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        box-shadow: var(--shadow);
    }
    .ats-card::before {
        content: "";
        position: absolute;
        inset: 0 auto 0 0;
        width: 4px;
        background: var(--card-accent);
    }
    .ats-card.positive { --card-accent: var(--positive); --card-soft: var(--green-soft); }
    .ats-card.negative { --card-accent: var(--negative); --card-soft: var(--red-soft); }
    .ats-card.warning { --card-accent: var(--warning); --card-soft: var(--amber-soft); }
    .ats-card.indigo { --card-accent: var(--indigo); --card-soft: #EEF2FF; }
    .ats-movement-card {
        min-height: 164px;
        padding: 15px 16px 14px 19px;
        margin-bottom: 11px;
    }
    .ats-card-top, .ats-kpi-row, .ats-movement-bottom {
        display: flex;
        justify-content: space-between;
        gap: 10px;
    }
    .ats-card-top { align-items: center; }
    .ats-card-icon, .ats-heading-icon, .ats-empty-icon {
        display: grid;
        place-items: center;
        flex: 0 0 auto;
        color: var(--card-accent, var(--primary));
        background: var(--card-soft, var(--blue-soft));
        border-radius: 10px;
    }
    .ats-card-icon { width: 34px; height: 34px; }
    .ats-card-icon .ats-icon { width: 18px; height: 18px; }
    .ats-symbol {
        max-width: 100%;
        margin-top: 7px;
        overflow-wrap: anywhere;
        color: var(--navy) !important;
        font-size: clamp(20px,1.75vw,28px);
        line-height: 1.02;
        font-weight: 850;
        letter-spacing: -.025em;
    }
    .ats-movement-bottom { align-items: end; margin-top: 9px; }
    .ats-price {
        color: var(--muted) !important;
        font-size: 14px;
        font-weight: 700;
        font-variant-numeric: tabular-nums;
    }
    .ats-descriptor, .ats-kpi-desc, .ats-direction {
        margin-top: 3px;
        color: var(--subtle) !important;
        font-size: 12px;
        line-height: 1.25;
    }
    .ats-change {
        color: var(--card-accent) !important;
        font-size: clamp(20px,1.7vw,27px);
        line-height: 1;
        font-weight: 850;
        font-variant-numeric: tabular-nums;
        white-space: nowrap;
    }
    .ats-direction { text-align: right; font-size: 12px; font-weight: 700; }
    .ats-kpi-card {
        min-height: 108px;
        padding: 13px 15px 12px 18px;
        margin-bottom: 10px;
    }
    .ats-kpi-card.is-attention { background: var(--amber-soft); }
    .ats-kpi-row { align-items: flex-start; }
    .ats-kpi-value {
        margin-top: 5px;
        color: var(--navy) !important;
        font-size: clamp(25px,2vw,32px);
        line-height: 1;
        font-weight: 850;
        font-variant-numeric: tabular-nums;
    }
    .ats-kpi-desc { margin-top: 7px; }

    /* Shared section headings and chart containers */
    .ats-section-head {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 16px;
        margin: 0 0 9px;
    }
    .ats-heading-wrap {
        display: flex;
        align-items: flex-start;
        gap: 10px;
        min-width: 0;
    }
    .ats-heading-icon { width: 34px; height: 34px; }
    .ats-section-head h2 {
        margin: 0;
        color: var(--navy) !important;
        font-size: 18px;
        line-height: 1.25;
        font-weight: 820;
        letter-spacing: -.015em;
    }
    .ats-section-head p {
        margin: 2px 0 0;
        color: var(--subtle) !important;
        font-size: 13px;
        line-height: 1.35;
    }
    .ats-legend {
        display: flex;
        flex-wrap: wrap;
        justify-content: flex-end;
        gap: 6px 12px;
        padding-top: 3px;
        color: var(--subtle) !important;
        font-size: 12px;
        font-weight: 700;
    }
    .ats-legend-item { display: inline-flex; align-items: center; gap: 6px; white-space: nowrap; }
    .ats-legend-dot { width: 9px; height: 9px; border-radius: 3px; }

    [data-testid="stVerticalBlockBorderWrapper"] {
        margin: 5px 0 10px;
        padding: 15px 16px 7px !important;
        overflow: hidden;
        background: var(--surface) !important;
        border: 1px solid var(--border) !important;
        border-radius: var(--radius) !important;
        box-shadow: var(--shadow);
    }
    [data-testid="stVerticalBlockBorderWrapper"] [data-testid="stPlotlyChart"] {
        margin-top: -2px;
    }
    [data-testid="stPlotlyChart"] > div { min-width: 0 !important; }

    .ats-empty {
        display: flex;
        align-items: center;
        gap: 12px;
        min-height: 150px;
        padding: 18px;
        color: var(--muted) !important;
        background: var(--soft);
        border: 1px dashed #CBD5E1;
        border-radius: var(--radius-sm);
    }
    .ats-empty-icon { width: 42px; height: 42px; --card-soft: #EAF0F7; --card-accent: var(--subtle); }
    .ats-empty strong { display: block; color: var(--navy) !important; font-size: 14px; }
    .ats-empty span { display: block; margin-top: 2px; color: var(--subtle) !important; font-size: 13px; }

    /* Accessible analytics tables */
    .ats-table-card, .ats-quality {
        padding: 16px;
        margin: 5px 0 10px;
        overflow: hidden;
        background: var(--surface);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        box-shadow: var(--shadow);
    }
    .ats-table-wrap {
        width: 100%;
        max-width: 100%;
        overflow-x: auto;
        border: 1px solid #E5EBF3;
        border-radius: 12px;
        scrollbar-width: thin;
        scrollbar-color: #CBD5E1 transparent;
    }
    .ats-table {
        width: 100%;
        min-width: 960px;
        border-collapse: separate;
        border-spacing: 0;
        color: var(--navy);
        font-size: 13px;
    }
    .ats-table th {
        position: sticky;
        top: 0;
        z-index: 2;
        padding: 10px 11px;
        color: var(--muted) !important;
        background: #F2F6FB;
        border-bottom: 1px solid #D9E2EE;
        font-size: 12px;
        font-weight: 800;
        letter-spacing: .045em;
        text-align: left;
        text-transform: uppercase;
        white-space: nowrap;
    }
    .ats-table td {
        height: 44px;
        padding: 9px 11px;
        color: var(--navy) !important;
        background: #FFF;
        border-bottom: 1px solid #EDF1F6;
        line-height: 1.35;
        vertical-align: middle;
        overflow-wrap: anywhere;
    }
    .ats-table tbody tr:nth-child(even) td { background: #FAFCFF; }
    .ats-table tbody tr:hover td { background: #EFF6FF; }
    .ats-table tbody tr:last-child td { border-bottom: 0; }
    .ats-table .num { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; }
    .ats-table .sym { max-width: 180px; color: var(--primary) !important; font-weight: 850; }
    .ats-table .company { min-width: 170px; max-width: 260px; }
    .ats-pos { color: var(--positive) !important; font-weight: 800; }
    .ats-neg { color: var(--negative) !important; font-weight: 800; }

    .ats-pill {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        max-width: 100%;
        padding: 4px 8px;
        border: 1px solid transparent;
        border-radius: 999px;
        font-size: 12px;
        line-height: 1.25;
        font-weight: 800;
        white-space: normal;
    }
    .ats-pill::before {
        content: "";
        width: 6px; height: 6px;
        flex: 0 0 auto;
        background: currentColor;
        border-radius: 50%;
    }
    .ats-pill.good { color: #166534 !important; background: #DCFCE7; border-color: #BBF7D0; }
    .ats-pill.bad { color: #991B1B !important; background: #FEE2E2; border-color: #FECACA; }
    .ats-pill.warn { color: #92400E !important; background: #FEF3C7; border-color: #FDE68A; }
    .ats-pill.flat { color: #475569 !important; background: #F1F5F9; border-color: #E2E8F0; }

    /* Data quality */
    .ats-quality-grid {
        display: grid;
        grid-template-columns: repeat(4,minmax(0,1fr));
        gap: 10px;
        margin-top: 12px;
    }
    .ats-quality-item {
        display: grid;
        grid-template-columns: 34px minmax(0,1fr);
        align-items: center;
        gap: 9px;
        min-width: 0;
        padding: 10px;
        background: var(--soft);
        border: 1px solid #E6ECF4;
        border-radius: 11px;
    }
    .ats-quality-value {
        color: var(--navy) !important;
        font-size: 20px;
        line-height: 1.05;
        font-weight: 850;
        font-variant-numeric: tabular-nums;
    }
    .ats-quality-label {
        margin-top: 2px;
        color: var(--subtle) !important;
        font-size: 12px;
        line-height: 1.2;
        font-weight: 700;
    }
    .ats-quality-progress-head {
        display: flex;
        justify-content: space-between;
        gap: 10px;
        margin-top: 14px;
        color: var(--muted) !important;
        font-size: 12px;
        font-weight: 750;
    }
    .ats-progress {
        width: 100%;
        height: 9px;
        margin-top: 6px;
        overflow: hidden;
        background: #E7EDF5;
        border-radius: 999px;
    }
    .ats-progress > span {
        display: block;
        width: var(--ats-progress);
        height: 100%;
        background: var(--positive);
        border-radius: inherit;
    }
    .ats-quality-note {
        margin-top: 9px;
        color: var(--muted) !important;
        font-size: 13px;
        line-height: 1.4;
    }

    [data-testid="stExpander"] {
        margin-top: 6px;
        overflow: hidden;
        background: var(--surface);
        border: 1px solid var(--border) !important;
        border-radius: var(--radius) !important;
        box-shadow: var(--shadow);
    }
    [data-testid="stExpander"] summary { min-height: 48px; }
    [data-testid="stExpander"] summary, [data-testid="stExpander"] summary p {
        color: var(--navy) !important;
        font-size: 14px !important;
        font-weight: 750 !important;
    }
    [data-testid="stAlert"] { color: var(--navy) !important; border-radius: var(--radius-sm) !important; }

    .ats-footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 16px;
        margin-top: 18px;
        padding: 14px 2px 2px;
        color: var(--subtle) !important;
        border-top: 1px solid var(--border);
        font-size: 12px;
        line-height: 1.4;
    }
    .ats-footer strong { color: var(--navy) !important; font-size: 13px; }
    .ats-footer-right { text-align: right; }

    @media (max-width: 1200px) {
        .block-container { padding-inline: 22px !important; }
        .ats-mood { grid-template-columns: 44px minmax(0,1fr); }
        .ats-mood-stats { grid-column: 1 / -1; }
    }
    @media (max-width: 900px) {
        .block-container { padding: 12px 16px 24px !important; }
        .ats-hero { align-items: flex-start; flex-direction: column; gap: 10px; }
        .ats-hero-meta {
            width: 100%;
            min-width: 0;
            padding: 9px 0 0;
            align-items: flex-start;
            border-top: 1px solid var(--border);
            border-left: 0;
        }
        .ats-workflow-head, .ats-section-head, .ats-footer {
            align-items: flex-start;
            flex-direction: column;
        }
        .ats-quality-grid { grid-template-columns: repeat(2,minmax(0,1fr)); }
        .ats-footer-right { text-align: left; }
    }
    @media (max-width: 640px) {
        .block-container { padding-inline: 13px !important; }
        .ats-hero { padding: 14px; }
        .ats-hero-copy { align-items: flex-start; }
        .ats-brand-mark { width: 44px; height: 44px; margin-right: 11px; border-radius: 12px; }
        .ats-hero h1 { font-size: 28px; }
        .ats-title-line { display: block; }
        .ats-hero-subtitle { margin-top: 2px; }
        .ats-mood { grid-template-columns: 40px minmax(0,1fr); padding: 13px; }
        .ats-mood-icon { width: 40px; height: 40px; }
        .ats-mood-stats { grid-template-columns: repeat(3,minmax(0,1fr)); gap: 6px; }
        .ats-mood-stat { min-width: 0; padding: 7px 5px; }
        .ats-movement-bottom { align-items: flex-start; flex-direction: column; }
        .ats-direction { text-align: left; }
        .ats-legend { justify-content: flex-start; }
        .ats-quality-grid { grid-template-columns: 1fr; }
        .ats-table-card, .ats-quality { padding: 13px; }
    }
    @media (prefers-reduced-motion: reduce) {
        html { scroll-behavior: auto; }
        *, *::before, *::after {
            animation-duration: .01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: .01ms !important;
        }
    }
    </style>
    """,
    unsafe_allow_html=True,
)


# ---------------------------------------------------------------------------
# SVG icons and reusable HTML helpers
# ---------------------------------------------------------------------------
ICON_PATHS = {
    "activity": '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
    "workflow": (
        '<rect x="3" y="3" width="6" height="6" rx="1"/>'
        '<rect x="15" y="15" width="6" height="6" rx="1"/>'
        '<path d="M9 6h6a3 3 0 0 1 3 3v6M15 18H9a3 3 0 0 1-3-3V9"/>'
    ),
    "sheet": (
        '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>'
        '<path d="M14 2v6h6M8 13h8M8 17h8M8 9h2"/>'
    ),
    "scan": (
        '<path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2"/>'
        '<path d="M7 12h10M7 9h10M7 15h7"/>'
    ),
    "code": '<path d="m8 9-3 3 3 3M16 9l3 3-3 3M14 5l-4 14"/>',
    "dashboard": (
        '<rect x="3" y="3" width="7" height="9" rx="1"/>'
        '<rect x="14" y="3" width="7" height="5" rx="1"/>'
        '<rect x="14" y="12" width="7" height="9" rx="1"/>'
        '<rect x="3" y="16" width="7" height="5" rx="1"/>'
    ),
    "brain": (
        '<path d="M9.5 4.5A3 3 0 0 0 4 6a3 3 0 0 0 .5 5.5A3.5 3.5 0 0 0 9 17v3"/>'
        '<path d="M14.5 4.5A3 3 0 0 1 20 6a3 3 0 0 1-.5 5.5A3.5 3.5 0 0 1 15 17v3"/>'
        '<path d="M9 8h6M9 12h6M12 4v16"/>'
    ),
    "send": '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    "trend_up": '<path d="m3 17 6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
    "trend_down": '<path d="m3 7 6 6 4-4 8 8"/><path d="M15 17h6v-6"/>',
    "move": (
        '<path d="M5 9 2 12l3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3"/>'
        '<path d="M2 12h20M12 2v20"/>'
    ),
    "list": (
        '<path d="M8 6h13M8 12h13M8 18h13"/>'
        '<path d="m3 6 .5.5L5 5M3 12l.5.5L5 11M3 18l.5.5L5 17"/>'
    ),
    "check": '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
    "alert": (
        '<path d="M10.3 3.7 2.5 17.2A2 2 0 0 0 4.2 20h15.6a2 2 0 0 0 1.7-2.8L13.7 3.7a2 2 0 0 0-3.4 0Z"/>'
        '<path d="M12 9v4M12 17h.01"/>'
    ),
    "gauge": (
        '<path d="M4.9 19a9 9 0 1 1 14.2 0"/><path d="m12 13 4-4"/>'
        '<path d="M12 19h.01"/>'
    ),
    "bars": '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    "donut": '<path d="M12 2a10 10 0 1 0 10 10"/><path d="M12 2v10h10"/>',
    "table": (
        '<rect x="3" y="4" width="18" height="16" rx="2"/>'
        '<path d="M3 10h18M9 4v16"/>'
    ),
    "shield": (
        '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>'
        '<path d="m9 12 2 2 4-4"/>'
    ),
    "file_scan": (
        '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>'
        '<path d="M14 2v6h6M8 13h8M8 17h5"/>'
    ),
    "x_circle": '<circle cx="12" cy="12" r="9"/><path d="m9 9 6 6M15 9l-6 6"/>',
    "database": (
        '<ellipse cx="12" cy="5" rx="8" ry="3"/>'
        '<path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6"/>'
    ),
    "eye": (
        '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z"/>'
        '<circle cx="12" cy="12" r="2.5"/>'
    ),
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
}


def icon(name, size=20):
    """Return a static, consistent outline SVG icon."""
    paths = ICON_PATHS.get(name, ICON_PATHS["activity"])
    return (
        f'<svg class="ats-icon" width="{int(size)}" height="{int(size)}" '
        'viewBox="0 0 24 24" fill="none" stroke="currentColor" '
        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" '
        f'aria-hidden="true" focusable="false">{paths}</svg>'
    )


def esc(value):
    """Escape all CSV-derived content before it enters HTML."""
    return html.escape(str(value))


def empty_state(title, detail):
    return (
        '<div class="ats-empty" role="status">'
        f'<div class="ats-empty-icon">{icon("eye", 20)}</div>'
        '<div>'
        f'<strong>{esc(title)}</strong>'
        f'<span>{esc(detail)}</span>'
        '</div></div>'
    )


def blocking_state(kind, title, detail, next_step):
    """Render a clear blocking state using native Streamlit feedback."""
    message = f"**{title}**\n\n{detail}\n\n**Check next:** {next_step}"
    if kind == "error":
        st.error(message)
    else:
        st.warning(message)


# ---------------------------------------------------------------------------
# Load and validate the processed results
# ---------------------------------------------------------------------------
if not os.path.exists(CSV_PATH):
    blocking_state(
        "error",
        "Processed results file not found",
        f"AnalyseTS could not locate {CSV_PATH}.",
        "Run the UiPath collection and Python validation stages, then confirm that "
        "processed_stock_results.csv is inside the output folder or beside this app.",
    )
    st.stop()

try:
    df = pd.read_csv(CSV_PATH)
except Exception as exc:
    blocking_state(
        "error",
        "Processed results could not be read",
        f"The file {CSV_PATH} exists, but pandas reported: {exc}",
        "Confirm that the file is a valid CSV, is not locked by another application, "
        "and still uses the expected AnalyseTS column headers.",
    )
    st.stop()

if df.empty:
    blocking_state(
        "warning",
        "Processed results file is empty",
        f"{CSV_PATH} contains column headers but no stock records.",
        "Complete the Browser/OCR and Python validation stages, then rerun this dashboard.",
    )
    st.stop()

for col in ["LatestPrice", "DailyChange", "PercentChange", "AbsPercentChange"]:
    if col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce")

summary = df.iloc[0]


# ---------------------------------------------------------------------------
# Data and formatting helpers
# ---------------------------------------------------------------------------
def safe(row, col, default="N/A"):
    value = row.get(col, default)
    if pd.isna(value) or value == "":
        return default
    return value


def num(row, col):
    value = row.get(col, None)
    if value is None or (not isinstance(value, str) and pd.isna(value)):
        return None
    try:
        return float(str(value).replace("%", "").replace(",", "").strip())
    except (TypeError, ValueError):
        return None


def whole(value, default="N/A"):
    if value is None or pd.isna(value):
        return default
    return str(int(round(value)))


def pct(value, default="N/A"):
    if value is None or pd.isna(value):
        return default
    return f"{value:+.2f}%"


def direction(value):
    if value is None or pd.isna(value):
        return "No movement data"
    if value > 0:
        return "Upward movement"
    if value < 0:
        return "Downward movement"
    return "No price movement"


def arrow(value):
    if value is None or pd.isna(value):
        return "—"
    if value > 0:
        return "↑"
    if value < 0:
        return "↓"
    return "•"


def latest_price_for(symbol):
    """Return the latest price for a symbol, or None when unavailable."""
    if symbol == "N/A" or "Symbol" not in df.columns or "LatestPrice" not in df.columns:
        return None
    matched = df.loc[
        df["Symbol"].astype(str).str.strip().str.upper()
        == str(symbol).strip().upper(),
        "LatestPrice",
    ].dropna()
    if matched.empty:
        return None
    return float(matched.iloc[0])


def money(value):
    if value is None or pd.isna(value):
        return "Price unavailable"
    return "$" + f"{value:,.2f}"


def money_change(value):
    if value is None or pd.isna(value):
        return "—"
    sign = "+" if value > 0 else "-" if value < 0 else ""
    return sign + "$" + f"{abs(float(value)):,.2f}"


def movement_card(title, symbol, value, price, descriptor, icon_name, tone):
    return (
        f'<article class="ats-card ats-movement-card {tone}" aria-label="{esc(title)}">'
        '<div class="ats-card-top">'
        f'<div class="ats-card-label">{esc(title)}</div>'
        f'<div class="ats-card-icon">{icon(icon_name, 18)}</div>'
        '</div>'
        f'<div class="ats-symbol">{esc(symbol)}</div>'
        '<div class="ats-movement-bottom">'
        '<div>'
        f'<div class="ats-price">{esc(money(price))}</div>'
        f'<div class="ats-descriptor">{esc(descriptor)}</div>'
        '</div><div>'
        f'<div class="ats-change">{esc(arrow(value))} {esc(pct(value))}</div>'
        f'<div class="ats-direction">{esc(direction(value))}</div>'
        '</div></div></article>'
    )


def stat_card(title, value, description, icon_name, tone, attention=False):
    attention_class = " is-attention" if attention else ""
    return (
        f'<article class="ats-card ats-kpi-card {tone}{attention_class}" '
        f'aria-label="{esc(title)}">'
        '<div class="ats-kpi-row"><div>'
        f'<div class="ats-card-label">{esc(title)}</div>'
        f'<div class="ats-kpi-value">{esc(value)}</div>'
        '</div>'
        f'<div class="ats-card-icon">{icon(icon_name, 18)}</div>'
        '</div>'
        f'<div class="ats-kpi-desc">{esc(description)}</div>'
        '</article>'
    )


def status_pill(value):
    text = str(value).strip()
    lower = text.lower()
    if "review" in lower or "pending" in lower:
        style, shown = "warn", "Manual Review Required"
    elif lower in {"valid", "up"} or "captured" in lower:
        style, shown = "good", text
    elif lower == "down" or "fail" in lower or "skipped" in lower:
        style, shown = "bad", text
    else:
        style, shown = "flat", text or "Unavailable"
    return f'<span class="ats-pill {style}">{esc(shown)}</span>'


def perf_cell(column, value):
    numeric_columns = ("LatestPrice", "DailyChange", "PercentChange")
    if pd.isna(value) or str(value).strip() == "":
        cell_class = ' class="num"' if column in numeric_columns else ""
        return f"<td{cell_class}>—</td>"
    if column == "Symbol":
        return f'<td class="sym">{esc(value)}</td>'
    if column == "CompanyName":
        return f'<td class="company">{esc(value)}</td>'
    if column == "LatestPrice":
        return '<td class="num">$' + f'{float(value):,.2f}</td>'
    if column == "DailyChange":
        number = float(value)
        sign_class = "ats-pos" if number > 0 else "ats-neg" if number < 0 else ""
        return f'<td class="num {sign_class}">{esc(money_change(number))}</td>'
    if column == "PercentChange":
        number = float(value)
        sign_class = "ats-pos" if number > 0 else "ats-neg" if number < 0 else ""
        return (
            f'<td class="num {sign_class}">'
            f'{esc(arrow(number))} {esc(pct(number))}</td>'
        )
    if column in ("MovementType", "ValidationStatus", "OCRStatus", "ReviewStatus"):
        return f"<td>{status_pill(value)}</td>"
    return f"<td>{esc(value)}</td>"


def build_table(rows, columns, label):
    header_cells = []
    for column, heading in columns:
        cell_class = (
            ' class="num"'
            if column in ("LatestPrice", "DailyChange", "PercentChange")
            else ""
        )
        header_cells.append(f'<th scope="col"{cell_class}>{esc(heading)}</th>')
    body_rows = []
    for _, row in rows.iterrows():
        cells = "".join(
            perf_cell(column, row.get(column, "")) for column, _ in columns
        )
        body_rows.append(f"<tr>{cells}</tr>")
    return (
        '<div class="ats-table-wrap" role="region" tabindex="0" '
        f'aria-label="{esc(label)}"><table class="ats-table">'
        f'<caption class="ats-sr-only">{esc(label)}</caption><thead><tr>'
        + "".join(header_cells)
        + "</tr></thead><tbody>"
        + "".join(body_rows)
        + "</tbody></table></div>"
    )


def style_fig(fig, height=380, showlegend=False):
    fig.update_layout(
        template="plotly_white",
        height=height,
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(
            family='system-ui, -apple-system, "Segoe UI", sans-serif',
            size=13,
            color=TEXT,
        ),
        margin=dict(t=8, b=58, l=14, r=22),
        showlegend=showlegend,
        hoverlabel=dict(
            bgcolor="#0F172A",
            bordercolor="#334155",
            font=dict(color="#FFFFFF", size=13),
        ),
        transition_duration=180,
    )
    fig.update_xaxes(
        automargin=True,
        gridcolor=GRID,
        linecolor="#CBD5E1",
        tickfont=dict(size=12, color="#334155"),
        title_font=dict(size=12, color=MUTED),
        zeroline=False,
    )
    fig.update_yaxes(
        automargin=True,
        gridcolor=GRID,
        linecolor="#CBD5E1",
        tickfont=dict(size=12, color="#334155"),
        title_font=dict(size=12, color=MUTED),
        zeroline=False,
    )
    return fig


def chart_heading(title, subtitle, icon_name, legend=False):
    legend_html = ""
    if legend:
        legend_html = (
            '<div class="ats-legend" aria-label="Movement legend">'
            '<span class="ats-legend-item">'
            f'<span class="ats-legend-dot" style="background:{POSITIVE};"></span>'
            'Positive movement</span>'
            '<span class="ats-legend-item">'
            f'<span class="ats-legend-dot" style="background:{NEGATIVE};"></span>'
            'Negative movement</span></div>'
        )
    return (
        '<div class="ats-section-head"><div class="ats-heading-wrap">'
        f'<div class="ats-heading-icon">{icon(icon_name, 18)}</div><div>'
        f'<h2>{esc(title)}</h2><p>{esc(subtitle)}</p>'
        '</div></div>'
        + legend_html
        + '</div>'
    )


def wrap_symbol_tick(value, max_line=10):
    """Wrap long symbols for Plotly while preserving the underlying value."""
    symbol = str(value)
    if len(symbol) <= max_line:
        return esc(symbol)
    parts = symbol.split("-")
    if len(parts) == 1:
        parts = [
            symbol[index:index + max_line]
            for index in range(0, len(symbol), max_line)
        ]
    lines, current = [], ""
    for part in parts:
        candidate = part if not current else f"{current}-{part}"
        if current and len(candidate) > max_line:
            lines.append(current)
            current = part
        else:
            current = candidate
    if current:
        lines.append(current)
    return "<br>".join(esc(line) for line in lines)


def price_hover_values(rows):
    if "LatestPrice" not in rows.columns:
        return [["Price unavailable"] for _ in range(len(rows))]
    return [[money(value)] for value in rows["LatestPrice"]]


# ---------------------------------------------------------------------------
# Existing AnalyseTS summary calculations
# ---------------------------------------------------------------------------
total_val = num(summary, "TotalRowsProcessed")
valid_val = num(summary, "ValidRows")
review_val = num(summary, "NeedsReviewRows")
mood = safe(summary, "OverallWatchlistMood", "Not available")
processed_at = safe(summary, "PythonProcessedAt", "")

gainer = safe(summary, "BiggestGainer", "N/A")
gainer_pct = num(summary, "BiggestGainerPercent")
drop = safe(summary, "BiggestDrop", "N/A")
drop_pct = num(summary, "BiggestDropPercent")
mover = safe(summary, "BiggestMover", "N/A")
mover_abs = num(summary, "BiggestMoverAbsPercent")

gainer_price = latest_price_for(gainer)
drop_price = latest_price_for(drop)
mover_price = latest_price_for(mover)

mover_signed = None
if mover != "N/A" and "Symbol" in df.columns and "PercentChange" in df.columns:
    matched = df.loc[
        df["Symbol"].astype(str).str.strip().str.upper()
        == str(mover).strip().upper(),
        "PercentChange",
    ].dropna()
    if not matched.empty:
        mover_signed = float(matched.iloc[0])
if mover_signed is None:
    mover_signed = mover_abs

success_rate_value = None
if total_val is not None and total_val > 0 and valid_val is not None:
    success_rate_value = max(0.0, min(100.0, (valid_val / total_val) * 100))
success_rate = (
    f"{success_rate_value:.1f}%" if success_rate_value is not None else "N/A"
)

chart_df = (
    df.dropna(subset=["PercentChange"]).copy()
    if "PercentChange" in df.columns
    else df.iloc[0:0].copy()
)
plot_config = {"displayModeBar": False, "responsive": True, "scrollZoom": False}

movements = (
    df["MovementType"].astype(str).str.strip().str.lower()
    if "MovementType" in df.columns
    else pd.Series(dtype="object")
)
up_count = int((movements == "up").sum())
down_count = int((movements == "down").sum())
priced_count = (
    int(df["PercentChange"].notna().sum())
    if "PercentChange" in df.columns
    else up_count + down_count
)


# ---------------------------------------------------------------------------
# Hero and RPA workflow
# ---------------------------------------------------------------------------
processed_text = (
    esc(processed_at)
    if processed_at and processed_at != "N/A"
    else "Not recorded"
)
hero_html = (
    '<header class="ats-hero">'
    '<div class="ats-hero-copy">'
    f'<div class="ats-brand-mark">{icon("activity", 26)}</div>'
    '<div class="ats-brand-copy">'
    '<div class="ats-eyebrow">UiPath-Orchestrated Market Monitoring</div>'
    '<div class="ats-title-line"><h1>AnalyseTS</h1>'
    '<div class="ats-hero-subtitle">Automated Stock Monitoring &amp; Reporting</div></div>'
    '<div class="ats-hero-value">'
    'Transforms watchlist data into validated, visual market summaries.'
    '</div>'
    '</div></div>'
    '<div class="ats-hero-meta" aria-label="Dashboard processing status">'
    '<span class="ats-ready"><span class="ats-ready-dot"></span>'
    'Analysis Ready</span>'
    f'<span class="ats-meta-item">{icon("clock", 15)} '
    f'Last processed: {processed_text}</span>'
    '</div></header>'
)
st.markdown(hero_html, unsafe_allow_html=True)

workflow_steps = [
    ("sheet", "Excel Watchlist", "Completed", "complete"),
    ("scan", "Browser + OCR", "Completed", "complete"),
    ("code", "CSV + Python Validation", "Completed", "complete"),
    ("dashboard", "Streamlit Dashboard", "Current stage", "current"),
    ("brain", "ChatGPT / LLM Digest", "Continues next", "upcoming"),
    ("send", "Discord Update", "Final delivery", "upcoming"),
]
steps_html = []
for step_icon, name, state, class_name in workflow_steps:
    steps_html.append(
        f'<div class="ats-step {class_name}">'
        f'<div class="ats-step-icon">{icon(step_icon, 17)}</div>'
        '<div>'
        f'<div class="ats-step-name">{esc(name)}</div>'
        f'<div class="ats-step-state">{esc(state)}</div>'
        '</div></div>'
    )

st.markdown(
    '<section class="ats-workflow" aria-label="UiPath automation workflow">'
    '<div class="ats-workflow-head">'
    f'<h2 class="ats-workflow-title">{icon("workflow", 17)} '
    'UiPath Automation Workflow</h2>'
    '<p class="ats-workflow-caption">'
    'UiPath coordinates collection, validation, visualisation and delivery.'
    '</p></div>'
    '<div class="ats-workflow-scroll" tabindex="0" '
    'aria-label="Scroll to view all six automation stages">'
    '<div class="ats-steps">'
    + "".join(steps_html)
    + '</div></div></section>',
    unsafe_allow_html=True,
)


# ---------------------------------------------------------------------------
# Overall watchlist mood
# ---------------------------------------------------------------------------
mood_text = str(mood).strip().lower()
if "bullish" in mood_text:
    mood_class, mood_icon = "bullish", "trend_up"
    mood_interpretation = (
        "More tracked stocks gained than declined in this processed run."
    )
elif "bearish" in mood_text:
    mood_class, mood_icon = "bearish", "trend_down"
    mood_interpretation = (
        "More tracked stocks declined than gained in this processed run."
    )
elif "mixed" in mood_text:
    mood_class, mood_icon = "mixed", "move"
    mood_interpretation = (
        "The watchlist produced a balanced or divided movement pattern."
    )
else:
    mood_class, mood_icon = "neutral", "activity"
    mood_interpretation = (
        "There is not enough valid movement data to determine the watchlist mood."
    )

st.markdown(
    f'<section class="ats-mood {mood_class}" aria-label="Overall watchlist mood">'
    f'<div class="ats-mood-icon">{icon(mood_icon, 22)}</div>'
    '<div><div class="ats-mood-label">Overall Watchlist Mood</div>'
    f'<div class="ats-mood-value">{esc(mood)}</div>'
    f'<div class="ats-mood-note">{esc(mood_interpretation)}</div></div>'
    '<div class="ats-mood-stats">'
    f'<div class="ats-mood-stat"><strong>{up_count}</strong>'
    '<span>Moved up</span></div>'
    f'<div class="ats-mood-stat"><strong>{down_count}</strong>'
    '<span>Moved down</span></div>'
    f'<div class="ats-mood-stat"><strong>{priced_count}</strong>'
    '<span>Priced</span></div>'
    '</div></section>',
    unsafe_allow_html=True,
)


# ---------------------------------------------------------------------------
# Primary movement cards
# ---------------------------------------------------------------------------
move_cols = st.columns(3, gap="medium")
with move_cols[0]:
    st.markdown(
        movement_card(
            "Biggest Gainer",
            gainer,
            gainer_pct,
            gainer_price,
            "Strongest positive move",
            "trend_up",
            "positive",
        ),
        unsafe_allow_html=True,
    )
with move_cols[1]:
    st.markdown(
        movement_card(
            "Biggest Drop",
            drop,
            drop_pct,
            drop_price,
            "Largest negative move",
            "trend_down",
            "negative",
        ),
        unsafe_allow_html=True,
    )
with move_cols[2]:
    st.markdown(
        movement_card(
            "Biggest Mover",
            mover,
            mover_signed,
            mover_price,
            "Highest absolute movement",
            "move",
            "indigo",
        ),
        unsafe_allow_html=True,
    )


# ---------------------------------------------------------------------------
# Processing KPI cards
# ---------------------------------------------------------------------------
review_attention = review_val is not None and review_val > 0
review_description = (
    "Manual review required" if review_attention else "No manual review required"
)
stat_cols = st.columns(4, gap="medium")
with stat_cols[0]:
    st.markdown(
        stat_card(
            "Stocks Processed",
            whole(total_val),
            "Total watchlist records",
            "list",
            "indigo",
        ),
        unsafe_allow_html=True,
    )
with stat_cols[1]:
    st.markdown(
        stat_card(
            "Valid",
            whole(valid_val),
            "Ready for analysis",
            "check",
            "positive",
        ),
        unsafe_allow_html=True,
    )
with stat_cols[2]:
    st.markdown(
        stat_card(
            "Needs Review",
            whole(review_val),
            review_description,
            "alert",
            "warning",
            review_attention,
        ),
        unsafe_allow_html=True,
    )
with stat_cols[3]:
    st.markdown(
        stat_card(
            "Success Rate",
            success_rate,
            "Valid processing rate",
            "gauge",
            "indigo",
        ),
        unsafe_allow_html=True,
    )


# ---------------------------------------------------------------------------
# Main percentage movement chart
# ---------------------------------------------------------------------------
with st.container(border=True):
    st.markdown(
        chart_heading(
            "Watchlist Movement",
            "Daily percentage movement for each successfully processed stock.",
            "bars",
            legend=True,
        ),
        unsafe_allow_html=True,
    )

    if not chart_df.empty and "Symbol" in chart_df.columns:
        chart_symbols = chart_df["Symbol"].astype(str).tolist()
        bar_colours = [
            POSITIVE if value >= 0 else NEGATIVE
            for value in chart_df["PercentChange"]
        ]
        bar_labels = [
            f"{value:+.2f}%" for value in chart_df["PercentChange"]
        ]
        fig = go.Figure(
            go.Bar(
                x=chart_symbols,
                y=chart_df["PercentChange"],
                customdata=price_hover_values(chart_df),
                marker=dict(color=bar_colours, line=dict(width=0)),
                text=bar_labels,
                textposition="outside",
                textfont=dict(size=12, color="#334155"),
                cliponaxis=False,
                hovertemplate=(
                    "<b>%{x}</b>"
                    "<br>Latest price: %{customdata[0]}"
                    "<br>Change: %{y:+.2f}%"
                    "<extra></extra>"
                ),
            )
        )
        fig.add_hline(y=0, line_color="#94A3B8", line_width=1.4)
        low = min(list(chart_df["PercentChange"]) + [0])
        high = max(list(chart_df["PercentChange"]) + [0])
        spread = high - low
        padding = max(
            spread * 0.22,
            max(abs(low), abs(high)) * 0.12,
            0.75,
        )
        fig.update_yaxes(
            title_text="Change (%)",
            ticksuffix="%",
            range=[low - padding, high + padding],
        )
        fig.update_xaxes(
            title_text="Stock symbol",
            tickmode="array",
            tickvals=chart_symbols,
            ticktext=[wrap_symbol_tick(symbol) for symbol in chart_symbols],
            tickangle=0,
        )
        style_fig(fig, height=310)
        st.plotly_chart(
            fig,
            use_container_width=True,
            config=plot_config,
            key="watchlist_movement",
        )
    else:
        st.markdown(
            empty_state(
                "No movement data available",
                "Check that PercentChange and Symbol contain valid processed values.",
            ),
            unsafe_allow_html=True,
        )