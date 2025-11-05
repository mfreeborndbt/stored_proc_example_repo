-- Test for continuous month coverage in Q3 2025 campaigns
-- We expect campaigns in July (2025-07), August (2025-08), and September (2025-09)

with campaigns as (
    select distinct
        campaign_id,
        campaign_name,
        event_month
    from {{ ref('stg_proofpoint_events') }}
),

expected_months as (
    select '2025-07-01'::date as month_start
    union all
    select '2025-08-01'::date
    union all
    select '2025-09-01'::date
),

coverage_check as (
    select
        em.month_start,
        count(distinct c.campaign_id) as campaign_count
    from expected_months em
    left join campaigns c
        on date_trunc('month', c.event_month) = em.month_start
    group by 1
),

missing_coverage as (
    select
        month_start,
        campaign_count
    from coverage_check
    where campaign_count = 0
)

-- This test will fail if any Q3 month has no campaigns
select * from missing_coverage

