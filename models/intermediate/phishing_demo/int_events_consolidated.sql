with events as (
    select * from {{ ref('stg_proofpoint_events') }}
),

-- Assign severity ranking to event types (lower number = worse action)
ranked_events as (
    select
        *,
        case event_type
            when 'DATA_SUBMISSION' then 1
            when 'EMAIL_CLICK' then 2
            when 'EMAIL_VIEW' then 3
            when 'REPORTED' then 4
            when 'NO_ACTION' then 5
            else 99
        end as event_severity_rank,
        
        row_number() over (
            partition by pernr, campaign_id 
            order by 
                case event_type
                    when 'DATA_SUBMISSION' then 1
                    when 'EMAIL_CLICK' then 2
                    when 'EMAIL_VIEW' then 3
                    when 'REPORTED' then 4
                    when 'NO_ACTION' then 5
                    else 99
                end,
                event_ts
        ) as event_rank
        
    from events
),

-- Get one record per employee per campaign (worst action)
consolidated as (
    select
        pernr,
        campaign_id,
        campaign_name,
        business_unit,
        event_type as final_event_type,
        event_severity_rank,
        event_ts as final_event_ts,
        event_date as final_event_date,
        event_month,
        employee_email,
        
        -- Create flags for each event type
        max(case when event_type = 'DATA_SUBMISSION' then 1 else 0 end) as had_data_submission,
        max(case when event_type = 'EMAIL_CLICK' then 1 else 0 end) as had_email_click,
        max(case when event_type = 'EMAIL_VIEW' then 1 else 0 end) as had_email_view,
        max(case when event_type = 'REPORTED' then 1 else 0 end) as had_reported,
        max(case when event_type = 'NO_ACTION' then 1 else 0 end) as had_no_action,
        
        -- Count total events per person per campaign
        count(*) as total_event_count,
        min(event_ts) as first_event_ts,
        max(event_ts) as last_event_ts
        
    from ranked_events
    where event_rank = 1
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
)

select * from consolidated

