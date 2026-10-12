-- Data Quality Checks for stg_encounters
-- Validates data standardization, transformations, and readiness for mart layer

-- 1. Check encounter_date standardization (no nulls, valid dates, reasonable range)
select 'encounter_date_null_count' as check_name,
       count(*) as issue_count,
       'No nulls should exist' as expected
from {{ ref('stg_encounters') }}
where encounter_date is null
union all

-- 2. Check if encounter_date is within reasonable range (last 3 years)
select 'encounter_date_out_of_range' as check_name,
       count(*) as issue_count,
       'All dates should be within last 3 years' as expected
from {{ ref('stg_encounters') }}
where encounter_date < dateadd('year', -3, current_date())
   or encounter_date > current_date()
union all

-- 3. Check wrvu conversion - no nulls, all converted to 0
select 'wrvu_null_after_transformation' as check_name,
       count(*) as issue_count,
       'No nulls should exist (all should be 0)' as expected
from {{ ref('stg_encounters') }}
where wrvu is null
union all

-- 4. Check wrvu is numeric and non-negative
select 'wrvu_negative_values' as check_name,
       count(*) as issue_count,
       'No negative values should exist' as expected
from {{ ref('stg_encounters') }}
where wrvu < 0
union all

-- 5. Check charge_amount conversion - no nulls, all converted to 0
select 'charge_amount_null_after_transformation' as check_name,
       count(*) as issue_count,
       'No nulls should exist (all should be 0)' as expected
from {{ ref('stg_encounters') }}
where charge_amount is null
union all

-- 6. Check charge_amount is numeric and non-negative
select 'charge_amount_negative_values' as check_name,
       count(*) as issue_count,
       'No negative values should exist' as expected
from {{ ref('stg_encounters') }}
where charge_amount < 0
union all

-- 7. Check key identifiers for nulls (required for joins in mart layer)
select 'encounter_id_null' as check_name,
       count(*) as issue_count,
       'No nulls in encounter_id' as expected
from {{ ref('stg_encounters') }}
where encounter_id is null
union all

-- 8. Check patient_id (MRN) for nulls
select 'patient_id_null' as check_name,
       count(*) as issue_count,
       'No nulls in patient_id' as expected
from {{ ref('stg_encounters') }}
where patient_id is null
union all

-- 9. Check provider_npi for nulls
select 'provider_npi_null' as check_name,
       count(*) as issue_count,
       'No nulls in provider_npi' as expected
from {{ ref('stg_encounters') }}
where provider_npi is null
union all

-- 10. Check for duplicate encounters (should be unique for fact table)
select 'duplicate_encounter_ids' as check_name,
       count(*) - count(distinct encounter_id) as issue_count,
       'All encounter_ids should be unique' as expected
from {{ ref('stg_encounters') }}
union all

-- 11. Check encounter_status has expected values (for dimension filtering)
select 'unexpected_encounter_status' as check_name,
       count(*) as issue_count,
       'Only expected status values should exist' as expected
from {{ ref('stg_encounters') }}
where encounter_status not in ('COMPLETED', 'CANCELLED', 'NO-SHOW', 'PENDING')
union all

-- 12. Check visit_type has expected values (for dimension filtering)
select 'unexpected_visit_type' as check_name,
       count(*) as issue_count,
       'Only expected visit types should exist' as expected
from {{ ref('stg_encounters') }}
where visit_type not in ('OFFICE', 'TELEHEALTH', 'ED', 'INPATIENT', 'PROCEDURE')
   and visit_type is not null
union all

-- 13. Check data types are optimal for calculation (all numeric columns as numbers)
select 'wrvu_data_type_check' as check_name,
       case when typeof(wrvu) = 'FIXED' then 0 else 1 end as issue_count,
       'wrvu should be numeric type' as expected
from {{ ref('stg_encounters') }}
limit 1
union all

-- 14. Check charge_amount data type
select 'charge_amount_data_type_check' as check_name,
       case when typeof(charge_amount) = 'FIXED' then 0 else 1 end as issue_count,
       'charge_amount should be numeric type' as expected
from {{ ref('stg_encounters') }}
limit 1
union all

-- 15. Summary statistics for numeric columns (mart layer context)
select 'wrvu_statistics' as check_name,
       0 as issue_count,
       concat('min=', min(wrvu), ' max=', max(wrvu), ' avg=', round(avg(wrvu), 2)) as expected
from {{ ref('stg_encounters') }}
union all

-- 16. Charge amount statistics
select 'charge_amount_statistics' as check_name,
       0 as issue_count,
       concat('min=', min(charge_amount), ' max=', max(charge_amount), ' avg=', round(avg(charge_amount), 2)) as expected
from {{ ref('stg_encounters') }}
union all

-- 17. Check for provider_name trimming (no leading/trailing spaces)
select 'provider_name_trim_check' as check_name,
       count(*) as issue_count,
       'Provider names should be trimmed' as expected
from {{ ref('stg_encounters') }}
where provider_name != trim(provider_name)
union all

-- 18. Check for department trimming
select 'department_trim_check' as check_name,
       count(*) as issue_count,
       'Departments should be trimmed' as expected
from {{ ref('stg_encounters') }}
where department != trim(department)
union all

-- 19. Check encounter_status trimming
select 'encounter_status_trim_check' as check_name,
       count(*) as issue_count,
       'Status values should be trimmed' as expected
from {{ ref('stg_encounters') }}
where encounter_status != trim(encounter_status)
union all

-- 20. Data volume check
select 'total_records' as check_name,
       count(*) as issue_count,
       'Total records loaded' as expected
from {{ ref('stg_encounters') }}
order by check_name
