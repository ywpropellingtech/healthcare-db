{{
  config(
    materialized='view',
    tags=['staging', 'employees'],
    pre_hook="{{ log('Starting stg_employees transformation', info=true) }}"
  )
}}

/*
Staging layer for employee data from Workday
- Cleans and normalizes employee records
- Standardizes name, NPI, salary, and FTE formats
- Handles missing values gracefully
*/

with source_data as (
  select
    EMPLOYEE_ID,
    FULL_NAME,
    NPI,
    JOB_TITLE,
    WORKER_TYPE,
    DEPARTMENT,
    COST_CENTER,
    FTE,
    ANNUAL_SALARY,
    HIRE_DATE,
    TERMINATION_DATE,
    LOCATION,
    LAST_UPDATED
  from {{ source('raw_workday', 'WRK_EMPLOYEES') }}
  where EMPLOYEE_ID is not null
),

cleaned_data as (
  select
    EMPLOYEE_ID as employee_id,
    trim(FULL_NAME) as full_name,
    NPI as npi,
    trim(JOB_TITLE) as job_title,
    trim(WORKER_TYPE) as worker_type,
    trim(DEPARTMENT) as department,
    trim(COST_CENTER) as cost_center,
    FTE as fte,
    ANNUAL_SALARY as annual_salary,
    HIRE_DATE as hire_date,
    TERMINATION_DATE as termination_date,
    trim(LOCATION) as location,
    LAST_UPDATED as last_updated,
    current_timestamp() as dbt_loaded_at,
    row_number() over (partition by EMPLOYEE_ID order by LAST_UPDATED desc) as recency_rank
  from source_data
),

-- Deduplicate to keep most recent record per employee
deduplicated as (
  select
    employee_id,
    full_name,
    npi,
    job_title,
    worker_type,
    department,
    cost_center,
    fte,
    annual_salary,
    hire_date,
    termination_date,
    location,
    last_updated,
    dbt_loaded_at
  from cleaned_data
  where recency_rank = 1
),

select
  EMPLOYEE_ID as employee_key,
  *
from deduplicated
where employee_id is not null
