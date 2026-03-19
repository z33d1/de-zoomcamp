import dataclasses
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import pandas as pd
from kafka import KafkaProducer
from models import Ride, ride_from_row

# Download NYC yellow taxi trip data (first 1000 rows)
url = "https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2025-10.parquet"
columns = [
    'lpep_pickup_datetime',
    'lpep_dropoff_datetime',
    'PULocationID',
    'DOLocationID',
    'passenger_count',
    'trip_distance',
    'tip_amount',
    'total_amount'
]
df = pd.read_parquet(url, columns=columns)

def ride_serializer(ride):
    ride_dict = dataclasses.asdict(ride)
    json_str = json.dumps(ride_dict)
    return json_str.encode('utf-8')

server = 'localhost:9092'

producer = KafkaProducer(
    bootstrap_servers=[server],
    value_serializer=ride_serializer,
    linger_ms=50,
    batch_size=64 * 1024,
)
t0 = time.time()

topic_name = 'green-trips'

for row in df.itertuples(index=False):
    passenger_count = 0.0 if pd.isna(row.passenger_count) else float(row.passenger_count)
    
    ride = Ride(
        PULocationID=int(row.PULocationID),
        DOLocationID=int(row.DOLocationID),
        trip_distance=float(row.trip_distance),
        total_amount=float(row.total_amount),
        lpep_pickup_datetime=int(row.lpep_pickup_datetime.timestamp() * 1000),
        lpep_dropoff_datetime=int(row.lpep_dropoff_datetime.timestamp() * 1000),
        passenger_count=passenger_count,
        tip_amount=float(row.tip_amount),
    )
    producer.send(topic_name, value=ride)

producer.flush()

t1 = time.time()
print(f'took {(t1 - t0):.2f} seconds')
