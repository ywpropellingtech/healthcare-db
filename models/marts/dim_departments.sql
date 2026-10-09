{{
  config(
    materialized='table',
    tags=['marts', 'dimensions', 'departments'],
    indexes=[
      {
        'columns': ['department_id'],
        'unique': True
      }
    ],
    pre_hook="{{ log('Starting dim_departments transformation', info=true) }}"
  )
}}

/*
Dimension Table: Departments
- Contains department attributes and hierarchies
- Serves as dimension for department-level analytics
- Includes department metadata and classifications
*/

with distinct_departments as (
  select distinct
    department_id,
    department_name
  from {{ ref('stg_employees') }}
  where department_id is not null
    and department_name is not null

  union all

  select distinct
    encounter_department_id,
    null
  from {{ ref('stg_encounters') }}
  where encounter_department_id is not null
    and encounter_department_id != 'UNKNOWN'
),

deduplicated as (
  select distinct
    department_id,
    department_name
  from distinct_departments
),

classified as (
  select
    {{ dbt_utils.generate_surrogate_key(['department_id']) }} as department_key,
    department_id,
    trim(coalesce(department_name, department_id)) as department_name,
    case
      when lower(department_name) like '%emergency%'
        or lower(department_name) like '%ed%' then 'Emergency Department'
      when lower(department_name) like '%cardio%' then 'Cardiology'
      when lower(department_name) like '%neuro%' then 'Neurology'
      when lower(department_name) like '%ortho%' then 'Orthopedics'
      when lower(department_name) like '%icu%'
        or lower(department_name) like '%intensive%' then 'Critical Care'
      when lower(department_name) like '%ob%gyn%'
        or lower(department_name) like '%maternity%' then 'Obstetrics & Gynecology'
      when lower(department_name) like '%general%' then 'General Medicine'
      else 'Other'
    end as department_category,
    case
      when lower(department_name) like '%ambulatory%'
        or lower(department_name) like '%clinic%'
        or lower(department_name) like '%office%' then 'Outpatient'
      when lower(department_name) like '%emergency%'
        or lower(department_name) like '%ed%' then 'Emergency'
      when lower(department_name) like '%icu%'
        or lower(department_name) like '%hospital%'
        or lower(department_name) like '%inpatient%' then 'Inpatient'
      else 'Other'
    end as department_type,
    current_timestamp() as dbt_loaded_at
  from deduplicated
)

select *
from classified
where department_id is not null

