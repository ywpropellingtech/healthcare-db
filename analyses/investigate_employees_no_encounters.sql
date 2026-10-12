-- Investigate the 18 employees with no encounter data

-- Query 1: List all 18 employees NOT in cost_per_wrvu analysis
select 'Employees NOT in Cost per wRVU Analysis' as analysis,
       e.employee_key,
       e.full_name,
       e.job_title,
       e.worker_type,
       e.department,
       e.fte,
       e.annual_salary,
       e.hire_date,
       e.termination_date,
       case when e.termination_date is not null then 'TERMINATED'
            when e.hire_date > dateadd('month', -3, current_date()) then 'NEW HIRE (<3 months)'
            when upper(e.job_title) like '%ADMIN%' then 'ADMINISTRATIVE'
            when upper(e.job_title) like '%MANAGER%' then 'MANAGER'
            when upper(e.job_title) like '%DIRECTOR%' then 'DIRECTOR'
            when upper(e.job_title) like '%PHYSICIAN%' then 'PHYSICIAN'
            else 'OTHER'
       end as likely_reason
from ANALYTICS.DBT_YWANG.STG_EMPLOYEES e
where e.employee_key not in (select employee_key from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE)
order by e.department, e.hire_date desc;

-- Query 2: Summary by category
select 'Summary by Employee Type' as analysis,
       case when e.termination_date is not null then 'TERMINATED'
            when e.hire_date > dateadd('month', -3, current_date()) then 'NEW HIRE (<3 months)'
            when upper(e.job_title) like '%ADMIN%' then 'ADMINISTRATIVE'
            when upper(e.job_title) like '%MANAGER%' then 'MANAGER'
            when upper(e.job_title) like '%DIRECTOR%' then 'DIRECTOR'
            when upper(e.job_title) like '%PHYSICIAN%' then 'PHYSICIAN'
            else 'OTHER'
       end as category,
       count(distinct e.employee_key) as employee_count,
       round(sum(e.annual_salary), 0) as total_salary,
       round(avg(e.fte), 2) as avg_fte
from ANALYTICS.DBT_YWANG.STG_EMPLOYEES e
where e.employee_key not in (select employee_key from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE)
group by category
order by employee_count desc;

-- Query 3: Check if any have encounters in source but all NULL NPI
select 'Employees with Encounters but NULL NPI' as analysis,
       e.employee_key,
       e.full_name,
       e.department,
       count(distinct enc.encounter_id) as total_encounters,
       sum(case when enc.provider_npi is null then 1 else 0 end) as null_npi_count,
       sum(case when enc.provider_npi is not null then 1 else 0 end) as npi_filled_count
from ANALYTICS.DBT_YWANG.STG_EMPLOYEES e
left join ANALYTICS.DBT_YWANG.STG_ENCOUNTERS enc on e.npi = enc.provider_npi
where e.employee_key not in (select employee_key from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE)
  and enc.encounter_id is not null
group by e.employee_key, e.full_name, e.department
order by total_encounters desc;

-- Query 4: Employee tenure and status analysis
select 'Tenure & Status Analysis' as analysis,
       e.employee_key,
       e.full_name,
       e.hire_date,
       e.termination_date,
       datediff('day', e.hire_date, current_date()) as days_employed,
       case when e.termination_date is not null
            then datediff('day', e.hire_date, e.termination_date)
            else null
       end as employment_duration_days,
       e.department,
       e.job_title,
       e.annual_salary,
       e.fte
from ANALYTICS.DBT_YWANG.STG_EMPLOYEES e
where e.employee_key not in (select employee_key from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE)
order by e.hire_date desc;

-- Query 5: Workday vs Epic coverage
select 'Coverage Gap: Workday vs Epic' as analysis,
       count(distinct e.employee_key) as total_workday_employees,
       (select count(distinct employee_key) from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE) as epic_encounter_employees,
       count(distinct e.employee_key) - (select count(distinct employee_key) from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE) as no_encounter_gap,
       round(100.0 * (count(distinct e.employee_key) - (select count(distinct employee_key) from ANALYTICS.DBT_YWANG.INT_COST_PER_WRVU_BY_EMPLOYEE))
             / count(distinct e.employee_key), 1) as pct_no_encounter
from ANALYTICS.DBT_YWANG.STG_EMPLOYEES e;
