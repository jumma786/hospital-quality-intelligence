IF DB_ID('HospitalQuality') IS NULL
BEGIN
    CREATE DATABASE HospitalQuality;
END
GO

USE HospitalQuality;
GO

IF OBJECT_ID('dbo.hospital_general_info', 'U') IS NOT NULL DROP TABLE dbo.hospital_general_info;
IF OBJECT_ID('dbo.timely_effective_care', 'U') IS NOT NULL DROP TABLE dbo.timely_effective_care;
IF OBJECT_ID('dbo.hcahps_survey', 'U') IS NOT NULL DROP TABLE dbo.hcahps_survey;
GO

CREATE TABLE dbo.hospital_general_info (
    facility_id                         VARCHAR(10),
    facility_name                       VARCHAR(200),
    address                             VARCHAR(200),
    city_town                           VARCHAR(100),
    state                               VARCHAR(5),
    zip_code                            VARCHAR(10),
    county_parish                       VARCHAR(100),
    phone_number                        VARCHAR(20),
    hospital_type                       VARCHAR(100),
    hospital_ownership                  VARCHAR(100),
    emergency_services                  VARCHAR(5),
    birthing_friendly                   VARCHAR(5),
    overall_rating                      VARCHAR(20),
    overall_rating_footnote             VARCHAR(100),
    mort_group_measure_count            VARCHAR(20),
    count_facility_mort_measures        VARCHAR(20),
    count_mort_measures_better          VARCHAR(20),
    count_mort_measures_no_different    VARCHAR(20),
    count_mort_measures_worse           VARCHAR(20),
    mort_group_footnote                 VARCHAR(100),
    safety_group_measure_count          VARCHAR(20),
    count_facility_safety_measures      VARCHAR(20),
    count_safety_measures_better        VARCHAR(20),
    count_safety_measures_no_different  VARCHAR(20),
    count_safety_measures_worse         VARCHAR(20),
    safety_group_footnote               VARCHAR(100),
    readm_group_measure_count           VARCHAR(20),
    count_facility_readm_measures       VARCHAR(20),
    count_readm_measures_better         VARCHAR(20),
    count_readm_measures_no_different   VARCHAR(20),
    count_readm_measures_worse          VARCHAR(20),
    readm_group_footnote                VARCHAR(100),
    pt_exp_group_measure_count          VARCHAR(20),
    count_facility_pt_exp_measures      VARCHAR(20),
    pt_exp_group_footnote               VARCHAR(100),
    te_group_measure_count              VARCHAR(20),
    count_facility_te_measures          VARCHAR(20),
    te_group_footnote                   VARCHAR(100)
);
GO

CREATE TABLE dbo.timely_effective_care (
    facility_id      VARCHAR(10),
    facility_name    VARCHAR(200),
    address          VARCHAR(200),
    city_town        VARCHAR(100),
    state            VARCHAR(5),
    zip_code         VARCHAR(10),
    county_parish    VARCHAR(100),
    phone_number     VARCHAR(20),
    condition_name   VARCHAR(150),
    measure_id       VARCHAR(50),
    measure_name     VARCHAR(400),
    score            VARCHAR(30),
    sample_size      VARCHAR(50),
    footnote         VARCHAR(100),
    start_date       VARCHAR(20),
    end_date         VARCHAR(20)
);
GO

CREATE TABLE dbo.hcahps_survey (
    facility_id                            VARCHAR(10),
    facility_name                          VARCHAR(200),
    address                                VARCHAR(200),
    city_town                              VARCHAR(100),
    state                                  VARCHAR(5),
    zip_code                               VARCHAR(10),
    county_parish                          VARCHAR(100),
    phone_number                           VARCHAR(20),
    hcahps_measure_id                      VARCHAR(30),
    hcahps_question                        VARCHAR(400),
    hcahps_answer_description              VARCHAR(400),
    patient_survey_star_rating             VARCHAR(20),
    patient_survey_star_rating_footnote    VARCHAR(100),
    hcahps_answer_percent                  VARCHAR(20),
    hcahps_answer_percent_footnote          VARCHAR(100),
    hcahps_linear_mean_value                VARCHAR(20),
    number_of_completed_surveys             VARCHAR(20),
    number_of_completed_surveys_footnote    VARCHAR(100),
    survey_response_rate_percent            VARCHAR(20),
    survey_response_rate_percent_footnote   VARCHAR(100),
    start_date                              VARCHAR(20),
    end_date                                VARCHAR(20)
);
GO

SELECT 'hospital_general_info' AS table_name, COUNT(*) AS row_count FROM dbo.hospital_general_info
UNION ALL
SELECT 'timely_effective_care', COUNT(*) FROM dbo.timely_effective_care
UNION ALL
SELECT 'hcahps_survey', COUNT(*) FROM dbo.hcahps_survey;
GO


SELECT DISTINCT birthing_friendly
FROM HospitalQuality.dbo.hospital_general_info;

SELECT DISTINCT emergency_services
FROM HospitalQuality.dbo.hospital_general_info;

SELECT DISTINCT birthing_friendly
FROM HospitalQuality.dbo.hospital_general_info;

SELECT DISTINCT overall_rating
FROM HospitalQuality.dbo.hospital_general_info;

SELECT DISTINCT hospital_type
FROM HospitalQuality.dbo.hospital_general_info;

SELECT DISTINCT hospital_ownership
FROM HospitalQuality.dbo.hospital_general_info;