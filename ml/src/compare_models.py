"""
compare_models.py
-----------------
Benchmarks several candidate models for each task with 5-fold cross-validation,
against a trivial baseline. Reports mean ± std so results don't hinge on one
lucky split, and writes a leaderboard the README can cite.

Run:
    python ml/src/compare_models.py
Outputs:
    ml/outputs/model_comparison.csv
"""

from __future__ import annotations
import pathlib
import sys

import pandas as pd
from sklearn.model_selection import cross_val_score
from sklearn.pipeline import Pipeline

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import config  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[1] / "outputs"
FEATURES = OUT / "hospital_features.csv"

TASKS = {
    "regression": {"target": "patient_star_avg", "numeric": config.REG_NUMERIC,
                   "scoring": "r2", "dropna_target": True},
    "classification": {"target": "is_underperformer", "numeric": config.CLF_NUMERIC,
                       "scoring": "roc_auc", "dropna_target": False},
}


def run():
    df = pd.read_csv(FEATURES)
    rows = []

    for task, cfg in TASKS.items():
        data = df.dropna(subset=[cfg["target"]]).copy() if cfg["dropna_target"] else df.copy()
        X = config.select_X(data, task)
        y = data[cfg["target"]]
        pre = config.make_preprocessor(cfg["numeric"])

        print(f"\n=== {task.upper()} — scoring: {cfg['scoring']} (5-fold CV) ===")
        for name, model in config.candidate_models(task).items():
            pipe = Pipeline([("pre", pre), ("model", model)])
            scores = cross_val_score(pipe, X, y, cv=5, scoring=cfg["scoring"], n_jobs=-1)
            rows.append({
                "task": task, "scoring": cfg["scoring"], "model": name,
                "cv_mean": round(float(scores.mean()), 4),
                "cv_std": round(float(scores.std()), 4),
            })
            print(f"  {name:<22} {scores.mean():.4f} ± {scores.std():.4f}")

    leaderboard = pd.DataFrame(rows).sort_values(
        ["task", "cv_mean"], ascending=[True, False])
    leaderboard.to_csv(OUT / "model_comparison.csv", index=False)
    print(f"\nSaved leaderboard -> {OUT / 'model_comparison.csv'}")
    return leaderboard


if __name__ == "__main__":
    run()
