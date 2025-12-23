-- Staging layer for products
-- Minimal transformations on product catalog

with source as (
    select * from {{ source('raw', 'product_catalog') }}
),

staged as (
    select
        product_id,
        product_name,
        description,
        category,
        subcategory,
        brand,
        price,
        cost,
        stock_quantity,
        reorder_level,
        supplier_id,
        created_date,
        last_updated,
        
        -- Derived fields
        price - cost as margin,
        (price - cost) / nullif(price, 0) as margin_percent,
        case 
            when stock_quantity <= reorder_level then 'low'
            when stock_quantity <= reorder_level * 2 then 'medium'
            else 'adequate'
        end as stock_status
        
    from source
)

select * from staged
