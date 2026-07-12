"""
build_features.py
-----------------
Turns the three raw CMS Care Compare CSVs into ONE clean, per-hospital
feature table used by every model in this project.

Design decisions (interview-ready):
  * Long -> wide reshaping of HCAHPS and Timely-Effective-Care so each
    hospital becomes a single row of features.
  * "Not Available" / blank strings are coerced to NaN, then numeric
    columns are cast safely.
  * LEAKAGE GUARD: the mortality/safety/readmission "worse" counts
    mechanically feed the CMS overall star rating, so we keep them ONLY
    for the underperformer-flag target engineering, and expose a
    STRUCTURAL feature set that excludes them for the satisfaction model.

Run:
    python ml/src/build_features.py
Outputs:
    ml/outputs/hospital_features.csv
"""

from __future__ import annotations
import pathlib
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from config import underperformer_flag  # noqa: E402

DATA_DIR = pathlib.Path(__file__).resolve().parents[2] / "data"
OUT_DIR = pathlib.Path(__file__).resolve().parents[1] / "outputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)

MISSING_TOKENS = {"Not Available", "Not Applicable", "", "N/A", "NA", "*"}


def _read_csv(path: pathlib.Path) -> pd.DataFrame:
    """Read a CMS CSV as strings, tolerant of encoding drift across years.
    Newer releases are UTF-8; older ones (≤2023) are Windows-1252/latin-1."""
    for enc in ("utf-8-sig", "latin-1"):
        try:
            df = pd.read_csv(path, dtype=str, encoding=enc)
            break
        except UnicodeDecodeError:
            continue
    return df.rename(columns=lambda c: c.strip())


def _to_num(series: pd.Series) -> pd.Series:
    """Coerce a CMS text column to numeric, mapping missing tokens to NaN."""
    cleaned = series.astype(str).str.strip()
    cleaned = cleaned.where(~cleaned.isin(MISSING_TOKENS), np.nan)
    return pd.to_numeric(cleaned, errors="coerce")


def _pick(df: pd.DataFrame, *names) -> pd.Series | None:
    """First matching column across CMS schema versions (columns get renamed over years)."""
    for n in names:
        if n in df.columns:
            return df[n]
    return None


def _pick_num(df: pd.DataFrame, *names) -> pd.Series:
    """Numeric version of a possibly-absent column; all-NaN if none of the names exist.
    Older CMS schemas (≤2021) lack the numeric worse-measure counts entirely."""
    s = _pick(df, *names)
    return _to_num(s) if s is not None else pd.Series(np.nan, index=df.index)


def load_general(data_dir: pathlib.Path = DATA_DIR) -> pd.DataFrame:
    df = _read_csv(data_dir / "Hospital_General_Information.csv")
    county = _pick(df, "County/Parish", "County Name")
    out = pd.DataFrame(
        {
            "facility_id": df["Facility ID"].str.strip(),
            "facility_name": df["Facility Name"].str.strip(),
            "state": df["State"].str.strip(),
            "county": county.str.strip() if county is not None else "",
            "hospital_type": df["Hospital Type"].str.strip(),
            "hospital_ownership": df["Hospital Ownership"].str.strip(),
            "emergency_services": (df["Emergency Services"].str.strip() == "Yes").astype(int),
            "overall_rating": _to_num(df["Hospital overall rating"]),
            # kept ONLY for target engineering (leakage-prone) -> dropped from X later.
            # Absent in older schemas -> all-NaN, handled downstream in assemble().
            "_mort_worse": _pick_num(df, "Count of MORT Measures Worse"),
            "_safety_worse": _pick_num(df, "Count of Safety Measures Worse"),
            "_readm_worse": _pick_num(df, "Count of READM Measures Worse"),
        }
    )
    return out.drop_duplicates("facility_id")


def load_hcahps(data_dir: pathlib.Path = DATA_DIR) -> pd.DataFrame:
    """Pivot HCAHPS to one row/hospital. Target = mean patient star rating."""
    df = _read_csv(data_dir / "HCAHPS-Hospital.csv")
    df["fid"] = df["Facility ID"].str.strip()
    df["star"] = _to_num(df["Patient Survey Star Rating"])
    df["resp_rate"] = _to_num(df["Survey Response Rate Percent"])
    df["completed"] = _to_num(df["Number of Completed Surveys"])

    grp = df.groupby("fid")
    out = pd.DataFrame(
        {
            "patient_star_avg": grp["star"].mean(),          # <- regression TARGET
            "survey_response_rate": grp["resp_rate"].max(),
            "completed_surveys": grp["completed"].max(),
        }
    ).reset_index().rename(columns={"fid": "facility_id"})
    return out


def load_timely(data_dir: pathlib.Path = DATA_DIR) -> pd.DataFrame:
    """Average timely/effective-care score per hospital (0-100 process measures)."""
    df = _read_csv(data_dir / "Timely_and_Effective_Care-Hospital.csv")
    df["fid"] = df["Facility ID"].str.strip()
    df["score"] = _to_num(df["Score"])
    # keep only 0-100 style process scores to avoid mixing minute-based measures
    df = df[df["score"].between(0, 100)]
    out = (
        df.groupby("fid")["score"].mean()
        .reset_index()
        .rename(columns={"fid": "facility_id", "score": "timely_care_avg"})
    )
    return out


def assemble(data_dir: pathlib.Path = DATA_DIR) -> pd.DataFrame:
    """Merge the three sources into one per-hospital feature frame + targets.
    Reusable for a single snapshot OR one period of the longitudinal panel."""
    gen = load_general(data_dir)
    hcahps = load_hcahps(data_dir)
    timely = load_timely(data_dir)

    df = gen.merge(hcahps, on="facility_id", how="left").merge(
        timely, on="facility_id", how="left"
    )

    # --- Target 2: underperformer flag (uses the leakage-prone worse-counts) ---
    worse = df[["_mort_worse", "_safety_worse", "_readm_worse"]]
    worse_total = worse.fillna(0).sum(axis=1)
    # Older CMS schemas (≤2022) lack the numeric worse-counts entirely -> record the
    # composite risk as NaN (genuinely unknown) rather than a misleading 0.
    has_counts = bool(worse.notna().to_numpy().any())
    df["composite_risk_score"] = worse_total if has_counts else np.nan
    # "Underperformer" = low overall rating (1-2 stars) OR any worse-than-avg measure
    df["is_underperformer"] = underperformer_flag(df["overall_rating"], worse_total)
    return df


def build() -> pd.DataFrame:
    df = assemble(DATA_DIR)
    df.to_csv(OUT_DIR / "hospital_features.csv", index=False)
    return df


if __name__ == "__main__":
    result = build()
    n = len(result)
    print(f"Built feature table: {n} hospitals -> ml/outputs/hospital_features.csv")
    print("\nColumn coverage (non-null %):")
    print((result.notna().mean() * 100).round(1).to_string())
    print("\nTarget balance (is_underperformer):")
    print(result["is_underperformer"].value_counts(normalize=True).round(3).to_string())
