{{
  config(
    materialized='table',
    schema='marts',
    tags=['marts', 'aggregates', 'revenue_analysis'],
    indexes=[
      {
        'columns': ['metric_date', 'provider_npi'],
        'unique': False
      },
      {
        'columns': ['metric_date', 'department_id'],
        'unique': False
      }
    ],
    pre_hook="{{ log('Starting mart_revenue_analysis transformation', info=true) }}"
  )
}}

/*
Mart: Revenue Analysis
- Comprehensive revenue metrics by provider and department
- Designed for revenue cycle and financial analysis
- Includes charge, revenue, and collection metrics
*/

with encounter_base as (
  select
    encounter_date as metric_date,
    provider_npi,
    employee_id,
    provider_first_name,
    provider_last_name,
    employee_department_id,
    employee_department_name,
    encounter_type,
    encounter_id,
    charge_amount,
    revenue_amount
  from {{ ref('int_employee_encounters') }}
  where encounter_date is not null
),

provider_daily_revenue as (
  select
    metric_date,
    provider_npi,
    employee_id,
    concat(provider_first_name, ' ', provider_last_name) as provider_name,
    employee_department_id,
    employee_department_name,

    -- Provider revenue metrics
    count(distinct encounter_id) as total_encounters,
    sum(charge_amount) as total_charges,
    sum(revenue_amount) as total_revenue,
    avg(charge_amount) as avg_charge_per_encounter,
    avg(revenue_amount) as avg_revenue_per_encounter,

    -- Charge vs Revenue analysis
    sum(charge_amount) - sum(revenue_amount) as total_adjustments,
    case
      when sum(charge_amount) > 0
        then round(100.0 * sum(revenue_amount) / sum(charge_amount), 1)
      else 0
    end as revenue_realization_pct,

    count(case when charge_amount > 0 then 1 end) as encounters_with_charges,
    count(case when revenue_amount > 0 then 1 end) as encounters_with_revenue,
    count(case when charge_amount > revenue_amount then 1 end) as encounters_with_adjustments

  from encounter_base
  group by
    metric_date,
    provider_npi,
    employee_id,
    provider_name,
    employee_department_id,
    employee_department_name
),

department_daily_revenue as (
  select
    metric_date,
    null as provider_npi,
    null as employee_id,
    'DEPARTMENT_TOTAL' as provider_name,
    employee_department_id,
    employee_department_name,

    -- Department revenue metrics
    count(distinct encounter_id) as total_encounters,
    sum(charge_amount) as total_charges,
    sum(revenue_amount) as total_revenue,
    avg(charge_amount) as avg_charge_per_encounter,
    avg(revenue_amount) as avg_revenue_per_encounter,

    -- Charge vs Revenue analysis
    sum(charge_amount) - sum(revenue_amount) as total_adjustments,
    case
      when sum(charge_amount) > 0
        then round(100.0 * sum(revenue_amount) / sum(charge_amount), 1)
      else 0
    end as revenue_realization_pct,

    count(case when charge_amount > 0 then 1 end) as encounters_with_charges,
    count(case when revenue_amount > 0 then 1 end) as encounters_with_revenue,
    count(case when charge_amount > revenue_amount then 1 end) as encounters_with_adjustments

  from encounter_base
  group by
    metric_date,
    employee_department_id,
    employee_department_name
),

combined_revenue as (
  select * from provider_daily_revenue
  union all
  select * from department_daily_revenue
),

with_key_and_dates as (
  select
    {{ dbt_utils.generate_surrogate_key(['metric_date', 'provider_npi', 'employee_department_id']) }} as revenue_key,
    metric_date,
    extract(dayofweek from metric_date) as day_of_week,
    extract(week from metric_date) as week_num,
    extract(month from metric_date) as month_num,
    extract(year from metric_date) as year_num,
    provider_npi,
    employee_id,
    provider_name,
    employee_department_id,
    employee_department_name,
    total_encounters,
    total_charges,
    total_revenue,
    avg_charge_per_encounter,
    avg_revenue_per_encounter,
    total_adjustments,
    revenue_realization_pct,
    encounters_with_charges,
    encounters_with_revenue,
    encounters_with_adjustments,
    case
      when provider_npi is not null then 'PROVIDER'
      else 'DEPARTMENT'
    end as aggregation_level
  from combined_revenue
)

select
  revenue_key,
  metric_date,
  day_of_week,
  week_num,
  month_num,
  year_num,
  provider_npi,
  employee_id,
  provider_name,
  employee_department_id,
  employee_department_name,
  aggregation_level,
  total_encounters,
  total_charges,
  total_revenue,
  avg_charge_per_encounter,
  avg_revenue_per_encounter,
  total_adjustments,
  revenue_realization_pct,
  encounters_with_charges,
  encounters_with_revenue,
  encounters_with_adjustments,
  current_timestamp() as dbt_loaded_at
from with_key_and_dates
where total_revenue is not null
