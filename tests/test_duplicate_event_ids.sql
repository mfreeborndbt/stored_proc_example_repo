-- Test to identify duplicate event_ids (intentionally present in the data)
-- This test is informational - we expect some duplicates by design

with events as (
    select
        event_id,
        count(*) as event_count
    from {{ ref('stg_proofpoint_events') }}
    group by 1
    having count(*) > 1
)

-- This will show which event_ids are duplicated (expected to find some)
select
    event_id,
    event_count,
    'Expected duplicates for DQ testing' as note
from events

