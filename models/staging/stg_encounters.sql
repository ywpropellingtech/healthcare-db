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
- Handles mixed date formats (YYYY-MM-DD and MM/DD/YYYY)
- Standardizes provider names and NPIs (handle Excel coercion, spacing)
- Parses department variants and trims whitespace
- Handles wRVU nulls/zeros for no-shows/cancellations
- Validates charge amounts and encounter status
*/

with source_data as (
  select
    encounter_id,
    patient_id,
    provider_name,
    provider_npi,
    encounter_date,
    encounter_time,
    encounter_type,
    encounter_status,
    department,
    chief_complaint,
    diagnosis_code,
    procedure_code,
    discharge_disposition,
    visit_duration_minutes,
    wrvu,
    charge_amount,
    revenue_amount,
    created_at,
    updated_at
  from {{ source('raw_epic', 'EPC_ENCOUNTERS') }}
  where encounter_id is not null
),

-- Handle mixed date formats: YYYY-MM-DD and MM/DD/YYYY
date_cleaned as (
  select
    *,
    case
      when encounter_date is null or trim(encounter_date) = '' then null
      -- Try ISO format first (YYYY-MM-DD)
      when try_to_date(encounter_date, 'YYYY-MM-DD') is not null
        then try_to_date(encounter_date, 'YYYY-MM-DD')
      -- Try US format (MM/DD/YYYY)
      when try_to_date(encounter_date, 'MM/DD/YYYY') is not null
        then try_to_date(encounter_date, 'MM/DD/YYYY')
      else null
    end as encounter_date_standardized
  from source_data
),

-- Standardize provider name: normalize case, trim whitespace, handle middle initials
provider_name_cleaned as (
  select
    *,
    -- Parse "LAST, FIRST M" format to "First Last"
    case
      when provider_name is null or trim(provider_name) = '' then 'UNKNOWN'
      when position(',' in provider_name) > 0
        then trim(initcap(substr_idx(provider_name, ',', 2))) || ' ' ||
             trim(initcap(substr_idx(provider_name, ',', 1)))
      else trim(initcap(provider_name))
    end as provider_name_standardized
  from date_cleaned
),

-- Standardize NPI (10-digit, remove spaces/decimals, flag invalid)
npi_cleaned as (
  select
    *,
    case
      when provider_npi is null or trim(provider_npi) = '' then null
      -- Valid 10-digit NPI
      when regexp_like(trim(provider_npi), '^\d{10}$') then upper(trim(provider_npi))
      -- Handle Excel-coerced format (e.g., "1234567890.0")
      when regexp_like(replace(trim(provider_npi), '.0', ''), '^\d{10}$')
        then replace(trim(provider_npi), '.0', '')
      -- Handle space-separated format (e.g., "12 34567890")
      when regexp_like(replace(trim(provider_npi), ' ', ''), '^\d{10}$')
        then replace(trim(provider_npi), ' ', '')
      else null  -- Invalid NPI
    end as provider_npi_standardized,
    case
      when provider_npi is null or trim(provider_npi) = '' then false
      when not regexp_like(replace(replace(trim(provider_npi), '.0', ''), ' ', ''), '^\d{10}$')
        then true
      else false
    end as npi_invalid_flag
  from provider_name_cleaned
),

-- Standardize department names (normalize case, trim, handle variants)
department_cleaned as (
  select
    *,
    case
      when department is null or trim(department) = '' then 'UNKNOWN'
      else upper(trim(department))  -- Standardize to uppercase
    end as department_standardized
  from npi_cleaned
),

-- Standardize encounter status and handle wRVU
encounter_cleaned as (
  select
    *,
    case
      when lower(trim(encounter_status)) in ('completed', 'c') then 'COMPLETED'
      when lower(trim(encounter_status)) in ('no-show', 'no show', 'no_show', 'ns') then 'NO_SHOW'
      when lower(trim(encounter_status)) in ('cancelled', 'canceled', 'c') then 'CANCELLED'
      else 'UNKNOWN'
    end as encounter_status_standardized,
    -- wRVU is null or 0 for no-shows/cancellations
    case
      when lower(trim(encounter_status)) in ('no-show', 'no show', 'no_show', 'ns', 'cancelled', 'canceled')
        then 0
      when wrvu is null or wrvu = 0 or wrvu < 0
        then 0
      else wrvu
    end as wrvu_standardized
  from department_cleaned
),

-- Standardize encounter type
encounter_type_cleaned as (
  select
    *,
    case
      when lower(trim(encounter_type)) = 'office' then 'NEW_PATIENT'
      when lower(trim(encounter_type)) = 'follow-up' or lower(trim(encounter_type)) = 'follow_up' then 'FOLLOW_UP'
      when lower(trim(encounter_type)) = 'telehealth' then 'TELEHEALTH'
      when lower(trim(encounter_type)) = 'procedure' then 'PROCEDURE'
      when lower(trim(encounter_type)) = 'ed' then 'ED'
      when lower(trim(encounter_type)) = 'inpatient' then 'INPATIENT'
      when lower(trim(encounter_type)) = 'outpatient' then 'OUTPATIENT'
      else 'OTHER'
    end as encounter_type_standardized
  from encounter_cleaned
),

-- Validate charge amounts
charge_cleaned as (
  select
    *,
    case
      when charge_amount is null or charge_amount < 0 then 0
      else charge_amount
    end as charge_amount_validated,
    case
      when revenue_amount is null or revenue_amount < 0 then 0
      else revenue_amount
    end as revenue_amount_validated
  from encounter_type_cleaned
),

final_cleaned as (
  select
    encounter_id,
    patient_id,
    provider_name_standardized as provider_name,
    provider_npi_standardized as provider_npi,
    npi_invalid_flag,
    encounter_date_standardized as encounter_date,
    try_to_timestamp(concat(encounter_date_standardized, ' ', coalesce(encounter_time, '00:00:00'))) as encounter_datetime,
    extract(hour from encounter_datetime) as encounter_hour,
    encounter_type_standardized as encounter_type,
    encounter_status_standardized as encounter_status,
    department_standardized as department,
    trim(chief_complaint) as chief_complaint,
    upper(trim(diagnosis_code)) as diagnosis_code,
    upper(trim(procedure_code)) as procedure_code,
    trim(discharge_disposition) as discharge_disposition,
    case
      when visit_duration_minutes < 0 then null
      when visit_duration_minutes > 1440 then null  -- Cap at 24 hours
      else visit_duration_minutes
    end as visit_duration_minutes,
    wrvu_standardized as wrvu,
    charge_amount_validated as charge_amount,
    revenue_amount_validated as revenue_amount,
    try_to_timestamp(created_at) as created_at,
    try_to_timestamp(updated_at) as updated_at,
    current_timestamp() as dbt_loaded_at
  from charge_cleaned
),

with_surrogate_key as (
  select
    {{ dbt_utils.generate_surrogate_key(['encounter_id', 'patient_id', 'provider_npi']) }} as encounter_key,
    *
  from final_cleaned
)

select *
from with_surrogate_key
where encounter_id is not null
  and patient_id is not null
  and encounter_date is not null
