{{
  config(
    materialized='view',
    tags=['quality_checks']
  )
}}

-- Data Quality Checks for intermediate layer
-- Validates aggregations and data consistency

-- 1. Check for null encounter_month
select 'encounter_month_null' as check_name,
       count(*) as issue_count,
       'No nulls in encounter_month' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where encounter_month is null
union all

-- 2. Check for null encounter_count
select 'encounter_count_null' as check_name,
       count(*) as issue_count,
       'No nulls in encounter_count' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where encounter_count is null
union all

-- 3. Check encounter_count > 0 (no zero-row groups)
select 'encounter_count_zero' as check_name,
       count(*) as issue_count,
       'All counts should be > 0' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where encounter_count <= 0
union all

-- 4. Check total_wrvu is not negative
select 'total_wrvu_negative' as check_name,
       count(*) as issue_count,
       'No negative wRVU totals' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where total_wrvu < 0
union all

-- 5. Check avg_wrvu matches total_wrvu / count (data consistency)
select 'avg_wrvu_consistency' as check_name,
       count(*) as issue_count,
       'avg_wrvu should equal total_wrvu / encounter_count' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where round(total_wrvu / encounter_count, 2) != avg_wrvu_per_encounter
union all

-- 6. Check all visit_type values are expected
select 'unexpected_visit_type' as check_name,
       count(*) as issue_count,
       'Only FOLLOW-UP, NEW PATIENT, PROCEDURE, TELEHEALTH expected' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where visit_type not in ('FOLLOW-UP', 'NEW PATIENT', 'PROCEDURE', 'TELEHEALTH')
union all

-- 7. Check all status values are expected
select 'unexpected_encounter_status' as check_name,
       count(*) as issue_count,
       'Only COMPLETED, CANCELLED, NO-SHOW expected' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where encounter_status not in ('COMPLETED', 'CANCELLED', 'NO-SHOW')
union all

-- 8. Summary: total encounter count by status (should match stg_encounters)
select 'total_encounter_count_by_status' as check_name,
       0 as issue_count,
       concat('COMPLETED=', sum(case when encounter_status = 'COMPLETED' then encounter_count else 0 end),
              ' CANCELLED=', sum(case when encounter_status = 'CANCELLED' then encounter_count else 0 end),
              ' NO-SHOW=', sum(case when encounter_status = 'NO-SHOW' then encounter_count else 0 end)) as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
union all

-- 9. Summary: encounter count by visit type
select 'total_encounter_count_by_visit_type' as check_name,
       0 as issue_count,
       concat('FOLLOW-UP=', sum(case when visit_type = 'FOLLOW-UP' then encounter_count else 0 end),
              ' NEW PATIENT=', sum(case when visit_type = 'NEW PATIENT' then encounter_count else 0 end),
              ' PROCEDURE=', sum(case when visit_type = 'PROCEDURE' then encounter_count else 0 end),
              ' TELEHEALTH=', sum(case when visit_type = 'TELEHEALTH' then encounter_count else 0 end)) as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
union all

-- 10. Date range check (should cover all encounter dates in stg_encounters)
select 'date_range_coverage' as check_name,
       0 as issue_count,
       concat('Earliest month: ', min(encounter_month), ' Latest month: ', max(encounter_month)) as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
union all

-- 11. Total records check
select 'int_encounter_volume_total_records' as check_name,
       count(*) as issue_count,
       'Total rows in encounter volume table' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
union all

-- Cost per wRVU checks
-- 12. Check for null employee_key
select 'cost_per_wrvu_employee_key_null' as check_name,
       count(*) as issue_count,
       'No nulls in employee_key' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where employee_key is null
union all

-- 13. Check for null cost_per_wrvu
select 'cost_per_wrvu_null' as check_name,
       count(*) as issue_count,
       'No nulls in cost_per_wrvu' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where cost_per_wrvu is null
union all

-- 14. Check for negative cost_per_wrvu
select 'cost_per_wrvu_negative' as check_name,
       count(*) as issue_count,
       'No negative cost per wRVU values' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where cost_per_wrvu < 0
union all

-- 15. Check efficiency_ratio is reasonable
select 'efficiency_ratio_out_of_range' as check_name,
       count(*) as issue_count,
       'Efficiency ratio should be positive' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where efficiency_ratio <= 0
union all

-- 16. Check efficiency_category values
select 'unexpected_efficiency_category' as check_name,
       count(*) as issue_count,
       'Only Above/Below/At Average expected' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where efficiency_category not in ('Above Average', 'Below Average', 'At Average')
union all

-- 17. Check wrvu_per_fte calculation consistency
select 'wrvu_per_fte_consistency' as check_name,
       count(*) as issue_count,
       'wrvu_per_fte should be total_wrvu / fte' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where round(total_wrvu / fte, 2) != wrvu_per_fte
union all

-- 18. Verify cost_per_wrvu = salary / wrvu calculation
select 'cost_per_wrvu_calculation_consistency' as check_name,
       count(*) as issue_count,
       'cost_per_wrvu should equal annual_salary / total_wrvu' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
where round(annual_salary / total_wrvu, 2) != cost_per_wrvu
union all

-- 19. Summary: total employees by service line
select 'employees_by_service_line' as check_name,
       0 as issue_count,
       concat('Total employees with encounter data: ', count(distinct employee_key)) as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
union all

-- 20. Summary: cost per wRVU statistics
select 'cost_per_wrvu_statistics' as check_name,
       0 as issue_count,
       concat('min=', round(min(cost_per_wrvu), 2), ' max=', round(max(cost_per_wrvu), 2),
              ' median=', round(percentile_cont(0.5) within group (order by cost_per_wrvu), 2)) as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
union all

-- 21. Total cost_per_wrvu records check
select 'int_cost_per_wrvu_total_records' as check_name,
       count(*) as issue_count,
       'Total rows in cost per wRVU table' as expected
from {{ ref('int_cost_per_wrvu_by_employee') }}
order by check_name
