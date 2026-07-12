"""Tests for the longitudinal pipeline: panel assembly, period-over-period
deltas, and trend-slope computation — all on synthetic multi-period data."""
import numpy as np
import pandas as pd


def test_slope_recovers_known_trend():
    import trend_analysis
    t = np.array([0, 1, 2, 3])
    y = pd.Series([2.0, 3.0, 4.0, 5.0])          # slope of exactly 1.0
    assert np.isclose(trend_analysis._slope(y, t), 1.0)


def test_slope_needs_at_least_two_points():
    import trend_analysis
    t = np.array([0, 1, 2])
    y = pd.Series([np.nan, 5.0, np.nan])          # only one real point
    assert np.isnan(trend_analysis._slope(y, t))


def test_build_panel_stacks_periods_and_computes_deltas(tmp_path, monkeypatch, synthetic_features):
    import build_panel

    snap = tmp_path / "snapshots"
    # Two periods; each hospital's satisfaction rises by exactly 1.0 star.
    for i, period in enumerate(["2024Q1", "2024Q2"]):
        d = snap / period
        d.mkdir(parents=True)
        frame = synthetic_features.copy()
        frame["patient_star_avg"] = frame["patient_star_avg"] + i
        frame.to_csv(d / "hospital_features.csv", index=False)

    monkeypatch.setattr(build_panel, "SNAP_DIR", snap)
    monkeypatch.setattr(build_panel, "OUT", tmp_path / "out")

    panel = build_panel.build_panel()
    assert panel["period"].nunique() == 2
    assert panel["facility_id"].nunique() == len(synthetic_features)
    assert "patient_star_avg_delta" in panel.columns

    # Every second-period row should show a +1.0 delta; first period is NaN.
    deltas = panel["patient_star_avg_delta"].dropna()
    assert len(deltas) == len(synthetic_features)
    assert np.allclose(deltas.values, 1.0)


def test_build_panel_errors_without_snapshots(tmp_path, monkeypatch):
    import build_panel
    monkeypatch.setattr(build_panel, "SNAP_DIR", tmp_path / "nope")
    try:
        build_panel.build_panel()
        assert False, "expected SystemExit when no snapshots exist"
    except SystemExit:
        pass
