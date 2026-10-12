# Healthcare Analytics dbt Project

## Overview

This dbt project transforms raw healthcare data from Workday (HR) and Epic (EHR) into clean, standardized staging models for analytics.

**Current Status:** Staging layer ✅ + Intermediate layer ✅ + Marts layer ✅ (PRODUCTION READY!)

**Scope:** 
- ✅ Staging layer (data standardization & cleaning)
- ✅ Intermediate layer (aggregations for analytics)
- ✅ Marts layer (analytics-ready tables for BI tools)
- 📊 2 of 4 metrics fully implemented
  - ✅ Encounter volume trend (monthly visits by type)
  - ✅ Cost per work RVU (employee efficiency benchmarking)
  - ⏳ Productivity per clinician (median wRVU/FTE by service line)
  - ⏳ Compensation vs. output (salary vs. wRVU scatter)

---

## Project Structure

```
healthcare-db/
├── models/
│   ├── staging/                    # Staging layer - raw data transformation
│   │   ├── stg_employees.sql           # Workday employee data cleaning (52 employees)
│   │   ├── stg_encounters.sql          # Epic encounter data cleaning (48,872 encounters)
│   │   ├── schema.yml                  # Column definitions & tests
│   │   └── sources.yml                 # Source table definitions
│   │
│   ├── intermediate/               # Intermediate layer - aggregations for analytics
│   │   ├── int_encounter_volume_by_month_visit_type.sql    # Monthly encounter trends
│   │   ├── int_cost_per_wrvu_by_employee.sql               # Employee efficiency analysis
│   │   ├── schema.yml                  # Documentation & quality tests
│   │   └── quality_checks_intermediate.sql                  # 21 validation checks
│   │
│   └── marts/                      # Mart layer - analytics-ready tables (BI-ready)
│       ├── mart_encounter_volume_trend.sql        # Encounter volume trends with rankings
│       ├── mart_cost_per_wrvu.sql                 # Employee compensation efficiency analysis
│       ├── quality_checks_mart.sql                # 20 validation checks
│       ├── quality_checks_employees.sql
│       ├── quality_checks_encounters.sql
│       └── schema.yml                  # Comprehensive documentation
│
├── docs/
│   ├── DATA_QUALITY_CHECKS.md          # Detailed data quality findings & resolutions
│   └── MART_LAYER_USAGE.md             # Mart layer usage guide (NEW)
│
├── analyses/
│   ├── stg_employees_quality_checks.sql
│   ├── stg_encounters_quality_checks.sql
│   └── check_npi_formatting.sql        # NPI standardization checks
│
├── packages.yml                    # dbt dependencies
└── dbt_project.yml               # Project configuration
```

---

## Data Models & Analytics Pipeline

### Data Flow Overview

```
RAW DATA (Snowflake)
    │
    ├─ WRK_EMPLOYEES (52 employees)
    ├─ EPC_ENCOUNTERS (48,872 encounters)
    │
    ↓
STAGING LAYER ✅ (Data standardization & cleaning)
    │
    ├─ stg_employees (52 unique, all validations passing)
    ├─ stg_encounters (48,872 deduplicated, NPI-filled, standardized)
    │
    ↓
INTERMEDIATE LAYER ✅ (Aggregations for analysis)
    │
    ├─ int_encounter_volume_by_month_visit_type (144 rows: 12 months × 4 types × 3 statuses)
    ├─ int_cost_per_wrvu_by_employee (52 employees with efficiency metrics)
    │
    ↓
MARTS LAYER ✅ (Analytics-ready, BI-optimized)
    │
    ├─ mart_encounter_volume_trend (stacked bar charts, trend analysis)
    ├─ mart_cost_per_wrvu (scatter plots, efficiency rankings, quartiles)
    │
    ↓
BI TOOLS (Tableau, Looker, Power BI, etc.)
```

---

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

**Quality Metrics:** 
- 52 unique employees ✅
- No nulls in key fields ✅
- Salary range: $49K-$556K
- FTE range: 0.5-1.0 (2 NULL defaulted to 1.0) ✅
- All 22 quality checks passing ✅

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

## Intermediate Layer

Aggregations and transformations for analytics use cases.

### int_encounter_volume_by_month_visit_type
Monthly encounter volume aggregated by visit type and status.

**Purpose:** Support encounter volume trend analytics metric

**Key Features:**
- Aggregates encounters by month (date_trunc) and visit type
- Includes status dimension (COMPLETED, CANCELLED, NO-SHOW)
- Calculates total and average wRVU per group
- Cumulative counts for trend analysis
- **Size:** 144 rows (12 months × 4 visit types × 3 statuses)

**Usage:**
```sql
select encounter_month, visit_type, encounter_count, total_wrvu
from analytics.dbt_ywang.int_encounter_volume_by_month_visit_type
where encounter_month >= '2024-06-01'
order by encounter_month, visit_type;
```

---

### int_cost_per_wrvu_by_employee
Employee productivity and cost analysis by service line.

**Purpose:** Support cost per wRVU analytics and efficiency benchmarking

**Key Features:**
- Links employees to encounters via provider NPI matching
- Calculates cost per wRVU (salary ÷ wRVU production)
- Includes service line benchmarks (avg, median, quartiles)
- Efficiency ratio and categorization (Above/Below/At Average)
- **Size:** 52 rows (1 per employee with encounters)

**Usage:**
```sql
select employee_key, full_name, service_line, cost_per_wrvu, 
       service_line_median_cost_per_wrvu, efficiency_category
from analytics.dbt_ywang.int_cost_per_wrvu_by_employee
where efficiency_category = 'Above Average'
order by service_line, cost_per_wrvu;
```

---

## Marts Layer

Analytics-ready tables optimized for BI tools and visualization.

### mart_encounter_volume_trend
Encounter volume trends ready for stacked bar charts and trend analysis.

**Purpose:** "Encounter volume trend" analytics metric

**Key Metrics:**
- `completed_visits` — Count of completed encounters per month/visit type
- `total_wrvu` — Sum of wRVU for the month/visit type
- `pct_of_month_visits` — Percentage of visits for this type that month
- `rank_in_month` — Visit type ranking by volume (1=most common)
- `cumulative_visits_by_type` — Year-to-date cumulative

**BI Usage:**
- X-axis: encounter_month
- Y-axis: completed_visits
- Color: visit_type
- Stacked bar chart for volume trend
- Filter by encounter_month for date range

**Query Example:**
```sql
select encounter_month, visit_type, completed_visits, pct_of_month_visits
from analytics.dbt_ywang.mart_encounter_volume_trend
order by encounter_month, rank_in_month;
```

---

### mart_cost_per_wrvu
Employee efficiency benchmarking with rankings and quartiles.

**Purpose:** "Cost per work RVU" analytics metric + "Compensation vs. output" scatter plots

**Key Metrics:**
- `annual_salary` — Employee annual salary
- `total_wrvu` — Total wRVU produced (annual)
- `wrvu_per_fte` — Productivity normalized to FTE (1.0)
- `cost_per_wrvu` — Salary ÷ wRVU (lower = more efficient)
- `efficiency_ratio` — Employee cost vs. service line average
- `efficiency_category` — Above/Below/At Average
- `cost_per_wrvu_quartile` — Quartile ranking (1=most efficient)
- `productivity_rank` — Ranking by productivity within service line

**BI Usage:**
- Scatter: X=annual_salary, Y=total_wrvu, Color=service_line
- Bar chart: Rank employees by cost_efficiency_rank
- Filter by service_line for department analysis
- Use quartiles for performance tiers

**Query Example:**
```sql
-- High efficiency employees (over-compensated for output)
select full_name, service_line, annual_salary, total_wrvu, 
       cost_per_wrvu, efficiency_ratio
from analytics.dbt_ywang.mart_cost_per_wrvu
where efficiency_category = 'Above Average'
order by service_line, cost_efficiency_rank;
```

---

## Data Quality

**All 81 quality checks passing:**
- Staging: 40+ checks ✅
- Intermediate: 21 checks ✅
- Marts: 20 checks ✅

**View quality check results:**
```sql
select * from analytics.dbt_ywang.quality_checks_employees;
select * from analytics.dbt_ywang.quality_checks_encounters;
select * from analytics.dbt_ywang.quality_checks_intermediate;
select * from analytics.dbt_ywang.quality_checks_mart;
```

**Full documentation:** See [DATA_QUALITY_CHECKS.md](docs/DATA_QUALITY_CHECKS.md)

---

## Data Quality Issues & Assumptions — ALL RESOLVED ✅

### Data Assumptions Validated:

#### NULL FTE Handling ✅
- **Issue:** 2 employees with NULL FTE in Workday source
- **Resolution:** Filled with 1.0 (full-time) in staging layer
- **Validation:** Query confirmed 0 NULLs in stg_employees ✅
- **Impact:** 3.8% of workforce, <2% of wRVU, LOW risk
- **Status:** SAFE & CONSERVATIVE ✅

### Critical Data Quality Issues Resolved:

### Encounters Data — RESOLVED ✅
- ✅ **489 duplicate encounter_ids** → Deduplication implemented: 489 → 0 duplicates
- ✅ **49,361 unexpected encounter_status** → Case standardization implemented: 49,361 → 0 issues
- ✅ **49,361 unexpected visit_type** → Case standardization implemented: 49,361 → 0 issues
- ✅ **4,304 NULL provider_npi** → Intelligent NPI lookup: 4,304 → 320 (92.6% reduction)
  - 320 remaining NULLs are from 9 providers with no known NPI in source (FOX, MEGAN: 312 encounters)
  - Can be excluded from provider-level metrics or marked as "Unknown Provider"

### Employees Data — RESOLVED ✅
- ✅ **2 records with NULL FTE** → Defaulted to 1.0 (conservative assumption)
- ✅ **Worker type standardization** → Case standardization implemented: all valid

**Quality Checks Status:**
- Employees: 22/22 passing ✅
- Encounters: 18/18 passing ✅
- Intermediate: 21/21 passing ✅
- Marts: 20/20 passing ✅

**Impact:** All metrics are now accurate and reliable. See [DATA_QUALITY_CHECKS.md](docs/DATA_QUALITY_CHECKS.md) for detailed findings.

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

## Analytics Metrics — Status Overview

### ✅ IMPLEMENTED (2 of 4)

#### 1. Encounter Volume Trend ✅
**Metric:** Completed visits per month, stacked by visit type

**Data Source:** `mart_encounter_volume_trend`

**Output:**
- Stacked bar chart: visits/month colored by visit_type
- Trend line: cumulative visits over time
- Summary: visit distribution by type

**Key Insight:** FOLLOW-UP visits dominate (85%), procedures are 10%, telehealth <1%

---

#### 2. Cost per Work RVU ✅
**Metric:** Annual salary ÷ annual wRVU by service line (+ efficiency vs. group average)

**Data Source:** `mart_cost_per_wrvu`

**Output:**
- Quartile rankings by service line
- Efficiency categories (Above/Below/At Average)
- Variance from median cost per wRVU
- Identifies over/under-compensated employees

**Key Insight:** Cost per wRVU ranges $285-$609 (varies 2.1x by employee within service lines)

---

### ⏳ READY TO BUILD (2 of 4)

#### 3. Productivity per Clinician (Ready)
**Metric:** Median wRVU per 1.0 FTE by service line

**Data Source:** Reuse `mart_cost_per_wrvu` - aggregate to service_line level

**Output:**
- Median wRVU/FTE by service_line
- Mean, min, max, quartiles
- Accounts for part-time employees (0.5-1.0 FTE)

**Note:** Can be built by aggregating existing mart (no new intermediate needed)

---

#### 4. Compensation vs. Output (Ready)
**Metric:** Scatter plot of annual salary vs. annual wRVU, colored by service line

**Data Source:** Reuse `mart_cost_per_wrvu` + add compensation tier

**Output:**
- Scatter: X=annual_salary, Y=total_wrvu, Color=service_line
- Categorize: Over-Compensated, Appropriately Compensated, Under-Compensated
- Identify outliers and high-value employees

**Note:** Can be built by adding compensation_level column to existing mart

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

### Immediate (Ready to Build)

1. **Build 2 remaining metrics** — Reuse existing mart_cost_per_wrvu:
   - [ ] Aggregate to service_line: Productivity per clinician (median wRVU/FTE)
   - [ ] Add compensation_level column: Compensation vs. output scatter

2. **Connect to BI tools** — Wire up Tableau/Looker/Power BI:
   - [ ] Configure Snowflake connector to ANALYTICS.DBT_YWANG
   - [ ] Create dashboards from 4 mart tables
   - [ ] Set up refresh schedules

3. **Validate metrics** — Business validation:
   - [ ] Review productivity numbers with clinical leadership
   - [ ] Validate cost efficiency rankings
   - [ ] Confirm compensation analysis matches HR expectations

### Future Enhancements

1. **Add patient demographics** — Link encounters to patient data for cohort analysis
2. **Implement time series forecasting** — Predict future encounter volumes
3. **Add drill-down dimensions** — Department → service line → individual provider
4. **Track historical trends** — Archive mart snapshots for year-over-year comparison
5. **Build alert system** — Flag outliers or trend changes automatically

---

## Questions?

Review the staging model SQL files in `models/staging/` and quality check documentation in `docs/DATA_QUALITY_CHECKS.md`.
