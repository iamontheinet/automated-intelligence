-- Staging layer for order items
-- Joins with product catalog for enrichment

with order_items as (
    select * from {{ source('raw', 'order_items') }}
),

products as (
    select * from {{ source('raw', 'product_catalog') }}
),

enriched as (
    select
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.line_total,
        oi.discount_amount,
        
        -- Product attributes
        p.product_name,
        p.category,
        p.brand,
        p.price as catalog_price,
        
        -- Derived fields
        oi.unit_price - p.price as price_difference,
        case 
            when oi.unit_price < p.price then 'discounted'
            when oi.unit_price > p.price then 'premium'
            else 'standard'
        end as pricing_type,
        oi.line_total / nullif(oi.quantity, 0) as calculated_unit_price
        
    from order_items oi
    left join products p on oi.product_id = p.product_id
)

select * from enriched
