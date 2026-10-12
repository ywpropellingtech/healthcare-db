{{
  config(
    materialized='table',
    tags=['mart', 'analytics'],
    description='Analytics-ready table for encounter volume trend visualization'
  )
}}

/*
Mart layer: Encounter volume trend
- Optimized for visualization (stacked bar chart: visits/month by visit_type)
- Filtered to COMPLETED encounters for accurate operational metrics
- Includes wRVU productivity insights by visit type
- Enables trend analysis, forecasting, and capacity planning
*/

select
  encounter_month,
  visit_type,
  encounter_count as completed_visits,
  total_wrvu,
  avg_wrvu_per_encounter,
  round(100.0 * encounter_count / sum(encounter_count) over (partition by encounter_month), 2) as pct_of_month_visits,
  cumulative_completed_count as cumulative_visits_by_type,
  -- Rank visits by month for easy filtering
  row_number() over (partition by encounter_month order by encounter_count desc) as rank_in_month
from {{ ref('int_encounter_volume_by_month_visit_type') }}
where encounter_status = 'COMPLETED'
order by encounter_month, rank_in_month
