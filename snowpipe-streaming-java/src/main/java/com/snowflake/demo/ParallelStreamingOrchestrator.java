package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

public class ParallelStreamingOrchestrator {
    private static final Logger logger = LoggerFactory.getLogger(ParallelStreamingOrchestrator.class);

    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: java ParallelStreamingOrchestrator <total_orders> <num_parallel_instances>");
            System.err.println("Example: java ParallelStreamingOrchestrator 1000000 5");
            System.exit(1);
        }

        int totalOrders = Integer.parseInt(args[0]);
        int numInstances = Integer.parseInt(args[1]);

        logger.info("=== Parallel Streaming Orchestrator ===");
        logger.info("Total orders to generate: {}", totalOrders);
        logger.info("Number of parallel instances: {}", numInstances);

        ConfigManager config = null;
        ExecutorService executorService = Executors.newFixedThreadPool(numInstances);
        List<Future<StreamingResult>> futures = new ArrayList<>();

        try {
            config = new ConfigManager("config.properties", "profile.json");
            int maxCustomerId = getMaxCustomerId(config);
            
            logger.info("Total customers available: {}", maxCustomerId);
            
            int ordersPerInstance = totalOrders / numInstances;
            int customerRangeSize = maxCustomerId / numInstances;

            for (int i = 0; i < numInstances; i++) {
                int instanceId = i;
                int ordersForThisInstance = (i == numInstances - 1) 
                    ? totalOrders - (ordersPerInstance * i) 
                    : ordersPerInstance;
                
                int customerIdStart = (i * customerRangeSize) + 1;
                int customerIdEnd = (i == numInstances - 1) 
                    ? maxCustomerId 
                    : (i + 1) * customerRangeSize;

                logger.info("Instance {}: {} orders, customer IDs {}-{}", 
                           instanceId, ordersForThisInstance, customerIdStart, customerIdEnd);

                final ConfigManager finalConfig = config;
                Callable<StreamingResult> task = () -> {
                    return runStreamingInstance(instanceId, ordersForThisInstance, 
                                               customerIdStart, customerIdEnd, finalConfig);
                };
                
                futures.add(executorService.submit(task));
            }

            logger.info("All {} instances submitted. Waiting for completion...", numInstances);

            int totalOrdersGenerated = 0;
            int successfulInstances = 0;
            int failedInstances = 0;

            for (int i = 0; i < futures.size(); i++) {
                try {
                    StreamingResult result = futures.get(i).get();
                    if (result.success) {
                        totalOrdersGenerated += result.ordersGenerated;
                        successfulInstances++;
                        logger.info("Instance {} completed: {} orders in {} ms", 
                                   result.instanceId, result.ordersGenerated, result.durationMs);
                    } else {
                        failedInstances++;
                        logger.error("Instance {} failed with {} orders generated before failure", 
                                   result.instanceId, result.ordersGenerated);
                    }
                } catch (Exception e) {
                    failedInstances++;
                    logger.error("Instance {} failed with exception: {}", i, e.getMessage(), e);
                }
            }

            logger.info("=== Parallel Streaming Completed ===");
            logger.info("Successful instances: {}/{}", successfulInstances, numInstances);
            logger.info("Failed instances: {}", failedInstances);
            logger.info("Total orders generated: {}", totalOrdersGenerated);

            if (failedInstances > 0) {
                System.exit(1);
            }

        } catch (Exception e) {
            logger.error("Orchestrator error", e);
            System.exit(1);
        } finally {
            executorService.shutdown();
            try {
                if (!executorService.awaitTermination(60, TimeUnit.SECONDS)) {
                    executorService.shutdownNow();
                }
            } catch (InterruptedException e) {
                executorService.shutdownNow();
            }
        }
    }

    private static StreamingResult runStreamingInstance(
            int instanceId, 
            int numOrders, 
            int customerIdStart, 
            int customerIdEnd,
            ConfigManager config) {
        
        logger.info("Instance {} starting: {} orders, customers {}-{}", 
                   instanceId, numOrders, customerIdStart, customerIdEnd);
        
        long startTime = System.currentTimeMillis();
        SnowpipeStreamingManager streamingManager = null;
        int ordersGenerated = 0;
        
        try {
            streamingManager = new SnowpipeStreamingManager(config, instanceId);
            PartitionedStreamingApp app = new PartitionedStreamingApp(
                config, streamingManager, customerIdStart, customerIdEnd);
            
            ordersGenerated = app.generateAndStreamOrders(numOrders);
            
            Thread.sleep(2000);
            
            long duration = System.currentTimeMillis() - startTime;
            return new StreamingResult(instanceId, ordersGenerated, duration, true);
            
        } catch (Exception e) {
            logger.error("Instance {} error: {}", instanceId, e.getMessage(), e);
            long duration = System.currentTimeMillis() - startTime;
            return new StreamingResult(instanceId, ordersGenerated, duration, false);
        } finally {
            if (streamingManager != null) {
                streamingManager.close();
            }
        }
    }

    private static int getMaxCustomerId(ConfigManager config) throws Exception {
        SnowpipeStreamingManager tempManager = null;
        try {
            tempManager = new SnowpipeStreamingManager(config, -1);
            return tempManager.getMaxCustomerId();
        } finally {
            if (tempManager != null) {
                tempManager.close();
            }
        }
    }

    static class StreamingResult {
        int instanceId;
        int ordersGenerated;
        long durationMs;
        boolean success;

        StreamingResult(int instanceId, int ordersGenerated, long durationMs, boolean success) {
            this.instanceId = instanceId;
            this.ordersGenerated = ordersGenerated;
            this.durationMs = durationMs;
            this.success = success;
        }
    }
}

class PartitionedStreamingApp {
    private static final Logger logger = LoggerFactory.getLogger(PartitionedStreamingApp.class);

    private final ConfigManager config;
    private final SnowpipeStreamingManager streamingManager;
    private final int customerIdStart;
    private final int customerIdEnd;

    public PartitionedStreamingApp(ConfigManager config, SnowpipeStreamingManager streamingManager,
                                   int customerIdStart, int customerIdEnd) {
        this.config = config;
        this.streamingManager = streamingManager;
        this.customerIdStart = customerIdStart;
        this.customerIdEnd = customerIdEnd;
    }

    public int generateAndStreamOrders(int numOrders) throws Exception {
        logger.info("Starting partitioned streaming: {} orders, customer range {}-{}", 
                   numOrders, customerIdStart, customerIdEnd);

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
                        int customerId = DataGenerator.randomCustomerIdInRange(customerIdStart, customerIdEnd);
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

        logger.info("Successfully streamed {} orders (customer range: {}-{})", 
                   numOrders, customerIdStart, customerIdEnd);
        
        return processedOrders;
    }
}
