"""Helpers for reading snapshot-based CSV extracts from the GCS landing bucket.

Landing layout (one folder per manual download, `_SUCCESS` uploaded last):

    gs://<bucket>/<dataset_prefix>/snapshot_YYYY_MM_DD/part_1.csv
                                                      part_2.csv
                                                      _SUCCESS
"""

import io
import re
import unicodedata
from dataclasses import dataclass
from datetime import date

import pandas as pd
from google.cloud import storage

SUCCESS_MARKER = "_SUCCESS"
SNAPSHOT_FOLDER = re.compile(r"snapshot_(\d{4})_(\d{2})_(\d{2})/")
PART_FILE = re.compile(r"part_\d+\.csv")


@dataclass(frozen=True)
class Snapshot:
    folder: str  # e.g. "waiting_times/first_contact/snapshot_2026_10_16/"
    snapshot_date: date


def find_latest_complete_snapshot(
    client: storage.Client, bucket: str, dataset_prefix: str
) -> Snapshot | None:
    """Return the newest snapshot folder directly under `dataset_prefix` that has a _SUCCESS marker."""
    complete = []
    for blob in client.list_blobs(bucket, prefix=dataset_prefix):
        if not blob.name.endswith("/" + SUCCESS_MARKER):
            continue
        folder = blob.name[: -len(SUCCESS_MARKER)]
        match = SNAPSHOT_FOLDER.fullmatch(folder[len(dataset_prefix) :])
        if match:
            complete.append(Snapshot(folder, date(*map(int, match.groups()))))
    return max(complete, key=lambda s: s.snapshot_date, default=None)


def list_part_blobs(client: storage.Client, bucket: str, snapshot: Snapshot) -> list:
    """All part_N.csv files directly inside the snapshot folder, in numeric order."""
    blobs = [
        b
        for b in client.list_blobs(bucket, prefix=snapshot.folder)
        if PART_FILE.fullmatch(b.name[len(snapshot.folder) :])
    ]
    return sorted(blobs, key=lambda b: int(re.search(r"\d+", b.name.rsplit("/", 1)[-1]).group()))


def parse_extract(text: str) -> pd.DataFrame:
    """Parse one Statistikdatabasen CSV export into an all-string DataFrame.

    Exports have a title line above the header and a source line below the data.
    Neither contains the ';' delimiter, so keeping only delimited lines drops both.
    Values are kept exactly as exported (suppression markers, decimal commas,
    leading spaces); cleaning happens in dbt staging.
    """
    lines = [line for line in text.splitlines() if ";" in line]
    if len(lines) < 2:
        raise ValueError("Extract contains no data rows")
    return pd.read_csv(io.StringIO("\n".join(lines)), sep=";", dtype=str, keep_default_na=False)


def to_snake_case(name: str) -> str:
    """'Vårdcentral' -> 'vardcentral', '10:e percentilen' -> 'c_10_e_percentilen'."""
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    snake = re.sub(r"[^0-9a-zA-Z]+", "_", ascii_name).strip("_").lower()
    return f"c_{snake}" if snake[:1].isdigit() else snake


def list_snapshot_files(client: storage.Client, bucket: str, snapshot: Snapshot, suffix: str) -> list:
    """Files with the given suffix directly inside the snapshot folder, sorted by name."""
    blobs = [
        b
        for b in client.list_blobs(bucket, prefix=snapshot.folder)
        if "/" not in b.name[len(snapshot.folder) :] and b.name.lower().endswith(suffix)
    ]
    return sorted(blobs, key=lambda b: b.name)
