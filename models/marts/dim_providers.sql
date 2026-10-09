{{
  config(
    materialized='table',
    tags=['marts', 'dimensions', 'providers'],
    indexes=[
      {
        'columns': ['provider_npi'],
        'unique': True
      },
      {
        'columns': ['employee_id'],
        'unique': True
      }
    ],
    pre_hook="{{ log('Starting dim_providers transformation', info=true) }}"
  )
}}

/*
Dimension Table: Providers
- Contains provider/employee attributes
- Slowly changing dimension (SCD Type 1)
- Used for provider filtering and grouping in analytics
*/

with employees as (
  select
    employee_key,
    employee_id,
    first_name,
    last_name,
    npi as provider_npi,
    job_title,
    employment_status,
    email as provider_email,
    phone as provider_phone,
    department_id as department_key,
    department_name as department_name,
    hire_date,
    termination_date,
    created_at,
    updated_at
  from {{ ref('stg_employees') }}
),

with_full_name as (
  select
    employee_key as provider_key,
    employee_id as provider_id,
    provider_npi,
    concat(first_name, ' ', last_name) as provider_name,
    first_name as provider_first_name,
    last_name as provider_last_name,
    job_title,
    employment_status as current_employment_status,
    provider_email,
    provider_phone,
    department_key,
    department_name,
    hire_date as provider_hire_date,
    termination_date as provider_termination_date,
    case
      when employment_status = 'ACTIVE' then 1
      else 0
    end as is_active_provider,
    created_at,
    updated_at,
    current_timestamp() as dbt_loaded_at
  from employees
)

select *
from with_full_name
where provider_npi is not null

