"""Load the latest complete waiting-times snapshot from GCS into BigQuery.

Each manual download from Socialstyrelsen's Statistikdatabasen is a full snapshot
(all months, possibly revised), so every load replaces the raw table (WRITE_TRUNCATE).
"""

from dataclasses import dataclass

import dagster as dg
import pandas as pd
from google.cloud import bigquery as bq

from dagster_project.gcp import BigQueryResource, LandingBucketResource
from dagster_project.landing import (
    find_latest_complete_snapshot,
    list_part_blobs,
    parse_extract,
    to_snake_case,
)

RAW_DATASET = "raw_waiting_times"


@dataclass(frozen=True)
class LandingDataset:
    table: str
    prefix: str
    column_map: dict[str, str]  # Swedish export header -> raw column name
    description: str


WAITING_TIMES_DATASETS = [
    LandingDataset(
        table="first_contact",
        prefix="waiting_times/first_contact/",
        description="Answered vs. total calls/chats per health centre and month (first contact).",
        column_map={
            "Region": "region",
            "Vårdcentral": "vardcentral",
            "Typ": "typ",
            "År": "ar",
            "Månad": "manad",
            "Besvarade samtal": "besvarade_samtal",
            "Andel (procent) besvarade samtal": "andel_procent_besvarade_samtal",
            "Totalt antal": "totalt_antal",
        },
    ),
    LandingDataset(
        table="medical_assessment",
        prefix="waiting_times/medical_assessment/",
        description="Waiting time to medical assessment per health centre and month.",
        column_map={
            "Region": "region",
            "Vårdcentral": "vardcentral",
            "År": "ar",
            "Månad": "manad",
            "Antal med väntetid inom 0 dagar": "antal_inom_0_dagar",
            "Antal med väntetid inom 3 dagar": "antal_inom_3_dagar",
            "Antal med väntetid över 3 dagar": "antal_over_3_dagar",
            "Totalt antal": "totalt_antal",
            "Antal där patienten valt att vänta längre": "antal_valt_vanta_langre",
            "Medelvärdet för väntetiden": "medelvarde_vantetid",
            "10:e percentilen för väntetiden": "p10_vantetid",
            "25:e percentilen för väntetiden": "p25_vantetid",
            "Medianvärdet för väntetid, 50:e percentilen": "median_vantetid",
            "75:e percentilen för väntetiden": "p75_vantetid",
            "90:e percentilen för väntetiden": "p90_vantetid",
        },
    ),
]


def build_raw_asset(ds: LandingDataset) -> dg.AssetsDefinition:
    @dg.asset(
        key=[RAW_DATASET, ds.table],
        group_name=RAW_DATASET,
        kinds={"gcs", "bigquery"},
        description=ds.description,
    )
    def _raw_asset(
        context: dg.AssetExecutionContext,
        landing: LandingBucketResource,
        bigquery: BigQueryResource,
    ) -> dg.MaterializeResult:
        storage_client = landing.get_client()
        snapshot = find_latest_complete_snapshot(storage_client, landing.bucket, ds.prefix)
        if snapshot is None:
            raise dg.Failure(f"No snapshot with a _SUCCESS marker under gs://{landing.bucket}/{ds.prefix}")

        parts = list_part_blobs(storage_client, landing.bucket, snapshot)
        if not parts:
            raise dg.Failure(f"Snapshot {snapshot.folder} has a _SUCCESS marker but no part_N.csv files")

        frames = []
        for blob in parts:
            df = parse_extract(blob.download_as_bytes().decode("utf-8-sig"))
            unmapped = [c for c in df.columns if c not in ds.column_map]
            if unmapped:
                context.log.warning(f"{blob.name}: unmapped columns {unmapped}, auto-naming them")
            df = df.rename(columns=lambda c: ds.column_map.get(c, to_snake_case(c)))
            df["_source_file"] = f"gs://{landing.bucket}/{blob.name}"
            frames.append(df)
            context.log.info(f"{blob.name}: {len(df)} rows")

        # All parts of one snapshot must share a schema; a mismatch means a bad download.
        expected = list(frames[0].columns)
        for blob, df in zip(parts, frames):
            if list(df.columns) != expected:
                raise dg.Failure(f"{blob.name} has columns {list(df.columns)}, expected {expected}")

        data = pd.concat(frames, ignore_index=True)
        data["_snapshot_date"] = snapshot.snapshot_date
        data["_loaded_at"] = pd.Timestamp.now(tz="UTC")

        data_columns = [c for c in expected if c != "_source_file"]
        schema = [bq.SchemaField(c, "STRING") for c in data_columns] + [
            bq.SchemaField("_source_file", "STRING"),
            bq.SchemaField("_snapshot_date", "DATE"),
            bq.SchemaField("_loaded_at", "TIMESTAMP"),
        ]
        data = data[[f.name for f in schema]]

        table_id = f"{bigquery.project}.{RAW_DATASET}.{ds.table}"
        with bigquery.get_client() as client:
            client.load_table_from_dataframe(
                data,
                table_id,
                job_config=bq.LoadJobConfig(
                    schema=schema,
                    write_disposition=bq.WriteDisposition.WRITE_TRUNCATE,
                ),
            ).result()

        return dg.MaterializeResult(
            metadata={
                "table": table_id,
                "snapshot_date": snapshot.snapshot_date.isoformat(),
                "source_files": [f"gs://{landing.bucket}/{b.name}" for b in parts],
                "dagster/row_count": len(data),
                "columns": data_columns,
            }
        )

    return _raw_asset


def build_snapshot_sensor(ds: LandingDataset, asset: dg.AssetsDefinition) -> dg.SensorDefinition:
    @dg.sensor(
        name=f"{RAW_DATASET}_{ds.table}_sensor",
        target=asset,
        minimum_interval_seconds=24 * 60 * 60,
        description=f"Loads {ds.table} when a new complete snapshot lands in {ds.prefix}",
    )
    def _sensor(context: dg.SensorEvaluationContext, landing: LandingBucketResource):
        snapshot = find_latest_complete_snapshot(landing.get_client(), landing.bucket, ds.prefix)
        if snapshot is None:
            return dg.SkipReason("No complete snapshot yet")

        snapshot_id = snapshot.snapshot_date.isoformat()
        if context.cursor == snapshot_id:
            return dg.SkipReason(f"Latest snapshot {snapshot_id} already requested")

        context.update_cursor(snapshot_id)
        return dg.RunRequest(run_key=f"{ds.table}:{snapshot_id}")

    return _sensor


@dg.definitions
def defs() -> dg.Definitions:
    assets = {ds.table: build_raw_asset(ds) for ds in WAITING_TIMES_DATASETS}
    return dg.Definitions(
        assets=list(assets.values()),
        sensors=[build_snapshot_sensor(ds, assets[ds.table]) for ds in WAITING_TIMES_DATASETS],
    )
