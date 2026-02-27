import os
from pathlib import Path

import pandas as pd
import pendulum as pdl
import requests as rq

BASE_URL = "https://github.com/DataTalksClub/nyc-tlc-data/releases/download"


def _get_window_months():
    start_date_raw = os.getenv("BRUIN_START_DATE")
    end_date_raw = os.getenv("BRUIN_END_DATE")

    if not start_date_raw or not end_date_raw:
        raise ValueError("BRUIN_START_DATE and BRUIN_END_DATE must be set.")

    start_date = pdl.parse(start_date_raw).start_of("month")
    end_date = pdl.parse(end_date_raw).start_of("month")

    window_months = []
    current = start_date
    while current <= end_date:
        window_months.append(current)
        current = current.add(months=1)

    return window_months


def materialize_taxi_type(taxi_type: str) -> pd.DataFrame:
    data_dir = Path("./data") / taxi_type
    data_dir.mkdir(parents=True, exist_ok=True)

    now_utc = pdl.now("UTC").to_iso8601_string()
    frames = []

    for data_month in _get_window_months():
        filename = f"{taxi_type}_tripdata_{data_month.year}-{data_month.month:02d}.csv.gz"
        file_path = data_dir / filename
        source_url = f"{BASE_URL}/{taxi_type}/{filename}"

        response = rq.get(source_url, stream=True, timeout=60)
        response.raise_for_status()

        with open(file_path, "wb") as file_obj:
            for chunk in response.iter_content(chunk_size=8192):
                file_obj.write(chunk)

        month_df = pd.read_csv(file_path, header=0)
        month_df["extracted_at"] = now_utc
        month_df["source_file"] = filename
        month_df["taxi_type"] = taxi_type
        frames.append(month_df)

    if not frames:
        raise ValueError(f"No source files were loaded for taxi_type={taxi_type}.")

    return pd.concat(frames, ignore_index=True)
