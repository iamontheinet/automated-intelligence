import logging
import sys
import time
from typing import List
from concurrent.futures import ThreadPoolExecutor, Future, as_completed
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


class ParallelStreamingOrchestrator:
    @staticmethod
    def main(total_orders: int, num_instances: int, config_file: str = "config.properties", profile_file: str = "profile.json"):
        logger.info("=== Parallel Streaming Orchestrator ===")
        logger.info(f"Total orders to generate: {total_orders}")
        logger.info(f"Number of parallel instances: {num_instances}")
        logger.info(f"Using config: {config_file}")
        
        config = None
        
        try:
            config = ConfigManager(config_file, profile_file)
            max_customer_id = ParallelStreamingOrchestrator._get_max_customer_id(config)
            
            logger.info(f"Total customers available: {max_customer_id}")
            
            orders_per_instance = total_orders // num_instances
            customer_range_size = max_customer_id // num_instances
            
            with ThreadPoolExecutor(max_workers=num_instances) as executor:
                futures: List[Future] = []
                
                for i in range(num_instances):
                    orders_for_this_instance = (
                        total_orders - (orders_per_instance * i)
                        if i == num_instances - 1
                        else orders_per_instance
                    )
                    
                    customer_id_start = (i * customer_range_size) + 1
                    customer_id_end = (
                        max_customer_id
                        if i == num_instances - 1
                        else (i + 1) * customer_range_size
                    )
                    
                    logger.info(
                        f"Instance {i}: {orders_for_this_instance} orders, "
                        f"customer IDs {customer_id_start}-{customer_id_end}"
                    )
                    
                    future = executor.submit(
                        ParallelStreamingOrchestrator._run_streaming_instance,
                        i,
                        orders_for_this_instance,
                        customer_id_start,
                        customer_id_end,
                        config,
                    )
                    futures.append(future)
                
                logger.info(
                    f"All {num_instances} instances submitted. Waiting for completion..."
                )
                
                total_orders_generated = 0
                successful_instances = 0
                failed_instances = 0
                
                for i, future in enumerate(futures):
                    try:
                        result = future.result()
                        total_orders_generated += result["orders_generated"]
                        successful_instances += 1
                        logger.info(
                            f"Instance {i} completed: {result['orders_generated']} orders "
                            f"in {result['duration_ms']} ms"
                        )
                    except Exception as e:
                        failed_instances += 1
                        logger.error(f"Instance {i} failed: {e}", exc_info=True)
                
                logger.info("=== Parallel Streaming Completed ===")
                logger.info(
                    f"Successful instances: {successful_instances}/{num_instances}"
                )
                logger.info(f"Failed instances: {failed_instances}")
                logger.info(f"Total orders generated: {total_orders_generated}")
                
                if failed_instances > 0:
                    sys.exit(1)
                    
        except Exception as e:
            logger.error("Orchestrator error", exc_info=True)
            sys.exit(1)

    @staticmethod
    def _run_streaming_instance(
        instance_id: int,
        num_orders: int,
        customer_id_start: int,
        customer_id_end: int,
        config: ConfigManager,
    ) -> dict:
        logger.info(
            f"Instance {instance_id} starting: {num_orders} orders, "
            f"customers {customer_id_start}-{customer_id_end}"
        )
        
        start_time = time.time()
        streaming_manager = None
        
        try:
            streaming_manager = SnowpipeStreamingManager(config, instance_id)
            app = PartitionedStreamingApp(
                config, streaming_manager, customer_id_start, customer_id_end
            )
            
            app.generate_and_stream_orders(num_orders)
            
            time.sleep(2)
            
            duration_ms = int((time.time() - start_time) * 1000)
            return {
                "instance_id": instance_id,
                "orders_generated": num_orders,
                "duration_ms": duration_ms,
                "success": True,
            }
            
        except Exception as e:
            logger.error(f"Instance {instance_id} error: {e}", exc_info=True)
            duration_ms = int((time.time() - start_time) * 1000)
            return {
                "instance_id": instance_id,
                "orders_generated": 0,
                "duration_ms": duration_ms,
                "success": False,
            }
        finally:
            if streaming_manager is not None:
                streaming_manager.close()

    @staticmethod
    def _get_max_customer_id(config: ConfigManager) -> int:
        temp_manager = None
        try:
            temp_manager = SnowpipeStreamingManager(config, -1)
            return temp_manager.get_max_customer_id()
        finally:
            if temp_manager is not None:
                temp_manager.close()


class PartitionedStreamingApp:
    def __init__(
        self,
        config: ConfigManager,
        streaming_manager: SnowpipeStreamingManager,
        customer_id_start: int,
        customer_id_end: int,
    ):
        self.config = config
        self.streaming_manager = streaming_manager
        self.customer_id_start = customer_id_start
        self.customer_id_end = customer_id_end

    def generate_and_stream_orders(self, num_orders: int) -> None:
        logger.info(
            f"Starting partitioned streaming: {num_orders} orders, "
            f"customer range {self.customer_id_start}-{self.customer_id_end}"
        )
        
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
                    customer_id = DataGenerator.random_customer_id_in_range(
                        self.customer_id_start, self.customer_id_end
                    )
                    order = DataGenerator.generate_order(customer_id)
                    order_batch.append(order)
                    
                    item_count = DataGenerator.random_item_count()
                    order_items = DataGenerator.generate_order_items(
                        order.order_id, item_count
                    )
                    all_order_items.extend(order_items)
                
                self.streaming_manager.insert_orders(order_batch)
                self.streaming_manager.insert_order_items(all_order_items)
                
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
        
        logger.info(
            f"Successfully streamed {num_orders} orders "
            f"(customer range: {self.customer_id_start}-{self.customer_id_end})"
        )


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            "Usage: python parallel_streaming_orchestrator.py <total_orders> <num_parallel_instances> [config_file] [profile_file]"
        )
        print("Example: python parallel_streaming_orchestrator.py 1000000 5")
        print("Example: python parallel_streaming_orchestrator.py 100000 5 config_staging.properties profile_staging.json")
        sys.exit(1)
    
    total_orders = int(sys.argv[1])
    num_instances = int(sys.argv[2])
    config_file = sys.argv[3] if len(sys.argv) > 3 else "config.properties"
    profile_file = sys.argv[4] if len(sys.argv) > 4 else "profile.json"
    
    ParallelStreamingOrchestrator.main(total_orders, num_instances, config_file, profile_file)
