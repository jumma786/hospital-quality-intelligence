"""
trend_analysis.py
-----------------
Turns the longitudinal panel into decision-useful trend signals:

  1. Per-hospital trajectory slopes (patient satisfaction & composite risk)
     via a simple linear fit over time -> an EARLY-WARNING flag for hospitals
     on a sustained downward path, before they show up as low-rated.
  2. National period-over-period trend for each tracked metric.
  3. A trend chart (watermarked if the panel contains simulated periods).

Run:
    python ml/src/trend_analysis.py
Outputs (ml/outputs/):
    hospital_trends.csv, national_trends.csv, national_trend.png
"""

from __future__ import annotations
import pathlib
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_panel import TREND_COLS  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[1] / "outputs"
PANEL = OUT / "hospital_panel.csv"

# A hospital is "declining" if its satisfaction is trending down while risk climbs.
SAT_DECLINE_SLOPE = -0.03    # stars per period
RISK_RISE_SLOPE = 0.05       # worse-measures per period


def _slope(y: pd.Series, t: np.ndarray) -> float:
    """Least-squares slope of y over time index t, ignoring NaNs."""
    mask = y.notna().values
    if mask.sum() < 2:
        return np.nan
    return float(np.polyfit(t[mask], y.values[mask], 1)[0])


def analyze() -> None:
    if not PANEL.exists():
        raise SystemExit("No panel found. Run `python ml/src/build_panel.py` first.")
    panel = pd.read_csv(PANEL)
    periods = sorted(panel["period"].unique())
    idx = {p: i for i, p in enumerate(periods)}
    panel["_t"] = panel["period"].map(idx)
    simulated = any(p.startswith("SIM-") for p in periods)

    # ---- 1. Per-hospital slopes + early-warning flag ----
    rows = []
    for fid, g in panel.groupby("facility_id"):
        t = g["_t"].values
        sat = _slope(g["patient_star_avg"], t) if "patient_star_avg" in g else np.nan
        risk = _slope(g["composite_risk_score"], t) if "composite_risk_score" in g else np.nan
        rows.append({
            "facility_id": fid,
            "facility_name": g["facility_name"].iloc[-1] if "facility_name" in g else fid,
            "state": g["state"].iloc[-1] if "state" in g else None,
            "satisfaction_slope": None if pd.isna(sat) else round(sat, 4),
            "risk_slope": None if pd.isna(risk) else round(risk, 4),
            "declining_trajectory": int(
                (pd.notna(sat) and sat < SAT_DECLINE_SLOPE)
                or (pd.notna(risk) and risk > RISK_RISE_SLOPE)
            ),
        })
    trends = pd.DataFrame(rows).sort_values("satisfaction_slope")
    trends.to_csv(OUT / "hospital_trends.csv", index=False)

    # ---- 2. National trend per metric ----
    nat = (panel.groupby("period")[[c for c in TREND_COLS if c in panel.columns]]
           .mean().reindex(periods).round(3))
    nat.to_csv(OUT / "national_trends.csv")

    # ---- 3. Chart ----
    fig, ax = plt.subplots(figsize=(9, 5))
    for col in ["patient_star_avg", "timely_care_avg", "overall_rating"]:
        if col in nat.columns:
            series = nat[col]
            ax.plot(range(len(periods)), series / series.iloc[0] * 100,
                    marker="o", label=col)
    ax.set_xticks(range(len(periods)))
    ax.set_xticklabels(periods, rotation=45, ha="right")
    ax.set_ylabel("Indexed to first period (=100)")
    ax.set_title("National quality metrics over time")
    ax.legend()
    ax.grid(alpha=0.3)
    if simulated:
        ax.text(0.5, 0.5, "SIMULATED DEMO DATA", transform=ax.transAxes,
                fontsize=34, color="red", alpha=0.18,
                ha="center", va="center", rotation=25, weight="bold")
    fig.tight_layout()
    fig.savefig(OUT / "national_trend.png", dpi=120)
    plt.close(fig)

    n_declining = int(trends["declining_trajectory"].sum())
    print(f"Analyzed {len(trends)} hospitals across {len(periods)} periods.")
    print(f"Early-warning (declining trajectory): {n_declining} hospitals flagged.")
    if simulated:
        print("[WARNING] Results include SIMULATED periods - demo only, not real CMS trends.")
    print(f"Saved hospital_trends.csv, national_trends.csv, national_trend.png -> {OUT}")


if __name__ == "__main__":
    analyze()
