import logging
import sys
import time
from typing import List
from config_manager import ConfigManager
from snowpipe_streaming_manager import SnowpipeStreamingManager
from data_generator import DataGenerator
from models import Order, OrderItem

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


class AutomatedIntelligenceStreaming:
    def __init__(
        self, config: ConfigManager, streaming_manager: SnowpipeStreamingManager
    ):
        self.config = config
        self.streaming_manager = streaming_manager

    def generate_and_stream_orders(self, num_orders: int) -> None:
        logger.info(f"Starting to generate and stream {num_orders} orders")
        
        max_customer_id = self.streaming_manager.get_max_customer_id()
        if max_customer_id == 0:
            logger.error(
                "No customers found in database. Please run generate_customers() "
                "stored procedure first to create customers."
            )
            raise ValueError("No customers available for order generation")
        
        logger.info(f"Will generate orders for customer IDs in range 1-{max_customer_id}")
        
        batch_size = self.config.get_int_property("orders.batch.size", 10000)
        logger.info(f"Using batch size: {batch_size} orders per insertRows call")
        
        processed_orders = 0
        while processed_orders < num_orders:
            remaining_orders = num_orders - processed_orders
            current_batch_size = min(batch_size, remaining_orders)
            
            try:
                order_batch: List[Order] = []
                all_order_items: List[OrderItem] = []
                
                for i in range(current_batch_size):
                    customer_id = DataGenerator.random_customer_id(max_customer_id)
                    order = DataGenerator.generate_order(customer_id)
                    order_batch.append(order)
                    
                    item_count = DataGenerator.random_item_count()
                    order_items = DataGenerator.generate_order_items(
                        order.order_id, item_count
                    )
                    all_order_items.extend(order_items)
                
                # Insert both orders and order_items - if either fails, both should fail
                try:
                    self.streaming_manager.insert_orders(order_batch)
                    self.streaming_manager.insert_order_items(all_order_items)
                except Exception as e:
                    logger.error(f"Failed to insert batch: {e}")
                    raise  # Re-raise to stop processing
                
                processed_orders += current_batch_size
                logger.info(
                    f"Progress: {processed_orders}/{num_orders} orders streamed "
                    f"({len(all_order_items)} order items)"
                )
                
            except Exception as e:
                logger.error(
                    f"Error generating order batch at position {processed_orders}: {e}",
                    exc_info=True,
                )
                raise
        
        logger.info(f"Successfully streamed {num_orders} orders")
        self._print_offset_status()

    def _print_offset_status(self) -> None:
        logger.info("=== Offset Token Status ===")
        logger.info(f"Orders: {self.streaming_manager.get_latest_order_offset()}")
        logger.info(
            f"Order Items: {self.streaming_manager.get_latest_order_item_offset()}"
        )


def main():
    logger.info("Starting Automated Intelligence Snowpipe Streaming")
    
    config = None
    streaming_manager = None
    
    try:
        config = ConfigManager("config.properties", "profile.json")
        streaming_manager = SnowpipeStreamingManager(config)
        
        app = AutomatedIntelligenceStreaming(config, streaming_manager)
        
        num_orders = config.get_int_property("num.orders.per.batch", 100)
        
        if len(sys.argv) > 1:
            num_orders = int(sys.argv[1])
        
        app.generate_and_stream_orders(num_orders)
        
        logger.info("Waiting 5 seconds for final data flush...")
        time.sleep(5)
        
        logger.info("Application completed successfully")
        
    except Exception as e:
        logger.error("Application error", exc_info=True)
        sys.exit(1)
    finally:
        if streaming_manager is not None:
            streaming_manager.close()


if __name__ == "__main__":
    main()
