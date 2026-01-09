#!/usr/bin/env python3
"""
Insert sample data into Snowflake Postgres tables.

This script populates the Postgres tables with sample data matching
the AUTOMATED_INTELLIGENCE.RAW schema in Snowflake.

Usage:
    python insert_sample_data.py

Requirements:
    pip install psycopg2-binary
"""

import json
import os
import psycopg2
import random
import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal

# Load config from postgres_config.json or environment variables
config_path = os.path.join(os.path.dirname(__file__), 'postgres_config.json')
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
    CONNECTION_STRING = f"postgres://{config['user']}:{config['password']}@{config['host']}:{config.get('port', 5432)}/{config.get('database', 'postgres')}"
else:
    if not os.getenv('POSTGRES_PASSWORD'):
        raise ValueError('postgres_config.json not found and POSTGRES_PASSWORD env var not set. Copy postgres_config.json.template to postgres_config.json and fill in credentials.')
    CONNECTION_STRING = f"postgres://{os.getenv('POSTGRES_USER', 'snowflake_admin')}:{os.getenv('POSTGRES_PASSWORD')}@{os.getenv('POSTGRES_HOST')}:{os.getenv('POSTGRES_PORT', '5432')}/{os.getenv('POSTGRES_DB', 'postgres')}"

# Product catalog data
PRODUCTS = [
    (1001, 'Powder Skis', 'Skis', 'Premium powder skis designed for deep snow conditions.', 'Wide waist (115mm), Rockered tip and tail, Carbon fiber construction', 799.99, 15),
    (1002, 'All-Mountain Skis', 'Skis', 'Versatile all-mountain skis perfect for any terrain.', 'Medium waist (88mm), Progressive sidecut, Titanal reinforcement', 649.99, 25),
    (1003, 'Freestyle Snowboard', 'Snowboards', 'Twin-tip freestyle snowboard for park and pipe.', 'True twin shape, Soft flex rating, Sintered base', 549.99, 20),
    (1004, 'Freeride Snowboard', 'Snowboards', 'Directional freeride snowboard for charging hard.', 'Directional shape, Stiff flex, Carbon stringers', 699.99, 12),
    (1005, 'Ski Boots', 'Boots', 'High-performance alpine ski boots with customizable fit.', '130 flex rating, GripWalk soles, Heat-moldable liner', 449.99, 30),
    (1006, 'Snowboard Boots', 'Boots', 'Comfortable snowboard boots with Boa lacing system.', 'Boa lacing system, Medium flex, Heat-moldable liner', 349.99, 35),
    (1007, 'Ski Poles', 'Accessories', 'Lightweight aluminum ski poles with ergonomic grips.', 'Aluminum construction, Adjustable length, Powder baskets', 79.99, 50),
    (1008, 'Ski Goggles', 'Accessories', 'Anti-fog ski goggles with interchangeable lenses.', 'Anti-fog coating, UV protection, Interchangeable lenses', 149.99, 40),
    (1009, 'Snowboard Bindings', 'Accessories', 'Responsive snowboard bindings with tool-free adjustment.', 'Tool-free adjustment, Canted footbeds, Universal disk', 249.99, 28),
    (1010, 'Ski Helmet', 'Accessories', 'Safety-certified ski helmet with integrated audio.', 'MIPS protection, Audio-ready, Adjustable vents', 179.99, 45),
]

STATES = ['CA', 'NY', 'TX', 'FL', 'WA', 'CO', 'OR', 'UT', 'NV', 'AZ']
SEGMENTS = ['Premium', 'Standard', 'Budget', 'VIP']
CITIES = ['San Francisco', 'New York', 'Austin', 'Miami', 'Seattle', 'Denver', 'Portland', 'Salt Lake City', 'Las Vegas', 'Phoenix']
STATUSES = ['Pending', 'Processing', 'Shipped', 'Completed', 'Cancelled']


def main():
    conn = psycopg2.connect(CONNECTION_STRING, sslmode='require')
    conn.autocommit = True
    cur = conn.cursor()
    
    # Clear existing data
    print("Clearing existing data...")
    cur.execute("DELETE FROM order_items")
    cur.execute("DELETE FROM orders")
    cur.execute("DELETE FROM customers")
    cur.execute("DELETE FROM product_catalog")
    
    # Insert products
    print("Inserting products...")
    cur.executemany("""
        INSERT INTO product_catalog (product_id, product_name, product_category, description, features, price, stock_quantity)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, PRODUCTS)
    print(f"  ✓ Inserted {len(PRODUCTS)} products")
    
    # Insert customers
    print("Inserting customers...")
    customers = []
    for i in range(1, 101):
        customers.append((
            i,
            f'First{i}',
            f'Last{i}',
            f'customer{i}@example.com',
            f'555-{i:04d}',
            f'{i * 100} Main St',
            CITIES[i % len(CITIES)],
            STATES[i % len(STATES)],
            f'{10000 + i}',
            date(2023, 1, 1) + timedelta(days=i),
            SEGMENTS[i % len(SEGMENTS)]
        ))
    
    cur.executemany("""
        INSERT INTO customers (customer_id, first_name, last_name, email, phone, address, city, state, zip_code, registration_date, customer_segment)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, customers)
    print(f"  ✓ Inserted {len(customers)} customers")
    
    # Insert orders
    print("Inserting orders...")
    orders = []
    order_items = []
    
    for i in range(1, 201):
        order_id = str(uuid.uuid4())
        customer_id = random.randint(1, 100)
        order_date = datetime(2024, 1, 1) + timedelta(days=random.randint(0, 365))
        discount = random.choice([0, 5, 10, 15, 20])
        shipping = random.choice([0, 5.99, 9.99, 14.99])
        
        # Generate 1-5 items per order
        num_items = random.randint(1, 5)
        total = 0
        for j in range(num_items):
            item_id = str(uuid.uuid4())
            product = random.choice(PRODUCTS)
            qty = random.randint(1, 3)
            line_total = product[5] * qty
            total += line_total
            order_items.append((
                item_id, order_id, product[0], product[1], product[2], qty, product[5], line_total
            ))
        
        total = total * (1 - discount/100) + shipping
        orders.append((
            order_id, customer_id, order_date, random.choice(STATUSES), round(total, 2), discount, shipping
        ))
    
    cur.executemany("""
        INSERT INTO orders (order_id, customer_id, order_date, order_status, total_amount, discount_percent, shipping_cost)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, orders)
    print(f"  ✓ Inserted {len(orders)} orders")
    
    cur.executemany("""
        INSERT INTO order_items (order_item_id, order_id, product_id, product_name, product_category, quantity, unit_price, line_total)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, order_items)
    print(f"  ✓ Inserted {len(order_items)} order items")
    
    # Summary
    print("\n📊 Final Table Summary:")
    for table in ['customers', 'orders', 'order_items', 'product_catalog']:
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        count = cur.fetchone()[0]
        print(f"  {table}: {count} rows")
    
    conn.close()
    print("\n✅ Done!")


if __name__ == "__main__":
    main()
