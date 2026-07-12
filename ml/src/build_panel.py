"""
build_panel.py
--------------
Ingests every period under data/snapshots/<period>/ into ONE longitudinal panel
(one row per hospital per period) and computes period-over-period changes.

Each snapshot dir may contain EITHER:
  * the raw CMS archive CSVs (Hospital_General_Information.csv, ...), which are
    assembled with build_features.assemble(); OR
  * a pre-built hospital_features.csv (what simulate_history.py writes).

Run:
    python ml/src/build_panel.py
Outputs:
    ml/outputs/hospital_panel.csv
"""

from __future__ import annotations
import pathlib
import sys

import pandas as pd

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_features import assemble  # noqa: E402

DATA_DIR = pathlib.Path(__file__).resolve().parents[2] / "data"
SNAP_DIR = DATA_DIR / "snapshots"
OUT = pathlib.Path(__file__).resolve().parents[1] / "outputs"

TREND_COLS = ["patient_star_avg", "survey_response_rate", "timely_care_avg",
              "overall_rating", "composite_risk_score"]


def _load_period(period_dir: pathlib.Path) -> pd.DataFrame:
    prebuilt = period_dir / "hospital_features.csv"
    if prebuilt.exists():
        df = pd.read_csv(prebuilt)
    elif (period_dir / "Hospital_General_Information.csv").exists():
        df = assemble(period_dir)
    else:
        raise FileNotFoundError(f"No recognizable data in {period_dir}")
    df["period"] = period_dir.name
    return df


def build_panel() -> pd.DataFrame:
    if not SNAP_DIR.exists():
        raise SystemExit(
            f"No snapshots found at {SNAP_DIR}.\n"
            "Add real CMS archived snapshots (one folder per period), or run "
            "`python ml/src/simulate_history.py` to generate demo history first."
        )
    period_dirs = sorted(p for p in SNAP_DIR.iterdir() if p.is_dir())
    if not period_dirs:
        raise SystemExit(f"{SNAP_DIR} exists but contains no period folders.")

    panel = pd.concat([_load_period(p) for p in period_dirs], ignore_index=True)
    # Chronological order matters for the LAG-style deltas.
    panel = panel.sort_values(["facility_id", "period"]).reset_index(drop=True)

    # Period-over-period change per hospital for each tracked metric.
    for col in TREND_COLS:
        if col in panel.columns:
            panel[f"{col}_delta"] = panel.groupby("facility_id")[col].diff()

    OUT.mkdir(parents=True, exist_ok=True)
    panel.to_csv(OUT / "hospital_panel.csv", index=False)
    return panel


if __name__ == "__main__":
    p = build_panel()
    periods = sorted(p["period"].unique())
    print(f"Built panel: {len(p)} rows | {p['facility_id'].nunique()} hospitals "
          f"× {len(periods)} periods")
    print(f"Periods: {', '.join(periods)}")
    if any(x.startswith("SIM-") for x in periods):
        print("[WARNING] Panel includes SIMULATED periods (SIM-*) - demo only, not real CMS history.")
    print(f"Saved -> {OUT / 'hospital_panel.csv'}")
