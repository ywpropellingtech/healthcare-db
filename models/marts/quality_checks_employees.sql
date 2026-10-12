{{
  config(
    materialized='view',
    tags=['quality_checks']
  )
}}

-- Data Quality Checks for stg_employees
-- Validates data standardization, transformations, and readiness for dimension table

-- 1. Check employee_id for nulls (primary key)
select 'employee_id_null' as check_name,
       count(*) as issue_count,
       'No nulls in employee_id' as expected
from {{ ref('stg_employees') }}
where employee_id is null
union all

-- 2. Check for duplicate employee_ids (should be unique)
select 'duplicate_employee_ids' as check_name,
       count(*) - count(distinct employee_id) as issue_count,
       'All employee_ids should be unique' as expected
from {{ ref('stg_employees') }}
union all

-- 3. Check hire_date for nulls
select 'hire_date_null' as check_name,
       count(*) as issue_count,
       'No nulls in hire_date' as expected
from {{ ref('stg_employees') }}
where hire_date is null
union all

-- 4. Check hire_date is within reasonable range
select 'hire_date_out_of_range' as check_name,
       count(*) as issue_count,
       'Hire dates should not be in future' as expected
from {{ ref('stg_employees') }}
where hire_date > current_date()
union all

-- 5. Check termination_date is after hire_date (if populated)
select 'termination_before_hire' as check_name,
       count(*) as issue_count,
       'Termination date should be after hire date' as expected
from {{ ref('stg_employees') }}
where termination_date is not null
  and termination_date < hire_date
union all

-- 6. Check full_name for nulls
select 'full_name_null' as check_name,
       count(*) as issue_count,
       'No nulls in full_name' as expected
from {{ ref('stg_employees') }}
where full_name is null
union all

-- 7. Check full_name is trimmed (no leading/trailing spaces)
select 'full_name_trim_check' as check_name,
       count(*) as issue_count,
       'Full names should be trimmed' as expected
from {{ ref('stg_employees') }}
where full_name != trim(full_name)
union all

-- 8. Check FTE is within reasonable range (0-2)
select 'fte_out_of_range' as check_name,
       count(*) as issue_count,
       'FTE should be between 0 and 2' as expected
from {{ ref('stg_employees') }}
where fte < 0 or fte > 2
union all

-- 10. Check annual_salary for negative values
select 'annual_salary_negative' as check_name,
       count(*) as issue_count,
       'Salary should not be negative' as expected
from {{ ref('stg_employees') }}
where annual_salary is not null and annual_salary < 0
union all

-- 11. Check NPI format (should be 10 digits if populated)
select 'npi_format_check' as check_name,
       count(*) as issue_count,
       'NPI should be 10 digits (if populated)' as expected
from {{ ref('stg_employees') }}
where npi is not null and (length(trim(npi)) != 10 or not regexp_like(npi, '^[0-9]+$'))
union all

-- 12. Check job_title for nulls and trimming
select 'job_title_null' as check_name,
       count(*) as issue_count,
       'No nulls in job_title' as expected
from {{ ref('stg_employees') }}
where job_title is null
union all

-- 13. Check job_title is trimmed
select 'job_title_trim_check' as check_name,
       count(*) as issue_count,
       'Job titles should be trimmed' as expected
from {{ ref('stg_employees') }}
where job_title != trim(job_title)
union all

-- 14. Check worker_type has expected values
select 'unexpected_worker_type' as check_name,
       count(*) as issue_count,
       'Only EMPLOYEE or CONTINGENT WORKER expected' as expected
from {{ ref('stg_employees') }}
where worker_type not in ('EMPLOYEE', 'CONTINGENT WORKER')
   and worker_type is not null
union all

-- 15. Check department has values (dimension table requirement)
select 'department_null' as check_name,
       count(*) as issue_count,
       'Department should be populated' as expected
from {{ ref('stg_employees') }}
where department is null or department = ''
union all

-- 16. Check department is trimmed
select 'department_trim_check' as check_name,
       count(*) as issue_count,
       'Departments should be trimmed' as expected
from {{ ref('stg_employees') }}
where department != trim(department)
union all

-- 17. Check cost_center is trimmed (if populated)
select 'cost_center_trim_check' as check_name,
       count(*) as issue_count,
       'Cost centers should be trimmed' as expected
from {{ ref('stg_employees') }}
where cost_center is not null and cost_center != trim(cost_center)
union all

-- 18. Check location is trimmed (if populated)
select 'location_trim_check' as check_name,
       count(*) as issue_count,
       'Locations should be trimmed' as expected
from {{ ref('stg_employees') }}
where location is not null and location != trim(location)
union all

-- 19. Salary statistics (for marts/compensation analysis)
select 'annual_salary_statistics' as check_name,
       0 as issue_count,
       concat('min=', min(annual_salary), ' max=', max(annual_salary), ' median=', approx_percentile(annual_salary, 0.5)) as expected
from {{ ref('stg_employees') }}
union all

-- 20. FTE statistics
select 'fte_statistics' as check_name,
       0 as issue_count,
       concat('min=', min(fte), ' max=', max(fte), ' avg=', round(avg(fte), 2)) as expected
from {{ ref('stg_employees') }}
union all

-- 21. Active vs Terminated employees
select 'active_vs_terminated_count' as check_name,
       0 as issue_count,
       concat('Active=', count(case when termination_date is null then 1 end), ' Terminated=', count(case when termination_date is not null then 1 end)) as expected
from {{ ref('stg_employees') }}
union all

-- 22. Data volume check
select 'total_records' as check_name,
       count(*) as issue_count,
       'Total unique employees loaded' as expected
from {{ ref('stg_employees') }}
order by check_name
