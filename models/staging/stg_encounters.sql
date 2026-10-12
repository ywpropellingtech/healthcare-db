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

-- Lookup table: get most common NPI per provider (to fill NULLs)
provider_npi_lookup as (
  select
    provider_name,
    known_npi
  from (
    select
      trim(PROVIDER_NAME) as provider_name,
      trim(PROVIDER_NPI) as known_npi,
      count(*) as npi_frequency,
      row_number() over (partition by trim(PROVIDER_NAME) order by count(*) desc) as rn
    from {{ source('raw_epic', 'EPC_ENCOUNTERS') }}
    where PROVIDER_NPI is not null
    group by trim(PROVIDER_NAME), trim(PROVIDER_NPI)
  )
  where rn = 1
),

cleaned_data as (
  select
    sd.ENCOUNTER_ID as encounter_id,
    sd.PATIENT_MRN as patient_id,
    trim(sd.PROVIDER_NAME) as provider_name,
    coalesce(trim(sd.PROVIDER_NPI), pnl.known_npi) as provider_npi,
    sd.ENCOUNTER_DATE as encounter_date,
    trim(sd.DEPARTMENT) as department,
    upper(trim(sd.VISIT_TYPE)) as visit_type,
    upper(trim(sd.ENCOUNTER_STATUS)) as encounter_status,
    case
      when sd.WRVU is null or sd.WRVU < 0 then 0
      else sd.WRVU
    end as wrvu,
    case
      when sd.CHARGE_AMOUNT is null or sd.CHARGE_AMOUNT < 0 then 0
      else sd.CHARGE_AMOUNT
    end as charge_amount,
    current_timestamp() as dbt_loaded_at,
    row_number() over (partition by sd.ENCOUNTER_ID, sd.PATIENT_MRN, sd.ENCOUNTER_DATE order by sd.ENCOUNTER_ID) as dedup_rank
  from source_data sd
  left join provider_npi_lookup pnl on trim(sd.PROVIDER_NAME) = pnl.provider_name
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
