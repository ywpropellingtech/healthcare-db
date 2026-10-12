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
select 'total_records' as check_name,
       count(*) as issue_count,
       'Total rows in intermediate table' as expected
from {{ ref('int_encounter_volume_by_month_visit_type') }}
order by check_name
