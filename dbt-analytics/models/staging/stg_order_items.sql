-- Staging layer for order items
-- Joins with product catalog for enrichment

with order_items as (
    select * from {{ source('raw', 'order_items') }}
    qualify row_number() over (partition by order_item_id order by order_item_id) = 1
),

products as (
    select * from {{ source('raw', 'product_catalog') }}
    qualify row_number() over (partition by product_id order by product_id) = 1
),

enriched as (
    select
        oi.order_item_id,
        oi.order_id,
        oi.product_id,
        oi.product_name,
        oi.product_category,
        oi.quantity,
        oi.unit_price,
        oi.line_total,
        
        -- Catalog enrichment from product_catalog
        p.price as catalog_price,
        p.description as product_description,
        p.features as product_features,
        
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
