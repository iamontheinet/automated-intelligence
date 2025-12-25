package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class AutomatedIntelligenceStreaming {
    private static final Logger logger = LoggerFactory.getLogger(AutomatedIntelligenceStreaming.class);

    private final ConfigManager config;
    private final SnowpipeStreamingManager streamingManager;

    public AutomatedIntelligenceStreaming(ConfigManager config, SnowpipeStreamingManager streamingManager) {
        this.config = config;
        this.streamingManager = streamingManager;
    }

    public void generateAndStreamOrders(int numOrders) throws Exception {
        logger.info("Starting to generate and stream {} orders", numOrders);

        int maxCustomerId = streamingManager.getMaxCustomerId();
        if (maxCustomerId == 0) {
            logger.error("No customers found in database. Please run generate_customers() stored procedure first to create customers.");
            throw new IllegalStateException("No customers available for order generation");
        }
        logger.info("Will generate orders for customer IDs in range 1-{}", maxCustomerId);

        int batchSize = config.getIntProperty("orders.batch.size", 10000);
        logger.info("Using batch size: {} orders per insertRows call", batchSize);
        
        int processedOrders = 0;
        int maxRetries = 3;
        
        while (processedOrders < numOrders) {
            int remainingOrders = numOrders - processedOrders;
            int currentBatchSize = Math.min(batchSize, remainingOrders);
            
            int retryCount = 0;
            while (retryCount <= maxRetries) {
                try {
                    List<Order> orderBatch = new ArrayList<>(currentBatchSize);
                    List<OrderItem> allOrderItems = new ArrayList<>();
                    
                    for (int i = 0; i < currentBatchSize; i++) {
                        int customerId = DataGenerator.randomCustomerId(maxCustomerId);
                        Order order = DataGenerator.generateOrder(customerId);
                        orderBatch.add(order);
                        
                        int itemCount = DataGenerator.randomItemCount();
                        List<OrderItem> orderItems = DataGenerator.generateOrderItems(order.getOrderId(), itemCount);
                        allOrderItems.addAll(orderItems);
                    }
                    
                    // Insert both orders and order_items - if either fails, both should fail
                    try {
                        streamingManager.insertOrders(orderBatch);
                    } catch (Exception e) {
                        logger.error("Failed to insert orders: {}", e.getMessage());
                        throw e;
                    }
                    
                    // Brief pause to allow order buffers to flush before inserting order_items
                    // This reduces backpressure and prevents ReceiverSaturated errors
                    Thread.sleep(100);
                    
                    try {
                        streamingManager.insertOrderItems(allOrderItems);
                    } catch (Exception e) {
                        logger.error("Failed to insert order_items after orders were inserted: {}", e.getMessage());
                        logger.warn("ATOMICITY VIOLATION: {} orders were inserted but {} order items failed. This will cause data inconsistency.",
                                   orderBatch.size(), allOrderItems.size());
                        throw e;
                    }
                    
                    // Success - break out of retry loop
                    processedOrders += currentBatchSize;
                    logger.info("Progress: {}/{} orders streamed ({} order items)", 
                               processedOrders, numOrders, allOrderItems.size());
                    break;
                    
                } catch (Exception e) {
                    retryCount++;
                    if (retryCount > maxRetries) {
                        logger.error("Failed to insert batch after {} retries at position {}: {}", 
                                   maxRetries, processedOrders, e.getMessage(), e);
                        throw e;
                    } else {
                        logger.warn("Batch insert failed (attempt {}/{}), retrying: {}", 
                                   retryCount, maxRetries, e.getMessage());
                        Thread.sleep(1000L * retryCount);  // Exponential backoff
                    }
                }
            }
        }

        logger.info("Successfully streamed {} orders", numOrders);
        printOffsetStatus();
    }

    private void printOffsetStatus() {
        logger.info("=== Offset Token Status ===");
        logger.info("Orders: {}", streamingManager.getLatestOrderOffset());
        logger.info("Order Items: {}", streamingManager.getLatestOrderItemOffset());
    }

    public static void main(String[] args) {
        logger.info("Starting Automated Intelligence Snowpipe Streaming");

        ConfigManager config = null;
        SnowpipeStreamingManager streamingManager = null;

        try {
            config = new ConfigManager("config.properties", "profile.json");
            streamingManager = new SnowpipeStreamingManager(config);

            AutomatedIntelligenceStreaming app = new AutomatedIntelligenceStreaming(config, streamingManager);

            int numOrders = config.getIntProperty("num.orders.per.batch", 100);
            
            if (args.length > 0) {
                numOrders = Integer.parseInt(args[0]);
            }

            app.generateAndStreamOrders(numOrders);

            logger.info("Waiting 5 seconds for final data flush...");
            Thread.sleep(5000);

            // Run reconciliation to clean up any orphaned records
            logger.info("\n" + "=".repeat(60));
            logger.info("Starting post-ingestion reconciliation...");
            logger.info("=".repeat(60));
            
            try {
                ReconciliationManager reconciliationManager = new ReconciliationManager(config);
                Map<String, Long> reconciliationStats = reconciliationManager.reconcileAndCleanup();
                
                // Report if any inconsistencies were found
                if (reconciliationStats.get("orphanedOrdersFound") > 0 || 
                    reconciliationStats.get("orphanedItemsFound") > 0) {
                    logger.warn(
                        "⚠️  Data inconsistencies detected and cleaned: {} orphaned orders, {} orphaned order_items",
                        String.format("%,d", reconciliationStats.get("orphanedOrdersDeleted")),
                        String.format("%,d", reconciliationStats.get("orphanedItemsDeleted"))
                    );
                } else {
                    logger.info("✅ No data inconsistencies found - ingestion was atomic");
                }
            } catch (Exception e) {
                logger.error("Reconciliation failed: {}", e.getMessage(), e);
                logger.warn("⚠️  Reconciliation failed but ingestion completed. Manual cleanup may be needed.");
            }
            
            logger.info("=".repeat(60) + "\n");

            logger.info("Application completed successfully");

        } catch (Exception e) {
            logger.error("Application error", e);
            System.exit(1);
        } finally {
            if (streamingManager != null) {
                streamingManager.close();
            }
        }
    }
}
