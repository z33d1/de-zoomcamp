#!/usr/bin/env python
# coding: utf-8

import click
import pandas as pd
from sqlalchemy import create_engine
from tqdm.auto import tqdm
import pyarrow.parquet as pq


@click.command()
@click.option('--pg-user', default='root', help='PostgreSQL user')
@click.option('--pg-pass', default='root', help='PostgreSQL password')
@click.option('--pg-host', default='localhost', help='PostgreSQL host')
@click.option('--pg-port', default=5432, type=int, help='PostgreSQL port')
@click.option('--pg-db', default='ny_taxi', help='PostgreSQL database name')
@click.option('--target-table', default='yellow_taxi_data', help='Target table name')
def run(pg_user, pg_pass, pg_host, pg_port, pg_db, target_table):
    
    data_path = 'data/green_taxi_trips/green_tripdata_2025-11.parquet'

    parquet_file = pq.ParquetFile(data_path)

    print(f'A file has {parquet_file.metadata.num_rows} rows. File path: "{data_path}"')

    engine = create_engine(f'postgresql://{pg_user}:{pg_pass}@{pg_host}:{pg_port}/{pg_db}')

    init_batch = next(parquet_file.iter_batches(batch_size=1))
    init_df = init_batch.to_pandas()
    init_df.head(0).to_sql(
        name=target_table,
        con=engine,
        if_exists="replace"
    )

    for batch in tqdm(parquet_file.iter_batches(batch_size=10_000)):
        df_batch = batch.to_pandas()
        df_batch.to_sql(
            name=target_table,
            con=engine,
            if_exists="append"
        )
        print(f"Inserted batch: {len(df_batch)}")

if __name__ == '__main__':
    run()