package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;

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
        while (processedOrders < numOrders) {
            int remainingOrders = numOrders - processedOrders;
            int currentBatchSize = Math.min(batchSize, remainingOrders);
            
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
                
                streamingManager.insertOrders(orderBatch);
                streamingManager.insertOrderItems(allOrderItems);
                
                processedOrders += currentBatchSize;
                logger.info("Progress: {}/{} orders streamed ({} order items)", 
                           processedOrders, numOrders, allOrderItems.size());

            } catch (Exception e) {
                logger.error("Error generating order batch at position {}: {}", processedOrders, e.getMessage(), e);
                throw e;
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
