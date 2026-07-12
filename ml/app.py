"""
Hospital Quality Intelligence - Streamlit dashboard
---------------------------------------------------
Interactive front-end for the two models trained in ml/src/train_models.py.

Run:
    streamlit run ml/app.py

Tabs:
  1. Audit Triage  - ranked risk list for a chosen state (the "who to inspect" tool)
  2. Hospital Profile - pick a hospital, see predicted satisfaction, risk, and drivers
  3. Model Card     - metrics + honest limitations
"""

from __future__ import annotations
import json
import pathlib

import pandas as pd
import streamlit as st

OUT = pathlib.Path(__file__).resolve().parent / "outputs"

st.set_page_config(page_title="Hospital Quality Intelligence", layout="wide")


@st.cache_data
def load():
    # The app reads precomputed model outputs (committed to the repo) so it
    # deploys to Streamlit Cloud without needing the raw CSVs or the trained
    # .joblib models. Regenerate these via ml/src/build_features.py + train_models.py.
    scored = pd.read_csv(OUT / "scored_hospitals.csv")
    feats = pd.read_csv(OUT / "hospital_features.csv")
    metrics = json.loads((OUT / "metrics.json").read_text())
    return scored, feats, metrics


scored, feats, metrics = load()

st.title("🏥 Hospital Quality Intelligence")
st.caption(
    "Decision-support for hospital-quality oversight — built on CMS Care Compare public data. "
    "Predicts patient satisfaction and flags likely underperformers for audit triage."
)

tab1, tab2, tab3 = st.tabs(["🎯 Audit Triage", "🔍 Hospital Profile", "📋 Model Card"])

# ---------------------------------------------------------------- Audit Triage
with tab1:
    st.subheader("Where should oversight resources go first?")
    c1, c2 = st.columns([1, 3])
    with c1:
        states = ["All"] + sorted(scored["state"].dropna().unique().tolist())
        state = st.selectbox("State", states)
        top_n = st.slider("Show top N by risk", 5, 50, 15)
    view = scored if state == "All" else scored[scored["state"] == state]
    view = view.sort_values("predicted_risk", ascending=False).head(top_n)
    with c2:
        st.metric("Hospitals in view", len(view))
        st.dataframe(
            view[["risk_rank", "facility_name", "state", "hospital_type",
                  "predicted_risk", "overall_rating", "patient_star_avg"]]
            .rename(columns={"predicted_risk": "risk_score (0-1)",
                             "patient_star_avg": "patient_stars"}),
            use_container_width=True, hide_index=True,
        )
    st.info("**Risk score** = model-estimated probability a hospital is an underperformer, "
            "using structural + patient-experience + process features (not the CMS rating itself).")

# ------------------------------------------------------------- Hospital Profile
with tab2:
    st.subheader("Single-hospital drill-down")
    name = st.selectbox("Choose a hospital",
                        sorted(scored["facility_name"].dropna().unique().tolist()))
    row = scored[scored["facility_name"] == name].iloc[0]
    f = feats[feats["facility_id"] == row["facility_id"]].iloc[0]

    m1, m2, m3, m4 = st.columns(4)
    m1.metric("Predicted risk", f"{row['predicted_risk']:.0%}")
    m2.metric("CMS overall rating", "—" if pd.isna(row["overall_rating"]) else f"{row['overall_rating']:.0f}★")
    m3.metric("Patient satisfaction", "—" if pd.isna(row["patient_star_avg"]) else f"{row['patient_star_avg']:.1f}★")
    m4.metric("National risk rank", f"#{int(row['risk_rank'])}")

    st.markdown("**Profile**")
    st.json({
        "state": f["state"], "type": f["hospital_type"],
        "ownership": f["hospital_ownership"],
        "emergency_services": bool(f["emergency_services"]),
        "survey_response_rate_%": None if pd.isna(f["survey_response_rate"]) else float(f["survey_response_rate"]),
        "timely_care_avg": None if pd.isna(f["timely_care_avg"]) else round(float(f["timely_care_avg"]), 1),
    })

# ------------------------------------------------------------------ Model Card
with tab3:
    st.subheader("Model card & honest limitations")
    r, c = metrics["regression"], metrics["classification"]
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("**Regression — patient satisfaction**")
        st.write(f"- Target: `{r['target']}`")
        st.write(f"- R² = **{r['r2']}**, MAE = **{r['mae_stars']} stars**")
        st.write(f"- Train/test: {r['n_train']}/{r['n_test']}")
        if (OUT / "shap_regression.png").exists():
            st.image(str(OUT / "shap_regression.png"))
    with col2:
        st.markdown("**Classification — underperformer flag**")
        st.write(f"- Target: `{c['target']}`")
        st.write(f"- ROC-AUC = **{c['roc_auc']}**, recall = **{c['report']['1']['recall']:.2f}**")
        st.write(f"- Train/test: {c['n_train']}/{c['n_test']}")
        if (OUT / "shap_classification.png").exists():
            st.image(str(OUT / "shap_classification.png"))

    st.warning(
        "**Limitations (read before acting on this):**\n"
        "- Cross-sectional data → associations, **not causation**. No forecasting claims.\n"
        "- Hospital-level aggregates (~5,400 rows) → classical ML, not deep learning.\n"
        "- To avoid leakage, models exclude the mortality/safety/readmission counts that "
        "mechanically define the CMS rating. This lowers accuracy but keeps findings honest.\n"
        "- Output is **decision-support for human reviewers**, not an automated verdict."
    )
