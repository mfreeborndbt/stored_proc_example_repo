-- Test that training due dates are >= assigned dates
-- and completion dates (if present) are reasonable

with training as (
    select * from {{ ref('stg_training') }}
),

invalid_records as (
    select
        pernr,
        learning_content,
        assigned_date,
        due_date,
        completion_date,
        
        case
            when due_date < assigned_date then 'Due date before assigned date'
            when completion_date is not null and completion_date < assigned_date then 'Completion before assignment'
            else null
        end as validation_error
        
    from training
    where due_date < assigned_date
       or (completion_date is not null and completion_date < assigned_date)
)

-- This test will fail if there are any invalid records
select * from invalid_records

