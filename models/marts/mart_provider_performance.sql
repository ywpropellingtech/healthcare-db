{{
  config(
    materialized='table',
    tags=['marts', 'aggregates', 'provider_performance'],
    indexes=[
      {
        'columns': ['metric_date', 'employee_id'],
        'unique': False
      }
    ],
    pre_hook="{{ log('Starting mart_provider_performance transformation', info=true) }}"
  )
}}

/*
Mart: Provider Performance Dashboard
- Daily KPIs for provider performance analytics
- Includes encounter volume, revenue, and efficiency metrics
- Designed for executive dashboards and performance monitoring
*/

with provider_metrics as (
  select
    pm.provider_metric_key,
    pm.metric_date,
    pm.employee_key,
    pm.employee_id,
    pm.provider_npi,
    pm.provider_first_name,
    pm.provider_last_name,
    concat(pm.provider_first_name, ' ', pm.provider_last_name) as provider_name,
    pm.job_title,
    pm.employee_department_id,
    pm.employee_department_name,
    pm.total_encounters,
    pm.unique_patients,
    pm.office_encounters,
    pm.telehealth_encounters,
    pm.ed_encounters,
    pm.inpatient_encounters,
    pm.outpatient_encounters,
    pm.total_charges,
    pm.total_revenue,
    pm.avg_revenue_per_encounter,
    pm.avg_visit_duration_minutes,
    pm.total_visit_minutes,
    pm.encounters_with_charges,
    pm.encounters_with_revenue,
    pm.most_common_diagnosis,
    pm.most_common_procedure
  from {{ ref('int_provider_metrics') }} pm
),

with_calculations as (
  select
    provider_metric_key,
    metric_date,
    extract(dayofweek from metric_date) as day_of_week,
    extract(week from metric_date) as week_num,
    extract(month from metric_date) as month_num,
    extract(year from metric_date) as year_num,
    employee_key,
    employee_id,
    provider_npi,
    provider_name,
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

    -- Revenue metrics
    total_charges,
    total_revenue,
    avg_revenue_per_encounter,
    round(total_revenue / nullif(total_encounters, 0), 2) as effective_revenue_per_encounter,

    -- Efficiency metrics
    round(total_encounters / nullif(total_visit_minutes, 0), 4) as encounters_per_minute,
    avg_visit_duration_minutes,

    -- Volume metrics
    unique_patients,
    round(total_encounters / nullif(unique_patients, 0), 2) as encounters_per_patient,

    -- Encounter type mix
    round(100.0 * office_encounters / nullif(total_encounters, 0), 1) as pct_office_encounters,
    round(100.0 * telehealth_encounters / nullif(total_encounters, 0), 1) as pct_telehealth_encounters,
    round(100.0 * ed_encounters / nullif(total_encounters, 0), 1) as pct_ed_encounters,

    -- Quality metrics
    encounters_with_charges,
    encounters_with_revenue,
    round(100.0 * encounters_with_revenue / nullif(total_encounters, 0), 1) as pct_encounters_with_revenue,

    most_common_diagnosis,
    most_common_procedure
  from provider_metrics
)

select
  provider_metric_key,
  metric_date,
  day_of_week,
  week_num,
  month_num,
  year_num,
  employee_key,
  employee_id,
  provider_npi,
  provider_name,
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
  effective_revenue_per_encounter,
  encounters_per_minute,
  avg_visit_duration_minutes,
  encounters_per_patient,
  pct_office_encounters,
  pct_telehealth_encounters,
  pct_ed_encounters,
  encounters_with_charges,
  encounters_with_revenue,
  pct_encounters_with_revenue,
  most_common_diagnosis,
  most_common_procedure,
  current_timestamp() as dbt_loaded_at
from with_calculations

