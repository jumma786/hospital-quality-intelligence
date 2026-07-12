"""
config.py
---------
Single source of truth for the modeling setup: which columns are features,
which are forbidden (leakage/targets), how the preprocessor is built, and
which candidate models compete. Both train_models.py and compare_models.py
import from here so the leakage rules can never drift between them — and the
test suite imports the same functions to *prove* the rules hold.
"""

from __future__ import annotations

from sklearn.compose import ColumnTransformer
from sklearn.dummy import DummyClassifier, DummyRegressor
from sklearn.ensemble import (
    HistGradientBoostingClassifier,
    HistGradientBoostingRegressor,
    RandomForestClassifier,
    RandomForestRegressor,
)
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

CATEGORICAL = ["state", "hospital_type", "hospital_ownership"]

REG_NUMERIC = ["emergency_services", "survey_response_rate", "completed_surveys", "timely_care_avg"]
CLF_NUMERIC = REG_NUMERIC + ["patient_star_avg"]

# Columns never allowed as predictors: identifiers, targets, and the
# worse-measure counts that mechanically define the CMS overall rating.
LEAKAGE_COLS = [
    "facility_id", "facility_name", "county",
    "overall_rating", "_mort_worse", "_safety_worse", "_readm_worse",
    "composite_risk_score", "is_underperformer", "patient_star_avg",
]


def select_X(df, task: str):
    """Return the feature frame for a task with all leakage/target columns removed.

    For classification we *keep* patient_star_avg (a legitimate experience
    predictor); for regression it is the target and must be dropped.
    """
    if task not in {"regression", "classification"}:
        raise ValueError(f"task must be 'regression' or 'classification', got {task!r}")
    keep_star = task == "classification"
    drop = [
        c for c in LEAKAGE_COLS
        if c in df.columns and not (keep_star and c == "patient_star_avg")
    ]
    return df.drop(columns=drop)


def make_preprocessor(numeric_cols) -> ColumnTransformer:
    return ColumnTransformer(
        transformers=[
            ("cat", OneHotEncoder(handle_unknown="ignore", min_frequency=25,
                                  sparse_output=False), CATEGORICAL),
            ("num", Pipeline([("impute", SimpleImputer(strategy="median")),
                              ("scale", StandardScaler())]), numeric_cols),
        ]
    )


def feature_names(fitted_preprocessor, numeric_cols):
    ohe = fitted_preprocessor.named_transformers_["cat"]
    return list(ohe.get_feature_names_out(CATEGORICAL)) + list(numeric_cols)


def underperformer_flag(overall_rating, worse_total):
    """Label logic, isolated so it can be unit-tested without the raw CSVs."""
    return ((overall_rating <= 2) | (worse_total > 0)).astype(int)


def candidate_models(task: str) -> dict:
    """Model leaderboard entries. A trivial baseline is always first so every
    real model must prove it beats predicting the mean / majority class."""
    if task == "regression":
        models = {
            "Baseline (mean)": DummyRegressor(strategy="mean"),
            "Ridge": Ridge(alpha=1.0),
            "RandomForest": RandomForestRegressor(
                n_estimators=300, min_samples_leaf=5, random_state=42, n_jobs=-1),
            "HistGradientBoosting": HistGradientBoostingRegressor(random_state=42),
        }
    elif task == "classification":
        models = {
            "Baseline (majority)": DummyClassifier(strategy="most_frequent"),
            "LogisticRegression": LogisticRegression(max_iter=1000, class_weight="balanced"),
            "RandomForest": RandomForestClassifier(
                n_estimators=300, min_samples_leaf=5, class_weight="balanced",
                random_state=42, n_jobs=-1),
            "HistGradientBoosting": HistGradientBoostingClassifier(random_state=42),
        }
    else:
        raise ValueError(f"unknown task {task!r}")

    # Optional: add XGBoost only if it's installed (keeps CI light).
    try:
        import xgboost as xgb  # noqa: F401
        if task == "regression":
            models["XGBoost"] = xgb.XGBRegressor(
                n_estimators=400, max_depth=5, learning_rate=0.05, random_state=42)
        else:
            models["XGBoost"] = xgb.XGBClassifier(
                n_estimators=400, max_depth=5, learning_rate=0.05,
                eval_metric="logloss", random_state=42)
    except Exception:
        pass

    return models
