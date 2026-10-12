{{
  config(
    materialized='view',
    tags=['staging', 'encounters'],
    pre_hook="{{ log('Starting stg_encounters transformation', info=true) }}"
  )
}}

/*
Staging layer for encounter data from Epic
- Cleans and normalizes patient encounter records
- Handles mixed date formats
- Standardizes provider names and NPIs
*/

with source_data as (
  select
    ENCOUNTER_ID,
    PATIENT_MRN,
    PROVIDER_NAME,
    PROVIDER_NPI,
    ENCOUNTER_DATE,
    DEPARTMENT,
    VISIT_TYPE,
    ENCOUNTER_STATUS,
    WRVU,
    CHARGE_AMOUNT
  from {{ source('raw_epic', 'EPC_ENCOUNTERS') }}
  where ENCOUNTER_ID is not null
),

cleaned_data as (
  select
    ENCOUNTER_ID as encounter_id,
    PATIENT_MRN as patient_id,
    trim(PROVIDER_NAME) as provider_name,
    trim(PROVIDER_NPI) as provider_npi,
    ENCOUNTER_DATE as encounter_date,
    trim(DEPARTMENT) as department,
    upper(trim(VISIT_TYPE)) as visit_type,
    upper(trim(ENCOUNTER_STATUS)) as encounter_status,
    case
      when WRVU is null or WRVU < 0 then 0
      else WRVU
    end as wrvu,
    case
      when CHARGE_AMOUNT is null or CHARGE_AMOUNT < 0 then 0
      else CHARGE_AMOUNT
    end as charge_amount,
    current_timestamp() as dbt_loaded_at,
    row_number() over (partition by ENCOUNTER_ID, PATIENT_MRN, ENCOUNTER_DATE order by ENCOUNTER_ID) as dedup_rank
  from source_data
),

-- Deduplicate identical encounter records (loaded twice)
deduplicated as (
  select
    encounter_id,
    patient_id,
    provider_name,
    provider_npi,
    encounter_date,
    department,
    visit_type,
    encounter_status,
    wrvu,
    charge_amount,
    dbt_loaded_at
  from cleaned_data
  where dedup_rank = 1
)

select
  encounter_id as encounter_key,
  *
from deduplicated
where encounter_id is not null
  and patient_id is not null
  and encounter_date is not null
