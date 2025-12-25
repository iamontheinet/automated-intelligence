"""
Reconciliation utilities for cleaning up orphaned records after Snowpipe Streaming ingestion.
Handles atomicity violations that may occur due to backpressure or other transient errors.
"""
import logging
from typing import Dict, Any
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import snowflake.connector
from config_manager import ConfigManager

logger = logging.getLogger(__name__)


class ReconciliationManager:
    """Manages data consistency checks and cleanup after streaming ingestion."""
    
    def __init__(self, config: ConfigManager):
        self.config = config
        
    def _get_connection(self):
        """Create a Snowflake connection for running SQL queries."""
        private_key_pem = self.config.get_private_key()
        private_key_obj = serialization.load_pem_private_key(
            private_key_pem.encode(),
            password=None,
            backend=default_backend()
        )
        
        conn_params = {
            "account": self.config.get_snowflake_account(),
            "user": self.config.get_snowflake_user(),
            "role": "SNOWFLAKE_INTELLIGENCE_ADMIN",
            "warehouse": self.config.get_warehouse(),
            "database": self.config.get_database(),
            "schema": self.config.get_schema(),
            "private_key": private_key_obj,
        }
        
        return snowflake.connector.connect(**conn_params)
    
    def reconcile_and_cleanup(self) -> Dict[str, Any]:
        """
        Check for orphaned records and clean them up.
        Returns statistics about what was found and deleted.
        """
        logger.info("Starting reconciliation and cleanup...")
        
        conn = self._get_connection()
        cursor = conn.cursor()
        
        try:
            database = self.config.get_database()
            schema = self.config.get_schema()
            
            # Get table names from config (handle both RAW and STAGING schemas)
            if schema.upper() == "STAGING":
                orders_table = "ORDERS_STAGING"
                order_items_table = "ORDER_ITEMS_STAGING"
            else:
                orders_table = "ORDERS"
                order_items_table = "ORDER_ITEMS"
            
            stats = {
                "orphaned_orders_found": 0,
                "orphaned_orders_deleted": 0,
                "orphaned_items_found": 0,
                "orphaned_items_deleted": 0,
                "final_orders_count": 0,
                "final_items_count": 0,
            }
            
            # 1. Check for orphaned orders (orders without order_items)
            logger.info("Checking for orphaned orders...")
            check_orphaned_orders_sql = f"""
            SELECT COUNT(DISTINCT o.order_id)
            FROM {database}.{schema}.{orders_table} o
            LEFT JOIN {database}.{schema}.{order_items_table} oi 
                ON o.order_id = oi.order_id
            WHERE oi.order_id IS NULL
            """
            cursor.execute(check_orphaned_orders_sql)
            stats["orphaned_orders_found"] = cursor.fetchone()[0]
            
            if stats["orphaned_orders_found"] > 0:
                logger.warning(
                    f"Found {stats['orphaned_orders_found']:,} orphaned orders. Deleting..."
                )
                delete_orphaned_orders_sql = f"""
                DELETE FROM {database}.{schema}.{orders_table}
                WHERE order_id IN (
                    SELECT o.order_id
                    FROM {database}.{schema}.{orders_table} o
                    LEFT JOIN {database}.{schema}.{order_items_table} oi 
                        ON o.order_id = oi.order_id
                    WHERE oi.order_id IS NULL
                )
                """
                cursor.execute(delete_orphaned_orders_sql)
                stats["orphaned_orders_deleted"] = cursor.rowcount
                logger.info(f"Deleted {stats['orphaned_orders_deleted']:,} orphaned orders")
            else:
                logger.info("✓ No orphaned orders found")
            
            # 2. Check for orphaned order_items (order_items without orders)
            logger.info("Checking for orphaned order_items...")
            check_orphaned_items_sql = f"""
            SELECT COUNT(DISTINCT oi.order_item_id)
            FROM {database}.{schema}.{order_items_table} oi
            LEFT JOIN {database}.{schema}.{orders_table} o 
                ON oi.order_id = o.order_id
            WHERE o.order_id IS NULL
            """
            cursor.execute(check_orphaned_items_sql)
            stats["orphaned_items_found"] = cursor.fetchone()[0]
            
            if stats["orphaned_items_found"] > 0:
                logger.warning(
                    f"Found {stats['orphaned_items_found']:,} orphaned order_items. Deleting..."
                )
                delete_orphaned_items_sql = f"""
                DELETE FROM {database}.{schema}.{order_items_table}
                WHERE order_id IN (
                    SELECT oi.order_id
                    FROM {database}.{schema}.{order_items_table} oi
                    LEFT JOIN {database}.{schema}.{orders_table} o 
                        ON oi.order_id = o.order_id
                    WHERE o.order_id IS NULL
                )
                """
                cursor.execute(delete_orphaned_items_sql)
                stats["orphaned_items_deleted"] = cursor.rowcount
                logger.info(f"Deleted {stats['orphaned_items_deleted']:,} orphaned order_items")
            else:
                logger.info("✓ No orphaned order_items found")
            
            # 3. Get final counts
            cursor.execute(f"SELECT COUNT(*) FROM {database}.{schema}.{orders_table}")
            stats["final_orders_count"] = cursor.fetchone()[0]
            
            cursor.execute(f"SELECT COUNT(*) FROM {database}.{schema}.{order_items_table}")
            stats["final_items_count"] = cursor.fetchone()[0]
            
            logger.info("=== Reconciliation Summary ===")
            logger.info(f"Orphaned orders found: {stats['orphaned_orders_found']:,}")
            logger.info(f"Orphaned orders deleted: {stats['orphaned_orders_deleted']:,}")
            logger.info(f"Orphaned items found: {stats['orphaned_items_found']:,}")
            logger.info(f"Orphaned items deleted: {stats['orphaned_items_deleted']:,}")
            logger.info(f"Final orders count: {stats['final_orders_count']:,}")
            logger.info(f"Final order_items count: {stats['final_items_count']:,}")
            
            if stats["orphaned_orders_found"] == 0 and stats["orphaned_items_found"] == 0:
                logger.info("✅ Data is consistent - no orphaned records found")
            else:
                logger.info("✅ Reconciliation completed - data is now consistent")
            
            return stats
            
        finally:
            cursor.close()
            conn.close()
