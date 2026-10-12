-- Summary of NULL provider_npi by provider with cumulative percentages

-- Query 1: Provider contribution to total NULL provider_npi
select 'Provider Contribution to NULL provider_npi' as summary_type,
       provider_name,
       null_npi_count,
       (select count(*) from {{ ref('stg_encounters') }} where provider_npi is null) as total_null_npi,
       round(100.0 * null_npi_count / (select count(*) from {{ ref('stg_encounters') }} where provider_npi is null), 2) as pct_of_total_null,
       round(100.0 * sum(null_npi_count) over (order by null_npi_count desc) / (select count(*) from {{ ref('stg_encounters') }} where provider_npi is null), 2) as cumulative_pct
from (
  select provider_name,
         sum(case when provider_npi is null then 1 else 0 end) as null_npi_count
  from {{ ref('stg_encounters') }}
  where provider_npi is null
  group by provider_name
)
order by null_npi_count desc;

-- Query 2: Aggregate summary
select 'Aggregate NULL provider_npi Summary' as summary_type,
       count(distinct provider_name) as num_providers_with_null,
       sum(null_npi_count) as total_null_npi,
       round(sum(pct_of_provider), 2) as sum_of_pct_null,
       round(100.0 * sum(null_npi_count) / (select count(*) from {{ ref('stg_encounters') }}), 2) as pct_of_all_encounters
from (
  select provider_name,
         sum(case when provider_npi is null then 1 else 0 end) as null_npi_count,
         round(100.0 * sum(case when provider_npi is null then 1 else 0 end) / count(*), 2) as pct_of_provider
  from {{ ref('stg_encounters') }}
  group by provider_name
  having sum(case when provider_npi is null then 1 else 0 end) > 0
);

-- Query 3: Top 10 providers by NULL NPI contribution
select 'Top 10 Providers Contributing to NULL provider_npi' as ranking,
       row_number() over (order by null_npi_count desc) as rank,
       provider_name,
       encounter_count,
       null_npi_count,
       round(100.0 * null_npi_count / encounter_count, 2) as pct_null_for_provider,
       round(100.0 * null_npi_count / (select count(*) from {{ ref('stg_encounters') }} where provider_npi is null), 2) as pct_of_total_null_npi
from (
  select provider_name,
         count(*) as encounter_count,
         sum(case when provider_npi is null then 1 else 0 end) as null_npi_count
  from {{ ref('stg_encounters') }}
  group by provider_name
  having sum(case when provider_npi is null then 1 else 0 end) > 0
)
order by null_npi_count desc
limit 10;
