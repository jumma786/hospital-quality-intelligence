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

## Data Source & Attribution

Data courtesy of the **Centers for Medicare & Medicaid Services (CMS)**, *Hospital Care Compare*, published as public-domain U.S. government data at [data.cms.gov](https://data.cms.gov/provider-data/).
