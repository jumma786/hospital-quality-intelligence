"""Make ml/src importable and provide a synthetic feature fixture (no raw CSVs needed)."""
import pathlib
import sys

import numpy as np
import pandas as pd
import pytest

SRC = pathlib.Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC))


@pytest.fixture
def synthetic_features():
    """A small, realistic per-hospital feature frame mirroring build_features output."""
    rng = np.random.default_rng(0)
    n = 120
    return pd.DataFrame({
        "facility_id": [f"H{i:04d}" for i in range(n)],
        "facility_name": [f"Hospital {i}" for i in range(n)],
        "state": rng.choice(["CA", "TX", "NY", "FL"], n),
        "county": rng.choice(["A", "B", "C"], n),
        "hospital_type": rng.choice(["Acute Care Hospitals", "Critical Access Hospitals"], n),
        "hospital_ownership": rng.choice(["Proprietary", "Government - State", "Voluntary non-profit - Private"], n),
        "emergency_services": rng.integers(0, 2, n),
        "overall_rating": rng.integers(1, 6, n).astype(float),
        "_mort_worse": rng.integers(0, 3, n).astype(float),
        "_safety_worse": rng.integers(0, 3, n).astype(float),
        "_readm_worse": rng.integers(0, 3, n).astype(float),
        "patient_star_avg": rng.uniform(1, 5, n).round(1),
        "survey_response_rate": rng.uniform(10, 50, n),
        "completed_surveys": rng.integers(50, 5000, n).astype(float),
        "timely_care_avg": rng.uniform(40, 100, n),
        "composite_risk_score": rng.integers(0, 6, n),
        "is_underperformer": rng.integers(0, 2, n),
    })
