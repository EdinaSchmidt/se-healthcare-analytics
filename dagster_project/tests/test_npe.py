import io

import pandas as pd

from dagster_project.npe import column_name, parse_npe_workbook


def _workbook(level: str, entity_columns: dict) -> bytes:
    rows = len(next(iter(entity_columns.values())))
    result = pd.DataFrame({**entity_columns, "1": [80.5] * rows, "2": [None] * rows})
    sheets = {
        "Parametrar": pd.DataFrame(
            {"Beskrivning": ["Datum", "Mätning", "Period", "Aggregera på", "Respondentgräns", "Urvalskriterie"],
             "Värde": ["2026-10-15", "Vårdcentraler och hälsocentraler", "2025", level, "Publik: 30", "Läkarbesök"]}
        ),
        **{name: result for name in ["Svarsfrekvens", "Helhetsupplevelse", "Dimensioner", "Dimensioner KI",
                                     "Medelvärde", "Medelvärde KI", "Frågesvar"]},
        "Frågor": pd.DataFrame(
            {"Position": [1, None], "Text": ["Hur upplevde du vården?", None],
             "Svarsalternativ": [1, 2], "Svarstext": ["Mycket bra", "Ganska bra"]}
        ),
    }
    buffer = io.BytesIO()
    with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
        for name, df in sheets.items():
            df.to_excel(writer, sheet_name=name, index=False)
    return buffer.getvalue()


def test_column_name():
    assert column_name("1.1") == "q1_1"
    assert column_name("18") == "q18"
    assert column_name(7.0) == "q7"
    assert column_name("HSA-ID") == "hsa_id"
    assert column_name("Hälso-/vårdcentral") == "halso_vardcentral"
    assert column_name("Vård och behandling") == "vard_och_behandling"


def test_region_level_gets_missing_entity_columns_and_parameters():
    workbook = parse_npe_workbook(_workbook("Region", {"Region": ["Blekinge", "Dalarna"]}))
    df = workbook.results["medelvarde"]
    assert {"kommun", "halso_vardcentral", "hsa_id", "kommentar"} <= set(df.columns)
    assert df["kommun"].isna().all()
    assert list(df["q1"]) == [80.5, 80.5]
    assert set(df["aggregation_level"]) == {"Region"}
    assert set(df["survey_period"]) == {"2025"}
    assert list(df["_row_number"]) == [1, 2]


def test_questions_keep_row_order_for_fill_down():
    workbook = parse_npe_workbook(_workbook("Region", {"Region": ["Blekinge"]}))
    questions = workbook.questions
    assert list(questions["_row_number"]) == [1, 2]
    assert questions.loc[1, "svarstext"] == "Ganska bra"
