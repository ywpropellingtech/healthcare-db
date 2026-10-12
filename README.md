# Healthcare Analytics dbt Project

## Overview

This dbt project transforms raw healthcare data from Workday (HR) and Epic (EHR) into clean, standardized staging models for analytics.

**Current Status:** Staging layer complete with comprehensive data quality checks.

**Scope:** 
- ✅ Staging layer (data standardization & cleaning)
- 📋 Marts layer (forthcoming - after data quality resolution)

---

## Project Structure

```
healthcare-db/
├── models/
│   ├── staging/              # Staging layer - raw data transformation
│   │   ├── stg_employees.sql      # Workday employee data cleaning
│   │   ├── stg_encounters.sql     # Epic encounter data cleaning
│   │   ├── schema.yml             # Column definitions & tests
│   │   └── sources.yml            # Source table definitions
│   └── marts/                # Mart layer (analytics-ready models)
│       ├── quality_checks_employees.sql
│       ├── quality_checks_encounters.sql
│       └── schema.yml
├── docs/
│   └── DATA_QUALITY_CHECKS.md     # Data quality documentation
├── analyses/
│   ├── stg_employees_quality_checks.sql
│   └── stg_encounters_quality_checks.sql
├── packages.yml              # dbt dependencies (dbt_utils, dbt_expectations)
└── dbt_project.yml           # Project configuration
```

---

## Data Models

### Staging Layer

#### stg_employees
Cleaned and standardized employee data from Workday.

**Source:** `RAW.WORKDAY.WRK_EMPLOYEES`

**Transformations:**
- Trim whitespace from text fields
- Deduplicate to keep most recent record per employee
- Convert annual_salary to numeric (removes $, commas)
- Add dbt load timestamp

**Key Columns:**
- `employee_key` — Natural key (EMPLOYEE_ID)
- `employee_id`, `full_name`, `npi`, `job_title`, `worker_type`
- `department`, `cost_center`, `fte`, `annual_salary`
- `hire_date`, `termination_date`, `location`, `last_updated`

**Quality Metrics:** 52 unique employees, no nulls in key fields, salary range $49K-$556K

---

#### stg_encounters
Cleaned and standardized encounter data from Epic EHR.

**Source:** `RAW.EPIC.EPC_ENCOUNTERS`

**Transformations:**
- Trim whitespace from text fields
- Convert NULL wrvu/charge_amount to 0
- Validate amounts are non-negative
- Add dbt load timestamp

**Key Columns:**
- `encounter_key` — Natural key (ENCOUNTER_ID)
- `encounter_id`, `patient_id` (from PATIENT_MRN), `provider_name`, `provider_npi`
- `encounter_date`, `department`, `visit_type`, `encounter_status`
- `wrvu`, `charge_amount`

**Data Issues:** 489 duplicate IDs, 4,304 NULL NPI, 49K unexpected status/visit_type values (see DATA_QUALITY_CHECKS.md)

---

## Data Quality

**Quality checks validate:**
- ✅ No nulls in required fields
- ✅ Proper data type conversions (salary, FTE, wRVU)
- ✅ String standardization (trimming)
- ✅ Date range validation
- ✅ Enumeration validation
- ✅ Uniqueness constraints
- 📊 Summary statistics

**View quality check results:**
```sql
select * from analytics.dbt_ywang.quality_checks_employees;
select * from analytics.dbt_ywang.quality_checks_encounters;
```

**Full documentation:** See [DATA_QUALITY_CHECKS.md](docs/DATA_QUALITY_CHECKS.md)

---

## Critical Issues to Resolve

Before building downstream marts, these data quality issues must be addressed:

### Encounters Data
1. **489 duplicate encounter_ids** — Understand if duplicates are legitimate or data errors
2. **49,361 unexpected encounter_status values** — Query actual values in source; update standardization
3. **49,361 unexpected visit_type values** — Query actual values in source; update standardization
4. **4,304 NULL provider_npi** — Investigate source data gaps; consider filling if reference data available

### Employees Data
1. **52 records with unexpected worker_type** — Minor issue, but verify expected values match source
2. **2 records with NULL FTE** — Populate with default or handle in analytics logic

**Impact:** These issues will skew productivity, volume, and cost metrics. See DATA_QUALITY_CHECKS.md for details.

---

## Running the Project

### Prerequisites
- dbt Cloud account configured with Snowflake connection
- Connection: `Snowflake_new` → `ANALYTICS.DBT_YWANG` (transforming warehouse)
- dbt packages installed (dbt_utils, dbt_expectations)

### Build Models
```bash
dbt build  # Compile and test all models
dbt run    # Materialize models in warehouse
```

### Run Quality Checks
```sql
-- In Snowflake
select * from analytics.dbt_ywang.quality_checks_employees order by check_name;
select * from analytics.dbt_ywang.quality_checks_encounters order by check_name;
```

### Generate Docs
```bash
dbt docs generate
dbt docs serve
```

---

## Configuration

**Profile:** `default` (or `Analytics` for prod)

**Database:** `ANALYTICS`

**Schema:** `DBT_YWANG` (staging/marts) or `ANALYTICS_DEV` (if configured)

**Warehouse:** `TRANSFORMING`

See `~/.dbt/profiles.yml` for connection details.

---

## Analytics Metrics (Planned)

Once data quality issues are resolved, build these mart models:

1. **Productivity per clinician** — Median wRVU per 1.0 FTE by service line
2. **Encounter volume trend** — Completed visits per month, stacked by visit type
3. **Cost per work RVU** — Annual salary ÷ annual wRVU by service line
4. **Compensation vs. output** — Scatter: salary vs. wRVU, colored by service line

These require clean encounter data with proper status, visit_type, and provider linkages.

---

## Dependencies

**dbt Packages:**
- `dbt_utils` (1.1.1) — Utility macros
- `dbt_expectations` (0.8.0) — Advanced data quality tests

See `packages.yml` for versions.

---

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [Snowflake dbt Adapter](https://docs.getdbt.com/reference/warehouse-setups/snowflake-setup)
- Data Quality Checks: [DATA_QUALITY_CHECKS.md](docs/DATA_QUALITY_CHECKS.md)

---

## Next Steps

1. **Investigate data quality issues** — Run investigation queries in DATA_QUALITY_CHECKS.md
2. **Resolve duplicates & missing values** — Update source data or staging transformation logic
3. **Standardize enumerations** — Update expected status/visit_type values based on actual source data
4. **Build marts layer** — Create analysis-ready models once staging is validated
5. **Create BI dashboards** — Implement the 4 planned analytics metrics

---

## Questions?

Review the staging model SQL files in `models/staging/` and quality check documentation in `docs/DATA_QUALITY_CHECKS.md`.
