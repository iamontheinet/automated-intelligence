-- ============================================================================
-- AI/SQL Functions Examples
-- Demonstrates AI_COMPLETE, AI_SENTIMENT, AI_AGG, and Cortex Search
-- ============================================================================

USE DATABASE automated_intelligence;
USE SCHEMA raw;
USE WAREHOUSE automated_intelligence_wh;

-- ============================================================================
-- Example 1: AI_SENTIMENT - Analyze sentiment of product reviews
-- ============================================================================

SELECT 
  product_id,
  review_title,
  rating,
  SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text) AS sentiment_score,
  CASE 
    WHEN SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text) > 0.5 THEN 'Positive'
    WHEN SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text) < -0.5 THEN 'Negative'
    ELSE 'Neutral'
  END AS sentiment_label
FROM product_reviews
ORDER BY product_id, review_date DESC;


-- ============================================================================
-- Example 2: AI_AGG - Aggregate and summarize reviews by product
-- ============================================================================

SELECT 
  pc.product_name,
  pc.product_category,
  COUNT(pr.review_id) AS total_reviews,
  ROUND(AVG(pr.rating), 2) AS avg_rating,
  SNOWFLAKE.CORTEX.AI_AGG(
    pr.review_text, 
    'Summarize the key themes and sentiment from these customer reviews in 2-3 sentences.'
  ) AS review_summary
FROM product_catalog pc
LEFT JOIN product_reviews pr ON pc.product_id = pr.product_id
WHERE pr.review_text IS NOT NULL
GROUP BY pc.product_name, pc.product_category
ORDER BY avg_rating DESC;


-- ============================================================================
-- Example 3: AI_COMPLETE - Generate product recommendations
-- ============================================================================

SELECT 
  product_name,
  product_category,
  price,
  SNOWFLAKE.CORTEX.AI_COMPLETE(
    'llama3.1-70b',
    'Based on this product: ' || product_name || 
    ' in category ' || product_category || 
    ' priced at $' || price || 
    ', write a compelling 2-sentence marketing pitch for winter sports enthusiasts.'
  ) AS marketing_pitch
FROM product_catalog
WHERE product_category IN ('Skis', 'Snowboards')
LIMIT 3;


-- ============================================================================
-- Example 4: AI_COMPLETE - Classify support tickets by urgency
-- ============================================================================

SELECT 
  ticket_id,
  customer_id,
  subject,
  category,
  SNOWFLAKE.CORTEX.AI_COMPLETE(
    'llama3.1-8b',
    'Classify this support ticket urgency as "Urgent", "Normal", or "Low Priority": ' || 
    subject || ' - ' || description
  ) AS ai_urgency_classification,
  priority AS current_priority
FROM support_tickets
WHERE status = 'Open'
LIMIT 5;


-- ============================================================================
-- Example 5: AI_COMPLETE - Generate automated support responses
-- ============================================================================

SELECT 
  ticket_id,
  subject,
  description,
  SNOWFLAKE.CORTEX.AI_COMPLETE(
    'llama3.1-70b',
    'You are a customer support agent for a ski and snowboard equipment retailer. ' ||
    'Write a helpful, professional response to this customer inquiry: ' || description
  ) AS suggested_response
FROM support_tickets
WHERE status = 'Open'
LIMIT 3;


-- ============================================================================
-- Example 6: Query Cortex Search Service - Semantic product search
-- ============================================================================

-- Find products related to "backcountry skiing in deep snow"
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'automated_intelligence.raw.product_search_service',
    '{
      "query": "backcountry skiing in deep snow",
      "columns": ["product_name", "product_category", "description", "price"],
      "limit": 3
    }'
  )
)['results'] AS search_results;


-- ============================================================================
-- Example 7: AI_EXTRACT - Extract key information from reviews
-- ============================================================================

SELECT 
  product_id,
  review_title,
  SNOWFLAKE.CORTEX.AI_EXTRACT(
    review_text,
    'What are the main pros and cons mentioned in this review?'
  ) AS extracted_pros_cons
FROM product_reviews
WHERE rating IN (5, 1, 2)
LIMIT 5;


-- ============================================================================
-- Example 8: Combine AI functions - Enhanced product analytics
-- ============================================================================

WITH sentiment_analysis AS (
  SELECT 
    product_id,
    AVG(SNOWFLAKE.CORTEX.AI_SENTIMENT(review_text)) AS avg_sentiment,
    COUNT(*) AS review_count,
    AVG(rating) AS avg_rating
  FROM product_reviews
  GROUP BY product_id
)
SELECT 
  pc.product_name,
  pc.product_category,
  pc.price,
  sa.review_count,
  ROUND(sa.avg_rating, 2) AS avg_rating,
  ROUND(sa.avg_sentiment, 2) AS avg_sentiment_score,
  CASE 
    WHEN sa.avg_sentiment > 0.5 AND sa.avg_rating >= 4.5 THEN 'Top Performer'
    WHEN sa.avg_sentiment > 0 AND sa.avg_rating >= 4.0 THEN 'Strong Product'
    WHEN sa.avg_sentiment > -0.3 AND sa.avg_rating >= 3.0 THEN 'Average Product'
    ELSE 'Needs Improvement'
  END AS product_status
FROM product_catalog pc
LEFT JOIN sentiment_analysis sa ON pc.product_id = sa.product_id
ORDER BY sa.avg_sentiment DESC NULLS LAST;


-- ============================================================================
-- Example 9: AI_AGG - Aggregate support ticket insights
-- ============================================================================

SELECT 
  category,
  COUNT(*) AS ticket_count,
  SNOWFLAKE.CORTEX.AI_AGG(
    description,
    'What are the top 3 most common issues mentioned in these support tickets? List them as bullet points.'
  ) AS common_issues
FROM support_tickets
WHERE status = 'Closed'
GROUP BY category
ORDER BY ticket_count DESC;


-- ============================================================================
-- Example 10: Create view combining AI insights
-- ============================================================================

CREATE OR REPLACE VIEW product_ai_insights AS
SELECT 
  pc.product_id,
  pc.product_name,
  pc.product_category,
  pc.description,
  pc.price,
  pc.stock_quantity,
  COUNT(pr.review_id) AS total_reviews,
  ROUND(AVG(pr.rating), 2) AS avg_rating,
  ROUND(AVG(SNOWFLAKE.CORTEX.AI_SENTIMENT(pr.review_text)), 2) AS avg_sentiment_score,
  CASE 
    WHEN AVG(SNOWFLAKE.CORTEX.AI_SENTIMENT(pr.review_text)) > 0.5 THEN 'Positive'
    WHEN AVG(SNOWFLAKE.CORTEX.AI_SENTIMENT(pr.review_text)) < -0.5 THEN 'Negative'
    ELSE 'Neutral'
  END AS overall_sentiment
FROM product_catalog pc
LEFT JOIN product_reviews pr ON pc.product_id = pr.product_id
GROUP BY 
  pc.product_id,
  pc.product_name,
  pc.product_category,
  pc.description,
  pc.price,
  pc.stock_quantity;

-- Query the AI insights view
SELECT * FROM product_ai_insights
ORDER BY avg_rating DESC NULLS LAST;
