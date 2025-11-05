with source as (
    select * from {{ source('phishing_demo', 'raw_training') }}
),

cleaned as (
    select
        pernr,
        learning_content,
        assigned_date::date as assigned_date,
        due_date::date as due_date,
        completion_date::date as completion_date,
        
        -- Derived fields
        case 
            when completion_date is not null then 1 
            else 0 
        end as is_completed,
        
        case 
            when completion_date is not null and completion_date <= due_date then 1
            when completion_date is not null and completion_date > due_date then 0
            else null
        end as completed_on_time,
        
        datediff(day, assigned_date::date, coalesce(completion_date::date, current_date)) as days_to_complete
        
    from source
)

select * from cleaned

