# Healthcare Analytics dbt Project

A comprehensive dbt project for healthcare data transformation and analytics. This project transforms raw healthcare data from Workday (HR) and Epic (EHR) systems into clean, modeled tables for analysis.

## Project Overview

This dbt project implements a layered analytics architecture:

- **Staging Layer**: Clean and normalize raw source data
- **Intermediate Layer**: Business logic and cross-system joins
- **Marts Layer**: Dimensional and fact tables optimized for analytics

## Project Structure

```
healthcare-db/
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   ├── stg_employees.sql
│   │   ├── stg_encounters.sql
│   │   └── schema.yml
│   ├── intermediate/
│   │   ├── int_employee_encounters.sql
│   │   ├── int_provider_metrics.sql
│   │   └── schema.yml
│   └── marts/
│       ├── fct_encounters.sql
│       ├── dim_providers.sql
│       ├── dim_departments.sql
│       ├── mart_provider_performance.sql
│       ├── mart_department_utilization.sql
│       ├── mart_revenue_analysis.sql
│       └── schema.yml
├── tests/
├── macros/
├── .github/workflows/
│   └── dbt_run.yml
├── dbt_project.yml
├── profiles.yml (gitignored)
└── README.md
```

## Data Sources

### Workday (HR System)
- **RAW.WORKDAY.WRK_EMPLOYEES**: Employee master data with NPI, department, job title, employment status

### Epic (EHR System)
- **RAW.EPIC.EPC_ENCOUNTERS**: Patient encounters with provider NPI, encounter type, charges, revenue

## Models Overview

### Staging Layer
- **stg_employees**: Cleaned employee data, removes nulls, standardizes formats
- **stg_encounters**: Cleaned encounter data, parses dates, validates amounts

### Intermediate Layer
- **int_employee_encounters**: Joins employees with encounters via NPI
- **int_provider_metrics**: Daily provider-level aggregations with KPIs

### Marts Layer
- **fct_encounters**: Fact table for encounter analysis
- **dim_providers**: Provider dimension with attributes
- **dim_departments**: Department dimension with classifications
- **mart_provider_performance**: Daily provider KPIs and efficiency metrics
- **mart_department_utilization**: Daily department operational metrics
- **mart_revenue_analysis**: Revenue cycle metrics by provider and department

## Key Features

- Comprehensive data quality tests (not null, unique, referential integrity)
- Surrogate key generation for all dimensions
- SCD Type 1 slowly changing dimensions
- Multi-level aggregations for analytics
- Production-ready SQL with proper indexing
- GitHub Actions CI/CD pipeline
- Complete documentation and lineage

## Getting Started

### Prerequisites
- Python 3.9+
- dbt-snowflake
- Snowflake account access

### Installation

```bash
git clone https://github.com/ywpropellingtech/healthcare-db.git
cd healthcare-db
python -m venv venv
source venv/bin/activate
pip install dbt-snowflake dbt-utils dbt-expectations
```

### Configure Credentials

```bash
mkdir -p ~/.dbt
cp profiles.yml ~/.dbt/profiles.yml
# Edit with your Snowflake credentials
```

### Run dbt

```bash
dbt deps
dbt run
dbt test
dbt docs generate
```

## Snowflake Configuration

Connection Details:
- Account: LXFQWXZ-BS91375
- User: YWPROPELLING
- Database: RAW
- Schema: analytics
- Supports key-pair authentication (preferred for production)

## CI/CD Pipeline

GitHub Actions workflow runs:
- dbt deps, run, test
- Documentation generation
- Results upload and PR comments

Required GitHub secrets:
- SNOWFLAKE_ACCOUNT
- SNOWFLAKE_USER
- SNOWFLAKE_PASSWORD
- SNOWFLAKE_ROLE
- SNOWFLAKE_WAREHOUSE
- SNOWFLAKE_DATABASE

## Best Practices

1. Layered architecture with clear separation of concerns
2. Comprehensive data quality testing
3. Surrogate keys for dimensional consistency
4. Table materialization for marts layer
5. Efficient SQL with appropriate indexes
6. Security: credentials excluded from git
7. Version control and change tracking

## Testing

All models include:
- Not null tests on critical columns
- Unique tests on identifiers
- Accepted values tests on categorical columns
- Range tests on numeric values
- Format validation (NPI, email patterns)

## Support

For issues or questions, contact the analytics team.
