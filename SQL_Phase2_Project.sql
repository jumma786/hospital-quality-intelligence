/* ============================================================
   SQL Phase 2, Level 2 — Capstone: Social-Impact SQL Analytics
   Domain: Public Health — Hospital Quality & Performance
   Dataset: CMS Care Compare (Hospital General Information,
            Timely and Effective Care, HCAHPS Patient Survey)
   End Consumer: A state health department's hospital quality
                 oversight official
   ============================================================ */

USE HospitalQuality;


/* ============================================================
   PERSPECTIVE 1: Geographic Perspective
   Which states/counties have clusters of low-rated or
   underperforming hospitals.
   ============================================================ */

-- PERSPECTIVE 1: Geographic | EASY | Q1: List all hospitals in a specific state, showing name, city, and overall rating.

SELECT
    facility_name,
    city_town,
    state,
    overall_rating
FROM [HospitalQuality].[dbo].[hospital_general_info]
WHERE state = 'CA'
ORDER BY facility_name;


-- PERSPECTIVE 1: Geographic | EASY | Q2: Show all distinct states represented in the dataset.
SELECT DISTINCT state
FROM [HospitalQuality].[dbo].[hospital_general_info]
ORDER BY state;


-- PERSPECTIVE 1: Geographic | EASY | Q3: List hospitals with a 1-star overall rating, sorted alphabetically by state.
SELECT
    facility_name,
    city_town,
    county_parish,
    state,
    overall_rating
FROM [HospitalQuality].[dbo].[hospital_general_info]
WHERE overall_rating = '1'
ORDER BY state, facility_name;


-- PERSPECTIVE 1: Geographic | EASY | Q4: Find all hospitals in a given county, along with their type and ownership.

SELECT
    facility_name,
    city_town,
    county_parish,
    hospital_type,
    hospital_ownership
    overall_rating
FROM [HospitalQuality].[dbo].[hospital_general_info]
WHERE county_parish = 'Los Angeles'
ORDER BY facility_name;


-- PERSPECTIVE 1: Geographic | EASY | Q5: List the top 20 highest-rated hospitals within a specific state.

SELECT TOP (20)
    facility_name,
    city_town,
    overall_rating
FROM [HospitalQuality].[dbo].[hospital_general_info]
WHERE state = 'TX'
      AND overall_rating <> 'Not Available'
ORDER BY
    CAST(overall_rating AS INT) DESC,
    facility_name;
-- PERSPECTIVE 1: Geographic | MEDIUM | Q6: How many hospitals are there per state?


SELECT
    state,
    COUNT(*) AS TotalHospitals
FROM [HospitalQuality].[dbo].[hospital_general_info]
GROUP BY state
ORDER BY TotalHospitals DESC;


-- PERSPECTIVE 1: Geographic | MEDIUM | Q7: What is the average overall hospital rating per state?
select state,
avg(cast(overall_rating as decimal(3,1))) as AvgRatings 
FROM [HospitalQuality].[dbo].[hospital_general_info]
where overall_rating <> 'not available' and overall_rating is not null
group by state
order by AvgRatings desc ;

-- PERSPECTIVE 1: Geographic | MEDIUM | Q8: Which counties have more than 5 hospitals rated 3 stars or below?
select state, county_parish,
count (*) as lowratedhospital 
FROM [HospitalQuality].[dbo].[hospital_general_info]
where overall_rating in ('1','2','3')
group by state, county_parish
having count (*) > 5
order by lowratedhospital desc;

-- PERSPECTIVE 1: Geographic | MEDIUM | Q9: For each state, how many hospitals offer emergency services vs. not?
SELECT
    state,

    SUM(CASE
            WHEN emergency_services = 'Yes' THEN 1
            ELSE 0
        END) AS EmergencyHospitals,

    SUM(CASE
            WHEN emergency_services = 'No' THEN 1
            ELSE 0
        END) AS NonEmergencyHospitals

FROM [HospitalQuality].[dbo].[hospital_general_info]

GROUP BY state

ORDER BY state;

-- PERSPECTIVE 1: Geographic | MEDIUM | Q10: Which states have the most hospitals with at least one mortality measure worse than the national average?
SELECT
    state,
    COUNT(*) AS HospitalCount
FROM [HospitalQuality].[dbo].[hospital_general_info]
WHERE TRY_CAST(count_mort_measures_worse AS INT) > 0
GROUP BY state
ORDER BY HospitalCount DESC;

-- PERSPECTIVE 1: Geographic | DIFFICULT | Q11: Rank all states by average hospital overall rating.
SELECT
    state,
    ROUND(AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))), 2) AS AverageRating,

    RANK() OVER
    (
        ORDER BY AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) DESC
    ) AS StateRank

FROM HospitalQuality.dbo.hospital_general_info

WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL

GROUP BY state

ORDER BY StateRank;

-- PERSPECTIVE 1: Geographic | DIFFICULT | Q12: For each state, identify the hospital with the lowest overall rating (partitioned window function).
WITH RankedHospitals AS
(
    SELECT
        facility_name,
        city_town,
        county_parish,
        state,
        overall_rating,

        ROW_NUMBER() OVER
        (
            PARTITION BY state
            ORDER BY
                TRY_CAST(overall_rating AS INT),
                facility_name
        ) AS rn

    FROM HospitalQuality.dbo.hospital_general_info

    WHERE TRY_CAST(overall_rating AS INT) IS NOT NULL
)

SELECT
    state,
    facility_name,
    city_town,
    county_parish,
    overall_rating
FROM RankedHospitals
WHERE rn = 1
ORDER BY state;

-- PERSPECTIVE 1: Geographic | DIFFICULT | Q13: Using a CTE, find counties whose average overall rating is below the national average.

WITH CountyRating AS
(
    SELECT
        county_parish,
        state,
        AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) AS AvgCountyRating
    FROM HospitalQuality.dbo.hospital_general_info
    WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL
    GROUP BY county_parish, state
),

NationalRating AS
(
    SELECT
        AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) AS NationalAverage
    FROM HospitalQuality.dbo.hospital_general_info
    WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL
)

SELECT
    c.county_parish,
    c.state,
    ROUND(c.AvgCountyRating,2) AS CountyAverageRating
FROM CountyRating c
CROSS JOIN NationalRating n
WHERE c.AvgCountyRating < n.NationalAverage
ORDER BY CountyAverageRating;


-- PERSPECTIVE 1: Geographic | DIFFICULT | Q14: Create a view summarizing hospital count and average rating by state, for reuse in later geographic queries.

CREATE VIEW vw_state_hospital_summary
AS
SELECT
    state,
    COUNT(*) AS TotalHospitals,
    ROUND(AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))),2) AS AverageRating
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL
GROUP BY state;

SELECT *
FROM vw_state_hospital_summary
ORDER BY AverageRating DESC;
-- PERSPECTIVE 1: Geographic | DIFFICULT | Q15: Using a CTE, find the 3 lowest-rated hospitals in each state for intervention targeting.

WITH RankedHospitals AS
(
    SELECT
        facility_name,
        city_town,
        county_parish,
        state,
        overall_rating,

        ROW_NUMBER() OVER
        (
            PARTITION BY state
            ORDER BY
                TRY_CAST(overall_rating AS INT),
                facility_name
        ) AS HospitalRank

    FROM HospitalQuality.dbo.hospital_general_info

    WHERE TRY_CAST(overall_rating AS INT) IS NOT NULL
)

SELECT
    state,
    facility_name,
    city_town,
    county_parish,
    overall_rating
FROM RankedHospitals
WHERE HospitalRank <= 3
ORDER BY state, HospitalRank;

/* ============================================================
   PERSPECTIVE 2: Ownership & Facility-Type Perspective
   How quality outcomes differ by who runs the hospital.
   ============================================================ */

-- PERSPECTIVE 2: Ownership & Facility-Type | EASY | Q16: List all hospitals with their hospital_type and hospital_ownership.
SELECT
    facility_name,
    hospital_type,
    hospital_ownership
FROM HospitalQuality.dbo.hospital_general_info
ORDER BY facility_name;

-- PERSPECTIVE 2: Ownership & Facility-Type | EASY | Q17: Show all distinct values of hospital_ownership in the dataset.

SELECT DISTINCT
    hospital_ownership
FROM HospitalQuality.dbo.hospital_general_info
ORDER BY hospital_ownership;
-- PERSPECTIVE 2: Ownership & Facility-Type | EASY | Q18: Find all hospitals owned under "Government - State" ownership.

SELECT
    facility_name,
    city_town,
    state,
    hospital_ownership
FROM HospitalQuality.dbo.hospital_general_info
WHERE hospital_ownership = 'Government - State'
ORDER BY state, facility_name;
-- PERSPECTIVE 2: Ownership & Facility-Type | EASY | Q19: List all Critical Access Hospitals, sorted by state.
SELECT
    facility_name,
    city_town,
    state,
    hospital_type
FROM HospitalQuality.dbo.hospital_general_info
WHERE hospital_type = 'Critical Access Hospitals'
ORDER BY state, facility_name;

-- PERSPECTIVE 2: Ownership & Facility-Type | EASY | Q20: Find hospitals that do not offer emergency services.

SELECT
    facility_name,
    city_town,
    state,
    emergency_services
FROM HospitalQuality.dbo.hospital_general_info
WHERE emergency_services = 'No'
ORDER BY state, facility_name;
-- PERSPECTIVE 2: Ownership & Facility-Type | MEDIUM | Q21: Count hospitals by ownership category.

SELECT
    hospital_ownership,
    COUNT(*) AS TotalHospitals
FROM HospitalQuality.dbo.hospital_general_info
GROUP BY hospital_ownership
ORDER BY TotalHospitals DESC;

-- PERSPECTIVE 2: Ownership & Facility-Type | MEDIUM | Q22: What is the average overall rating by hospital_type?
SELECT
    hospital_type,
    ROUND(AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))),2) AS AverageRating
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL
GROUP BY hospital_type
ORDER BY AverageRating DESC;

-- PERSPECTIVE 2: Ownership & Facility-Type | MEDIUM | Q23: Which ownership categories have an average rating above 3.5?
SELECT
    hospital_ownership,
    ROUND(AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))),2) AS AverageRating
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL
GROUP BY hospital_ownership
HAVING AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) > 3.5
ORDER BY AverageRating DESC;

-- PERSPECTIVE 2: Ownership & Facility-Type | MEDIUM | Q24: For each ownership type, how many hospitals have birthing-friendly designation?
SELECT
    hospital_ownership,
    COUNT(*) AS BirthingFriendlyHospitals
FROM HospitalQuality.dbo.hospital_general_info
WHERE birthing_friendly = 'Y'
GROUP BY hospital_ownership
ORDER BY BirthingFriendlyHospitals DESC;

-- PERSPECTIVE 2: Ownership & Facility-Type | MEDIUM | Q25: Compare average count_of_mort_measures_worse between for-profit and non-profit ownership categories.
SELECT
    CASE
        WHEN hospital_ownership = 'Proprietary'
            THEN 'For-Profit'

        WHEN hospital_ownership IN
        (
            'Voluntary non-profit - Private',
            'Voluntary non-profit - Church',
            'Voluntary non-profit - Other'
        )
            THEN 'Non-Profit'

        ELSE 'Other'
    END AS OwnershipCategory,

    ROUND(
        AVG(TRY_CAST(count_mort_measures_worse AS FLOAT)),
        2
    ) AS AvgMortalityMeasures

FROM HospitalQuality.dbo.hospital_general_info

GROUP BY
CASE
        WHEN hospital_ownership = 'Proprietary'
            THEN 'For-Profit'

        WHEN hospital_ownership IN
        (
            'Voluntary non-profit - Private',
            'Voluntary non-profit - Church',
            'Voluntary non-profit - Other'
        )
            THEN 'Non-Profit'

        ELSE 'Other'
END;
-- PERSPECTIVE 2: Ownership & Facility-Type | DIFFICULT | Q26: Rank ownership categories by average overall rating.

SELECT
    hospital_ownership,
    ROUND(AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))),2) AS AverageRating,

    RANK() OVER
    (
        ORDER BY AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) DESC
    ) AS OwnershipRank

FROM HospitalQuality.dbo.hospital_general_info

WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL

GROUP BY hospital_ownership

ORDER BY OwnershipRank;
-- PERSPECTIVE 2: Ownership & Facility-Type | DIFFICULT | Q27: Using a CTE, calculate the % of hospitals per ownership category with zero worse-than-average safety measures.

WITH SafetySummary AS
(
    SELECT
        hospital_ownership,
        COUNT(*) AS TotalHospitals,

        SUM(
            CASE
                WHEN TRY_CAST(count_safety_measures_worse AS INT) = 0
                THEN 1
                ELSE 0
            END
        ) AS ZeroSafetyHospitals

    FROM HospitalQuality.dbo.hospital_general_info

    GROUP BY hospital_ownership
)

SELECT
    hospital_ownership,
    TotalHospitals,
    ZeroSafetyHospitals,

    ROUND(
        (100.0 * ZeroSafetyHospitals) / TotalHospitals,
        2
    ) AS PercentageZeroSafety

FROM SafetySummary

ORDER BY PercentageZeroSafety DESC;
-- PERSPECTIVE 2: Ownership & Facility-Type | DIFFICULT | Q28: Create a view summarizing hospital_type/ownership combinations with average rating and % offering emergency services.

CREATE VIEW vw_hospital_type_ownership_summary

AS

SELECT

    hospital_type,

    hospital_ownership,

    COUNT(*) AS TotalHospitals,

    ROUND(
        AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))),
        2
    ) AS AverageRating,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN emergency_services = 'Yes'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS EmergencyServicePercentage

FROM HospitalQuality.dbo.hospital_general_info

WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL

GROUP BY
    hospital_type,
    hospital_ownership;

SELECT *
FROM vw_hospital_type_ownership_summary
ORDER BY AverageRating DESC;
-- PERSPECTIVE 2: Ownership & Facility-Type | DIFFICULT | Q29: For each hospital_type, find the ownership category with the highest average rating (partitioned window function).

WITH OwnershipRanking AS
(
    SELECT

        hospital_type,

        hospital_ownership,

        ROUND(
            AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))),
            2
        ) AS AverageRating,

        ROW_NUMBER() OVER
        (
            PARTITION BY hospital_type
            ORDER BY AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) DESC
        ) AS RN

    FROM HospitalQuality.dbo.hospital_general_info

    WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL

    GROUP BY
        hospital_type,
        hospital_ownership
)

SELECT
    hospital_type,
    hospital_ownership,
    AverageRating
FROM OwnershipRanking
WHERE RN = 1
ORDER BY hospital_type;
-- PERSPECTIVE 2: Ownership & Facility-Type | DIFFICULT | Q30: Using a CTE, identify ownership categories whose average rating differs meaningfully from the national average.
WITH OwnershipAverage AS
(
    SELECT

        hospital_ownership,

        AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) AS AvgOwnershipRating

    FROM HospitalQuality.dbo.hospital_general_info

    WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL

    GROUP BY hospital_ownership
),

NationalAverage AS
(
    SELECT
        AVG(TRY_CAST(overall_rating AS DECIMAL(3,1))) AS AvgNationalRating
    FROM HospitalQuality.dbo.hospital_general_info
    WHERE TRY_CAST(overall_rating AS DECIMAL(3,1)) IS NOT NULL
)

SELECT
    o.hospital_ownership,
    ROUND(o.AvgOwnershipRating,2) AS AverageRating,
    ROUND(n.AvgNationalRating,2) AS NationalAverage
FROM OwnershipAverage o
CROSS JOIN NationalAverage n
WHERE o.AvgOwnershipRating < n.AvgNationalRating
ORDER BY AverageRating;

/* ============================================================
   PERSPECTIVE 3: Clinical Quality/Safety Perspective
   Mortality, safety, and readmission outcome comparisons.
   ============================================================ */

-- PERSPECTIVE 3: Clinical Quality/Safety | EASY | Q31: List hospitals with their count_of_mort_measures_worse and count_of_safety_measures_worse.
SELECT
    facility_name,
    state,
    count_mort_measures_worse,
    count_safety_measures_worse
FROM HospitalQuality.dbo.hospital_general_info
ORDER BY facility_name;

-- PERSPECTIVE 3: Clinical Quality/Safety | EASY | Q32: Find hospitals where count_of_readm_measures_worse is greater than 0.
SELECT
    facility_name,
    city_town,
    state,
    count_readm_measures_worse
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_readm_measures_worse AS INT) > 0
ORDER BY count_readm_measures_worse DESC;

-- PERSPECTIVE 3: Clinical Quality/Safety | EASY | Q33: List hospitals with zero worse-than-average mortality measures, sorted by state.
SELECT
    facility_name,
    city_town,
    state,
    count_mort_measures_worse
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_mort_measures_worse AS INT) = 0
ORDER BY state, facility_name;

-- PERSPECTIVE 3: Clinical Quality/Safety | EASY | Q34: Find hospitals with more than 2 safety measures rated better than average.

SELECT
    facility_name,
    city_town,
    state,
    count_safety_measures_better
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_safety_measures_better AS INT) > 2
ORDER BY count_safety_measures_better DESC;



-- PERSPECTIVE 3: Clinical Quality/Safety | EASY | Q35: Show hospitals where mortality, safety, and readmission worse-counts are all zero.

SELECT
    facility_name,
    city_town,
    state,
    count_mort_measures_worse,
    count_safety_measures_worse,
    count_readm_measures_worse
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_mort_measures_worse AS INT) = 0
  AND TRY_CAST(count_safety_measures_worse AS INT) = 0
  AND TRY_CAST(count_readm_measures_worse AS INT) = 0
ORDER BY facility_name;



-- PERSPECTIVE 3: Clinical Quality/Safety | MEDIUM | Q36: What is the average count_of_mort_measures_worse per state?


SELECT
    state,
    ROUND(AVG(TRY_CAST(count_mort_measures_worse AS FLOAT)),2) AS AvgMortalityMeasures
FROM HospitalQuality.dbo.hospital_general_info
GROUP BY state
ORDER BY AvgMortalityMeasures DESC;



-- PERSPECTIVE 3: Clinical Quality/Safety | MEDIUM | Q37: How many hospitals per hospital_type have at least one readmission measure rated worse?
SELECT
    hospital_type,
    COUNT(*) AS TotalHospitals
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_readm_measures_worse AS INT) > 0
GROUP BY hospital_type
ORDER BY TotalHospitals DESC;



-- PERSPECTIVE 3: Clinical Quality/Safety | MEDIUM | Q38: Group hospitals by overall rating tier and compute average safety-measures-worse count.
SELECT
    overall_rating,
    ROUND(AVG(TRY_CAST(count_safety_measures_worse AS FLOAT)),2) AS AvgSafetyMeasuresWorse
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(overall_rating AS INT) IS NOT NULL
GROUP BY overall_rating
ORDER BY TRY_CAST(overall_rating AS INT);



-- PERSPECTIVE 3: Clinical Quality/Safety | MEDIUM | Q39: Which states have more than 10 hospitals with at least one worse-than-average mortality measure?
SELECT
    state,
    COUNT(*) AS TotalHospitals
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_mort_measures_worse AS INT) > 0
GROUP BY state
HAVING COUNT(*) > 10
ORDER BY TotalHospitals DESC;



-- PERSPECTIVE 3: Clinical Quality/Safety | MEDIUM | Q40: Compare average count_of_readm_measures_worse between hospitals with and without emergency services.

SELECT
    emergency_services,
    ROUND(AVG(TRY_CAST(count_readm_measures_worse AS FLOAT)),2) AS AvgReadmissionMeasures
FROM HospitalQuality.dbo.hospital_general_info
GROUP BY emergency_services
ORDER BY AvgReadmissionMeasures DESC;




-- PERSPECTIVE 3: Clinical Quality/Safety | DIFFICULT | Q41: Rank hospitals nationally by total worse-than-average measures (mortality + safety + readmission combined).
SELECT
    facility_name,
    state,
    count_mort_measures_worse,
    count_safety_measures_worse,
    count_readm_measures_worse,

    ISNULL(TRY_CAST(count_mort_measures_worse AS INT), 0) +
    ISNULL(TRY_CAST(count_safety_measures_worse AS INT), 0) +
    ISNULL(TRY_CAST(count_readm_measures_worse AS INT), 0) AS TotalRiskScore,

    RANK() OVER (
        ORDER BY
            ISNULL(TRY_CAST(count_mort_measures_worse AS INT), 0) +
            ISNULL(TRY_CAST(count_safety_measures_worse AS INT), 0) +
            ISNULL(TRY_CAST(count_readm_measures_worse AS INT), 0) DESC
    ) AS NationalRank

FROM HospitalQuality.dbo.hospital_general_info
ORDER BY NationalRank, facility_name;

-- PERSPECTIVE 3: Clinical Quality/Safety | DIFFICULT | Q42: Using a CTE, flag hospitals in the bottom 10% nationally on combined worse-measure count as "high risk," then count high-risk hospitals per state.
WITH HospitalRisk AS
(
    SELECT
        facility_name,
        state,

        (
            count_mort_measures_worse +
            count_safety_measures_worse +
            count_readm_measures_worse
        ) AS RiskScore,

        NTILE(10) OVER
        (
            ORDER BY
            (
                count_mort_measures_worse +
                count_safety_measures_worse +
                count_readm_measures_worse
            ) DESC
        ) AS RiskGroup

    FROM HospitalQuality.dbo.hospital_general_info
)

SELECT
    state,
    COUNT(*) AS HighRiskHospitals
FROM HospitalRisk
WHERE RiskGroup = 1
GROUP BY state
ORDER BY HighRiskHospitals DESC;

-- PERSPECTIVE 3: Clinical Quality/Safety | DIFFICULT | Q43: Create a view "hospital_risk_summary" combining mortality/safety/readmission worse-counts into one composite risk score per hospital.
CREATE VIEW vw_hospital_risk_summary
AS
SELECT
    facility_id,
    facility_name,
    state,

    count_mort_measures_worse,
    count_safety_measures_worse,
    count_readm_measures_worse,

    ISNULL(TRY_CAST(count_mort_measures_worse AS INT), 0) +
    ISNULL(TRY_CAST(count_safety_measures_worse AS INT), 0) +
    ISNULL(TRY_CAST(count_readm_measures_worse AS INT), 0)
    AS CompositeRiskScore

FROM HospitalQuality.dbo.hospital_general_info;

Select * From  vw_hospital_risk_summary order by CompositeRiskScore desc;

-- PERSPECTIVE 3: Clinical Quality/Safety | DIFFICULT | Q44: Using a CTE and window function, find the hospital with the worst composite risk score in each state.
WITH HospitalRisk AS
(
    SELECT
        facility_name,
        state,

        ISNULL(TRY_CAST(count_mort_measures_worse AS INT),0) +
        ISNULL(TRY_CAST(count_safety_measures_worse AS INT),0) +
        ISNULL(TRY_CAST(count_readm_measures_worse AS INT),0) AS RiskScore,

        ROW_NUMBER() OVER
        (
            PARTITION BY state
            ORDER BY
                ISNULL(TRY_CAST(count_mort_measures_worse AS INT),0) +
                ISNULL(TRY_CAST(count_safety_measures_worse AS INT),0) +
                ISNULL(TRY_CAST(count_readm_measures_worse AS INT),0) DESC
        ) AS RN

    FROM HospitalQuality.dbo.hospital_general_info

    WHERE
        TRY_CAST(count_mort_measures_worse AS INT) IS NOT NULL
        OR TRY_CAST(count_safety_measures_worse AS INT) IS NOT NULL
        OR TRY_CAST(count_readm_measures_worse AS INT) IS NOT NULL
)

SELECT
    state,
    facility_name,
    RiskScore
FROM HospitalRisk
WHERE RN = 1
ORDER BY state;



-- PERSPECTIVE 3: Clinical Quality/Safety | DIFFICULT | Q45: Using a subquery, list hospitals whose safety-measures-worse count is significantly above the national average.

SELECT
    facility_name,
    state,
    count_safety_measures_worse
FROM HospitalQuality.dbo.hospital_general_info
WHERE TRY_CAST(count_safety_measures_worse AS INT) >
(
    SELECT AVG(TRY_CAST(count_safety_measures_worse AS INT))
    FROM HospitalQuality.dbo.hospital_general_info
)
ORDER BY TRY_CAST(count_safety_measures_worse AS INT) DESC;
/* ============================================================
   PERSPECTIVE 4: Timeliness & Effective Care Perspective
   Process-of-care measures by condition, joined to hospital info.
   ============================================================ */

-- PERSPECTIVE 4: Timeliness & Effective Care | EASY | Q46: List all timely/effective care measures for a specific hospital, showing measure_name and score.
SELECT
    facility_name,
    measure_name,
    score
FROM HospitalQuality.dbo.timely_effective_care
WHERE facility_name = 'SOUTHEAST HEALTH MEDICAL CENTER'
ORDER BY measure_name;

-- PERSPECTIVE 4: Timeliness & Effective Care | EASY | Q47: Find all records for a specific condition, sorted by score descending.
SELECT
    facility_name,
    state,
    condition_name,
    measure_name,
    score
FROM HospitalQuality.dbo.timely_effective_care
WHERE condition_name = 'Emergency Department'
AND TRY_CAST(score AS FLOAT) IS NOT NULL
ORDER BY TRY_CAST(score AS FLOAT) DESC;

    
-- PERSPECTIVE 4: Timeliness & Effective Care | EASY | Q48: Show the distinct list of conditions tracked in the timely-care data.

SELECT DISTINCT
    condition_name
FROM HospitalQuality.dbo.timely_effective_care
ORDER BY condition_name;

-- PERSPECTIVE 4: Timeliness & Effective Care | EASY | Q49: Find all measures with a perfect score (100) for a given condition.

SELECT
    facility_name,
    state,
    measure_name,
    score
FROM HospitalQuality.dbo.timely_effective_care
WHERE condition_name = 'Healthcare Personnel Vaccination'
AND TRY_CAST(score AS FLOAT) = 100
ORDER BY facility_name;


-- PERSPECTIVE 4: Timeliness & Effective Care | EASY | Q50: List hospitals with missing (NULL) score values for a specific measure.
SELECT
    facility_name,
    state,
    measure_name,
    score
FROM HospitalQuality.dbo.timely_effective_care
WHERE measure_id = 'OP_23'
AND
(
      score IS NULL
   OR score = 'Not Available'
)
ORDER BY state, facility_name;

-- PERSPECTIVE 4: Timeliness & Effective Care | MEDIUM | Q51: What is the average score per measure_name across all hospitals?
SELECT
    measure_name,
    ROUND(AVG(TRY_CAST(score AS FLOAT)), 2) AS AverageScore
FROM HospitalQuality.dbo.timely_effective_care
WHERE TRY_CAST(score AS FLOAT) IS NOT NULL
GROUP BY measure_name
ORDER BY AverageScore DESC;

-- PERSPECTIVE 4: Timeliness & Effective Care | MEDIUM | Q52: Which conditions have the lowest average score nationally?
SELECT
    condition_name,
    ROUND(AVG(TRY_CAST(score AS FLOAT)), 2) AS AverageScore
FROM HospitalQuality.dbo.timely_effective_care
WHERE TRY_CAST(score AS FLOAT) IS NOT NULL
GROUP BY condition_name
ORDER BY AverageScore ASC;

-- PERSPECTIVE 4: Timeliness & Effective Care | MEDIUM | Q53: Count how many hospitals report data for each measure_id.
SELECT
    measure_id,
    COUNT(DISTINCT facility_id) AS TotalHospitals
FROM HospitalQuality.dbo.timely_effective_care
WHERE score <> 'Not Available'
GROUP BY measure_id
ORDER BY TotalHospitals DESC;

-- PERSPECTIVE 4: Timeliness & Effective Care | MEDIUM | Q54: Join with hospital_general_info to find the average score by state for a specific condition.

SELECT
    h.state,
    ROUND(AVG(TRY_CAST(t.score AS FLOAT)),2) AS AverageScore
FROM HospitalQuality.dbo.timely_effective_care t
INNER JOIN HospitalQuality.dbo.hospital_general_info h
    ON t.facility_id = h.facility_id
WHERE t.condition_name = 'Emergency Department'
AND TRY_CAST(t.score AS FLOAT) IS NOT NULL
GROUP BY h.state
ORDER BY AverageScore DESC;
-- PERSPECTIVE 4: Timeliness & Effective Care | MEDIUM | Q55: Which states have an average score below the national average for a specific measure?

SELECT
    h.state,
    ROUND(AVG(TRY_CAST(t.score AS FLOAT)),2) AS StateAverage
FROM HospitalQuality.dbo.timely_effective_care t
INNER JOIN HospitalQuality.dbo.hospital_general_info h
    ON t.facility_id = h.facility_id
WHERE t.measure_id = 'IMM_3'
AND TRY_CAST(t.score AS FLOAT) IS NOT NULL
GROUP BY h.state
HAVING AVG(TRY_CAST(t.score AS FLOAT))
<
(
    SELECT AVG(TRY_CAST(score AS FLOAT))
    FROM HospitalQuality.dbo.timely_effective_care
    WHERE measure_id = 'IMM_3'
    AND TRY_CAST(score AS FLOAT) IS NOT NULL
)
ORDER BY StateAverage;
-- PERSPECTIVE 4: Timeliness & Effective Care | DIFFICULT | Q56: Using a CTE joining timely-care data with hospital info, rank hospitals within each state by score for a specific measure.
WITH HospitalRanking AS
(
    SELECT
        h.state,
        t.facility_name,
        t.measure_id,
        TRY_CAST(t.score AS FLOAT) AS Score,

        ROW_NUMBER() OVER
        (
            PARTITION BY h.state
            ORDER BY TRY_CAST(t.score AS FLOAT) DESC
        ) AS StateRank

    FROM HospitalQuality.dbo.timely_effective_care t
    INNER JOIN HospitalQuality.dbo.hospital_general_info h
        ON t.facility_id = h.facility_id

    WHERE t.measure_id = 'IMM_3'
      AND TRY_CAST(t.score AS FLOAT) IS NOT NULL
)

SELECT *
FROM HospitalRanking
ORDER BY state, StateRank;


-- PERSPECTIVE 4: Timeliness & Effective Care | DIFFICULT | Q57: Create a view joining timely-care scores with hospital state/ownership info for reuse.
CREATE VIEW vw_timely_care_summary
AS

SELECT
    t.facility_id,
    t.facility_name,
    h.state,
    h.hospital_ownership,
    t.condition_name,
    t.measure_id,
    t.measure_name,
    t.score,
    t.start_date,
    t.end_date

FROM HospitalQuality.dbo.timely_effective_care t
INNER JOIN HospitalQuality.dbo.hospital_general_info h
ON t.facility_id = h.facility_id;


-- PERSPECTIVE 4: Timeliness & Effective Care | DIFFICULT | Q58: Using a window function, rank hospitals nationally by score for a specific measure and flag the bottom 10%.

WITH NationalRanking AS
(
    SELECT
        facility_name,
        state,
        measure_id,
        TRY_CAST(score AS FLOAT) AS Score,

        NTILE(10) OVER
        (
            ORDER BY TRY_CAST(score AS FLOAT)
        ) AS RiskGroup

    FROM HospitalQuality.dbo.timely_effective_care

    WHERE measure_id='IMM_3'
      AND TRY_CAST(score AS FLOAT) IS NOT NULL
)

SELECT
    facility_name,
    state,
    Score,

    CASE
        WHEN RiskGroup=1 THEN 'Bottom 10%'
        ELSE 'Other'
    END AS Performance

FROM NationalRanking
ORDER BY Score;


-- PERSPECTIVE 4: Timeliness & Effective Care | DIFFICULT | Q59: Using a CTE and LAG, compute each condition's period-over-period average score change (using start_date/end_date).
WITH AvgScores AS
(
    SELECT

        condition_name,

        start_date,

        end_date,

        AVG(TRY_CAST(score AS FLOAT)) AS AvgScore

    FROM HospitalQuality.dbo.timely_effective_care

    WHERE TRY_CAST(score AS FLOAT) IS NOT NULL

    GROUP BY
        condition_name,
        start_date,
        end_date
)

SELECT

    condition_name,

    start_date,

    end_date,

    AvgScore,

    LAG(AvgScore) OVER
    (
        PARTITION BY condition_name
        ORDER BY start_date
    ) AS PreviousScore,

    AvgScore -
    LAG(AvgScore) OVER
    (
        PARTITION BY condition_name
        ORDER BY start_date
    ) AS ScoreChange

FROM AvgScores
ORDER BY condition_name,start_date;




-- PERSPECTIVE 4: Timeliness & Effective Care | DIFFICULT | Q60: Using a CTE joining hospital overall rating with timely-care scores, test whether higher-rated hospitals have higher timely-care scores on average.

WITH RatingSummary AS
(
    SELECT

        h.overall_rating,

        AVG(TRY_CAST(t.score AS FLOAT)) AS AvgTimelyScore

    FROM HospitalQuality.dbo.hospital_general_info h

    INNER JOIN HospitalQuality.dbo.timely_effective_care t
    ON h.facility_id=t.facility_id

    WHERE TRY_CAST(h.overall_rating AS INT) IS NOT NULL
      AND TRY_CAST(t.score AS FLOAT) IS NOT NULL

    GROUP BY h.overall_rating
)

SELECT *
FROM RatingSummary
ORDER BY TRY_CAST(overall_rating AS INT);

/* ============================================================
   PERSPECTIVE 5: Patient Experience Perspective
   HCAHPS survey data joined to hospital info.
   ============================================================ */

-- PERSPECTIVE 5: Patient Experience | EASY | Q61: List all HCAHPS questions and answer descriptions for a specific hospital.
SELECT
    facility_name,
    hcahps_question,
    hcahps_answer_description,
    hcahps_answer_percent
FROM HospitalQuality.dbo.hcahps_survey
WHERE facility_name = 'SOUTHEAST HEALTH MEDICAL CENTER'
ORDER BY hcahps_question;


-- PERSPECTIVE 5: Patient Experience | EASY | Q62: Find hospitals with a 5-star patient_survey_star_rating for a specific hcahps_measure_id.
SELECT
    facility_name,
    state,
    hcahps_measure_id,
    patient_survey_star_rating
FROM HospitalQuality.dbo.hcahps_survey
WHERE hcahps_measure_id = 'H_STAR_RATING'
  AND patient_survey_star_rating = '5'
ORDER BY state, facility_name;


-- PERSPECTIVE 5: Patient Experience | EASY | Q63: Show the distinct hcahps_question values in the dataset.
SELECT DISTINCT
    hcahps_question
FROM HospitalQuality.dbo.hcahps_survey
ORDER BY hcahps_question;


-- PERSPECTIVE 5: Patient Experience | EASY | Q64: Find hospitals with a survey_response_rate_percent below 20%.
SELECT DISTINCT
    facility_name,
    state,
    survey_response_rate_percent
FROM HospitalQuality.dbo.hcahps_survey
WHERE TRY_CAST(survey_response_rate_percent AS INT) < 20
ORDER BY state, facility_name;


-- PERSPECTIVE 5: Patient Experience | EASY | Q65: List the top 15 hospitals by number_of_completed_surveys.
SELECT TOP (15)
    facility_name,
    state,
    MAX(TRY_CAST(number_of_completed_surveys AS INT)) AS CompletedSurveys
FROM HospitalQuality.dbo.hcahps_survey
WHERE TRY_CAST(number_of_completed_surveys AS INT) IS NOT NULL
GROUP BY facility_name, state
ORDER BY CompletedSurveys DESC;


-- PERSPECTIVE 5: Patient Experience | MEDIUM | Q66: Joined with hospital_general_info, what is the average patient_survey_star_rating per state?
SELECT
    h.state,
    ROUND(AVG(TRY_CAST(s.patient_survey_star_rating AS FLOAT)), 2) AS AvgStarRating
FROM HospitalQuality.dbo.hcahps_survey s
INNER JOIN HospitalQuality.dbo.hospital_general_info h
    ON s.facility_id = h.facility_id
WHERE TRY_CAST(s.patient_survey_star_rating AS FLOAT) IS NOT NULL
GROUP BY h.state
ORDER BY AvgStarRating DESC;


-- PERSPECTIVE 5: Patient Experience | MEDIUM | Q67: Which hcahps_measure_id has the lowest average hcahps_answer_percent nationally?
SELECT
    hcahps_measure_id,
    ROUND(AVG(TRY_CAST(hcahps_answer_percent AS FLOAT)), 2) AS AvgAnswerPercent
FROM HospitalQuality.dbo.hcahps_survey
WHERE TRY_CAST(hcahps_answer_percent AS FLOAT) IS NOT NULL
GROUP BY hcahps_measure_id
ORDER BY AvgAnswerPercent ASC;


-- PERSPECTIVE 5: Patient Experience | MEDIUM | Q68: Joined with hospital_general_info, count hospitals with response rate below 30%, grouped by hospital_ownership.
SELECT
    h.hospital_ownership,
    COUNT(DISTINCT s.facility_id) AS LowResponseHospitals
FROM HospitalQuality.dbo.hcahps_survey s
INNER JOIN HospitalQuality.dbo.hospital_general_info h
    ON s.facility_id = h.facility_id
WHERE TRY_CAST(s.survey_response_rate_percent AS INT) < 30
GROUP BY h.hospital_ownership
ORDER BY LowResponseHospitals DESC;


-- PERSPECTIVE 5: Patient Experience | MEDIUM | Q69: Compare average patient star rating between hospitals with and without emergency services.
SELECT
    h.emergency_services,
    ROUND(AVG(TRY_CAST(s.patient_survey_star_rating AS FLOAT)), 2) AS AvgStarRating
FROM HospitalQuality.dbo.hcahps_survey s
INNER JOIN HospitalQuality.dbo.hospital_general_info h
    ON s.facility_id = h.facility_id
WHERE TRY_CAST(s.patient_survey_star_rating AS FLOAT) IS NOT NULL
GROUP BY h.emergency_services
ORDER BY AvgStarRating DESC;


-- PERSPECTIVE 5: Patient Experience | MEDIUM | Q70: Which states have more than 20 hospitals with average patient star rating below 3?
WITH HospitalAvgRating AS
(
    SELECT
        s.facility_id,
        h.state,
        AVG(TRY_CAST(s.patient_survey_star_rating AS FLOAT)) AS AvgHospitalStar
    FROM HospitalQuality.dbo.hcahps_survey s
    INNER JOIN HospitalQuality.dbo.hospital_general_info h
        ON s.facility_id = h.facility_id
    WHERE TRY_CAST(s.patient_survey_star_rating AS FLOAT) IS NOT NULL
    GROUP BY s.facility_id, h.state
)

SELECT
    state,
    COUNT(*) AS LowRatedHospitals
FROM HospitalAvgRating
WHERE AvgHospitalStar < 3
GROUP BY state
HAVING COUNT(*) > 20
ORDER BY LowRatedHospitals DESC;


-- PERSPECTIVE 5: Patient Experience | DIFFICULT | Q71: Using a CTE, join HCAHPS with the Perspective 3 risk-summary view to test whether high-risk hospitals also have lower patient satisfaction.
WITH PatientSatisfaction AS
(
    SELECT
        facility_id,
        AVG(TRY_CAST(patient_survey_star_rating AS FLOAT)) AS AvgStarRating
    FROM HospitalQuality.dbo.hcahps_survey
    WHERE TRY_CAST(patient_survey_star_rating AS FLOAT) IS NOT NULL
    GROUP BY facility_id
),

RiskBuckets AS
(
    SELECT
        facility_id,
        CompositeRiskScore,

        CASE
            WHEN CompositeRiskScore >= 3 THEN 'High Risk'
            WHEN CompositeRiskScore BETWEEN 1 AND 2 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS RiskCategory

    FROM HospitalQuality.dbo.vw_hospital_risk_summary
)

SELECT
    r.RiskCategory,
    COUNT(*) AS TotalHospitals,
    ROUND(AVG(p.AvgStarRating), 2) AS AvgPatientStarRating
FROM RiskBuckets r
INNER JOIN PatientSatisfaction p
    ON r.facility_id = p.facility_id
GROUP BY r.RiskCategory
ORDER BY AvgPatientStarRating DESC;


-- PERSPECTIVE 5: Patient Experience | DIFFICULT | Q72: Using a window function, rank hospitals within each state by star rating to find the top patient-experience hospital per state.
WITH HospitalStars AS
(
    SELECT
        s.facility_id,
        s.facility_name,
        h.state,
        AVG(TRY_CAST(s.patient_survey_star_rating AS FLOAT)) AS AvgStarRating
    FROM HospitalQuality.dbo.hcahps_survey s
    INNER JOIN HospitalQuality.dbo.hospital_general_info h
        ON s.facility_id = h.facility_id
    WHERE TRY_CAST(s.patient_survey_star_rating AS FLOAT) IS NOT NULL
    GROUP BY s.facility_id, s.facility_name, h.state
),

RankedHospitals AS
(
    SELECT
        state,
        facility_name,
        AvgStarRating,

        ROW_NUMBER() OVER
        (
            PARTITION BY state
            ORDER BY AvgStarRating DESC, facility_name
        ) AS RN

    FROM HospitalStars
)

SELECT
    state,
    facility_name,
    ROUND(AvgStarRating, 2) AS AvgStarRating
FROM RankedHospitals
WHERE RN = 1
ORDER BY state;


-- PERSPECTIVE 5: Patient Experience | DIFFICULT | Q73: Create a view "patient_experience_summary" combining average star rating, response rate, and completed surveys per hospital.

CREATE VIEW vw_patient_experience_summary
AS
SELECT
    s.facility_id,
    s.facility_name,
    h.state,
    h.hospital_ownership,

    ROUND(AVG(TRY_CAST(s.patient_survey_star_rating AS FLOAT)), 2) AS AvgStarRating,
    MAX(TRY_CAST(s.survey_response_rate_percent AS INT)) AS ResponseRatePercent,
    MAX(TRY_CAST(s.number_of_completed_surveys AS INT)) AS CompletedSurveys

FROM HospitalQuality.dbo.hcahps_survey s
INNER JOIN HospitalQuality.dbo.hospital_general_info h
    ON s.facility_id = h.facility_id

GROUP BY
    s.facility_id,
    s.facility_name,
    h.state,
    h.hospital_ownership;

SELECT *
FROM vw_patient_experience_summary
ORDER BY AvgStarRating DESC;


-- PERSPECTIVE 5: Patient Experience | DIFFICULT | Q74: Using LAG, compute the change in survey_response_rate_percent over time for hospitals with multiple survey periods.
WITH ResponseRates AS
(
    SELECT
        facility_id,
        facility_name,
        start_date,
        end_date,
        MAX(TRY_CAST(survey_response_rate_percent AS INT)) AS ResponseRate
    FROM HospitalQuality.dbo.hcahps_survey
    WHERE TRY_CAST(survey_response_rate_percent AS INT) IS NOT NULL
    GROUP BY
        facility_id,
        facility_name,
        start_date,
        end_date
)

SELECT
    facility_name,
    start_date,
    end_date,
    ResponseRate,

    LAG(ResponseRate) OVER
    (
        PARTITION BY facility_id
        ORDER BY start_date
    ) AS PreviousResponseRate,

    ResponseRate -
    LAG(ResponseRate) OVER
    (
        PARTITION BY facility_id
        ORDER BY start_date
    ) AS ResponseRateChange

FROM ResponseRates
ORDER BY facility_name, start_date;


-- PERSPECTIVE 5: Patient Experience | DIFFICULT | Q75: Using a CTE joining hospital_general_info, timely_effective_care, and hcahps_survey, build a single "hospital scorecard" ranking hospitals nationally by combining risk score, timeliness score, and patient satisfaction with RANK().
WITH RiskScore AS
(
    SELECT
        facility_id,
        ISNULL(TRY_CAST(count_mort_measures_worse AS INT), 0) +
        ISNULL(TRY_CAST(count_safety_measures_worse AS INT), 0) +
        ISNULL(TRY_CAST(count_readm_measures_worse AS INT), 0) AS CompositeRiskScore
    FROM HospitalQuality.dbo.hospital_general_info
),

TimelinessScore AS
(
    SELECT
        facility_id,
        AVG(TRY_CAST(score AS FLOAT)) AS AvgTimelyScore
    FROM HospitalQuality.dbo.timely_effective_care
    WHERE TRY_CAST(score AS FLOAT) IS NOT NULL
    GROUP BY facility_id
),

SatisfactionScore AS
(
    SELECT
        facility_id,
        AVG(TRY_CAST(patient_survey_star_rating AS FLOAT)) AS AvgStarRating
    FROM HospitalQuality.dbo.hcahps_survey
    WHERE TRY_CAST(patient_survey_star_rating AS FLOAT) IS NOT NULL
    GROUP BY facility_id
),

Scorecard AS
(
    SELECT
        h.facility_id,
        h.facility_name,
        h.state,

        r.CompositeRiskScore,
        ROUND(t.AvgTimelyScore, 2) AS AvgTimelyScore,
        ROUND(s.AvgStarRating, 2) AS AvgStarRating,

        -- Combined score: satisfaction (out of 5) scaled to 100,
        -- timeliness as-is (0-100), risk penalised 10 points per worse measure
        ROUND(
            (s.AvgStarRating * 20) +
            t.AvgTimelyScore -
            (r.CompositeRiskScore * 10),
            2
        ) AS OverallScore

    FROM HospitalQuality.dbo.hospital_general_info h
    INNER JOIN RiskScore r
        ON h.facility_id = r.facility_id
    INNER JOIN TimelinessScore t
        ON h.facility_id = t.facility_id
    INNER JOIN SatisfactionScore s
        ON h.facility_id = s.facility_id
)

SELECT
    facility_name,
    state,
    CompositeRiskScore,
    AvgTimelyScore,
    AvgStarRating,
    OverallScore,

    RANK() OVER
    (
        ORDER BY OverallScore DESC
    ) AS NationalRank

FROM Scorecard
ORDER BY NationalRank;