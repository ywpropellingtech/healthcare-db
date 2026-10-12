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
order by check_name
