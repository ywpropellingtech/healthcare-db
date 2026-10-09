{{
  config(
    materialized='table',
    tags=['marts', 'aggregates', 'department_utilization'],
    indexes=[
      {
        'columns': ['metric_date', 'department_id'],
        'unique': False
      }
    ],
    pre_hook="{{ log('Starting mart_department_utilization transformation', info=true) }}"
  )
}}

/*
Mart: Department Utilization Analysis
- Daily metrics for department-level operational analytics
- Includes encounter volume, provider utilization, and efficiency metrics
- Designed for operations teams and capacity planning
*/

with daily_dept_encounters as (
  select
    encounter_date as metric_date,
    encounter_department_id as department_id,

    -- Volume metrics
    count(distinct encounter_id) as total_encounters,
    count(distinct patient_id) as unique_patients,
    count(distinct provider_npi) as active_providers,

    -- Encounter type breakdown
    count(case when encounter_type = 'OFFICE' then 1 end) as office_encounters,
    count(case when encounter_type = 'TELEHEALTH' then 1 end) as telehealth_encounters,
    count(case when encounter_type = 'ED' then 1 end) as ed_encounters,
    count(case when encounter_type = 'INPATIENT' then 1 end) as inpatient_encounters,
    count(case when encounter_type = 'OUTPATIENT' then 1 end) as outpatient_encounters,

    -- Revenue metrics
    sum(charge_amount) as total_charges,
    sum(revenue_amount) as total_revenue,

    -- Time metrics
    sum(visit_duration_minutes) as total_visit_minutes,
    avg(visit_duration_minutes) as avg_visit_duration_minutes,

    -- Data quality
    count(case when charge_amount > 0 then 1 end) as encounters_with_charges,
    count(case when revenue_amount > 0 then 1 end) as encounters_with_revenue

  from {{ ref('int_employee_encounters') }}
  where encounter_department_id is not null
    and encounter_department_id != 'UNKNOWN'
  group by
    metric_date,
    encounter_department_id
),

with_calculations as (
  select
    {{ dbt_utils.generate_surrogate_key(['metric_date', 'department_id']) }} as dept_metric_key,
    metric_date,
    extract(dayofweek from metric_date) as day_of_week,
    extract(week from metric_date) as week_num,
    extract(month from metric_date) as month_num,
    extract(year from metric_date) as year_num,
    department_id,
    total_encounters,
    unique_patients,
    active_providers,
    office_encounters,
    telehealth_encounters,
    ed_encounters,
    inpatient_encounters,
    outpatient_encounters,

    -- Revenue metrics
    total_charges,
    total_revenue,
    round(total_revenue / nullif(total_encounters, 0), 2) as avg_revenue_per_encounter,

    -- Efficiency metrics
    round(total_encounters / nullif(active_providers, 0), 2) as avg_encounters_per_provider,
    round(total_visit_minutes / nullif(total_encounters, 0), 2) as avg_encounter_duration_minutes,

    -- Utilization metrics
    round(100.0 * office_encounters / nullif(total_encounters, 0), 1) as pct_office_encounters,
    round(100.0 * telehealth_encounters / nullif(total_encounters, 0), 1) as pct_telehealth_encounters,
    round(100.0 * ed_encounters / nullif(total_encounters, 0), 1) as pct_ed_encounters,
    round(100.0 * inpatient_encounters / nullif(total_encounters, 0), 1) as pct_inpatient_encounters,

    -- Quality metrics
    encounters_with_charges,
    encounters_with_revenue,
    round(100.0 * encounters_with_revenue / nullif(total_encounters, 0), 1) as pct_encounters_with_revenue

  from daily_dept_encounters
)

select
  dept_metric_key,
  metric_date,
  day_of_week,
  week_num,
  month_num,
  year_num,
  department_id,
  total_encounters,
  unique_patients,
  active_providers,
  office_encounters,
  telehealth_encounters,
  ed_encounters,
  inpatient_encounters,
  outpatient_encounters,
  total_charges,
  total_revenue,
  avg_revenue_per_encounter,
  avg_encounters_per_provider,
  avg_encounter_duration_minutes,
  pct_office_encounters,
  pct_telehealth_encounters,
  pct_ed_encounters,
  pct_inpatient_encounters,
  encounters_with_charges,
  encounters_with_revenue,
  pct_encounters_with_revenue,
  current_timestamp() as dbt_loaded_at
from with_calculations

