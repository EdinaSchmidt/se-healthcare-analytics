"""Load Nationell Patientenkät (NPE) primary care results from GCS into BigQuery.

A snapshot folder holds one xlsx per aggregation level (region, kommun, health
centre). Each result tab becomes one raw table with all levels stacked and an
`aggregation_level` column; the question catalogue becomes `fragor`.
"""

import dagster as dg
import pandas as pd
from google.cloud import bigquery as bq

from dagster_project.gcp import BigQueryResource, LandingBucketResource
from dagster_project.landing import find_latest_complete_snapshot, list_snapshot_files
from dagster_project.npe import ENTITY_COLUMNS, RESULT_SHEETS, TEXT_COLUMNS, parse_npe_workbook
from dagster_project.sensors import build_snapshot_sensor

RAW_DATASET = "raw_patient_surveys"
PREFIX = "patient_surveys/npe_primary_care/"
QUESTIONS_TABLE = "fragor"
METADATA_COLUMNS = ["_source_file", "_row_number", "_snapshot_date", "_loaded_at"]

TABLE_DESCRIPTIONS = {
    "svarsfrekvens": "Surveys sent, respondents and response rate.",
    "helhetsupplevelse": "Overall experience score and confidence interval.",
    "dimensioner": "Scores for the six NPE dimensions.",
    "dimensioner_ki": "Confidence intervals for the dimension scores.",
    "medelvarde": "Score per question (q1..qN).",
    "medelvarde_ki": "Confidence intervals for the question scores.",
    "fragesvar": "Answer counts per question and answer option (q<question>_<option>).",
    QUESTIONS_TABLE: "Question catalogue: text, dimension and answer options (fill-down layout, keep _row_number order).",
}


def _order_and_type(df: pd.DataFrame) -> tuple[pd.DataFrame, list[bq.SchemaField]]:
    """Column order: entity columns, values, parameters, metadata. Values must be numeric."""
    value_columns = [c for c in df.columns if c not in TEXT_COLUMNS and c not in METADATA_COLUMNS]
    entity = [c for c in ENTITY_COLUMNS if c in df.columns]
    text = [c for c in df.columns if c in TEXT_COLUMNS and c not in entity]
    ordered = entity + value_columns + text + METADATA_COLUMNS
    df = df[ordered].copy()

    schema = []
    for column in entity + text + ["_source_file"]:
        df[column] = df[column].astype("string")
    for column in value_columns:
        df[column] = pd.to_numeric(df[column], errors="raise").astype("float64")
    schema += [bq.SchemaField(c, "STRING") for c in entity]
    schema += [bq.SchemaField(c, "FLOAT64") for c in value_columns]
    schema += [bq.SchemaField(c, "STRING") for c in text]
    schema += [
        bq.SchemaField("_source_file", "STRING"),
        bq.SchemaField("_row_number", "INT64"),
        bq.SchemaField("_snapshot_date", "DATE"),
        bq.SchemaField("_loaded_at", "TIMESTAMP"),
    ]
    return df, schema


def _order_and_type_questions(df: pd.DataFrame) -> tuple[pd.DataFrame, list[bq.SchemaField]]:
    data_columns = [c for c in df.columns if c not in METADATA_COLUMNS]
    df = df[data_columns + METADATA_COLUMNS].copy()
    schema = []
    for column in data_columns:
        if pd.api.types.is_numeric_dtype(df[column]):
            schema.append(bq.SchemaField(column, "FLOAT64"))
        else:
            df[column] = df[column].astype("string")
            schema.append(bq.SchemaField(column, "STRING"))
    df["_source_file"] = df["_source_file"].astype("string")
    schema += [
        bq.SchemaField("_source_file", "STRING"),
        bq.SchemaField("_row_number", "INT64"),
        bq.SchemaField("_snapshot_date", "DATE"),
        bq.SchemaField("_loaded_at", "TIMESTAMP"),
    ]
    return df, schema


@dg.multi_asset(
    name="raw_patient_surveys_npe",
    specs=[
        dg.AssetSpec(
            [RAW_DATASET, table],
            group_name=RAW_DATASET,
            kinds={"gcs", "bigquery"},
            description=TABLE_DESCRIPTIONS[table],
        )
        for table in [*RESULT_SHEETS.values(), QUESTIONS_TABLE]
    ],
)
def raw_patient_surveys_npe(
    context: dg.AssetExecutionContext,
    landing: LandingBucketResource,
    bigquery: BigQueryResource,
):
    storage_client = landing.get_client()
    snapshot = find_latest_complete_snapshot(storage_client, landing.bucket, PREFIX)
    if snapshot is None:
        raise dg.Failure(f"No snapshot with a _SUCCESS marker under gs://{landing.bucket}/{PREFIX}")

    blobs = list_snapshot_files(storage_client, landing.bucket, snapshot, ".xlsx")
    if not blobs:
        raise dg.Failure(f"Snapshot {snapshot.folder} has a _SUCCESS marker but no .xlsx files")

    results: dict[str, list[pd.DataFrame]] = {table: [] for table in RESULT_SHEETS.values()}
    questions_by_survey: dict[tuple, tuple[pd.DataFrame, str]] = {}
    seen_files: dict[tuple, str] = {}

    for blob in blobs:
        uri = f"gs://{landing.bucket}/{blob.name}"
        workbook = parse_npe_workbook(blob.download_as_bytes())
        p = workbook.parameters
        context.log.info(f"{blob.name}: period={p['survey_period']}, level={p['aggregation_level']}")

        # Two files for the same period, level and selection would double-count.
        key = (p["survey_period"], p["measurement"], p["selection"], p["aggregation_level"])
        if None in key:
            raise dg.Failure(f"{uri}: missing period, measurement, selection or aggregation level in Parametrar")
        if key in seen_files:
            raise dg.Failure(f"{uri} duplicates {seen_files[key]} (same period, measurement, selection and level)")
        seen_files[key] = uri

        for table, df in workbook.results.items():
            df["_source_file"] = uri
            results[table].append(df)

        # The question catalogue repeats in every file; it must be identical per survey.
        survey = key[:3]
        if survey in questions_by_survey:
            if not questions_by_survey[survey][0].equals(workbook.questions):
                raise dg.Failure(f"{uri}: Frågor differs from another file of the same survey {survey}")
        else:
            questions_by_survey[survey] = (workbook.questions, uri)

    # Every level must have the same value columns, or the stacked table is misaligned.
    for table, frames in results.items():
        value_sets = {tuple(c for c in df.columns if c not in TEXT_COLUMNS and not c.startswith("_")) for df in frames}
        if len(value_sets) > 1:
            raise dg.Failure(f"{table}: value columns differ between files: {sorted(value_sets)}")

    loaded_at = pd.Timestamp.now(tz="UTC")
    tables = {table: pd.concat(frames, ignore_index=True) for table, frames in results.items()}
    tables[QUESTIONS_TABLE] = pd.concat(
        [
            questions.assign(survey_period=period, measurement=measurement, selection=selection, _source_file=uri)
            for (period, measurement, selection), (questions, uri) in questions_by_survey.items()
        ],
        ignore_index=True,
    )

    with bigquery.get_client() as client:
        for table, df in tables.items():
            df["_snapshot_date"] = snapshot.snapshot_date
            df["_loaded_at"] = loaded_at
            df, schema = (_order_and_type_questions if table == QUESTIONS_TABLE else _order_and_type)(df)

            table_id = f"{bigquery.project}.{RAW_DATASET}.{table}"
            client.load_table_from_dataframe(
                df,
                table_id,
                job_config=bq.LoadJobConfig(schema=schema, write_disposition=bq.WriteDisposition.WRITE_TRUNCATE),
            ).result()
            context.log.info(f"Loaded {len(df)} rows into {table_id}")

            yield dg.MaterializeResult(
                asset_key=[RAW_DATASET, table],
                metadata={
                    "table": table_id,
                    "snapshot_date": snapshot.snapshot_date.isoformat(),
                    "source_files": [f"gs://{landing.bucket}/{b.name}" for b in blobs],
                    "dagster/row_count": len(df),
                    "columns": [f.name for f in schema],
                },
            )


@dg.definitions
def defs() -> dg.Definitions:
    return dg.Definitions(
        assets=[raw_patient_surveys_npe],
        sensors=[build_snapshot_sensor(f"{RAW_DATASET}_npe_primary_care_sensor", PREFIX, raw_patient_surveys_npe)],
    )
