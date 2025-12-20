BEGIN TRANSACTION;

------------------------------------------------------------
-- 1. Declare variables
------------------------------------------------------------
DECLARE @total_rows INT;
DECLARE @current_anonymous INT;
DECLARE @target_anonymous INT;
DECLARE @rows_to_update INT;

------------------------------------------------------------
-- 2. Calculate row counts
------------------------------------------------------------
SELECT @total_rows = COUNT(*)
FROM bronze.pos_raw;

SELECT @current_anonymous = COUNT(*)
FROM bronze.pos_raw
WHERE customer_id = 'ANONYMOUS';

SET @target_anonymous = CAST(@total_rows * 0.05 AS INT);

SET @rows_to_update =
    CASE
        WHEN @current_anonymous > @target_anonymous
            THEN @current_anonymous - @target_anonymous
        ELSE 0
    END;

------------------------------------------------------------
-- 3. Update ONLY the excess ANONYMOUS rows
------------------------------------------------------------
IF @rows_to_update > 0
BEGIN
    ;WITH ToFix AS (
        SELECT TOP (@rows_to_update)
            transaction_id
        FROM bronze.pos_raw
        WHERE customer_id = 'ANONYMOUS'
        ORDER BY NEWID()  -- random selection
    )
    UPDATE b
    SET customer_id =
        'CUST_2023' +
        RIGHT(
            '000000' +
            CAST(ABS(CHECKSUM(NEWID())) % 1000000 AS VARCHAR(6)),
            6
        )
    FROM bronze.pos_raw b
    INNER JOIN ToFix t
        ON b.transaction_id = t.transaction_id;
END;

------------------------------------------------------------
-- 4. Validation (DO NOT SKIP)
------------------------------------------------------------
SELECT
    COUNT(*) AS anonymous_rows,
    CAST(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM bronze.pos_raw)
        AS DECIMAL(5,2)
    ) AS anonymous_percentage
FROM bronze.pos_raw
WHERE customer_id = 'ANONYMOUS';

------------------------------------------------------------
-- 5. Commit or rollback
------------------------------------------------------------
-- COMMIT TRANSACTION;
-- ROLLBACK TRANSACTION;

SELECT COUNT(customer_id) from bronze.pos_raw
where  customer_id = 'ANONYMOUS'
