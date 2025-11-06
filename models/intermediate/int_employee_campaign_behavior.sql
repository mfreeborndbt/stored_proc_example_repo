with consolidated_events as (
    select * from {{ ref('int_events_consolidated') }}
),

workforce as (
    select * from {{ ref('stg_workforce') }}
),

training as (
    select * from {{ ref('stg_training') }}
),

-- Join events with employee data
events_with_employees as (
    select
        e.pernr,
        e.campaign_id,
        e.campaign_name,
        e.event_month,
        e.final_event_type,
        e.event_severity_rank,
        e.final_event_ts,
        e.final_event_date,
        e.had_data_submission,
        e.had_email_click,
        e.had_email_view,
        e.had_reported,
        e.had_no_action,
        e.total_event_count,
        e.first_event_ts,
        e.last_event_ts,
        
        -- Employee attributes
        w.full_name,
        w.email as employee_email,
        w.business_unit,
        w.department,
        w.title,
        w.employee_type,
        w.employment_status,
        w.location,
        w.manager_pernr,
        
        -- Categorize risk level based on final event
        case 
            when e.final_event_type = 'DATA_SUBMISSION' then 'Critical'
            when e.final_event_type = 'EMAIL_CLICK' then 'High'
            when e.final_event_type = 'EMAIL_VIEW' then 'Medium'
            when e.final_event_type = 'REPORTED' then 'Low'
            when e.final_event_type = 'NO_ACTION' then 'Low'
            else 'Unknown'
        end as risk_level,
        
        -- Flag for "clickers" (anyone who clicked or submitted data)
        case 
            when e.final_event_type in ('EMAIL_CLICK', 'DATA_SUBMISSION') then 1 
            else 0 
        end as is_clicker
        
    from consolidated_events e
    left join workforce w
        on e.pernr = w.pernr
),

-- Add training information for clickers
enriched as (
    select
        e.*,
        t.learning_content,
        t.assigned_date as training_assigned_date,
        t.due_date as training_due_date,
        t.completion_date as training_completion_date,
        t.is_completed as training_completed,
        t.completed_on_time as training_completed_on_time,
        t.days_to_complete as training_days_to_complete
        
    from events_with_employees e
    left join training t
        on e.pernr = t.pernr
        and t.learning_content = 'Simulated Phishing Awareness 2025Q3'
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['pernr', 'campaign_id']) }} as employee_campaign_key,
        *
    from enriched
)

select * from final

