# MLDP-C25U02-Apr2026

**Machine Learning for Developers (CAI2C08) — Term 2 Project Repository**
Diploma in Applied Artificial Intelligence · School of Informatics & IT · Temasek Polytechnic · AY2026/2027 April Semester

This repository is your working space for the **individual** MLDP project. Read this README in full before you start, and use your **own branch** for all your work (see [GitHub Workflow](#github-workflow) below).

---

## 1. The Scenario

> Imagine yourself as the **founder of a start-up**. Your mission is to use machine learning to solve a real-world problem and convince a potential **investor (your tutor)** of your solution.

You will **develop** a machine learning web app and **present** it convincingly. This simulates a real-world setting to prepare you for your Major Project, Student Internship Programme, and future industry roles — where you must communicate solutions to stakeholders, justify decisions with evidence, and adapt to changing business needs.

### Objectives
By completing this project, you will:
- identify problems suitable for machine learning;
- perform exploratory data analysis (EDA) using Python libraries;
- apply machine learning concepts and methods to write solutions in Python;
- deploy solutions to an online platform using Python and **Streamlit**;
- communicate your results clearly and respond to business challenges.

---

## 2. Weighting & Deadlines

This project contributes **70% to your overall subject grade** (total mark of 70). It is an **INDIVIDUAL** project with two components:

| # | Deliverable | Weight | Submit to | Due Date |
|---|-------------|:------:|-----------|----------|
| 1 | **Program Code** | **50%** | TP-LMS | **31 Jul (Fri), 5:00 pm** |
| 2 | **Demo & Presentation** (slides) | **20%** | TP-LMS / In classroom (**business attire**) | **Slides: 17 Aug (Mon), 5:00 pm** |

> ⚠️ **Late submission** penalties (deduction from the absolute mark): **< 1 day → −10%**, **≥ 1 and < 2 days → −20%**, **≥ 2 days → 0 marks**. "Day" **includes** non-working days (Sat, Sun, public holidays). **Laptop issues are not accepted** as a reason for extension — back up your work (this repo is part of that backup).

---

## 3. The Task

### 3.1 Identify a practical problem
Choose a topic that interests you and is a **practical real-world problem** addressable by **supervised** machine learning — e.g. finance, healthcare, marketing, logistics, services, manufacturing, sustainability, or cybersecurity.

### 3.2 Source & analyze data
- Find a **public dataset with at least 200 rows** (e.g. [UCI](https://archive.ics.uci.edu/ml/index.php), [Kaggle](https://www.kaggle.com), [HuggingFace](https://huggingface.co), [data.gov.sg](https://data.gov.sg), [Google Dataset Search](https://datasetsearch.research.google.com)).
- Dataset must have **multiple columns** for feature engineering / selection.
- Identify the target column(s) and determine whether it is a **regression** or **classification** task.
- **Do NOT use**: unstructured data (paragraphs of text), images, or **solely time-series** data (e.g. crypto / stock prices). The dataset must **not be synthetically generated**.
- Perform **EDA** to understand the data and its relevance to your problem.
- **Get your tutor's approval at Project Checkpoint 1** before building your solution.
- Make sure the scope is achievable by the deadline.

### 3.3 Develop your ML solution (Python 3)
- Implement models using **scikit-learn ONLY** — no other modelling libraries.
- Document your code, including the **rationale** for data preprocessing / feature engineering **and** algorithm / model selection.
- **Justify** your choice of evaluation metric(s).
- **Experiment with different models** (incl. feature engineering / selection), then tune the best model using **`RandomizedSearchCV` only**, with **no more than 3 values per hyperparameter**. Justify your final model based on evidence and business needs; state any assumptions.
- Show **all steps** used to train and evaluate your models, with outputs (graphs, logs).

### 3.4 Deploy your solution
- Build a **Streamlit** web app that is aesthetically appealing, user-friendly, and appropriate for the target audience.
- Prepare a Word document with the **web app link** and **three screenshots** of its functionality.

### 3.5 Pitch your solution
- Create a concise, compelling **pitch deck** (problem, key approach, results / business impact).
- **Present & demo** your web app to the investor (lecturer) as a compelling product.
- **Respond to questions and a case challenge** — handle concerns, overcome constraints, assess alternatives.

---

## 4. What to Submit

### Submission 1 — Program Code (50%) — *due 31 Jul*
A single **`.zip`** (not `.rar`) named `<TP-LMS Name>_<Student ID>.zip` (e.g. `Aiman Tan_2401234A.zip`) containing:

1. **Jupyter notebook (`.ipynb`)** — code, documentation (outputs, graphs, training logs, comments), analysis & justification.
2. **Streamlit app code (`.py`)**.
3. **Word document (`.docx`, use the given template)** with:
   - Declaration of Originality (cite any Gen AI use — this does not affect your marks);
   - Source of dataset; **GitHub link**; **Streamlit link**;
   - **3 screenshots**: (1) before any option is selected, (2) after an option is selected (shows a prediction), (3) after a different option is selected (shows a **changed** prediction);
   - Screenshots of version control / development logs (if applicable).

> Only the **latest** submission is graded. If resubmitting, re-zip **all** components. Upload early; do **not** submit an empty or corrupted zip.

### Submission 2 — Demo & Presentation Slides (20%) — *slides due 17 Aug*
A **`.pptx`** with a **maximum of 10 slides** (excluding cover & references). Suggested content: (1) Problem & Dataset, (2) Web App Demonstration, (3) Key Approach / Methods / Results & Impact, (4) Conclusion & Next Steps, (5) References. You have **up to 3 minutes** to pitch, followed by Q&A and a case challenge. (See the **MAPS framework** and Microsoft Presenter Coach links in TP-LMS to prepare.)

---

## 5. How You Are Scored

All percentages below are of your **overall subject grade**. Components sum to the project's **70%**.

### (1) Program Code — 50%

| Component | Sub-criteria | Weight | What earns top marks |
|-----------|--------------|:------:|----------------------|
| **Code Explanation & Documentation** | Code Clarity & Documentation | **4%** | Organized, readable code; **all** key steps clearly documented with the *why* and meaningful comments |
| | Version Control / Development Logs | **4%** | **Clear, observable iterative development** (e.g. commit history / logs) |
| **Iterative Model Development** *(34% total)* | Exploratory Data Analysis (EDA) & Interpretation | **8%** | Insightful, clearly-labelled visualisations; trends/outliers interpreted with **business-relevant** implications for modelling |
| | Model Diversity, Comparison & Selection Rationale | **8%** | **Two or more** distinct algorithms; test results **vs baseline**; quantitative + qualitative comparison; clear selection rationale |
| | Feature Engineering / Selection with Rationale | **10%** | Meaningful feature engineering/selection with changes clearly **explained** |
| | Hyperparameter Tuning | **4%** | Tune **two** hyperparameters; comparison logs/tables; impact explained; reproducible setup (`RandomizedSearchCV`) |
| | Evaluation Metric Selection, Interpretation & Justification | **4%** | Task-appropriate metric with a **clear link to the business outcome** |
| **Design of App & Deployment** *(8% total)* | Correct prediction without error | **2%** | Correct outputs for all tested cases; no crashes; input validation & user-facing error messages |
| | Interactive application | **6%** | Highly interactive, responsive, user-friendly; appealing visuals; labels suitable for the target audience |

### (2) Demo & Presentation — 20%

| Component | Sub-criteria | Weight | What earns top marks |
|-----------|--------------|:------:|----------------------|
| **Pitching Problem, Solution & Results** *(12% total)* | Slide Organization & Visuals | **4%** | Within slide limit; clear, well-organized slides; informative visuals with explanation |
| | Presentation Delivery & Preparedness | **4%** | Strictly on time; clear, confident, engaging; good eye contact / body language; **business attire** |
| | Solution Alignment & Convincing Justification | **4%** | Addresses the stated problem; links outcomes to **business value**; convincing, evidence-backed justification |
| **Response to Case & Questions** | Solution Comparison & Technical Justification | **8%** | Insightful, critical comparison of solution vs alternatives; clear, technically accurate justification |

> **Gen AI:** You may use Gen AI to generate ideas and prepare your pitch, but **do not** paste exact results unverified — verify all code, suggestions, and explanations; you are responsible for your own work. Cite any Gen AI use in your Declaration of Originality. See the ChatGPT Playbook (Student Edition) in TP-LMS.
>
> **Plagiarism** is reported and awarded **zero marks**, with further penalties up to dismissal. If two or more students are involved, the **same penalty applies to all** — including whoever allowed their work to be copied.

---

## 6. GitHub Workflow

You will use Git to track your work. Your commit history is **graded** under *Version Control / Development Logs (4%)* and provides a backup of your work, so commit and push **regularly**.

> 🔴 **Work only on YOUR OWN branch. Never push to `master`.**
> Everyone shares this one repository. If you push to `master`, you will overwrite the shared branch and clash with your classmates' work. Create a branch named after yourself (e.g. your Student ID) and keep **all** your work there. Marks come from *your* branch — pushing to the wrong place means your work may not be graded and may disrupt others.

### 6.1 Clone the repository (one-time setup)
```bash
git clone https://github.com/alvin-ps-tan/MLDP-C25U02-Apr2026.git
cd MLDP-C25U02-Apr2026
```

### 6.2 Create and switch to your own local branch
Name your branch with your Student ID (or name) so it is unique and easy to identify.
```bash
# Create a new branch and switch to it in one step
git checkout -b 2401234A

# Confirm which branch you are on (the * marks the current branch)
git branch
```
> If your branch already exists on GitHub, switch to it instead: `git checkout 2401234A`

### 6.3 Stage & commit your work (with good commit messages)
Stage the files you changed, then commit. Write **concise, descriptive** messages. Use the convention **`YYYY-MM-DD_majorchange`** so each commit is dated and states the major change.

```bash
# See what changed
git status

# Stage specific files (preferred) ...
git add notebook.ipynb app.py

# ... or stage everything that changed
git add .

# Commit with a dated, descriptive message
git commit -m "2026-06-30_added EDA and correlation heatmap"
```

**Good commit messages** (concise, dated, one major change each):
```
2026-07-02_cleaned data and handled missing values
2026-07-05_added baseline logistic regression model
2026-07-08_feature engineering: encoded categoricals, scaled numerics
2026-07-11_tuned random forest with RandomizedSearchCV
2026-07-15_built streamlit app with prediction form
```
**Avoid** vague messages like `update`, `changes`, `final`, `asdf`.

### 6.4 Push to YOUR remote branch
The **first** push creates your branch on GitHub and links it (`-u`). After that, a plain `git push` is enough.
```bash
# First push for this branch (creates it on GitHub):
git push -u origin 2401234A

# Every push afterwards:
git push
```
> ✅ Double-check you are pushing to **your** branch, not `master`. After pushing, open the repo on GitHub and confirm your commits appear under **your** branch.

### 6.5 Push regularly — at the end of every major change
**Do not wait until the deadline to push.** Commit and push at the end of **every major change** — after EDA, after a model, after feature engineering, after tuning, after the app, etc.

Pushing regularly:
- **backs up your work** off your laptop (laptop failure is *not* a valid excuse for late submission);
- builds the **commit history** that is graded for *iterative development*;
- lets your tutor see your progress at checkpoints;
- means you never lose more than your last small change.

A typical day's cycle:
```bash
git add .
git commit -m "2026-07-09_<the major change you just finished>"
git push
```

---

## 7. Quick Checklist

- [ ] Dataset approved by tutor at Checkpoint 1 (public, ≥ 200 rows, supervised, not synthetic, not text/image/pure time-series)
- [ ] Jupyter notebook: EDA, ≥ 2 models vs baseline, feature engineering, `RandomizedSearchCV` tuning, justified metric — all documented
- [ ] Streamlit app deployed, interactive, error-handled
- [ ] Word document: Declaration of Originality, dataset source, **GitHub link**, **Streamlit link**, 3 screenshots
- [ ] Slides (≤ 10) prepared; pitch rehearsed to ≤ 3 minutes; business attire ready
- [ ] All work committed and pushed to **your own branch** — and you verified it on GitHub
- [ ] Final `.zip` named `<TP-LMS Name>_<Student ID>.zip`, submitted to TP-LMS **before** the deadline
