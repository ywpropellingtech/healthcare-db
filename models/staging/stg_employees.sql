{{
  config(
    materialized='view',
    tags=['staging', 'employees'],
    pre_hook="{{ log('Starting stg_employees transformation', info=true) }}"
  )
}}

/*
Staging layer for employee data from Workday
- Cleans and normalizes employee records (clinical and non-clinical)
- Standardizes name, NPI, department, salary, and FTE formats
- Handles missing values gracefully for non-clinical staff
- Deduplicates based on last_updated timestamp
*/

with source_data as (
  select
    EMPLOYEE_ID as employee_id,
    FIRST_NAME as first_name,
    LAST_NAME as last_name,
    FULL_NAME as full_name,
    NPI as npi,
    DEPARTMENT_ID as department_id,
    DEPARTMENT_NAME as department_name,
    JOB_TITLE as job_title,
    WORKER_TYPE as worker_type,
    FTE as fte,
    ANNUAL_SALARY as annual_salary,
    HIRE_DATE as hire_date,
    TERMINATION_DATE as termination_date,
    STATUS as status,
    EMAIL as email,
    PHONE as phone,
    LAST_UPDATED as last_updated,
    CREATED_AT as created_at,
    UPDATED_AT as updated_at
  from {{ source('raw_workday', 'WRK_EMPLOYEES') }}
  where EMPLOYEE_ID is not null
),

-- Handle full_name parsing if first/last names not available
name_parsed as (
  select
    *,
    case
      when first_name is not null and last_name is not null
        then trim(first_name) || ' ' || trim(last_name)
      when full_name is not null
        then trim(full_name)
      else 'UNKNOWN'
    end as full_name_standardized
  from source_data
),

-- Standardize NPI (10-digit, remove spaces/decimals, flag invalid)
npi_cleaned as (
  select
    *,
    case
      when npi is null or trim(npi) = '' then null
      when regexp_like(trim(npi), '^\d{10}$') then upper(trim(npi))
      -- Handle Excel-coerced format (e.g., "1234567890.0")
      when regexp_like(replace(trim(npi), '.0', ''), '^\d{10}$')
        then replace(trim(npi), '.0', '')
      -- Handle space-separated format (e.g., "12 34567890")
      when regexp_like(replace(trim(npi), ' ', ''), '^\d{10}$')
        then replace(trim(npi), ' ', '')
      else null  -- Invalid NPI
    end as npi_standardized,
    case
      when npi is null or trim(npi) = '' then false
      when not regexp_like(replace(replace(trim(npi), '.0', ''), ' ', ''), '^\d{10}$')
        then true
      else false
    end as npi_invalid_flag
  from name_parsed
),

-- Standardize salary (handle text with $ and commas)
salary_cleaned as (
  select
    *,
    case
      when annual_salary is null or trim(annual_salary) = '' then null
      -- Try numeric parse first
      when try_to_number(annual_salary) is not null
        then try_to_number(annual_salary)
      -- Handle text format like "$286,400"
      when try_to_number(replace(replace(annual_salary, '$', ''), ',', '')) is not null
        then try_to_number(replace(replace(annual_salary, '$', ''), ',', ''))
      else null
    end as annual_salary_numeric,
    case
      when annual_salary is not null and worker_type = 'Contingent Worker'
        then 1  -- Flag: contingent workers often have blank salary
      when annual_salary is null or trim(annual_salary) = ''
        then 1
      else 0
    end as salary_missing_flag
  from npi_cleaned
),

-- Standardize FTE (default 1.0 if missing for active employees)
fte_standardized as (
  select
    *,
    case
      when fte is null or trim(fte) = '' then
        case
          when lower(status) = 'active' then 1.0
          else null
        end
      else try_to_number(fte)
    end as fte_standardized
  from salary_cleaned
),

cleaned_data as (
  select
    employee_id,
    full_name_standardized as full_name,
    trim(first_name) as first_name,
    trim(last_name) as last_name,
    npi_standardized as npi,
    npi_invalid_flag,
    coalesce(department_id, 'UNKNOWN') as department_id,
    trim(department_name) as department_name,
    trim(job_title) as job_title,
    trim(worker_type) as worker_type,
    fte_standardized as fte,
    annual_salary_numeric as annual_salary,
    salary_missing_flag,
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
    try_to_timestamp(last_updated) as last_updated,
    try_to_timestamp(created_at) as created_at,
    try_to_timestamp(updated_at) as updated_at,
    current_timestamp() as dbt_loaded_at,
    row_number() over (partition by employee_id order by try_to_timestamp(last_updated) desc) as recency_rank
  from fte_standardized
),

-- Deduplicate to keep most recent record per employee
deduplicated as (
  select
    employee_id,
    full_name,
    first_name,
    last_name,
    npi,
    npi_invalid_flag,
    department_id,
    department_name,
    job_title,
    worker_type,
    fte,
    annual_salary,
    salary_missing_flag,
    hire_date,
    termination_date,
    employment_status,
    email,
    phone,
    last_updated,
    created_at,
    updated_at,
    dbt_loaded_at
  from cleaned_data
  where recency_rank = 1
),

with_surrogate_key as (
  select
    {{ dbt_utils.generate_surrogate_key(['employee_id', 'hire_date']) }} as employee_key,
    *
  from deduplicated
)

select *
from with_surrogate_key
where employee_id is not null
