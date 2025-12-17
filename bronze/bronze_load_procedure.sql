CREATE OR ALTER PROCEDURE bronze.load_bronze AS 
BEGIN 
  DECLARE @start_time DATETIME, @end_time DATETIME
  SET @start_time = GETDATE()
  BEGIN TRY
    TRUNCATE TABLE Bronze.crm_raw; ---- OVERWRITE THE TABLE FIRST BEFORE INSERTING DATA
	PRINT'>>>Inserting table:Bronze.crm_raw<<<';
	BULK INSERT Bronze.crm_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\crm_raw.csv'
	WITH (
		   FIRSTROW = 2,
		   FIELDTERMINATOR= ',',
		   TABLOCK
		);
	TRUNCATE TABLE bronze.pos_raw
	PRINT'>>>Inserting table:bronze.pos_raw<<<';
	BULK INSERT bronze.pos_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\pos_raw.csv'
	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
		);
	TRUNCATE TABLE bronze.stores_raw
	PRINT'>>>Inserting table:bronze.stores_raw<<<';
	BULK INSERT bronze.stores_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\stores_raw.csv'
	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
		);

    PRINT'>>>Truncating table:bronze.gis_counties_raw';
	PRINT'==============================================================';
	TRUNCATE TABLE bronze.gis_counties_raw
	PRINT'>>>Inserting table:bronze.gis_counties_raw';
	BULK INSERT bronze.gis_counties_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\gis_counties_raw.csv'
	WITH (
		 FIRSTROW = 2,
		 FIELDTERMINATOR= ',',
		  CODEPAGE = '65001',
		 TABLOCK
	);
	TRUNCATE TABLE bronze.economic_raw
	PRINT'>>>Inserting table:bronze.economic_raw<<<'
	BULK INSERT bronze.economic_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\economic_raw.csv'
	WITH (
	   FIRSTROW= 2,
	   FIELDTERMINATOR= ',',
	   TABLOCK
	   );
	TRUNCATE TABLE bronze.competitor_stores_raw
	PRINT'>>>Inserting table:bronze.competitor_stores_raw<<<'
	BULK INSERT bronze.competitor_stores_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\competitor_stores_raw.csv'
	WITH (
		FIRSTROW= 2,
		FIELDTERMINATOR= ',',
		TABLOCK
		);

   	TRUNCATE TABLE bronze.gis_locations_raw
	PRINT'>>>Inserting table:bronze.gis_locations_raw<<<'
	BULK INSERT bronze.gis_locations_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\gis_locations_raw.csv'
	WITH (
		FIRSTROW= 2,
		FIELDTERMINATOR= ',',
		TABLOCK
		);
	TRUNCATE TABLE bronze.competitors_raw
	PRINT'>>>Inserting table:bronze.competitors_raw<<<'
	BULK INSERT bronze.competitors_raw
	FROM 'C:\Users\HomePC\Desktop\data science\Market Basket Analysis\bronze\competitors_raw.csv'
	WITH (
		FIRSTROW= 2,
		FIELDTERMINATOR= ',',
		TABLOCK
		);
 SET @end_time = GETDATE()
 PRINT'>>>Total duration'+ CAST (DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
 END TRY
 BEGIN CATCH
 PRINT'========================================================';
 PRINT'------------ERROR OCCURED WHILE LOADING DATA------------';
 PRINT'ERROR MESSAGE' + ERROR_MESSAGE() + '--------------------';
 PRINT'========================================================';
 END CATCH
END
