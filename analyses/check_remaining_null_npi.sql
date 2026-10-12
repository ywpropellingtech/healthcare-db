-- Comprehensive check of remaining NULL provider_npi after NPI fill
-- Shows which providers still have NULL NPIs and why

-- Query 1: Summary of NULL provider_npi after fill
select 'Summary of Remaining NULL provider_npi' as query_name,
       count(*) as total_encounters,
       sum(case when provider_npi is null then 1 else 0 end) as remaining_null_npi,
       sum(case when provider_npi is not null then 1 else 0 end) as filled_npi_count,
       round(100.0 * sum(case when provider_npi is null then 1 else 0 end) / count(*), 2) as pct_null_remaining
from {{ ref('stg_encounters') }};

-- Query 2: Providers with remaining NULL provider_npi
select 'Providers with Remaining NULL NPI' as query_name,
       provider_name,
       count(*) as encounter_count,
       sum(case when provider_npi is null then 1 else 0 end) as null_npi_count,
       round(100.0 * sum(case when provider_npi is null then 1 else 0 end) / count(*), 2) as pct_null,
       'No known NPI in source data' as reason
from {{ ref('stg_encounters') }}
where provider_npi is null
group by provider_name
order by null_npi_count desc;

-- Query 3: Verify these providers have NO known NPIs in source
select 'Providers with No Known NPI (source verification)' as query_name,
       provider_name,
       count(*) as total_encounters,
       sum(case when provider_npi is null then 1 else 0 end) as all_null_encounters,
       count(distinct provider_npi) as distinct_npi_values,
       listagg(distinct provider_npi, ', ') within group (order by provider_npi) as npi_values
from {{ ref('stg_encounters') }}
where provider_name in (
  select distinct provider_name
  from {{ ref('stg_encounters') }}
  where provider_npi is null
)
group by provider_name
order by provider_name;

-- Query 4: Sample encounters with NULL provider_npi
select 'Sample Encounters with Remaining NULL provider_npi' as query_name,
       encounter_id,
       patient_id,
       provider_name,
       provider_npi,
       encounter_date,
       visit_type,
       encounter_status,
       wrvu,
       charge_amount
from {{ ref('stg_encounters') }}
where provider_npi is null
order by provider_name, encounter_date
limit 50;

-- Query 5: Impact analysis - which metrics will be affected by remaining NULL NPIs?
select 'Impact Analysis - Encounters with NULL provider_npi by Dimension' as query_name,
       'By Visit Type' as dimension,
       visit_type as dimension_value,
       count(*) as total_encounters,
       sum(case when provider_npi is null then 1 else 0 end) as null_npi_count,
       round(100.0 * sum(case when provider_npi is null then 1 else 0 end) / count(*), 2) as pct_null
from {{ ref('stg_encounters') }}
group by visit_type
union all
select 'Impact Analysis - Encounters with NULL provider_npi by Dimension' as query_name,
       'By Status' as dimension,
       encounter_status as dimension_value,
       count(*) as total_encounters,
       sum(case when provider_npi is null then 1 else 0 end) as null_npi_count,
       round(100.0 * sum(case when provider_npi is null then 1 else 0 end) / count(*), 2) as pct_null
from {{ ref('stg_encounters') }}
group by encounter_status
order by pct_null desc;

-- Query 6: Recommendations for handling remaining NULL NPIs
select 'Recommendation for Handling Remaining NULL NPIs' as finding,
       'Providers with 100% NULL provider_npi cannot be matched to employee dimension' as issue,
       'Consider excluding these encounters from provider-level metrics' as recommendation,
       (select sum(case when provider_npi is null then 1 else 0 end) from {{ ref('stg_encounters') }}) as affected_encounters,
       (select count(*) from {{ ref('stg_encounters') }}) as total_encounters;
