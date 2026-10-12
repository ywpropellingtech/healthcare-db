{{
  config(
    materialized='table',
    tags=['mart', 'analytics'],
    description='Analytics-ready table for cost per wRVU analysis and benchmarking'
  )
}}

/*
Mart layer: Cost per wRVU analysis
- Optimized for compensation benchmarking and efficiency analysis
- Includes employee rankings within service line
- Compares individual performance vs. service line benchmarks
- Enables scatter plots (salary vs. wRVU), bar charts (efficiency comparison)
*/

select
  employee_key,
  full_name,
  service_line,
  annual_salary,
  fte,
  completed_encounters,
  total_wrvu,
  wrvu_per_fte,
  cost_per_wrvu,
  service_line_avg_cost_per_wrvu,
  service_line_median_cost_per_wrvu,
  service_line_avg_wrvu_per_fte,
  service_line_employee_count,
  efficiency_ratio,
  efficiency_category,
  -- Quartile ranking by cost per wRVU within service line (lower is better)
  ntile(4) over (partition by service_line order by cost_per_wrvu) as cost_per_wrvu_quartile,
  -- Quartile ranking by wRVU per FTE within service line (higher is better)
  ntile(4) over (partition by service_line order by wrvu_per_fte desc) as wrvu_per_fte_quartile,
  -- Rank employees by cost efficiency within service line
  row_number() over (partition by service_line order by cost_per_wrvu) as cost_efficiency_rank,
  row_number() over (partition by service_line order by wrvu_per_fte desc) as productivity_rank,
  -- Variance from service line average (percentage)
  round(100.0 * (cost_per_wrvu - service_line_median_cost_per_wrvu) / service_line_median_cost_per_wrvu, 2) as pct_variance_from_median
from {{ ref('int_cost_per_wrvu_by_employee') }}
order by service_line, cost_per_wrvu
