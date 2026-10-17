"""Load primary care KPIs from the Kolada API into BigQuery.

Kolada has an API, so there is no manual step and no GCS landing: a monthly
schedule fetches every KPI and year and replaces the raw tables. Kolada revises
earlier years, so a full refresh (about 100 small API calls) is both simpler
and more correct than loading incrementally.
"""

from datetime import date

import dagster as dg
import pandas as pd
from google.cloud import bigquery as bq

from dagster_project.gcp import BigQueryResource
from dagster_project.kolada import KPIS, KoladaResource, flatten_kpi_values

RAW_DATASET = "raw_kolada"
FIRST_YEAR = 2020

KPI_VALUES_SCHEMA = [
    bq.SchemaField("kpi", "STRING"),
    bq.SchemaField("municipality", "STRING"),
    bq.SchemaField("period", "INT64"),
    bq.SchemaField("gender", "STRING"),
    bq.SchemaField("count", "INT64"),
    bq.SchemaField("status", "STRING"),
    bq.SchemaField("value", "FLOAT64"),
    bq.SchemaField("isdeleted", "BOOL"),
    bq.SchemaField("_source_url", "STRING"),
]
KPIS_SCHEMA = [
    bq.SchemaField("id", "STRING"),
    bq.SchemaField("title", "STRING"),
    bq.SchemaField("description", "STRING"),
    bq.SchemaField("is_divided_by_gender", "BOOL"),
    bq.SchemaField("municipality_type", "STRING"),
    bq.SchemaField("auspice", "STRING"),
    bq.SchemaField("operating_area", "STRING"),
    bq.SchemaField("perspective", "STRING"),
    bq.SchemaField("prel_publication_date", "STRING"),
    bq.SchemaField("publication_date", "STRING"),
    bq.SchemaField("publ_period", "STRING"),
    bq.SchemaField("has_ou_data", "BOOL"),
]
REGIONS_SCHEMA = [
    bq.SchemaField("id", "STRING"),
    bq.SchemaField("title", "STRING"),
    bq.SchemaField("type", "STRING"),
]
METADATA_SCHEMA = [bq.SchemaField("_fetched_at", "TIMESTAMP")]

PANDAS_TYPES = {"STRING": "string", "INT64": "Int64", "FLOAT64": "float64", "BOOL": "boolean"}


def _to_frame(context, table: str, records: list[dict], schema: list[bq.SchemaField], fetched_at) -> pd.DataFrame:
    """Keep the known fields, typed; warn about fields the API added since."""
    known = [f.name for f in schema]
    extra = sorted({k for r in records for k in r} - set(known))
    if extra:
        context.log.warning(f"{table}: API returned new fields {extra}; not loaded until added to the schema")
    df = pd.DataFrame.from_records(records, columns=known)
    for field in schema:
        df[field.name] = df[field.name].astype(PANDAS_TYPES[field.field_type])
    df["_fetched_at"] = fetched_at
    return df


@dg.multi_asset(
    name="raw_kolada",
    specs=[
        dg.AssetSpec(
            [RAW_DATASET, "kpi_values"],
            group_name=RAW_DATASET,
            kinds={"api", "bigquery"},
            description="Primary care KPI values per region, year and gender (T/K/M) from Kolada.",
        ),
        dg.AssetSpec(
            [RAW_DATASET, "kpis"],
            group_name=RAW_DATASET,
            kinds={"api", "bigquery"},
            description="Kolada KPI definitions: title, description, perspective, publication dates.",
        ),
        dg.AssetSpec(
            [RAW_DATASET, "regions"],
            group_name=RAW_DATASET,
            kinds={"api", "bigquery"},
            description="Kolada region ids and names (type 'L'), including 0000 = the whole country.",
        ),
    ],
)
def raw_kolada(context: dg.AssetExecutionContext, kolada: KoladaResource, bigquery: BigQueryResource):
    fetched_at = pd.Timestamp.now(tz="UTC")
    years = list(range(FIRST_YEAR, date.today().year + 1))

    regions = [r for r in kolada.get_values("municipality") if r.get("type") == "L"]
    if not regions:
        raise dg.Failure("Kolada returned no regions (records with type == 'L')")
    region_ids = {r["id"] for r in regions}

    kpis = kolada.get_values(f"kpi/{','.join(KPIS)}")
    missing = set(KPIS) - {k.get("id") for k in kpis}
    if missing:
        raise dg.Failure(f"Kolada returned no definition for KPIs {sorted(missing)}")

    value_rows = []
    for kpi_id in KPIS:
        for year in years:
            path = f"data/kpi/{kpi_id}/year/{year}"
            records = [r for r in kolada.get_values(path) if r.get("municipality") in region_ids]
            rows = flatten_kpi_values(records)
            for row in rows:
                row["_source_url"] = kolada.url(path)
            value_rows.extend(rows)
            if not rows:
                context.log.info(f"{kpi_id} {year}: no data (not published yet?)")

    tables = {
        "kpi_values": _to_frame(context, "kpi_values", value_rows, KPI_VALUES_SCHEMA, fetched_at),
        "kpis": _to_frame(context, "kpis", kpis, KPIS_SCHEMA, fetched_at),
        "regions": _to_frame(context, "regions", regions, REGIONS_SCHEMA, fetched_at),
    }
    schemas = {"kpi_values": KPI_VALUES_SCHEMA, "kpis": KPIS_SCHEMA, "regions": REGIONS_SCHEMA}

    key = ["kpi", "municipality", "period", "gender"]
    duplicates = tables["kpi_values"].duplicated(key).sum()
    if duplicates:
        raise dg.Failure(f"kpi_values has {duplicates} duplicate rows on {key}")

    with bigquery.get_client() as client:
        for table, df in tables.items():
            table_id = f"{bigquery.project}.{RAW_DATASET}.{table}"
            client.load_table_from_dataframe(
                df,
                table_id,
                job_config=bq.LoadJobConfig(
                    schema=schemas[table] + METADATA_SCHEMA,
                    write_disposition=bq.WriteDisposition.WRITE_TRUNCATE,
                ),
            ).result()
            context.log.info(f"Loaded {len(df)} rows into {table_id}")

            metadata = {"table": table_id, "dagster/row_count": len(df)}
            if table == "kpi_values":
                metadata["years_requested"] = f"{years[0]}-{years[-1]}"
                metadata["rows_per_kpi"] = df.groupby("kpi").size().to_dict()
            yield dg.MaterializeResult(asset_key=[RAW_DATASET, table], metadata=metadata)


@dg.definitions
def defs() -> dg.Definitions:
    return dg.Definitions(
        assets=[raw_kolada],
        schedules=[
            dg.ScheduleDefinition(
                name="raw_kolada_monthly",
                target=raw_kolada,
                cron_schedule="0 6 1 * *",  # 06:00 on the 1st of every month
                execution_timezone="Europe/Stockholm",
            )
        ],
    )
