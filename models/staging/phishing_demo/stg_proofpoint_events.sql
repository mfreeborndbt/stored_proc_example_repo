with source as (
    select * from {{ source('phishing_demo', 'raw_proofpoint_events') }}
),

cleaned as (
    select
        ingestion_run_id,
        event_id,
        event_ts::timestamp as event_ts,
        campaign_id,
        campaign_name,
        template_name,
        employee_email,
        employee_pernr as pernr,
        business_unit,
        event_type,
        
        -- Add useful derived fields
        event_ts::date as event_date,
        date_trunc('month', event_ts::timestamp) as event_month
        
    from source
)

select * from cleaned

