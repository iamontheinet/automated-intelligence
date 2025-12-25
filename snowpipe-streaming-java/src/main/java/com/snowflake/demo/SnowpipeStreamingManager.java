package com.snowflake.demo;

import com.snowflake.ingest.streaming.SnowflakeStreamingIngestChannel;
import com.snowflake.ingest.streaming.SnowflakeStreamingIngestClient;
import com.snowflake.ingest.streaming.SnowflakeStreamingIngestClientFactory;
import com.snowflake.ingest.streaming.OpenChannelResult;
import com.snowflake.ingest.utils.SFException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.stream.Collectors;

public class SnowpipeStreamingManager {
    private static final Logger logger = LoggerFactory.getLogger(SnowpipeStreamingManager.class);

    private final SnowflakeStreamingIngestClient ordersClient;
    private final SnowflakeStreamingIngestClient orderItemsClient;
    private final SnowflakeStreamingIngestChannel ordersChannel;
    private final SnowflakeStreamingIngestChannel orderItemsChannel;
    private final ConfigManager config;
    private final Properties connectionProps;

    public SnowpipeStreamingManager(ConfigManager config) throws Exception {
        this(config, -1);
    }

    public SnowpipeStreamingManager(ConfigManager config, int instanceId) throws Exception {
        this.config = config;

        this.connectionProps = new Properties();
        connectionProps.put("account", config.getSnowflakeAccount());
        connectionProps.put("user", config.getSnowflakeUser());
        connectionProps.put("url", config.getSnowflakeUrl());
        connectionProps.put("private_key", config.getPrivateKey());
        connectionProps.put("role", "SNOWFLAKE_INTELLIGENCE_ADMIN");
        connectionProps.put("warehouse", config.getWarehouse());
        connectionProps.put("db", config.getDatabase());
        connectionProps.put("schema", config.getSchema());

        String channelSuffix = (instanceId >= 0) ? "_instance_" + instanceId : "";
        logger.info("Creating Snowflake Streaming clients and opening channels{}", 
                   instanceId >= 0 ? " for instance " + instanceId : "...");
        
        this.ordersClient = SnowflakeStreamingIngestClientFactory.builder(
                "ORDERS_CLIENT_" + java.util.UUID.randomUUID(),
                config.getDatabase(),
                config.getSchema(),
                config.getProperty("pipe.orders.name")
        )
                .setProperties(connectionProps)
                .build();
        
        this.orderItemsClient = SnowflakeStreamingIngestClientFactory.builder(
                "ORDER_ITEMS_CLIENT_" + java.util.UUID.randomUUID(),
                config.getDatabase(),
                config.getSchema(),
                config.getProperty("pipe.order_items.name")
        )
                .setProperties(connectionProps)
                .build();

        this.ordersChannel = openChannel(
                ordersClient,
                config.getProperty("channel.orders.name") + channelSuffix
        );

        this.orderItemsChannel = openChannel(
                orderItemsClient,
                config.getProperty("channel.order_items.name") + channelSuffix
        );

        logger.info("All clients and channels initialized successfully");
    }

    private SnowflakeStreamingIngestChannel openChannel(SnowflakeStreamingIngestClient client, String channelName) throws Exception {
        String initialOffset = "0";
        OpenChannelResult result = client.openChannel(channelName, initialOffset);
        SnowflakeStreamingIngestChannel channel = result.getChannel();
        
        String latestOffset = channel.getLatestCommittedOffsetToken();
        logger.info("Channel {} opened. Latest committed offset: {}", channelName, 
                    latestOffset != null ? latestOffset : "NULL (new channel)");
        
        return channel;
    }

    private PrivateKey parsePrivateKey(String privateKeyPEM) throws Exception {
        String privateKeyPEMClean = privateKeyPEM
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
        
        byte[] encoded = Base64.getDecoder().decode(privateKeyPEMClean);
        PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(encoded);
        KeyFactory kf = KeyFactory.getInstance("RSA");
        return kf.generatePrivate(keySpec);
    }

    public int getMaxCustomerId() throws Exception {
        String jdbcUrl = config.getSnowflakeUrl().replace(":443", "").replace("https://", "jdbc:snowflake://");
        
        Properties jdbcProps = new Properties();
        jdbcProps.put("account", config.getSnowflakeAccount());
        jdbcProps.put("user", config.getSnowflakeUser());
        jdbcProps.put("role", "SNOWFLAKE_INTELLIGENCE_ADMIN");
        jdbcProps.put("warehouse", config.getWarehouse());
        jdbcProps.put("db", config.getDatabase());
        jdbcProps.put("schema", config.getSchema());
        
        PrivateKey privateKey = parsePrivateKey(config.getPrivateKey());
        jdbcProps.put("privateKey", privateKey);
        
        int maxId = 1;
        try (Connection conn = DriverManager.getConnection(jdbcUrl, jdbcProps);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT MAX(CUSTOMER_ID) as MAX_ID FROM " + 
                                            config.getDatabase() + "." + 
                                            config.getSchema() + ".CUSTOMERS")) {
            if (rs.next()) {
                maxId = rs.getInt("MAX_ID");
            }
            logger.info("Max customer ID in database: {}", maxId);
        }
        
        return maxId;
    }

    public void insertOrder(Order order) throws Exception {
        Map<String, Object> row = order.toMap();
        String offsetToken = "order_" + order.getOrderId();
        
        ordersChannel.appendRow(row, offsetToken);
        logger.debug("Order {} inserted with offset {}", order.getOrderId(), offsetToken);
    }

    public void insertOrders(List<Order> orders) throws Exception {
        if (orders.isEmpty()) {
            return;
        }
        
        String startOffset = "order_" + orders.get(0).getOrderId();
        String endOffset = "order_" + orders.get(orders.size() - 1).getOrderId();
        
        List<Map<String, Object>> rows = orders.stream()
                .map(Order::toMap)
                .collect(Collectors.toList());
        
        insertWithBackpressureRetry(ordersChannel, rows, startOffset, endOffset, "orders");
        logger.debug("Inserted {} orders (offset range: {} to {})", 
                    orders.size(), startOffset, endOffset);
    }

    public void insertOrderItems(List<OrderItem> items) throws Exception {
        if (items.isEmpty()) {
            return;
        }
        
        String startOffset = "item_" + items.get(0).getOrderItemId();
        String endOffset = "item_" + items.get(items.size() - 1).getOrderItemId();
        
        List<Map<String, Object>> rows = items.stream()
                .map(OrderItem::toMap)
                .collect(Collectors.toList());
        
        insertWithBackpressureRetry(orderItemsChannel, rows, startOffset, endOffset, "order_items");
        logger.debug("Inserted {} order items (offset range: {} to {})", 
                    items.size(), startOffset, endOffset);
    }

    /**
     * Insert rows with exponential backoff retry for ReceiverSaturated errors.
     * 
     * @param channel The streaming channel to insert into
     * @param rows Data rows to insert
     * @param startOffset Starting offset token
     * @param endOffset Ending offset token
     * @param dataType Description of data type (for logging)
     */
    private void insertWithBackpressureRetry(
            SnowflakeStreamingIngestChannel channel,
            List<Map<String, Object>> rows,
            String startOffset,
            String endOffset,
            String dataType) throws Exception {
        
        int maxRetries = 5;
        double delay = 1.0;  // Initial delay in seconds
        double maxDelay = 30.0;
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
            try {
                channel.appendRows(rows, startOffset, endOffset);
                
                if (attempt > 0) {
                    logger.info("Successfully inserted {} {} after {} attempts",
                               rows.size(), dataType, attempt + 1);
                }
                return;
                
            } catch (SFException e) {
                String errorMsg = e.getMessage();
                
                // Check for ReceiverSaturated (HTTP 429) backpressure errors
                if (errorMsg.contains("ReceiverSaturated") || errorMsg.contains("429")) {
                    if (attempt < maxRetries - 1) {
                        logger.warn("Backpressure detected for {} (attempt {}/{}): " +
                                   "Channel buffers full. Retrying in {:.1f}s...",
                                   dataType, attempt + 1, maxRetries, delay);
                        Thread.sleep((long) (delay * 1000));
                        delay = Math.min(delay * 2, maxDelay);  // Exponential backoff
                        continue;
                    } else {
                        logger.error("Failed to insert {} {} after {} attempts: " +
                                    "Channel buffers remain saturated",
                                    rows.size(), dataType, maxRetries);
                        throw e;
                    }
                } else {
                    // Non-backpressure error, re-throw immediately
                    logger.error("Unexpected error inserting {}: {}", dataType, errorMsg);
                    throw e;
                }
            } catch (Exception e) {
                logger.error("Unexpected error type inserting {}: {}", dataType, e.getMessage());
                throw e;
            }
        }
    }

    public String getLatestOrderOffset() {
        return ordersChannel.getLatestCommittedOffsetToken();
    }

    public String getLatestOrderItemOffset() {
        return orderItemsChannel.getLatestCommittedOffsetToken();
    }

    public void close() {
        try {
            logger.info("Closing channels...");
            if (ordersChannel != null) ordersChannel.close();
            if (orderItemsChannel != null) orderItemsChannel.close();
            
            logger.info("Closing clients...");
            if (ordersClient != null) ordersClient.close();
            if (orderItemsClient != null) orderItemsClient.close();
            
            logger.info("Snowpipe Streaming manager closed successfully");
        } catch (Exception e) {
            logger.error("Error closing Snowpipe Streaming manager", e);
        }
    }
}
