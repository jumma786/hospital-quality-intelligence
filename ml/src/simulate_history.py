"""
simulate_history.py   ⚠️  DEMO / TESTING ONLY  ⚠️
--------------------------------------------------
CMS publishes hospital data as periodic *archived snapshots*. This project's
longitudinal pipeline (build_panel.py, trend_analysis.py) is designed to ingest
those real archives from `data/snapshots/<period>/`.

Until you download the real archives, this script fabricates a handful of prior
"quarters" by applying small random walks to the CURRENT snapshot's numeric
features, so the time-series code can be run and tested end to end.

>>> The output is SYNTHETIC and must NOT be presented as real CMS history. <<<
Every generated period is written under data/snapshots/SIM-* and every chart
built from it is watermarked. To use real data, drop the real CMS archive CSVs
into data/snapshots/<period>/ and skip this script entirely.

Run:
    python ml/src/simulate_history.py --periods 6
Outputs:
    data/snapshots/SIM-<period>/hospital_features.csv   (gitignored)
"""

from __future__ import annotations
import argparse
import pathlib
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_features import assemble  # noqa: E402

DATA_DIR = pathlib.Path(__file__).resolve().parents[2] / "data"
SNAP_DIR = DATA_DIR / "snapshots"

# Numeric features that plausibly drift period-over-period.
DRIFT_COLS = {
    "patient_star_avg": (0.12, 1, 5),
    "survey_response_rate": (2.5, 0, 100),
    "timely_care_avg": (2.0, 0, 100),
    "overall_rating": (0.15, 1, 5),
    "composite_risk_score": (0.4, 0, 12),
}


def simulate(periods: int, seed: int = 7) -> list[str]:
    current = assemble(DATA_DIR)
    rng = np.random.default_rng(seed)
    # Quarters ending most-recent-first, e.g. 2024Q4, 2024Q3, ...
    labels = [f"SIM-{2024 - (i // 4)}Q{4 - (i % 4)}" for i in range(periods)]
    labels = list(reversed(labels))  # oldest -> newest

    written = []
    for step, label in enumerate(labels):
        # Older periods sit further from "current"; add a mild systemic trend
        # (national quality slowly improving) plus per-hospital noise.
        lag = periods - 1 - step
        snap = current.copy()
        for col, (sigma, lo, hi) in DRIFT_COLS.items():
            if col not in snap.columns:
                continue
            trend = -0.03 * lag if col != "composite_risk_score" else 0.05 * lag
            noise = rng.normal(0, sigma, len(snap))
            snap[col] = (snap[col] + trend * snap[col].mean() + noise).clip(lo, hi)
        snap["period"] = label
        out = SNAP_DIR / label
        out.mkdir(parents=True, exist_ok=True)
        snap.to_csv(out / "hospital_features.csv", index=False)
        written.append(label)
    return written


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--periods", type=int, default=6)
    args = ap.parse_args()
    made = simulate(args.periods)
    print("[WARNING] SYNTHETIC demo history written (NOT real CMS data):")
    for label in made:
        print(f"   data/snapshots/{label}/hospital_features.csv")
    print("\nReplace with real CMS archived snapshots for genuine analysis.")
