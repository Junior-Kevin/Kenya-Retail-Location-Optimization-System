
CREATE VIEW gold.dim_county AS 
WITH econ AS (
    SELECT
        county,
        AVG(unemployment_rate) AS avg_unemployment_rate,
        AVG(inflation_rate) AS avg_inflation_rate,
        AVG(retail_sales_index) AS avg_retail_sales_index
    FROM silver.economic
    GROUP BY county
)
SELECT
    gc.county_id,
    gc.county_name,
    gc.population_2023,
    gc.population_density_psqkm,
    gc.urbanization_rate,
    gc.avg_household_income_kes,
    econ.avg_unemployment_rate,
    econ.avg_inflation_rate,
    econ.avg_retail_sales_index,

    (
        gc.road_infrastructure_score * 0.4 +
        gc.internet_penetration * 0.3 +
        gc.public_transport_score * 0.3
    ) AS infrastructure_score

FROM silver.gis_counties gc
LEFT JOIN econ
    ON gc.county_name = econ.county;








