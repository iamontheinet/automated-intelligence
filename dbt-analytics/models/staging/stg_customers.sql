-- Staging layer for customers
-- Lightweight transformations, data type casting, basic cleaning

with source as (
    select * from {{ source('raw', 'customers') }}
),

staged as (
    select
        customer_id,
        customer_name,
        email,
        phone,
        address,
        city,
        state,
        zip_code,
        country,
        signup_date,
        customer_segment,
        preferred_contact_method,
        
        -- Derived fields
        datediff('day', signup_date, current_date()) as days_since_signup,
        date_trunc('month', signup_date) as signup_month,
        date_trunc('year', signup_date) as signup_year
        
    from source
)

select * from staged
