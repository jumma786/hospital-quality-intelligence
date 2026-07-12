[![CI](https://github.com/jumma786/sql_phase2_level2/actions/workflows/ci.yml/badge.svg)](https://github.com/jumma786/sql_phase2_level2/actions/workflows/ci.yml)

# Hospital Quality & Performance — SQL Analytics Capstone

A SQL analytics project that explores **U.S. hospital quality and performance** using public data from the **CMS Care Compare** program. The project answers **75 business questions** across **5 analytical perspectives**, progressing from simple lookups to multi-table window functions, CTEs, and reusable views — framed around a real end consumer: *a state health department's hospital quality oversight official.*

> **Stack:** Microsoft SQL Server (T-SQL) · SQL Server Management Studio / SQLEXPRESS

---

## Dataset

Public data published by the Centers for Medicare & Medicaid Services (CMS) via [data.cms.gov](https://data.cms.gov/provider-data/) — *Hospital Care Compare*:

| Table | Source file | Description |
|-------|-------------|-------------|
| `hospital_general_info` | `Hospital_General_Information.csv` | One row per hospital — location, type, ownership, emergency services, overall star rating, and mortality/safety/readmission measure counts |
| `timely_effective_care` | `Timely_and_Effective_Care-Hospital.csv` | Process-of-care measure scores by clinical condition |
| `hcahps_survey` | `HCAHPS-Hospital.csv` | HCAHPS patient-experience survey results (star ratings, response rates, completed surveys) |

> **Note:** The raw CSV files (~140 MB) are **not** committed to this repo (one exceeds GitHub's 100 MB limit). Download them from CMS at the link above and place them in the `data/` folder before running the import.

---

## The 5 Perspectives

Each perspective is a set of 15 questions graded **Easy → Medium → Difficult**:

1. **Geographic** — Where are the clusters of low-rated or underperforming hospitals? (counts/averages by state & county, state ranking, worst-hospital-per-state)
2. **Ownership & Facility Type** — How do outcomes differ by who runs the hospital? (for-profit vs. non-profit, critical access, per-type rating leaders)
3. **Clinical Quality & Safety** — Mortality, safety, and readmission outcomes, combined into a **composite risk score** and a national risk ranking
4. **Timeliness & Effective Care** — Process-of-care scores by condition, joined to hospital info, with period-over-period trend analysis (`LAG`)
5. **Patient Experience** — HCAHPS survey signals, and whether **higher-risk hospitals also have lower patient satisfaction**

The final query (**Q75**) unifies all three data sources into a single **national hospital scorecard**, blending risk, timeliness, and patient satisfaction into one ranked score.

---

## SQL Techniques Demonstrated

- Filtering, sorting, aggregation (`GROUP BY` / `HAVING`)
- Safe type handling on messy real-world data (`TRY_CAST`, `ISNULL`, `Not Available` guards)
- Conditional aggregation (`CASE`-based pivots)
- **Multi-table `JOIN`s** across all three datasets on `facility_id`
- **Common Table Expressions (CTEs)** — single and multi-CTE pipelines
- **Window functions** — `RANK()`, `ROW_NUMBER()`, `NTILE()`, and `LAG()` with `PARTITION BY`
- Correlated & scalar **subqueries** (above-national-average comparisons)
- Reusable **views** (`vw_state_hospital_summary`, `vw_hospital_risk_summary`, `vw_timely_care_summary`, `vw_patient_experience_summary`, and more)

---

## Repository Structure

```
sql_phase2_level2/
├── SQL_Phase2_Project.sql        # The 75 analytical queries (main deliverable)
├── data/
│   ├── setup_and_import.sql      # Creates the HospitalQuality DB + 3 tables
│   ├── import_csv.ps1            # Bulk-loads a CSV into a table (SqlBulkCopy)
│   ├── build_training_view.sql   # Supporting view
│   ├── check_lengths.ps1         # Column-length helper
│   └── *.csv                     # (not committed — download from CMS)
└── README.md
```

## How to Run

1. **Create the schema** — run `data/setup_and_import.sql` in SQL Server Management Studio (creates the `HospitalQuality` database and three tables).
2. **Download the CSVs** from [CMS Care Compare](https://data.cms.gov/provider-data/) into the `data/` folder.
3. **Import the data** — for each file, run the PowerShell loader:
   ```powershell
   ./data/import_csv.ps1 -CsvPath "./data/Hospital_General_Information.csv" -TableName "dbo.hospital_general_info"
   ./data/import_csv.ps1 -CsvPath "./data/Timely_and_Effective_Care-Hospital.csv" -TableName "dbo.timely_effective_care"
   ./data/import_csv.ps1 -CsvPath "./data/HCAHPS-Hospital.csv" -TableName "dbo.hcahps_survey"
   ```
   *(The script targets `localhost\SQLEXPRESS` with integrated security — adjust the connection string inside if your instance differs.)*
4. **Run the analysis** — open `SQL_Phase2_Project.sql` and execute the queries.

---

---

# Part 2 — Hospital Quality Intelligence (Machine Learning)

The SQL analysis answers *"what does the data say?"* This second phase turns it into a **decision-support product** that answers *"what should we do about it?"* — two models plus an interactive dashboard, living in [`ml/`](ml/).

## Business problems it solves

1. **Audit triage** *(regulator / health department)* — a ranked risk list so limited inspection resources go to the hospitals most likely to be underperforming.
2. **Improvement targeting** *(hospital administrator)* — SHAP explanations of *which controllable factors* associate with lower patient satisfaction.
3. **Benchmarking** *(insurer / payer)* — predicted-vs-actual performance to spot hospitals over/under-performing their peer profile.

## The two models

| Model | Task | Target | Test performance |
|-------|------|--------|------------------|
| **Patient-satisfaction model** | Regression (Random Forest) | Avg HCAHPS star rating | **R² = 0.44**, MAE = 0.47 stars |
| **Underperformer flag** | Classification (Random Forest) | Low-rated / worse-than-average hospital | **ROC-AUC = 0.90**, recall = 0.84 |

### ⚠️ Leakage discipline (the key design decision)
The CMS overall star rating is *mechanically derived* from the mortality/safety/readmission measure counts. Predicting the rating from those counts would produce a fake "perfect" model. Instead, both models are trained on **structural + patient-experience + process features only** (hospital type, ownership, location, emergency services, survey engagement, timely-care scores). The result is a lower — but **honest and interpretable** — model whose findings you can actually trust. The forbidden columns live in one place (`config.LEAKAGE_COLS`) and a unit test asserts they never reach the feature matrix.

### Model selection (5-fold cross-validated)
Every candidate is benchmarked against a trivial baseline it must beat, with `python src/compare_models.py`:

| Task | Metric | Baseline | Ridge / LogReg | HistGB | RandomForest | XGBoost |
|------|--------|:--------:|:--------------:|:------:|:------------:|:-------:|
| Satisfaction (regression) | R² | −0.07 | 0.36 | 0.39 | 0.39 | **0.40** |
| Underperformer (classification) | ROC-AUC | 0.50 | 0.72 | 0.72 | **0.83** | 0.74 |

*RandomForest is used in the shipped models for its top classification AUC and strong, stable regression score; XGBoost edges it slightly on regression R².*

## Explainability (SHAP)

| Drivers of patient satisfaction | Drivers of underperformer risk |
|---|---|
| ![Regression SHAP](ml/outputs/shap_regression.png) | ![Classification SHAP](ml/outputs/shap_classification.png) |

## How to run the ML pipeline

```bash
cd ml
pip install -r requirements.txt
python src/build_features.py     # 3 CSVs -> one per-hospital feature table
python src/compare_models.py     # 5-fold CV leaderboard vs. baselines
python src/train_models.py       # trains both models, SHAP plots, scored list
streamlit run app.py             # interactive dashboard
```

## Testing & CI

The cleaning logic and the leakage guard are covered by a `pytest` suite that runs on synthetic data (no raw CSVs needed), and **GitHub Actions runs it on every push** across Python 3.10 and 3.11:

```bash
pytest ml/tests -v
```

Tests assert, among other things, that missing-value tokens map to `NaN`, that the underperformer label logic is correct, and that **no leakage column can ever enter the feature matrix** — the kind of guarantee that keeps a model honest as the code changes.

The dashboard has three tabs: **Audit Triage** (ranked risk list by state), **Hospital Profile** (single-hospital drill-down), and **Model Card** (metrics + honest limitations).

## Honest limitations
- **Cross-sectional** data → associations, *not* causation; no forecasting claims.
- **Hospital-level aggregates** (~5,400 rows) → classical ML is the right call, not deep learning.
- Output is **decision-support for human reviewers**, not an automated verdict.

## ML project structure
```
ml/
├── src/config.py           # single source of truth: features, leakage rules, model roster
├── src/build_features.py   # feature engineering (long→wide, cleaning, leakage guard)
├── src/compare_models.py   # 5-fold CV benchmark vs. baselines -> leaderboard
├── src/train_models.py     # trains both models + SHAP + scored hospital list
├── app.py                  # Streamlit dashboard
├── tests/                  # pytest: cleaning, label logic, leakage guard, pipeline smoke
├── requirements.txt
└── outputs/                # SHAP pngs, metrics.json, leaderboard committed; models/CSVs regenerated
.github/workflows/ci.yml    # runs the test suite on every push (Py 3.10 & 3.11)
```

---

## Data Source & Attribution

Data courtesy of the **Centers for Medicare & Medicaid Services (CMS)**, *Hospital Care Compare*, published as public-domain U.S. government data at [data.cms.gov](https://data.cms.gov/provider-data/).
