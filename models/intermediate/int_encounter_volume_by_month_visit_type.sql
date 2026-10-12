{{
  config(
    materialized='table',
    tags=['intermediate', 'analytics'],
    description='Encounter volume aggregated by month and visit type for trend analysis'
  )
}}

/*
Intermediate layer: Encounter volume trend
- Aggregates encounters by month and visit type
- Enables stacked bar chart of visit volume over time
- Filters to COMPLETED encounters only (legitimate activity)
- Useful for operational demand analysis and capacity planning
*/

with monthly_visits as (
  select
    date_trunc('month', encounter_date)::date as encounter_month,
    visit_type,
    encounter_status,
    count(*) as encounter_count,
    round(sum(wrvu), 2) as total_wrvu,
    round(avg(wrvu), 2) as avg_wrvu_per_encounter
  from {{ ref('stg_encounters') }}
  where encounter_date is not null
    and visit_type is not null
  group by date_trunc('month', encounter_date)::date, visit_type, encounter_status
)

select
  encounter_month,
  visit_type,
  encounter_status,
  encounter_count,
  total_wrvu,
  avg_wrvu_per_encounter,
  -- Cumulative count across the year for trend analysis
  sum(case when encounter_status = 'COMPLETED' then encounter_count else 0 end)
    over (partition by visit_type order by encounter_month) as cumulative_completed_count
from monthly_visits
order by encounter_month, visit_type, encounter_status
