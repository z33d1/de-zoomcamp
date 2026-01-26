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


# Misc

## Build zones ingestion image
```bash
docker build -t zones-ingestion:latest -f ./zones.Dockerfile .
```

## Build trips ingestion image
```bash
docker build -t trips-ingestion:latest -f ./trips.Dockerfile .
```

## Run zones ingestion
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

## Run trips ingestion
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