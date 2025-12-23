import logging
from typing import List, Dict, Any, Optional
from snowflake.ingest.streaming import StreamingIngestClient, StreamingIngestChannel
from models import Order, OrderItem
from config_manager import ConfigManager
import snowflake.connector
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

logger = logging.getLogger(__name__)


class SnowpipeStreamingManager:
    def __init__(self, config: ConfigManager, instance_id: int = -1):
        self.config = config
        self.instance_id = instance_id
        
        channel_suffix = f"_instance_{instance_id}" if instance_id >= 0 else ""
        logger.info(
            f"Creating Snowflake Streaming clients and opening channels"
            f"{' for instance ' + str(instance_id) if instance_id >= 0 else '...'}"
        )
        
        self.properties = {
            "account": config.get_snowflake_account(),
            "user": config.get_snowflake_user(),
            "private_key": config.get_private_key(),
            "url": config.get_snowflake_url(),
            "role": "SNOWFLAKE_INTELLIGENCE_ADMIN",
            "warehouse": config.get_warehouse(),
        }
        
        self.orders_client = StreamingIngestClient(
            client_name=f"ORDERS_CLIENT_{instance_id}",
            db_name=config.get_database(),
            schema_name=config.get_schema(),
            pipe_name=config.get_property("pipe.orders.name"),
            properties=self.properties,
        )
        
        self.order_items_client = StreamingIngestClient(
            client_name=f"ORDER_ITEMS_CLIENT_{instance_id}",
            db_name=config.get_database(),
            schema_name=config.get_schema(),
            pipe_name=config.get_property("pipe.order_items.name"),
            properties=self.properties,
        )
        
        self.orders_channel = self._open_channel(
            self.orders_client,
            config.get_property("channel.orders.name") + channel_suffix,
        )
        
        self.order_items_channel = self._open_channel(
            self.order_items_client,
            config.get_property("channel.order_items.name") + channel_suffix,
        )
        
        logger.info("All clients and channels initialized successfully")

    def _open_channel(
        self, client: StreamingIngestClient, channel_name: str
    ) -> StreamingIngestChannel:
        initial_offset = "0"
        channel, status = client.open_channel(channel_name, initial_offset)
        
        latest_offset = channel.get_latest_committed_offset_token()
        logger.info(
            f"Channel {channel_name} opened. Latest committed offset: "
            f"{latest_offset if latest_offset else 'NULL (new channel)'}"
        )
        
        return channel

    def get_max_customer_id(self) -> int:
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
        
        max_id = 1
        try:
            conn = snowflake.connector.connect(**conn_params)
            cursor = conn.cursor()
            cursor.execute(
                f"SELECT MAX(CUSTOMER_ID) as MAX_ID FROM "
                f"{self.config.get_database()}.RAW.CUSTOMERS"
            )
            result = cursor.fetchone()
            if result and result[0]:
                max_id = result[0]
            logger.info(f"Max customer ID in database: {max_id}")
            cursor.close()
            conn.close()
        except Exception as e:
            logger.error(f"Error fetching max customer ID: {e}")
            raise
        
        return max_id

    def insert_order(self, order: Order) -> None:
        row = order.to_dict()
        offset_token = f"order_{order.order_id}"
        
        self.orders_channel.append_row(row, offset_token)
        logger.debug(f"Order {order.order_id} inserted with offset {offset_token}")

    def insert_orders(self, orders: List[Order]) -> None:
        if not orders:
            return
        
        start_offset = f"order_{orders[0].order_id}"
        end_offset = f"order_{orders[-1].order_id}"
        
        rows = [order.to_dict() for order in orders]
        
        self.orders_channel.append_rows(rows, start_offset, end_offset)
        logger.debug(
            f"Inserted {len(orders)} orders (offset range: {start_offset} to {end_offset})"
        )

    def insert_order_items(self, items: List[OrderItem]) -> None:
        if not items:
            return
        
        start_offset = f"item_{items[0].order_item_id}"
        end_offset = f"item_{items[-1].order_item_id}"
        
        rows = [item.to_dict() for item in items]
        
        self.order_items_channel.append_rows(rows, start_offset, end_offset)
        logger.debug(
            f"Inserted {len(items)} order items (offset range: {start_offset} to {end_offset})"
        )

    def get_latest_order_offset(self) -> Optional[str]:
        return self.orders_channel.get_latest_committed_offset_token()

    def get_latest_order_item_offset(self) -> Optional[str]:
        return self.order_items_channel.get_latest_committed_offset_token()

    def close(self) -> None:
        try:
            logger.info("Closing channels...")
            if hasattr(self, "orders_channel"):
                self.orders_channel.close()
            if hasattr(self, "order_items_channel"):
                self.order_items_channel.close()
            
            logger.info("Closing clients...")
            if hasattr(self, "orders_client"):
                self.orders_client.close()
            if hasattr(self, "order_items_client"):
                self.order_items_client.close()
            
            logger.info("Snowpipe Streaming manager closed successfully")
        except Exception as e:
            logger.error(f"Error closing Snowpipe Streaming manager: {e}")
