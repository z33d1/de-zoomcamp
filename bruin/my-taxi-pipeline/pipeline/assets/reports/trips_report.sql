/* @bruin

name: reports.trips_report
type: duckdb.sql

depends:
  - staging.yellow_trips
  - staging.green_trips
  - staging.fhv_trips

materialization:
  type: table
  strategy: time_interval
  incremental_key: pickup_datetime
  time_granularity: timestamp

columns:
  - name: report_date
    type: date
    description: Trip pickup date (UTC).
    primary_key: true
    checks:
      - name: not_null
  - name: taxi_type
    type: string
    description: Taxi type (yellow, green, fhv).
    primary_key: true
    checks:
      - name: not_null
  - name: payment_type_name
    type: string
    description: Payment type label; "unknown" for FHV trips.
    primary_key: true
    checks:
      - name: not_null
  - name: trip_count
    type: bigint
    description: Number of trips in the group.
    checks:
      - name: non_negative
  - name: total_amount
    type: double
    description: Sum of total_amount across trips.
    checks:
      - name: non_negative
  - name: total_fare_amount
    type: double
    description: Sum of fare_amount across trips.
    checks:
      - name: non_negative
  - name: total_tip_amount
    type: double
    description: Sum of tip_amount across trips.
    checks:
      - name: non_negative
  - name: total_trip_distance
    type: double
    description: Sum of trip_distance across trips.
    checks:
      - name: non_negative
  - name: avg_trip_distance
    type: double
    description: Average trip distance across trips.
    checks:
      - name: non_negative

@bruin */

WITH base AS (
  SELECT
    pickup_datetime,
    taxi_type,
    payment_type_name,
    total_amount,
    fare_amount,
    tip_amount,
    trip_distance
  FROM staging.yellow_trips

  UNION ALL

  SELECT
    pickup_datetime,
    taxi_type,
    payment_type_name,
    total_amount,
    fare_amount,
    tip_amount,
    trip_distance
  FROM staging.green_trips

  UNION ALL

  SELECT
    pickup_datetime,
    taxi_type,
    'unknown' AS payment_type_name,
    0.0 AS total_amount,
    0.0 AS fare_amount,
    0.0 AS tip_amount,
    0.0 AS trip_distance
  FROM staging.fhv_trips
),
filtered AS (
  SELECT *
  FROM base
  WHERE pickup_datetime >= '{{ start_datetime }}'
    AND pickup_datetime < '{{ end_datetime }}'
)
SELECT
  date_trunc('day', pickup_datetime) AS report_date,
  taxi_type,
  payment_type_name,
  COUNT(*) AS trip_count,
  SUM(total_amount) AS total_amount,
  SUM(fare_amount) AS total_fare_amount,
  SUM(tip_amount) AS total_tip_amount,
  SUM(trip_distance) AS total_trip_distance,
  AVG(trip_distance) AS avg_trip_distance
FROM filtered
GROUP BY 1, 2, 3;
