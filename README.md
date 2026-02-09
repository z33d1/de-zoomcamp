# Home Work 1

## Question 1. What's the version of pip in the python:3.13 image?

Commands to reproduce
```bash
docker pull python:3.13
docker run -it python:3.13 /bin/bash
pip -V
>> pip 25.3 from /usr/local/lib/python3.13/site-packages/pip (python 3.13)
```

## Question 2. Given the docker-compose.yaml, what is the hostname and port that pgadmin should use to connect to the postgres database?


## Question 3. Counting short trips

```sql
SELECT
	COUNT(*) as cnt
FROM
    green_taxi_trips 
WHERE lpep_pickup_datetime between '2025-11-01' and '2025-12-01'
AND trip_distance <= 1
```

## Question 4. Longest trip for each day

```sql
SELECT
	lpep_pickup_datetime, trip_distance
FROM
    green_taxi_trips 
WHERE trip_distance < 100
ORDER BY trip_distance DESC
LIMIT 1
```

## Question 5. Which was the pickup zone with the largest total_amount (sum of all trips) on November 18th, 2025?

```sql
SELECT
	date_trunc('day', lpep_pickup_datetime) as date,
	zpu."Zone" as pickup_zone,
	sum(trip_distance) as total_amount
FROM green_taxi_trips as t
LEFT JOIN zones as zpu
ON t."PULocationID" = zpu."LocationID"
WHERE date_trunc('day', lpep_pickup_datetime) = TIMESTAMP '2025-11-18'
-- AND trip_distance < 100
GROUP BY 1,2
ORDER BY total_amount DESC
LIMIT 1
```

## Question 6. For the passengers picked up in the zone named "East Harlem North" in November 2025, which was the drop off zone that had the largest tip?

```sql
SELECT
	lpep_pickup_datetime as pickup_dt,
	zdo."Zone" as do_zone_name,
	max(tip_amount) as tip_amount
FROM green_taxi_trips as t
LEFT JOIN zones as zpu
ON t."PULocationID" = zpu."LocationID"
LEFT JOIN zones as zdo
ON t."DOLocationID" = zdo."LocationID"
WHERE date_trunc('month', lpep_pickup_datetime) = TIMESTAMP '2025-11-01'
AND zpu."Zone" = 'East Harlem North'
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 1
```


## Misc

### Build zones ingestion image
```bash
docker build -t zones-ingestion:latest -f ./zones.Dockerfile .
```

## Build trips ingestion image
```bash
docker build -t trips-ingestion:latest -f ./trips.Dockerfile .
```

### Run zones ingestion
```bash
docker run -it \
    --network=de-zoomcamp_default \
    zones-ingestion:latest \
    --pg-user=root \
    --pg-pass=root \
    --pg-host=pgdatabase \
    --pg-port=5432 \
    --pg-db=ny_taxi \
    --target-table=zones
```

### Run trips ingestion
```bash
docker run -it \
    --network=de-zoomcamp_default \
    trips-ingestion:latest \
    --pg-user=root \
    --pg-pass=root \
    --pg-host=pgdatabase \
    --pg-port=5432 \
    --pg-db=ny_taxi \
    --target-table=yellow_taxi_trips
```

# Home Work 2

## Question 1. Within the execution for Yellow Taxi data for the year 2020 and month 12: what is the uncompressed file size (i.e. the output file yellow_tripdata_2020-12.csv of the extract task)?
To get unzipped file size add ls command after file was downloaded in extract task. [Link to the line.](./kestra/src/trips.yaml#L43)
```bash
ls -l {{render(vars.file)}}
```

<!-- ## Question 2. What is the rendered value of the variable file when the inputs taxi is set to green, year is set to 2020, and month is set to 04 during execution?
```sql
SELECT COUNT(*) as cnt
FROM public.yellow_tripdata
WHERE date_trunc('year',tpep_pickup_datetime) = TIMESTAMP '2020-01-01'
``` -->

## Question 3. How many rows are there for the Yellow Taxi data for all CSV files in the year 2020?
```sql
SELECT count(*) as cnt 
FROM public.yellow_tripdata
WHERE split_part(split_part(filename,'_',3),'-',1) = '2020'
```

## Question 4. How many rows are there for the Green Taxi data for all CSV files in the year 2020?
```sql
SELECT count(*) as cnt 
FROM public.green_tripdata
WHERE split_part(split_part(filename,'_',3),'-',1) = '2020'
```

## Question 5. How many rows are there for the Yellow Taxi data for the March 2021 CSV file?
```sql
SELECT count(*) as cnt 
FROM public.yellow_tripdata
WHERE split_part(split_part(filename,'_',3),'.',1) = '2021-03'
```

## Misc
### How to backfill 2021 data?
Utilize native Kestra backfill feature. Backfill range has to include the timestamp when cron fires.

# Home Work 3
## Misc
Execute data ingestion py script
```bash
GCS_BUCKET_NAME=XXX GCP_PROJECT_ID=XXX GCS_BUCKET_KEY=XXX uv run ingestion/load_yellow_taxi_data.py
```

## Question 1. Counting records
What is count of records for the 2024 Yellow Taxi Data?
```sql
SELECT count(*) as cnt
FROM tmp.yellow_taxi
```

## Question 4. Counting zero fare trips
```sql
SELECT count(*) as cnt
FROM tmp.yellow_taxi_table
WHERE fare_amount = 0
```

## Question 5. Partitioning and clustering
```sql
CREATE OR REPLACE TABLE `tmp.yellow_taxi_table_optim`
PARTITION BY date(tpep_dropoff_datetime)
CLUSTER BY VendorID
OPTIONS (
  require_partition_filter = TRUE,
  description = 'A yellow taxi trips table partitioned by tpep_dropoff_datetime date and clustered by VendorID'
)
AS (
  SELECT * FROM tmp.yellow_taxi
)
```


## Question 6. Partition benefits

Write a query to retrieve the distinct VendorIDs between tpep_dropoff_datetime
2024-03-01 and 2024-03-15 (inclusive)


Use the materialized table you created earlier in your from clause and note the estimated bytes. Now change the table in the from clause to the partitioned table you created for question 5 and note the estimated bytes processed. What are these values? 
```sql
-- Count on optimized table
SELECT COUNT(DISTINCT VendorID)
FROM `tmp.yellow_taxi_table_optim`
WHERE date_trunc(tpep_dropoff_datetime, DAY) >= TIMESTAMP '2024-03-01'
AND date_trunc(tpep_dropoff_datetime, DAY) <= TIMESTAMP '2024-03-15'

-- Count on nonoptimized materialized table
SELECT COUNT(DISTINCT VendorID)
FROM `tmp.yellow_taxi_table`
WHERE date_trunc(tpep_dropoff_datetime, DAY) >= TIMESTAMP '2024-03-01'
AND date_trunc(tpep_dropoff_datetime, DAY) <= TIMESTAMP '2024-03-15'
```


## Question 7. External table storage

Where is the data stored in the External Table you created?

- Big Query
- Container Registry
- GCP Bucket
- Big Table

## Question 8. Clustering best practices
It is best practice in Big Query to always cluster your data:

I assume that it is true, as the clustering feature is free and can speed up data scans even for small amount of data,
