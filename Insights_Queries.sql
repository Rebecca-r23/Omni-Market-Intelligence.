USE OmniMI;
GO

-- 1. Revenue by Channel (Which platform makes the most money?)
SELECT 
    channel, 
    SUM(total_amount) AS total_revenue,
    COUNT(transaction_id) AS total_orders
FROM dbo.transactions
GROUP BY channel
ORDER BY total_revenue DESC;

-- 2. Competitor Price Gap (Are we more expensive than rivals?)
SELECT 
    p.product_name,
    p.current_price AS our_price,
    m.competitor_name,
    m.competitor_price,
    (p.current_price - m.competitor_price) AS price_difference
FROM dbo.products p
JOIN dbo.market_trends m ON p.product_id = m.product_id;

-- 3. Customer Loyalty Breakdown (How many VIPs do we have?)
SELECT 
    loyalty_tier, 
    COUNT(customer_id) AS customer_count
FROM dbo.customers
GROUP BY loyalty_tier;
