DROP TABLE IF EXISTS gold.customer_value;
GO

WITH pos_agg AS (
    SELECT
        p.customer_id,

        COUNT(DISTINCT p.transaction_id) AS total_transactions,
        SUM(p.final_price_kes) AS total_spend_kes,
        AVG(p.final_price_kes) AS avg_transaction_value_kes,

        MAX(p.transaction_date) AS last_purchase_date,

        -- Payment method ratios
        AVG(CASE WHEN p.payment_method = 'M-Pesa' THEN 1.0 ELSE 0.0 END) AS mpesa_ratio,
        AVG(CASE WHEN p.payment_method = 'Cash' THEN 1.0 ELSE 0.0 END) AS cash_ratio,
        AVG(CASE WHEN p.payment_method = 'Card' THEN 1.0 ELSE 0.0 END) AS card_ratio
    FROM silver.pos p
    WHERE p.customer_id <> 'ANONYMOUS'
    GROUP BY p.customer_id
),

customer_base AS (
    SELECT
        c.customer_id,
        c.county AS primary_county,
        c.customer_segment,
        c.preferred_store_format,
        c.registration_date,
        c.feedback_score,
        c.purchase_frequency_monthly,
        c.lifetime_value_kes
    FROM silver.crm c
),

joined AS (
    SELECT
        cb.customer_id,
        cb.primary_county,
        cb.customer_segment,
        cb.preferred_store_format,

        pa.total_spend_kes,
        pa.avg_transaction_value_kes,
        cb.lifetime_value_kes,

        pa.total_transactions,
        cb.purchase_frequency_monthly,

        DATEDIFF(DAY, pa.last_purchase_date, GETDATE()) AS days_since_last_purchase,
        DATEDIFF(MONTH, cb.registration_date, GETDATE()) AS customer_tenure_months,

        cb.feedback_score,

        pa.mpesa_ratio,
        pa.cash_ratio,
        pa.card_ratio
    FROM customer_base cb
    JOIN pos_agg pa
        ON cb.customer_id = pa.customer_id
),

rfm_scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY days_since_last_purchase ASC) AS recency_score,
        NTILE(5) OVER (ORDER BY total_transactions DESC) AS frequency_score,
        NTILE(5) OVER (ORDER BY total_spend_kes DESC) AS monetary_score
    FROM joined
)

SELECT
    customer_id,
    primary_county,
    customer_segment,
    preferred_store_format,

    total_spend_kes,
    avg_transaction_value_kes,
    lifetime_value_kes,

    total_transactions,
    purchase_frequency_monthly,
    days_since_last_purchase,
    customer_tenure_months,

    feedback_score,

    mpesa_ratio,
    cash_ratio,
    card_ratio,

    recency_score,
    frequency_score,
    monetary_score,

    -- Composite Customer Value Score (0–100)
    CAST(
        (
            recency_score * 0.3 +
            frequency_score * 0.3 +
            monetary_score * 0.4
        ) * 20
        AS DECIMAL(5,2)
    ) AS customer_value_score,

    -- Value tiers
    CASE
        WHEN (recency_score + frequency_score + monetary_score) >= 13 THEN 'Platinum'
        WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Gold'
        WHEN (recency_score + frequency_score + monetary_score) >= 7 THEN 'Silver'
        ELSE 'Bronze'
    END AS value_tier,

    -- Business flags
    CASE
        WHEN days_since_last_purchase > 90 THEN 1 ELSE 0
    END AS churn_risk_flag,

    CASE
        WHEN monetary_score >= 4 AND frequency_score >= 4 THEN 1 ELSE 0
    END AS high_value_flag

INTO gold.customer_value
FROM rfm_scored;
GO
