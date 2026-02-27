/* @bruin

name: staging.fhv_trips
type: duckdb.sql

depends:
  - ingestion.fhv_trips

materialization:
  type: table
  strategy: time_interval
  incremental_key: pickup_datetime
  time_granularity: timestamp

columns:
  - name: trip_id
    type: string
    description: Deterministic surrogate key for an FHV trip.
    primary_key: true
    nullable: false
    checks:
      - name: not_null
      - name: unique
  - name: dispatching_base_num
    type: string
    description: Base number that dispatched the trip.
    checks:
      - name: not_null
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
      FROM staging.fhv_trips
    value: 0
  - name: valid_trip_time_order
    description: Ensures trips do not end before they start.
    query: |
      SELECT count(*)
      FROM staging.fhv_trips
      WHERE dropoff_datetime < pickup_datetime
    value: 0

@bruin */

WITH renamed AS (
  SELECT
    CAST(dispatching_base_num AS VARCHAR) AS dispatching_base_num,
    CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,
    CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
    CAST(pu_location_id AS INTEGER) AS pickup_location_id,
    CAST(do_location_id AS INTEGER) AS dropoff_location_id,
    CAST(sr_flag AS VARCHAR) AS sr_flag,
    CAST(affiliated_base_number AS VARCHAR) AS affiliated_base_number,
    CAST(extracted_at AS TIMESTAMP) AS extracted_at,
    source_file,
    taxi_type
  FROM ingestion.fhv_trips
),
filtered AS (
  SELECT *
  FROM renamed
  WHERE pickup_datetime >= '{{ start_datetime }}'
    AND pickup_datetime < '{{ end_datetime }}'
    AND dispatching_base_num IS NOT NULL
    AND pickup_location_id IS NOT NULL
    AND dropoff_location_id IS NOT NULL
),
with_trip_id AS (
  SELECT
    md5(
      concat_ws(
        '||',
        COALESCE(dispatching_base_num, ''),
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
  trip_id,
  dispatching_base_num,
  pickup_datetime,
  dropoff_datetime,
  pickup_location_id,
  dropoff_location_id,
  sr_flag,
  affiliated_base_number,
  extracted_at,
  source_file,
  taxi_type
FROM deduped
WHERE rn = 1;
