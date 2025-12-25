package com.snowflake.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayInputStream;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

/**
 * Reconciliation utilities for cleaning up orphaned records after Snowpipe Streaming ingestion.
 * Handles atomicity violations that may occur due to backpressure or other transient errors.
 */
public class ReconciliationManager {
    private static final Logger logger = LoggerFactory.getLogger(ReconciliationManager.class);
    private final ConfigManager config;

    public ReconciliationManager(ConfigManager config) {
        this.config = config;
    }

    /**
     * Create a Snowflake JDBC connection for running SQL queries.
     */
    private Connection getConnection() throws Exception {
        String privateKeyPem = config.getPrivateKey();
        
        // Remove header/footer and whitespace
        String privateKeyContent = privateKeyPem
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
        
        // Decode base64
        byte[] keyBytes = Base64.getDecoder().decode(privateKeyContent);
        
        // Generate private key
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(keyBytes);
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        PrivateKey privateKey = keyFactory.generatePrivate(keySpec);
        
        // Build connection URL
        String url = String.format(
            "jdbc:snowflake://%s.snowflakecomputing.com",
            config.getSnowflakeAccount()
        );
        
        // Set connection properties
        Properties props = new Properties();
        props.put("user", config.getSnowflakeUser());
        props.put("role", "SNOWFLAKE_INTELLIGENCE_ADMIN");
        props.put("warehouse", config.getWarehouse());
        props.put("db", config.getDatabase());
        props.put("schema", config.getSchema());
        props.put("privateKey", privateKey);
        
        return DriverManager.getConnection(url, props);
    }

    /**
     * Check for orphaned records and clean them up.
     * Returns statistics about what was found and deleted.
     */
    public Map<String, Long> reconcileAndCleanup() {
        logger.info("Starting reconciliation and cleanup...");
        
        Map<String, Long> stats = new HashMap<>();
        stats.put("orphanedOrdersFound", 0L);
        stats.put("orphanedOrdersDeleted", 0L);
        stats.put("orphanedItemsFound", 0L);
        stats.put("orphanedItemsDeleted", 0L);
        stats.put("finalOrdersCount", 0L);
        stats.put("finalItemsCount", 0L);
        
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            
            String database = config.getDatabase();
            String schema = config.getSchema();
            
            // Get table names based on schema
            String ordersTable = schema.equalsIgnoreCase("STAGING") ? "ORDERS_STAGING" : "ORDERS";
            String orderItemsTable = schema.equalsIgnoreCase("STAGING") ? "ORDER_ITEMS_STAGING" : "ORDER_ITEMS";
            
            // 1. Check for orphaned orders (orders without order_items)
            logger.info("Checking for orphaned orders...");
            String checkOrphanedOrdersSql = String.format(
                "SELECT COUNT(DISTINCT o.order_id) " +
                "FROM %s.%s.%s o " +
                "LEFT JOIN %s.%s.%s oi ON o.order_id = oi.order_id " +
                "WHERE oi.order_id IS NULL",
                database, schema, ordersTable,
                database, schema, orderItemsTable
            );
            
            ResultSet rs = stmt.executeQuery(checkOrphanedOrdersSql);
            if (rs.next()) {
                stats.put("orphanedOrdersFound", rs.getLong(1));
            }
            rs.close();
            
            if (stats.get("orphanedOrdersFound") > 0) {
                logger.warn("Found {} orphaned orders. Deleting...", 
                    String.format("%,d", stats.get("orphanedOrdersFound")));
                
                String deleteOrphanedOrdersSql = String.format(
                    "DELETE FROM %s.%s.%s " +
                    "WHERE order_id IN (" +
                    "  SELECT o.order_id " +
                    "  FROM %s.%s.%s o " +
                    "  LEFT JOIN %s.%s.%s oi ON o.order_id = oi.order_id " +
                    "  WHERE oi.order_id IS NULL" +
                    ")",
                    database, schema, ordersTable,
                    database, schema, ordersTable,
                    database, schema, orderItemsTable
                );
                
                int deletedOrders = stmt.executeUpdate(deleteOrphanedOrdersSql);
                stats.put("orphanedOrdersDeleted", (long) deletedOrders);
                logger.info("Deleted {} orphaned orders", String.format("%,d", deletedOrders));
            } else {
                logger.info("✓ No orphaned orders found");
            }
            
            // 2. Check for orphaned order_items (order_items without orders)
            logger.info("Checking for orphaned order_items...");
            String checkOrphanedItemsSql = String.format(
                "SELECT COUNT(DISTINCT oi.order_item_id) " +
                "FROM %s.%s.%s oi " +
                "LEFT JOIN %s.%s.%s o ON oi.order_id = o.order_id " +
                "WHERE o.order_id IS NULL",
                database, schema, orderItemsTable,
                database, schema, ordersTable
            );
            
            rs = stmt.executeQuery(checkOrphanedItemsSql);
            if (rs.next()) {
                stats.put("orphanedItemsFound", rs.getLong(1));
            }
            rs.close();
            
            if (stats.get("orphanedItemsFound") > 0) {
                logger.warn("Found {} orphaned order_items. Deleting...", 
                    String.format("%,d", stats.get("orphanedItemsFound")));
                
                String deleteOrphanedItemsSql = String.format(
                    "DELETE FROM %s.%s.%s " +
                    "WHERE order_id IN (" +
                    "  SELECT oi.order_id " +
                    "  FROM %s.%s.%s oi " +
                    "  LEFT JOIN %s.%s.%s o ON oi.order_id = o.order_id " +
                    "  WHERE o.order_id IS NULL" +
                    ")",
                    database, schema, orderItemsTable,
                    database, schema, orderItemsTable,
                    database, schema, ordersTable
                );
                
                int deletedItems = stmt.executeUpdate(deleteOrphanedItemsSql);
                stats.put("orphanedItemsDeleted", (long) deletedItems);
                logger.info("Deleted {} orphaned order_items", String.format("%,d", deletedItems));
            } else {
                logger.info("✓ No orphaned order_items found");
            }
            
            // 3. Get final counts
            rs = stmt.executeQuery(String.format("SELECT COUNT(*) FROM %s.%s.%s", 
                database, schema, ordersTable));
            if (rs.next()) {
                stats.put("finalOrdersCount", rs.getLong(1));
            }
            rs.close();
            
            rs = stmt.executeQuery(String.format("SELECT COUNT(*) FROM %s.%s.%s", 
                database, schema, orderItemsTable));
            if (rs.next()) {
                stats.put("finalItemsCount", rs.getLong(1));
            }
            rs.close();
            
            // Log summary
            logger.info("=== Reconciliation Summary ===");
            logger.info("Orphaned orders found: {}", String.format("%,d", stats.get("orphanedOrdersFound")));
            logger.info("Orphaned orders deleted: {}", String.format("%,d", stats.get("orphanedOrdersDeleted")));
            logger.info("Orphaned items found: {}", String.format("%,d", stats.get("orphanedItemsFound")));
            logger.info("Orphaned items deleted: {}", String.format("%,d", stats.get("orphanedItemsDeleted")));
            logger.info("Final orders count: {}", String.format("%,d", stats.get("finalOrdersCount")));
            logger.info("Final order_items count: {}", String.format("%,d", stats.get("finalItemsCount")));
            
            if (stats.get("orphanedOrdersFound") == 0 && stats.get("orphanedItemsFound") == 0) {
                logger.info("✅ Data is consistent - no orphaned records found");
            } else {
                logger.info("✅ Reconciliation completed - data is now consistent");
            }
            
        } catch (Exception e) {
            logger.error("Reconciliation failed", e);
            throw new RuntimeException("Reconciliation failed", e);
        }
        
        return stats;
    }
}
