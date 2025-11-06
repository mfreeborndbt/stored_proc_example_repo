with source as (
    select * from {{ source('phishing_demo', 'raw_workforce') }}
),

cleaned as (
    select
        snapshot_date::date as snapshot_date,
        pernr,
        email,
        full_name,
        company_code,
        business_unit,
        department,
        title,
        employee_type,
        employment_status,
        manager_pernr,
        location
        
    from source
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['snapshot_date', 'pernr']) }} as workforce_key,
        *
    from cleaned
)

select * from final

