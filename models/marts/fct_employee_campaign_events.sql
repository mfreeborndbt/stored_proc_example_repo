-- Fact table at employee x campaign grain showing phishing simulation results
with employee_campaign_behavior as (
    select * from {{ ref('int_employee_campaign_behavior') }}
),

enriched as (
    select
        -- Keys
        pernr,
        campaign_id,
        campaign_name,
        event_month,
        
        -- Event details
        final_event_type,
        event_severity_rank,
        final_event_ts,
        final_event_date,
        
        -- Event flags
        had_data_submission,
        had_email_click,
        had_email_view,
        had_reported,
        had_no_action,
        total_event_count,
        first_event_ts,
        last_event_ts,
        
        -- Employee attributes
        full_name,
        employee_email,
        business_unit,
        department,
        title,
        employee_type,
        employment_status,
        location,
        manager_pernr,
        
        -- Risk assessment
        risk_level,
        is_clicker,
        
        -- Training information
        learning_content,
        training_assigned_date,
        training_due_date,
        training_completion_date,
        training_completed,
        training_completed_on_time,
        training_days_to_complete,
        
        -- Derived metrics
        datediff(second, first_event_ts, last_event_ts) as seconds_between_first_and_last_event,
        
        case 
            when is_clicker = 1 and training_completed = 1 then 'Clicker - Trained'
            when is_clicker = 1 and training_completed = 0 then 'Clicker - Not Trained'
            when is_clicker = 0 and training_completed = 1 then 'Non-Clicker - Trained'
            when is_clicker = 0 and training_completed = 0 then 'Non-Clicker - Not Trained'
            else 'Unknown'
        end as training_status_category
        
    from employee_campaign_behavior
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['pernr', 'campaign_id']) }} as employee_campaign_event_key,
        *
    from enriched
)

select * from final

