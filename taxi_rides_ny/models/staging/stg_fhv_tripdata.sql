with source as (
    select * from {{ source('raw', 'fhv_tripdata') }}
),

filtered as (
    SELECT * FROM source     
    WHERE dispatching_base_num IS NOT NULL
),

renamed as (
    select
        dispatching_base_num,
        -- timestamps
        cast(pickup_datetime as timestamp) as pickup_datetime,  -- lpep = Licensed Passenger Enhancement Program (green taxis)
        cast(dropoff_datetime as timestamp) as dropoff_datetime,

        cast(pulocationid as integer) as pickup_location_id,
        cast(dolocationid as integer) as dropoff_location_id,

        SR_Flag as sr_flag,
        Affiliated_base_number as affiliated_base_number

    from filtered
)

select * from renamed

-- Sample records for dev environment using deterministic date filter
{% if target.name == 'dev' %}
where pickup_datetime >= '2019-01-01' and pickup_datetime < '2019-02-01'
{% endif %}
