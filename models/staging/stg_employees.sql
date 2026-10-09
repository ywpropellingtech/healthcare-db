{{
  config(
    materialized='view',
    schema='staging',
    tags=['staging', 'employees'],
    pre_hook="{{ log('Starting stg_employees transformation', info=true) }}"
  )
}}

/*
Staging layer for employee data from Workday
- Cleans and normalizes employee records
- Removes records with missing critical identifiers
- Standardizes field formats and data types
*/

with source_data as (
  select
    employee_id,
    first_name,
    last_name,
    npi,
    department_id,
    department_name,
    job_title,
    hire_date,
    termination_date,
    status,
    email,
    phone,
    created_at,
    updated_at
  from {{ source('raw_workday', 'WRK_EMPLOYEES') }}
  where employee_id is not null
    and npi is not null
),

cleaned_data as (
  select
    employee_id,
    trim(first_name) as first_name,
    trim(last_name) as last_name,
    upper(trim(npi)) as npi,
    coalesce(department_id, 'UNKNOWN') as department_id,
    trim(department_name) as department_name,
    trim(job_title) as job_title,
    try_to_date(hire_date) as hire_date,
    try_to_date(termination_date) as termination_date,
    case
      when lower(status) in ('active', 'a') then 'ACTIVE'
      when lower(status) in ('inactive', 'i') then 'INACTIVE'
      when lower(status) in ('terminated', 't') then 'TERMINATED'
      else 'UNKNOWN'
    end as employment_status,
    lower(trim(email)) as email,
    trim(phone) as phone,
    try_to_timestamp(created_at) as created_at,
    try_to_timestamp(updated_at) as updated_at,
    current_timestamp() as dbt_loaded_at
  from source_data
),

with_surrogate_key as (
  select
    {{ dbt_utils.generate_surrogate_key(['employee_id', 'hire_date']) }} as employee_key,
    *
  from cleaned_data
)

select *
from with_surrogate_key
where employee_id is not null
  and npi is not null
