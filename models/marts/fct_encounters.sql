{{
  config(
    materialized='table',
    schema='marts',
    tags=['marts', 'facts', 'encounters'],
    indexes=[
      {
        'columns': ['encounter_date', 'provider_npi', 'employee_id'],
        'unique': False
      },
      {
        'columns': ['patient_id'],
        'unique': False
      }
    ],
    pre_hook="{{ log('Starting fct_encounters transformation', info=true) }}"
  )
}}

/*
Fact Table: Encounters
- Core fact table for patient encounters
- Designed for analysis of encounter volume, revenue, and provider performance
- Includes all dimensional keys for slicing and dicing
*/

select
  e.encounter_key,
  e.encounter_id,
  e.patient_id,
  e.employee_key,
  e.employee_id,
  e.provider_npi,
  e.encounter_date,
  e.encounter_datetime,
  e.encounter_hour,
  extract(dayofweek from e.encounter_date) as encounter_day_of_week,
  extract(week from e.encounter_date) as encounter_week,
  extract(month from e.encounter_date) as encounter_month,
  extract(year from e.encounter_date) as encounter_year,
  e.encounter_type,
  e.encounter_department_id,
  e.chief_complaint,
  e.diagnosis_code,
  e.procedure_code,
  e.discharge_disposition,
  e.visit_duration_minutes,
  e.charge_amount,
  e.revenue_amount,
  case
    when e.revenue_amount > 0 then 1
    else 0
  end as is_revenue_generating,
  case
    when e.charge_amount > 0 then 1
    else 0
  end as is_charged,
  case
    when e.visit_duration_minutes > 0 then 1
    else 0
  end as is_timed_visit,
  e.created_at,
  e.updated_at,
  current_timestamp() as dbt_loaded_at
from {{ ref('int_employee_encounters') }} e
where e.encounter_date >= '2020-01-01'
  and e.encounter_date <= current_date()
