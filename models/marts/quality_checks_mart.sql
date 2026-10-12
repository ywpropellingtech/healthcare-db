{{
  config(
    materialized='view',
    tags=['quality_checks']
  )
}}

-- Data Quality Checks for mart layer
-- Validates analytics-ready tables

-- 1. Check for null encounter_month
select 'encounter_month_null' as check_name,
       count(*) as issue_count,
       'No nulls in encounter_month' as expected
from {{ ref('mart_encounter_volume_trend') }}
where encounter_month is null
union all

-- 2. Check for null completed_visits
select 'completed_visits_null' as check_name,
       count(*) as issue_count,
       'No nulls in completed_visits' as expected
from {{ ref('mart_encounter_volume_trend') }}
where completed_visits is null
union all

-- 3. Check completed_visits > 0
select 'completed_visits_zero' as check_name,
       count(*) as issue_count,
       'All counts should be > 0' as expected
from {{ ref('mart_encounter_volume_trend') }}
where completed_visits <= 0
union all

-- 4. Check pct_of_month_visits is between 0 and 100
select 'pct_of_month_visits_out_of_range' as check_name,
       count(*) as issue_count,
       'All percentages should be between 0 and 100' as expected
from {{ ref('mart_encounter_volume_trend') }}
where pct_of_month_visits < 0 or pct_of_month_visits > 100
union all

-- 5. Check rank_in_month is between 1 and 4
select 'rank_in_month_out_of_range' as check_name,
       count(*) as issue_count,
       'Rank should be between 1 and 4' as expected
from {{ ref('mart_encounter_volume_trend') }}
where rank_in_month < 1 or rank_in_month > 4
union all

-- 6. Check visit_type values are expected
select 'unexpected_visit_type' as check_name,
       count(*) as issue_count,
       'Only FOLLOW-UP, NEW PATIENT, PROCEDURE, TELEHEALTH expected' as expected
from {{ ref('mart_encounter_volume_trend') }}
where visit_type not in ('FOLLOW-UP', 'NEW PATIENT', 'PROCEDURE', 'TELEHEALTH')
union all

-- 7. Verify percentages sum to ~100 per month
select 'percentages_dont_sum_to_100' as check_name,
       count(*) as issue_count,
       'Each month should sum to 100%' as expected
from (
  select encounter_month,
         round(sum(pct_of_month_visits), 1) as total_pct
  from {{ ref('mart_encounter_volume_trend') }}
  group by encounter_month
  having round(sum(pct_of_month_visits), 1) != 100.0
)
union all

-- 8. Total records check
select 'total_records' as check_name,
       count(*) as issue_count,
       'Total rows in mart table' as expected
from {{ ref('mart_encounter_volume_trend') }}
union all

-- 9. Summary by visit type
select 'total_completed_visits_by_type' as check_name,
       0 as issue_count,
       concat('FOLLOW-UP=', sum(case when visit_type = 'FOLLOW-UP' then completed_visits else 0 end),
              ' NEW PATIENT=', sum(case when visit_type = 'NEW PATIENT' then completed_visits else 0 end),
              ' PROCEDURE=', sum(case when visit_type = 'PROCEDURE' then completed_visits else 0 end),
              ' TELEHEALTH=', sum(case when visit_type = 'TELEHEALTH' then completed_visits else 0 end)) as expected
from {{ ref('mart_encounter_volume_trend') }}
union all

-- 10. Date range check
select 'date_range_coverage' as check_name,
       0 as issue_count,
       concat('Earliest: ', min(encounter_month), ' Latest: ', max(encounter_month)) as expected
from {{ ref('mart_encounter_volume_trend') }}
union all

-- Cost per wRVU checks
-- 11. Check for null employee_key in cost mart
select 'cost_per_wrvu_employee_key_null' as check_name,
       count(*) as issue_count,
       'No nulls in employee_key' as expected
from {{ ref('mart_cost_per_wrvu') }}
where employee_key is null
union all

-- 12. Check for null cost_per_wrvu
select 'cost_per_wrvu_null' as check_name,
       count(*) as issue_count,
       'No nulls in cost_per_wrvu' as expected
from {{ ref('mart_cost_per_wrvu') }}
where cost_per_wrvu is null
union all

-- 13. Check for negative cost_per_wrvu
select 'cost_per_wrvu_negative' as check_name,
       count(*) as issue_count,
       'No negative cost per wRVU' as expected
from {{ ref('mart_cost_per_wrvu') }}
where cost_per_wrvu < 0
union all

-- 14. Check quartile values are valid
select 'cost_per_wrvu_quartile_invalid' as check_name,
       count(*) as issue_count,
       'Quartiles should be 1-4' as expected
from {{ ref('mart_cost_per_wrvu') }}
where cost_per_wrvu_quartile not in (1, 2, 3, 4)
union all

-- 15. Check wrvu_per_fte quartiles are valid
select 'wrvu_per_fte_quartile_invalid' as check_name,
       count(*) as issue_count,
       'Quartiles should be 1-4' as expected
from {{ ref('mart_cost_per_wrvu') }}
where wrvu_per_fte_quartile not in (1, 2, 3, 4)
union all

-- 16. Check efficiency_category values
select 'unexpected_efficiency_category' as check_name,
       count(*) as issue_count,
       'Only Above/Below/At Average expected' as expected
from {{ ref('mart_cost_per_wrvu') }}
where efficiency_category not in ('Above Average', 'Below Average', 'At Average')
union all

-- 17. Check efficiency_ratio is positive
select 'efficiency_ratio_non_positive' as check_name,
       count(*) as issue_count,
       'Efficiency ratio should be positive' as expected
from {{ ref('mart_cost_per_wrvu') }}
where efficiency_ratio <= 0
union all

-- 18. Summary: total employees by service line
select 'employees_by_service_line' as check_name,
       0 as issue_count,
       concat('Total employees in cost analysis: ', count(distinct employee_key)) as expected
from {{ ref('mart_cost_per_wrvu') }}
union all

-- 19. Summary: cost per wRVU statistics by service line
select 'cost_per_wrvu_service_line_stats' as check_name,
       0 as issue_count,
       concat('Min=', round(min(cost_per_wrvu), 2), ' Max=', round(max(cost_per_wrvu), 2),
              ' Median=', round(percentile_cont(0.5) within group (order by cost_per_wrvu), 2)) as expected
from {{ ref('mart_cost_per_wrvu') }}
union all

-- 20. Total records check for cost mart
select 'mart_cost_per_wrvu_total_records' as check_name,
       count(*) as issue_count,
       'Total rows in cost per wRVU mart' as expected
from {{ ref('mart_cost_per_wrvu') }}
order by check_name
