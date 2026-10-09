{{
  config(
    materialized='view',
    tags=['intermediate', 'metrics'],
    pre_hook="{{ log('Starting int_provider_metrics transformation', info=true) }}"
  )
}}

/*
Intermediate model: Provider Daily Metrics
- Aggregates encounter data at provider level by day
- Calculates key performance indicators
- Includes encounter counts, revenue, and duration metrics
*/

with daily_provider_encounters as (
  select
    encounter_date as metric_date,
    employee_key,
    employee_id,
    provider_npi,
    provider_first_name,
    provider_last_name,
    job_title,
    employee_department_id,
    employee_department_name,

    -- Encounter counts
    count(distinct encounter_id) as total_encounters,
    count(distinct patient_id) as unique_patients,

    -- Encounter type breakdown
    count(case when encounter_type = 'OFFICE' then 1 end) as office_encounters,
    count(case when encounter_type = 'TELEHEALTH' then 1 end) as telehealth_encounters,
    count(case when encounter_type = 'ED' then 1 end) as ed_encounters,
    count(case when encounter_type = 'INPATIENT' then 1 end) as inpatient_encounters,
    count(case when encounter_type = 'OUTPATIENT' then 1 end) as outpatient_encounters,

    -- Revenue metrics
    sum(charge_amount) as total_charges,
    sum(revenue_amount) as total_revenue,
    avg(revenue_amount) as avg_revenue_per_encounter,

    -- Time metrics
    avg(visit_duration_minutes) as avg_visit_duration_minutes,
    sum(visit_duration_minutes) as total_visit_minutes,

    -- Data quality
    count(case when charge_amount > 0 then 1 end) as encounters_with_charges,
    count(case when revenue_amount > 0 then 1 end) as encounters_with_revenue,

    -- Top diagnosis and procedure (most frequent)
    mode(diagnosis_code) as most_common_diagnosis,
    mode(procedure_code) as most_common_procedure

  from {{ ref('int_employee_encounters') }}
  where employee_key is not null
    and provider_npi is not null
  group by
    metric_date,
    employee_key,
    employee_id,
    provider_npi,
    provider_first_name,
    provider_last_name,
    job_title,
    employee_department_id,
    employee_department_name
)

select
  {{ dbt_utils.generate_surrogate_key(['metric_date', 'employee_id']) }} as provider_metric_key,
  metric_date,
  employee_key,
  employee_id,
  provider_npi,
  provider_first_name,
  provider_last_name,
  job_title,
  employee_department_id,
  employee_department_name,
  total_encounters,
  unique_patients,
  office_encounters,
  telehealth_encounters,
  ed_encounters,
  inpatient_encounters,
  outpatient_encounters,
  total_charges,
  total_revenue,
  avg_revenue_per_encounter,
  avg_visit_duration_minutes,
  total_visit_minutes,
  encounters_with_charges,
  encounters_with_revenue,
  most_common_diagnosis,
  most_common_procedure,
  current_timestamp() as dbt_loaded_at
from daily_provider_encounters
