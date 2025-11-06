-- Business unit level summary metrics across all campaigns
with employee_events as (
    select * from {{ ref('fct_employee_campaign_events') }}
),

bu_metrics as (
    select
        business_unit,
        event_month,
        
        -- Overall metrics
        count(distinct pernr) as unique_employees,
        count(distinct campaign_id) as campaigns_participated,
        count(*) as total_campaign_participations,
        
        -- Event type breakdowns
        sum(case when final_event_type = 'DATA_SUBMISSION' then 1 else 0 end) as data_submissions,
        sum(case when final_event_type = 'EMAIL_CLICK' then 1 else 0 end) as email_clicks,
        sum(case when final_event_type = 'EMAIL_VIEW' then 1 else 0 end) as email_views,
        sum(case when final_event_type = 'REPORTED' then 1 else 0 end) as emails_reported,
        sum(case when final_event_type = 'NO_ACTION' then 1 else 0 end) as no_actions,
        
        -- Risk metrics
        sum(is_clicker) as total_click_incidents,
        count(distinct case when is_clicker = 1 then pernr end) as unique_clickers,
        
        -- Calculate rates
        round(100.0 * sum(is_clicker) / nullif(count(*), 0), 2) as click_rate_pct,
        round(100.0 * sum(case when final_event_type = 'REPORTED' then 1 else 0 end) / 
            nullif(count(*), 0), 2) as report_rate_pct,
        
        -- Average risk score (lower is worse)
        round(avg(event_severity_rank), 2) as avg_event_severity_rank
        
    from employee_events
    group by 1, 2
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['business_unit', 'event_month']) }} as business_unit_summary_key,
        *
    from bu_metrics
)

select * from final

