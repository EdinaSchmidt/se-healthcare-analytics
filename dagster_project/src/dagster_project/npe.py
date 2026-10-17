"""Parsing for Nationell Patientenkät (NPE) result workbooks.

One workbook = one survey period at one aggregation level (region, kommun or
health centre). Every workbook has the same tabs: a parameters tab, seven result
tabs and a question catalogue (`Frågor`).
"""

import io
import re
from dataclasses import dataclass

import pandas as pd

from dagster_project.landing import to_snake_case

PARAMETERS_SHEET = "Parametrar"
QUESTIONS_SHEET = "Frågor"

# Excel tab -> raw table name
RESULT_SHEETS = {
    "Svarsfrekvens": "svarsfrekvens",
    "Helhetsupplevelse": "helhetsupplevelse",
    "Dimensioner": "dimensioner",
    "Dimensioner KI": "dimensioner_ki",
    "Medelvärde": "medelvarde",
    "Medelvärde KI": "medelvarde_ki",
    "Frågesvar": "fragesvar",
}

# Row in `Parametrar` -> column added to every result row
PARAMETER_COLUMNS = {
    "Period": "survey_period",
    "Mätning": "measurement",
    "Aggregera på": "aggregation_level",
    "Urvalskriterie": "selection",
    "Respondentgräns": "respondent_threshold",
    "Datum": "extract_date",
}

KNOWN_COLUMNS = {
    "Region": "region",
    "Kommun": "kommun",
    "Hälso-/vårdcentral": "halso_vardcentral",
    "HSA-ID": "hsa_id",
    "Kommentar": "kommentar",
}
ENTITY_COLUMNS = ["region", "kommun", "halso_vardcentral", "hsa_id"]
TEXT_COLUMNS = set(ENTITY_COLUMNS) | {"kommentar"} | set(PARAMETER_COLUMNS.values())


def column_name(header) -> str:
    """'1.1' -> 'q1_1', '7' -> 'q7', 'HSA-ID' -> 'hsa_id', 'Vård och behandling' -> 'vard_och_behandling'."""
    if isinstance(header, float) and header.is_integer():
        header = int(header)
    header = str(header).strip()
    if re.fullmatch(r"\d+(\.\d+)?", header):
        return "q" + header.replace(".", "_")
    return KNOWN_COLUMNS.get(header) or to_snake_case(header)


@dataclass
class NpeWorkbook:
    parameters: dict[str, str | None]
    results: dict[str, pd.DataFrame]  # raw table name -> rows
    questions: pd.DataFrame


def _parameter_value(value) -> str | None:
    if pd.isna(value):
        return None
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if isinstance(value, pd.Timestamp):
        return value.date().isoformat()
    return str(value).strip()


def parse_npe_workbook(content: bytes) -> NpeWorkbook:
    sheets = pd.read_excel(io.BytesIO(content), sheet_name=None)
    missing = ({PARAMETERS_SHEET, QUESTIONS_SHEET} | RESULT_SHEETS.keys()) - sheets.keys()
    if missing:
        raise ValueError(f"Workbook is missing tabs: {sorted(missing)}")

    params_sheet = sheets[PARAMETERS_SHEET]
    raw_params = {
        str(name).strip(): _parameter_value(value)
        for name, value in zip(params_sheet.iloc[:, 0], params_sheet.iloc[:, 1])
    }
    parameters = {column: raw_params.get(name) for name, column in PARAMETER_COLUMNS.items()}

    results = {}
    for sheet, table in RESULT_SHEETS.items():
        df = sheets[sheet].rename(columns=column_name)
        # Coarser levels lack some entity columns; add them so all levels stack into one table.
        for column in ENTITY_COLUMNS + ["kommentar"]:
            if column not in df.columns:
                df[column] = None
        for column, value in parameters.items():
            df[column] = value
        df["_row_number"] = range(1, len(df) + 1)
        results[table] = df

    # Frågor is a fill-down layout (question text only on its first option row),
    # so the row order must survive the trip into BigQuery.
    questions = sheets[QUESTIONS_SHEET].rename(columns=column_name)
    questions["_row_number"] = range(1, len(questions) + 1)

    return NpeWorkbook(parameters, results, questions)
