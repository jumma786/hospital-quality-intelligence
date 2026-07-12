"""Smoke tests: the full preprocess->model pipeline trains and predicts on
synthetic data, and every candidate model is a valid, cloneable estimator."""
from sklearn.base import clone, is_classifier, is_regressor
from sklearn.pipeline import Pipeline

import config


def test_candidate_models_are_valid():
    reg = config.candidate_models("regression")
    clf = config.candidate_models("classification")
    assert "Baseline (mean)" in reg and len(reg) >= 3
    assert "Baseline (majority)" in clf and len(clf) >= 3
    assert all(is_regressor(clone(m)) for m in reg.values())
    assert all(is_classifier(clone(m)) for m in clf.values())


def test_classification_pipeline_fits_and_predicts(synthetic_features):
    X = config.select_X(synthetic_features, "classification")
    y = synthetic_features["is_underperformer"]
    pre = config.make_preprocessor(config.CLF_NUMERIC)
    model = config.candidate_models("classification")["RandomForest"]
    model.set_params(n_estimators=20)
    pipe = Pipeline([("pre", pre), ("model", model)]).fit(X, y)
    proba = pipe.predict_proba(X)[:, 1]
    assert proba.shape[0] == len(y)
    assert ((proba >= 0) & (proba <= 1)).all()


def test_regression_pipeline_fits_and_predicts(synthetic_features):
    data = synthetic_features
    X = config.select_X(data, "regression")
    y = data["patient_star_avg"]
    pre = config.make_preprocessor(config.REG_NUMERIC)
    model = config.candidate_models("regression")["RandomForest"]
    model.set_params(n_estimators=20)
    pipe = Pipeline([("pre", pre), ("model", model)]).fit(X, y)
    preds = pipe.predict(X)
    assert preds.shape[0] == len(y)


def test_feature_names_match_transformed_width(synthetic_features):
    X = config.select_X(synthetic_features, "regression")
    pre = config.make_preprocessor(config.REG_NUMERIC).fit(X)
    Xt = pre.transform(X)
    names = config.feature_names(pre, config.REG_NUMERIC)
    assert len(names) == Xt.shape[1]
