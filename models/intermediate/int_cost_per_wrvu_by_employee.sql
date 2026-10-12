{{
  config(
    materialized='table',
    tags=['intermediate', 'analytics'],
    description='Employee productivity and cost analysis by service line'
  )
}}

/*
Intermediate layer: Cost per wRVU analysis
- Links employees to their encounters via provider NPI matching
- Calculates annual wRVU production per employee
- Calculates cost per work RVU (salary ÷ wRVU)
- Compares individual performance vs. service line average
- Useful for compensation benchmarking and efficiency analysis
*/

with employee_encounters as (
  select
    e.employee_key,
    e.full_name,
    e.department as service_line,
    e.annual_salary,
    e.fte,
    enc.encounter_key,
    enc.wrvu
  from {{ ref('stg_employees') }} e
  left join {{ ref('stg_encounters') }} enc on e.npi = enc.provider_npi
  where enc.encounter_key is not null
    and enc.encounter_status = 'COMPLETED'
),

employee_productivity as (
  select
    employee_key,
    full_name,
    service_line,
    annual_salary,
    fte,
    count(distinct encounter_key) as completed_encounters,
    round(sum(wrvu), 2) as total_wrvu,
    round(sum(wrvu) / fte, 2) as wrvu_per_fte,
    round(annual_salary / nullif(sum(wrvu), 0), 2) as cost_per_wrvu
  from employee_encounters
  group by employee_key, full_name, service_line, annual_salary, fte
),

service_line_benchmarks as (
  select
    service_line,
    round(avg(cost_per_wrvu), 2) as service_line_avg_cost_per_wrvu,
    round(avg(wrvu_per_fte), 2) as service_line_avg_wrvu_per_fte,
    round(median(cost_per_wrvu), 2) as service_line_median_cost_per_wrvu,
    count(distinct employee_key) as service_line_employee_count
  from employee_productivity
  group by service_line
)

select
  ep.employee_key,
  ep.full_name,
  ep.service_line,
  ep.annual_salary,
  ep.fte,
  ep.completed_encounters,
  ep.total_wrvu,
  ep.wrvu_per_fte,
  ep.cost_per_wrvu,
  sb.service_line_avg_cost_per_wrvu,
  sb.service_line_median_cost_per_wrvu,
  sb.service_line_avg_wrvu_per_fte,
  sb.service_line_employee_count,
  -- Efficiency ratio: lower is better (more productive per dollar)
  round(ep.cost_per_wrvu / nullif(sb.service_line_avg_cost_per_wrvu, 0), 2) as efficiency_ratio,
  case
    when ep.cost_per_wrvu < sb.service_line_median_cost_per_wrvu then 'Above Average'
    when ep.cost_per_wrvu > sb.service_line_median_cost_per_wrvu then 'Below Average'
    else 'At Average'
  end as efficiency_category
from employee_productivity ep
left join service_line_benchmarks sb on ep.service_line = sb.service_line
order by ep.service_line, ep.cost_per_wrvu
