{{
  config(
    materialized='view',
    schema='intermediate',
    tags=['intermediate', 'encounters'],
    pre_hook="{{ log('Starting int_employee_encounters transformation', info=true) }}"
  )
}}

/*
Intermediate model: Employee Encounters
- Joins employee and encounter data via NPI
- Enriches encounters with employee context
- Includes employee demographic and status information
*/

with employees as (
  select
    employee_key,
    employee_id,
    first_name,
    last_name,
    npi,
    department_id as employee_department_id,
    department_name as employee_department_name,
    job_title,
    hire_date,
    employment_status,
    email,
    phone
  from {{ ref('stg_employees') }}
  where employment_status in ('ACTIVE', 'INACTIVE')
),

encounters as (
  select
    encounter_key,
    encounter_id,
    patient_id,
    provider_npi,
    encounter_date,
    encounter_datetime,
    encounter_hour,
    encounter_type,
    department_id as encounter_department_id,
    chief_complaint,
    diagnosis_code,
    procedure_code,
    discharge_disposition,
    visit_duration_minutes,
    charge_amount,
    revenue_amount,
    created_at,
    updated_at
  from {{ ref('stg_encounters') }}
),

joined_data as (
  select
    e.encounter_key,
    e.encounter_id,
    e.patient_id,
    emp.employee_key,
    emp.employee_id,
    emp.first_name as provider_first_name,
    emp.last_name as provider_last_name,
    emp.npi as provider_npi,
    emp.job_title,
    emp.employment_status,
    emp.email as provider_email,
    emp.employee_department_id,
    emp.employee_department_name,
    e.encounter_date,
    e.encounter_datetime,
    e.encounter_hour,
    e.encounter_type,
    e.encounter_department_id,
    e.chief_complaint,
    e.diagnosis_code,
    e.procedure_code,
    e.discharge_disposition,
    e.visit_duration_minutes,
    e.charge_amount,
    e.revenue_amount,
    e.created_at,
    e.updated_at,
    row_number() over (
      partition by e.encounter_id
      order by e.updated_at desc
    ) as recency_rank
  from encounters e
  left join employees emp
    on upper(e.provider_npi) = upper(emp.npi)
)

select
  encounter_key,
  encounter_id,
  patient_id,
  employee_key,
  employee_id,
  provider_first_name,
  provider_last_name,
  provider_npi,
  job_title,
  employment_status,
  provider_email,
  employee_department_id,
  employee_department_name,
  encounter_date,
  encounter_datetime,
  encounter_hour,
  encounter_type,
  encounter_department_id,
  chief_complaint,
  diagnosis_code,
  procedure_code,
  discharge_disposition,
  visit_duration_minutes,
  charge_amount,
  revenue_amount,
  created_at,
  updated_at
from joined_data
where recency_rank = 1  -- Take most recent version
