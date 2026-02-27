/* @bruin

name: staging.green_trips
type: duckdb.sql

depends:
  - ingestion.green_trips
  - ingestion.payment_lookup

materialization:
  type: table
  strategy: time_interval
  incremental_key: pickup_datetime
  time_granularity: timestamp

columns:
  - name: trip_id
    type: string
    description: Deterministic surrogate key for a green taxi trip.
    primary_key: true
    nullable: false
    checks:
      - name: not_null
      - name: unique
  - name: vendor_id
    type: integer
    description: Taxi vendor identifier.

  - name: pickup_datetime
    type: timestamp
    description: Pickup timestamp.
    checks:
      - name: not_null
  - name: pickup_location_id
    type: integer
    description: Pickup zone ID.
    checks:
      - name: not_null
  - name: dropoff_location_id
    type: integer
    description: Dropoff zone ID.
    checks:
      - name: not_null

custom_checks:
  - name: no_duplicate_trip_id
    description: Ensures there are no duplicate staged trip IDs.
    query: |
      SELECT count(*) - count(DISTINCT trip_id)
      FROM staging.green_trips
    value: 0
  - name: valid_trip_time_order
    description: Ensures trips do not end before they start.
    query: |
      SELECT count(*)
      FROM staging.green_trips
      WHERE dropoff_datetime < pickup_datetime
    value: 0

@bruin */

WITH renamed AS (
  SELECT
    CAST(vendor_id AS INTEGER) AS vendor_id,
    try_cast(ratecode_id AS INTEGER) AS rate_code_id,
    CAST(pu_location_id AS INTEGER) AS pickup_location_id,
    CAST(do_location_id AS INTEGER) AS dropoff_location_id,
    CAST(lpep_pickup_datetime AS TIMESTAMP) AS pickup_datetime,
    CAST(lpep_dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
    CAST(store_and_fwd_flag AS VARCHAR) AS store_and_fwd_flag,
    CAST(passenger_count AS INTEGER) AS passenger_count,
    CAST(trip_distance AS DOUBLE) AS trip_distance,
    try_cast(trip_type AS INTEGER) AS trip_type,
    CASE
      WHEN CAST(fare_amount AS DOUBLE) < 0 THEN NULL
      ELSE CAST(fare_amount AS DOUBLE)
    END AS fare_amount,
    CAST(extra AS DOUBLE) AS extra,
    CAST(mta_tax AS DOUBLE) AS mta_tax,
    CASE
      WHEN CAST(tip_amount AS DOUBLE) < 0 THEN NULL
      ELSE CAST(tip_amount AS DOUBLE)
    END AS tip_amount,
    CAST(tolls_amount AS DOUBLE) AS tolls_amount,
    CAST(ehail_fee AS DOUBLE) AS ehail_fee,
    CAST(improvement_surcharge AS DOUBLE) AS improvement_surcharge,
    CASE
      WHEN CAST(total_amount AS DOUBLE) < 0 THEN NULL
      ELSE CAST(total_amount AS DOUBLE)
    END AS total_amount,
    try_cast(payment_type AS INTEGER) AS payment_type,
    CAST(extracted_at AS TIMESTAMP) AS extracted_at,
    source_file,
    taxi_type
  FROM ingestion.green_trips
),
filtered AS (
  SELECT *
  FROM renamed
  WHERE pickup_datetime >= '{{ start_datetime }}'
    AND pickup_datetime < '{{ end_datetime }}'
    AND vendor_id IS NOT NULL
    AND pickup_location_id IS NOT NULL
    AND dropoff_location_id IS NOT NULL
),
with_trip_id AS (
  SELECT
    md5(
      concat_ws(
        '||',
        COALESCE(CAST(vendor_id AS VARCHAR), ''),
        COALESCE(CAST(pickup_datetime AS VARCHAR), ''),
        COALESCE(CAST(dropoff_datetime AS VARCHAR), ''),
        COALESCE(CAST(pickup_location_id AS VARCHAR), ''),
        COALESCE(CAST(dropoff_location_id AS VARCHAR), '')
      )
    ) AS trip_id,
    *
  FROM filtered
),
deduped AS (
  SELECT
    *,
    row_number() OVER (
      PARTITION BY trip_id
      ORDER BY extracted_at DESC, source_file DESC
    ) AS rn
  FROM with_trip_id
)
SELECT
  d.trip_id,
  d.vendor_id,
  d.rate_code_id,
  d.pickup_location_id,
  d.dropoff_location_id,
  d.pickup_datetime,
  d.dropoff_datetime,
  d.store_and_fwd_flag,
  d.passenger_count,
  d.trip_distance,
  d.trip_type,
  d.fare_amount,
  d.extra,
  d.mta_tax,
  d.tip_amount,
  d.tolls_amount,
  d.ehail_fee,
  d.improvement_surcharge,
  d.total_amount,
  d.payment_type,
  p.payment_type_name,
  d.extracted_at,
  d.source_file,
  d.taxi_type
FROM deduped d
LEFT JOIN ingestion.payment_lookup p
  ON d.payment_type = p.payment_type_id
WHERE rn = 1;
