{{
  config(
    materialized='view',
    schema='staging',
    tags=['staging', 'encounters'],
    pre_hook="{{ log('Starting stg_encounters transformation', info=true) }}"
  )
}}

/*
Staging layer for encounter data from Epic
- Cleans and normalizes patient encounter records
- Parses and validates encounter dates/times
- Removes records with missing critical identifiers
- Standardizes encounter type values
*/

with source_data as (
  select
    encounter_id,
    patient_id,
    provider_npi,
    encounter_date,
    encounter_time,
    encounter_type,
    department_id,
    chief_complaint,
    diagnosis_code,
    procedure_code,
    discharge_disposition,
    visit_duration_minutes,
    charge_amount,
    revenue_amount,
    created_at,
    updated_at
  from {{ source('raw_epic', 'EPC_ENCOUNTERS') }}
  where encounter_id is not null
    and patient_id is not null
    and provider_npi is not null
    and encounter_date is not null
),

cleaned_data as (
  select
    encounter_id,
    patient_id,
    upper(trim(provider_npi)) as provider_npi,
    try_to_date(encounter_date) as encounter_date,
    try_to_timestamp(concat(encounter_date, ' ', coalesce(encounter_time, '00:00:00'))) as encounter_datetime,
    extract(hour from encounter_datetime) as encounter_hour,
    case
      when lower(trim(encounter_type)) = 'office' then 'OFFICE'
      when lower(trim(encounter_type)) = 'telehealth' then 'TELEHEALTH'
      when lower(trim(encounter_type)) = 'ed' then 'ED'
      when lower(trim(encounter_type)) = 'inpatient' then 'INPATIENT'
      when lower(trim(encounter_type)) = 'outpatient' then 'OUTPATIENT'
      else 'OTHER'
    end as encounter_type,
    coalesce(department_id, 'UNKNOWN') as department_id,
    trim(chief_complaint) as chief_complaint,
    upper(trim(diagnosis_code)) as diagnosis_code,
    upper(trim(procedure_code)) as procedure_code,
    trim(discharge_disposition) as discharge_disposition,
    case
      when visit_duration_minutes < 0 then null
      when visit_duration_minutes > 1440 then null  -- Cap at 24 hours
      else visit_duration_minutes
    end as visit_duration_minutes,
    case
      when charge_amount < 0 then 0
      else coalesce(charge_amount, 0)
    end as charge_amount,
    case
      when revenue_amount < 0 then 0
      else coalesce(revenue_amount, 0)
    end as revenue_amount,
    try_to_timestamp(created_at) as created_at,
    try_to_timestamp(updated_at) as updated_at,
    current_timestamp() as dbt_loaded_at
  from source_data
),

with_surrogate_key as (
  select
    {{ dbt_utils.generate_surrogate_key(['encounter_id', 'patient_id', 'provider_npi']) }} as encounter_key,
    *
  from cleaned_data
)

select *
from with_surrogate_key
where encounter_id is not null
  and patient_id is not null
  and provider_npi is not null
  and encounter_date is not null
