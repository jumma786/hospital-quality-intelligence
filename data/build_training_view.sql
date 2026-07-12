USE HospitalQuality;
GO

/* ============================================================
   ML Project 1: Training data extraction for overall_rating
   prediction. Joins hospital_general_info with aggregated
   timely_effective_care and hcahps_survey features.
   ============================================================ */

WITH TimelyAgg AS (
    SELECT
        facility_id,
        AVG(TRY_CAST(score AS FLOAT)) AS avg_timely_score
    FROM dbo.timely_effective_care
    WHERE TRY_CAST(score AS FLOAT) IS NOT NULL
    GROUP BY facility_id
),

HcahpsAgg AS (
    SELECT
        facility_id,
        AVG(TRY_CAST(patient_survey_star_rating AS FLOAT))  AS avg_patient_star_rating,
        AVG(TRY_CAST(survey_response_rate_percent AS FLOAT)) AS avg_response_rate,
        SUM(TRY_CAST(number_of_completed_surveys AS INT))    AS total_completed_surveys
    FROM dbo.hcahps_survey
    GROUP BY facility_id
)

SELECT
    h.facility_id,
    h.facility_name,
    h.state,
    h.hospital_type,
    h.hospital_ownership,
    h.emergency_services,
    h.birthing_friendly,

    TRY_CAST(h.count_mort_measures_better AS INT)         AS count_mort_measures_better,
    TRY_CAST(h.count_mort_measures_no_different AS INT)   AS count_mort_measures_no_different,
    TRY_CAST(h.count_mort_measures_worse AS INT)          AS count_mort_measures_worse,

    TRY_CAST(h.count_safety_measures_better AS INT)       AS count_safety_measures_better,
    TRY_CAST(h.count_safety_measures_no_different AS INT) AS count_safety_measures_no_different,
    TRY_CAST(h.count_safety_measures_worse AS INT)        AS count_safety_measures_worse,

    TRY_CAST(h.count_readm_measures_better AS INT)        AS count_readm_measures_better,
    TRY_CAST(h.count_readm_measures_no_different AS INT)  AS count_readm_measures_no_different,
    TRY_CAST(h.count_readm_measures_worse AS INT)         AS count_readm_measures_worse,

    t.avg_timely_score,
    p.avg_patient_star_rating,
    p.avg_response_rate,
    p.total_completed_surveys,

    TRY_CAST(h.overall_rating AS INT) AS overall_rating

FROM dbo.hospital_general_info h
LEFT JOIN TimelyAgg t ON h.facility_id = t.facility_id
LEFT JOIN HcahpsAgg p ON h.facility_id = p.facility_id
WHERE TRY_CAST(h.overall_rating AS INT) IS NOT NULL;
