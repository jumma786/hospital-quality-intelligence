"""
train_models.py
----------------
Trains the two models that make up the Hospital Quality Intelligence tool:

  1. REGRESSION  -> predict a hospital's average patient-satisfaction star
     (HCAHPS) from STRUCTURAL + process features.  We deliberately exclude
     the CMS overall rating and the worse-measure counts so the model finds
     genuine drivers instead of leaking the answer.

  2. CLASSIFICATION -> flag likely "underperformers" for audit triage,
     again from features that do NOT mechanically define the label.

Also computes SHAP values so we can explain *why* a hospital scores as it
does, and writes a ranked risk list for the Streamlit dashboard.

Run:
    python ml/src/train_models.py
Outputs (ml/outputs/):
    reg_model.joblib, clf_model.joblib
    shap_regression.png, shap_classification.png
    scored_hospitals.csv, metrics.json
"""

from __future__ import annotations
import json
import pathlib
import sys
import warnings

import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import shap
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import (
    classification_report,
    mean_absolute_error,
    r2_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import config  # noqa: E402
from config import LEAKAGE_COLS, feature_names, make_preprocessor  # noqa: E402

warnings.filterwarnings("ignore")

OUT = pathlib.Path(__file__).resolve().parents[1] / "outputs"
FEATURES = OUT / "hospital_features.csv"


def shap_summary(model, preprocessor, X, numeric_cols, title, path):
    Xt = preprocessor.transform(X)
    if hasattr(Xt, "toarray"):
        Xt = Xt.toarray()
    names = feature_names(preprocessor, numeric_cols)
    sample = shap.utils.sample(Xt, min(500, Xt.shape[0]), random_state=42)
    explainer = shap.TreeExplainer(model)
    sv = explainer.shap_values(sample)
    if isinstance(sv, list):          # classifier returns per-class; take positive class
        sv = sv[1]
    if sv.ndim == 3:                  # (n, features, classes)
        sv = sv[:, :, 1]
    plt.figure()
    shap.summary_plot(sv, sample, feature_names=names, show=False, max_display=12)
    plt.title(title)
    plt.tight_layout()
    plt.savefig(path, dpi=120, bbox_inches="tight")
    plt.close()


def main():
    df = pd.read_csv(FEATURES)
    metrics = {}

    # ================= 1. REGRESSION: patient satisfaction =================
    reg_num = ["emergency_services", "survey_response_rate", "completed_surveys", "timely_care_avg"]
    reg = df.dropna(subset=["patient_star_avg"]).copy()
    Xr = reg.drop(columns=[c for c in LEAKAGE_COLS if c in reg.columns])
    yr = reg["patient_star_avg"]

    pre_r = make_preprocessor(reg_num)
    Xr_tr, Xr_te, yr_tr, yr_te = train_test_split(Xr, yr, test_size=0.2, random_state=42)
    pre_r.fit(Xr_tr)
    reg_model = RandomForestRegressor(n_estimators=300, min_samples_leaf=5, random_state=42, n_jobs=-1)
    reg_model.fit(pre_r.transform(Xr_tr), yr_tr)
    pred_r = reg_model.predict(pre_r.transform(Xr_te))
    metrics["regression"] = {
        "target": "patient_star_avg",
        "n_train": int(len(Xr_tr)), "n_test": int(len(Xr_te)),
        "r2": round(float(r2_score(yr_te, pred_r)), 3),
        "mae_stars": round(float(mean_absolute_error(yr_te, pred_r)), 3),
    }
    joblib.dump({"pre": pre_r, "model": reg_model, "num": reg_num}, OUT / "reg_model.joblib")
    shap_summary(reg_model, pre_r, Xr_tr, reg_num,
                 "Drivers of patient satisfaction (SHAP)", OUT / "shap_regression.png")

    # ================= 2. CLASSIFICATION: underperformer flag =================
    clf_num = ["emergency_services", "survey_response_rate", "completed_surveys",
               "timely_care_avg", "patient_star_avg"]
    clf = df.copy()
    drop_c = [c for c in LEAKAGE_COLS if c in clf.columns and c != "patient_star_avg"]
    Xc = clf.drop(columns=drop_c)
    yc = clf["is_underperformer"]

    pre_c = make_preprocessor(clf_num)
    Xc_tr, Xc_te, yc_tr, yc_te = train_test_split(Xc, yc, test_size=0.2, random_state=42, stratify=yc)
    pre_c.fit(Xc_tr)
    clf_model = RandomForestClassifier(n_estimators=300, min_samples_leaf=5,
                                       class_weight="balanced", random_state=42, n_jobs=-1)
    clf_model.fit(pre_c.transform(Xc_tr), yc_tr)
    proba = clf_model.predict_proba(pre_c.transform(Xc_te))[:, 1]
    pred_c = (proba >= 0.5).astype(int)
    metrics["classification"] = {
        "target": "is_underperformer",
        "n_train": int(len(Xc_tr)), "n_test": int(len(Xc_te)),
        "roc_auc": round(float(roc_auc_score(yc_te, proba)), 3),
        "report": classification_report(yc_te, pred_c, output_dict=True, zero_division=0),
    }
    joblib.dump({"pre": pre_c, "model": clf_model, "num": clf_num}, OUT / "clf_model.joblib")
    shap_summary(clf_model, pre_c, Xc_tr, clf_num,
                 "Drivers of underperformer risk (SHAP)", OUT / "shap_classification.png")

    # ================= 3. Score every hospital for the dashboard =================
    all_risk = clf_model.predict_proba(pre_c.transform(Xc))[:, 1]
    scored = df[["facility_id", "facility_name", "state", "hospital_type",
                 "hospital_ownership", "overall_rating", "patient_star_avg"]].copy()
    scored["predicted_risk"] = all_risk.round(3)
    scored["risk_rank"] = scored["predicted_risk"].rank(ascending=False, method="min").astype(int)
    scored.sort_values("predicted_risk", ascending=False).to_csv(
        OUT / "scored_hospitals.csv", index=False)

    with open(OUT / "metrics.json", "w") as f:
        json.dump(metrics, f, indent=2)

    print("=== Regression (patient satisfaction) ===")
    print(f"  R^2 = {metrics['regression']['r2']}  |  MAE = {metrics['regression']['mae_stars']} stars")
    print("=== Classification (underperformer flag) ===")
    c = metrics["classification"]
    print(f"  ROC-AUC = {c['roc_auc']}  |  precision(1) = "
          f"{c['report']['1']['precision']:.3f}  recall(1) = {c['report']['1']['recall']:.3f}")
    print(f"\nSaved models, SHAP plots, scored_hospitals.csv, metrics.json -> {OUT}")


if __name__ == "__main__":
    main()
