# Data Quality Checks Documentation

## Overview

Data quality checks validate that staging models (`stg_employees`, `stg_encounters`) meet standardization requirements before downstream analytics. Checks are materialized as views in the data warehouse and can be queried directly.

**Location:** `ANALYTICS.DBT_YWANG`
- `quality_checks_employees` — Employee data validation
- `quality_checks_encounters` — Encounter data validation

---

## How to Use

### Query Results in Snowflake

```sql
-- Check employees quality
select * from analytics.dbt_ywang.quality_checks_employees order by check_name;

-- Check encounters quality
select * from analytics.dbt_ywang.quality_checks_encounters order by check_name;
```

### Interpreting Results

Each check returns 3 columns:

| Column | Meaning |
|--------|---------|
| `check_name` | Name of the quality check |
| `issue_count` | Number of issues found (0 = ✅ pass) |
| `expected` | Expected result or statistic |

**Status indicators:**
- `issue_count = 0` → ✅ **PASS** - Check succeeded
- `issue_count > 0` → ⚠️ **ISSUE** - Problems detected
- Statistic rows → 📊 **INFO** - Summary statistics

---

## Employees Quality Checks (22 checks)

### Data Standardization

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `employee_id_null` | Primary key validation | No NULL values |
| `duplicate_employee_ids` | Uniqueness validation | All IDs unique |
| `full_name_null` | Required field validation | No NULL values |
| `full_name_trim_check` | String standardization | No leading/trailing spaces |
| `job_title_null` | Required field validation | No NULL values |
| `job_title_trim_check` | String standardization | No leading/trailing spaces |
| `department_null` | Required field validation | No empty departments |
| `department_trim_check` | String standardization | No leading/trailing spaces |
| `cost_center_trim_check` | String standardization | No leading/trailing spaces (if populated) |
| `location_trim_check` | String standardization | No leading/trailing spaces (if populated) |

### Type Conversion & Calculation

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `fte_null_values` | Required field validation | No NULL FTE values |
| `fte_out_of_range` | Valid range validation | FTE between 0-2 |
| `annual_salary_negative` | Data validation | No negative salaries |

### Date Validation

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `hire_date_null` | Required field validation | No NULL hire dates |
| `hire_date_out_of_range` | Logical validation | No future hire dates |
| `termination_before_hire` | Logical validation | Termination date ≥ hire date |

### Format & Enumeration

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `npi_format_check` | Format validation | 10 digits (if populated) |
| `unexpected_worker_type` | Enumeration validation | Only EMPLOYEE or CONTINGENT_WORKER |

### Statistics & Counts

| Check | Purpose | Info |
|-------|---------|------|
| `annual_salary_statistics` | Summary stats | min, max, median salary |
| `fte_statistics` | Summary stats | min, max, avg FTE |
| `active_vs_terminated_count` | Status breakdown | Count of active vs terminated |
| `total_records` | Volume check | Total unique employees |

---

## Encounters Quality Checks (18 checks)

### Data Standardization & Transformation

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `encounter_date_null_count` | Required field validation | No NULL dates |
| `encounter_id_null` | Required field validation | No NULL encounter IDs |
| `patient_id_null` | Required field validation | No NULL patient IDs |
| `encounter_status_trim_check` | String standardization | No leading/trailing spaces |
| `department_trim_check` | String standardization | No leading/trailing spaces |
| `provider_name_trim_check` | String standardization | No leading/trailing spaces |

### Numeric Conversion Validation

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `wrvu_null_after_transformation` | Null conversion check | All NULLs → 0 |
| `wrvu_negative_values` | Data validation | No negative wRVU |
| `charge_amount_null_after_transformation` | Null conversion check | All NULLs → 0 |
| `charge_amount_negative_values` | Data validation | No negative charges |

### Enumeration & Format

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `provider_npi_null` | Required field validation | No NULL provider NPI |
| `unexpected_encounter_status` | Enumeration validation | Only: COMPLETED, CANCELLED, NO-SHOW, PENDING |
| `unexpected_visit_type` | Enumeration validation | Only: OFFICE, TELEHEALTH, ED, INPATIENT, PROCEDURE |

### Uniqueness & Date Range

| Check | Purpose | Pass Criteria |
|-------|---------|---------------|
| `duplicate_encounter_ids` | Uniqueness validation | All encounter IDs unique |
| `encounter_date_out_of_range` | Date range validation | Within last 3 years |

### Statistics & Counts

| Check | Purpose | Info |
|-------|---------|------|
| `wrvu_statistics` | Summary stats | min, max, avg wRVU |
| `charge_amount_statistics` | Summary stats | min, max, avg charge |
| `total_records` | Volume check | Total encounters loaded |

---

## Known Issues & Remediation

### Employees Data

#### RESOLVED: Worker Type Standardization ✅
- **Original Issue:** All 52 records showed unexpected worker_type values
- **Root Cause:** Source data has mixed case ("Employee", "Contingent Worker") but check expected uppercase
- **Resolution:** Added `upper(trim())` to stg_employees to standardize to uppercase ("EMPLOYEE", "CONTINGENT WORKER")
- **Status:** ✅ RESOLVED - All employee records now pass worker_type validation

#### RESOLVED: FTE NULL Values ✅
- **Issue:** 2 employees with NULL FTE (physicians)
- **Investigation Findings:**
  - Both are contingent physicians hired recently
  - Employee 1 (Mary L. Hernandez, WD300000) - Physician, Contingent Worker
  - Employee 2 (Betty Nguyen, WD300001) - Physician, Contingent Worker
  
  **Physician FTE Analysis:**
  - Total physicians with FTE: 34
  - FTE Distribution:
    - 1.0 FTE: 17 physicians (50%)
    - 0.8 FTE: 7 physicians (20.59%)
    - 0.6 FTE: 7 physicians (20.59%)
    - 0.5 FTE: 3 physicians (8.82%)
  - **Finding:** Cannot assume physicians are full-time; they have diverse FTE levels
  
- **Resolution:** Default NULL FTE to 1.0 using `coalesce(FTE, 1.0)` in staging
- **Rationale:** 
  - Most conservative approach (full-time assumption)
  - Represents 50% of physician population
  - Allows all records to have valid FTE for downstream calculations
- **Status:** ✅ RESOLVED - All employees now have valid FTE values (2 defaulted to 1.0)

#### RESOLVED: Duplicate Employee Records ✅
- **Issue:** Multiple employees appear twice in source data
- **Examples:**
  - D100000 (Patricia Hall): 2 records with different FTE (1.0, 0.8) and salary ($544K, $519K)
  - D100003 (Carlos Patel): 2 records with different FTE (1.0, 0.8) and salary ($483K, $458K)
  - D100007 (Betty J. Williams): 2 records with different FTE (1.0, 0.8) and salary ($442K, $417K)
  - D100012 (Karen Lee): 2 records with different FTE (1.0, 0.8) and salary ($350K, $325K)

- **Pattern Analysis:**
  - Each duplicate has 2 versions with dates:
    - Most recent: 2024-12-31 (FTE=1.0, higher salary)
    - Older: 2024-03-31 (FTE=0.8, lower salary)
  - Likely represents: Year-end salary increases and FTE promotions (part-time → full-time)

- **Resolution:** Deduplication logic in stg_employees using:
  ```sql
  row_number() over (partition by EMPLOYEE_ID order by LAST_UPDATED desc) as recency_rank
  where recency_rank = 1
  ```
  Keeps only the most recent (2024-12-31) version for each employee

- **Verification Results:**
  - ✅ All 52 staged employees are unique (no duplicates in stg_employees)
  - ✅ Most recent version with best FTE/salary kept for each employee
  - ✅ Deduplication working correctly

- **Status:** ✅ RESOLVED - Uniqueness validation passes

---

### Encounters Data (CRITICAL)

**Issue: Duplicate encounter_ids**
- **Status:** 489 duplicate encounter IDs
- **Impact:** 
  - ❌ wRVU counts inflated (productivity appears artificially high)
  - ❌ Encounter volume metrics unreliable
  - ❌ Cost per wRVU calculations skewed
- **Root Cause:** Either legitimate updates to same encounter OR data quality issue in source
- **Fix:** Investigate if duplicates represent encounter updates; if so, implement deduplication logic in staging

**Issue: Unexpected encounter_status values**
- **Status:** 49,361 records (~100%) have unexpected values
- **Impact:** 
  - ❌ Can't filter for completed visits
  - ❌ Can't implement "completed visits per month" metric
- **Root Cause:** Actual status values in source don't match expected values
- **Fix:** Query actual values in source; update quality check or source data standardization

**Issue: Unexpected visit_type values**
- **Status:** 49,361 records (~100%) have unexpected values
- **Impact:** 
  - ❌ Can't segment by visit type (operational demand analysis blocked)
  - ❌ Can't implement visit type breakdown in metrics
- **Root Cause:** Actual visit types in source don't match expected values
- **Fix:** Query actual values in source; update quality check or source data standardization

**Issue: NULL provider_npi**
- **Status:** 4,304 records (~8.7%) have NULL provider NPI
- **Impact:** 
  - ⚠️ Encounter-to-employee joins will fail for these records
  - ⚠️ Some providers missing from downstream analysis
- **Root Cause:** Data quality issue in Epic source system
- **Fix:** Investigate source; consider filling with patient-provider relationship if available

---

## Impact on Analytics Metrics

| Metric | Affected By | Severity |
|--------|------------|----------|
| Productivity per clinician (wRVU/FTE) | Duplicates | ⚠️ MODERATE |
| Encounter volume trend | Duplicates, status/type values | ❌ **SEVERE** |
| Cost per wRVU | Duplicates | ⚠️ MODERATE |
| Compensation vs. output | Duplicates, NULL NPI | ⚠️ MODERATE |

**Recommendation:** Resolve critical issues in encounters data before building mart/analysis layer.

---

## Investigation Queries

### Find actual encounter_status values
```sql
select encounter_status, count(*) as count
from raw.epic.epc_encounters
group by encounter_status
order by count desc;
```

### Find actual visit_type values
```sql
select visit_type, count(*) as count
from raw.epic.epc_encounters
group by visit_type
order by count desc;
```

### Find duplicate encounter_ids
```sql
select encounter_id, count(*) as encounter_count, count(distinct patient_mrn) as distinct_patients
from raw.epic.epc_encounters
group by encounter_id
having count(*) > 1
order by encounter_count desc
limit 20;
```

### Find NULL provider_npi distribution
```sql
select count(*) as total_encounters,
       sum(case when provider_npi is null then 1 else 0 end) as null_npi_count,
       round(100.0 * sum(case when provider_npi is null then 1 else 0 end) / count(*), 2) as pct_null
from raw.epic.epc_encounters;
```

---

## Quality Check Maintenance

### When to Run
- **After source data refresh:** Validate new data meets standards
- **Before building analyses:** Ensure staging layer is clean
- **After schema changes:** Verify transformations still work
- **Regularly:** Weekly or monthly data quality reviews

### When to Update Checks
- New data quality requirements
- Expected values change (enumeration updates)
- Data ranges change (numeric bounds)
- New standardization rules introduced

### How to Update

Edit the quality check SQL files:
- `models/marts/quality_checks_employees.sql`
- `models/marts/quality_checks_encounters.sql`

Then rebuild with `dbt build`.

---

## Related Files

- **Staging Models:** `models/staging/stg_employees.sql`, `models/staging/stg_encounters.sql`
- **Quality Check Models:** `models/marts/quality_checks_employees.sql`, `models/marts/quality_checks_encounters.sql`
- **Test Definitions:** `models/staging/schema.yml`
- **Source Definitions:** `models/staging/sources.yml`

---

## Contact & Support

For questions about data quality or staging layer issues, review the staged data in:
- `ANALYTICS.DBT_YWANG.STG_EMPLOYEES`
- `ANALYTICS.DBT_YWANG.STG_ENCOUNTERS`

Check dbt Cloud logs for transformation details and error messages.
