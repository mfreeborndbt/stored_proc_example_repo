-- Campaign-level summary metrics
with employee_events as (
    select * from {{ ref('fct_employee_campaign_events') }}
),

campaign_metrics as (
    select
        campaign_id,
        campaign_name,
        event_month,
        
        -- Overall metrics
        count(distinct pernr) as total_employees_targeted,
        count(distinct case when final_event_type != 'NO_ACTION' then pernr end) as employees_who_engaged,
        
        -- Event type breakdowns
        count(distinct case when final_event_type = 'DATA_SUBMISSION' then pernr end) as employees_data_submission,
        count(distinct case when final_event_type = 'EMAIL_CLICK' then pernr end) as employees_clicked,
        count(distinct case when final_event_type = 'EMAIL_VIEW' then pernr end) as employees_viewed,
        count(distinct case when final_event_type = 'REPORTED' then pernr end) as employees_reported,
        count(distinct case when final_event_type = 'NO_ACTION' then pernr end) as employees_no_action,
        
        -- Risk metrics
        count(distinct case when is_clicker = 1 then pernr end) as total_clickers,
        count(distinct case when risk_level = 'Critical' then pernr end) as critical_risk_count,
        count(distinct case when risk_level = 'High' then pernr end) as high_risk_count,
        count(distinct case when risk_level = 'Medium' then pernr end) as medium_risk_count,
        
        -- Training metrics for clickers
        count(distinct case when is_clicker = 1 and training_completed = 1 then pernr end) as clickers_completed_training,
        count(distinct case when is_clicker = 1 and training_completed = 0 then pernr end) as clickers_not_completed_training,
        
        -- Calculate rates
        round(100.0 * count(distinct case when is_clicker = 1 then pernr end) / 
            nullif(count(distinct pernr), 0), 2) as click_rate_pct,
        round(100.0 * count(distinct case when final_event_type = 'REPORTED' then pernr end) / 
            nullif(count(distinct pernr), 0), 2) as report_rate_pct,
        round(100.0 * count(distinct case when is_clicker = 1 and training_completed = 1 then pernr end) / 
            nullif(count(distinct case when is_clicker = 1 then pernr end), 0), 2) as clicker_training_completion_rate_pct
        
    from employee_events
    group by 1, 2, 3
)

select * from campaign_metrics

