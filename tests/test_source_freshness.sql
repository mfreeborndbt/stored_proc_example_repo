-- Test source freshness: warn if data is older than 7 days
-- This test checks that our source tables have been updated recently

with source_freshness as (
    select 
        'raw_proofpoint_events' as table_name,
        max(event_ts::timestamp) as last_updated,
        datediff('day', max(event_ts::timestamp), current_timestamp()) as days_since_update
    from {{ source('phishing_demo', 'raw_proofpoint_events') }}
    
    union all
    
    select 
        'raw_workforce' as table_name,
        max(snapshot_date::timestamp) as last_updated,
        datediff('day', max(snapshot_date::timestamp), current_timestamp()) as days_since_update
    from {{ source('phishing_demo', 'raw_workforce') }}
    
    union all
    
    select 
        'raw_training' as table_name,
        max(assigned_date::timestamp) as last_updated,
        datediff('day', max(assigned_date::timestamp), current_timestamp()) as days_since_update
    from {{ source('phishing_demo', 'raw_training') }}
)

-- Flag tables that are more than 7 days old
select 
    table_name,
    last_updated,
    days_since_update,
    'Data is ' || days_since_update || ' days old (threshold: 7 days)' as freshness_note
from source_freshness
where days_since_update > 7

