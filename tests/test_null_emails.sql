-- Test to identify records with null employee emails
-- This test is informational - we expect at least one null by design

with events as (
    select
        event_id,
        pernr,
        employee_email,
        campaign_name
    from {{ ref('stg_proofpoint_events') }}
    where employee_email is null
)

-- This will show records with null emails (expected to find at least one)
select
    event_id,
    pernr,
    campaign_name,
    'Expected null emails for DQ testing' as note
from events

