"""@bruin

name: ingestion.green_trips
type: python
image: python:3.11
connection: duckdb-default

materialization:
  type: table
  strategy: append

@bruin"""

from ._trip_ingestion import materialize_taxi_type


def materialize():
    return materialize_taxi_type("green")
