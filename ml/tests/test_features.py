"""Unit tests for data cleaning and the leakage guard — the parts that,
if broken silently, would invalidate every downstream result."""
import numpy as np
import pandas as pd

import build_features
import config


def test_to_num_maps_missing_tokens_to_nan():
    s = pd.Series(["5", "3.2", "Not Available", "", "N/A", "100"])
    out = build_features._to_num(s)
    assert out.tolist()[:2] == [5.0, 3.2]
    assert out.isna().sum() == 3          # "Not Available", "", "N/A"
    assert out.iloc[-1] == 100.0


def test_underperformer_flag_logic():
    rating = pd.Series([1, 2, 3, 5, 4])
    worse = pd.Series([0, 0, 2, 0, 0])
    flag = config.underperformer_flag(rating, worse)
    # 1★ -> yes, 2★ -> yes, 3★ with a worse measure -> yes, 5★ clean -> no, 4★ clean -> no
    assert flag.tolist() == [1, 1, 1, 0, 0]


def test_regression_feature_matrix_has_no_leakage(synthetic_features):
    X = config.select_X(synthetic_features, "regression")
    for col in config.LEAKAGE_COLS:
        assert col not in X.columns, f"leakage column {col} leaked into regression X"


def test_classification_keeps_patient_star_but_drops_targets(synthetic_features):
    X = config.select_X(synthetic_features, "classification")
    assert "patient_star_avg" in X.columns          # legitimate experience predictor
    assert "is_underperformer" not in X.columns      # the target
    assert "overall_rating" not in X.columns          # leakage source
    assert "_mort_worse" not in X.columns


def test_select_X_rejects_bad_task(synthetic_features):
    import pytest
    with pytest.raises(ValueError):
        config.select_X(synthetic_features, "clustering")
