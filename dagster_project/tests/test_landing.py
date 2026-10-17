from datetime import date
from types import SimpleNamespace

from dagster_project.landing import (
    find_latest_complete_snapshot,
    list_part_blobs,
    parse_extract,
    to_snake_case,
)

SAMPLE_EXPORT = (
    "\ufeffVäntetider till primärvård\r\n"
    "Region;Vårdcentral;År;Månad;Totalt antal;Medelvärdet för väntetiden\r\n"
    "Skåne; Alla vårdcentraler;2025;Juli;243838;0,8\r\n"
    "Skåne;Exempel vårdcentral;2025;Juli;\u00ad\u00ad;X\r\n"
    "Socialstyrelsens statistikdatabas 2026-10-15\r\n"
)


class FakeStorageClient:
    def __init__(self, names):
        self.names = names

    def list_blobs(self, bucket, prefix):
        return [SimpleNamespace(name=n) for n in self.names if n.startswith(prefix)]


def test_parse_extract_drops_title_and_footer_and_keeps_raw_values():
    df = parse_extract(SAMPLE_EXPORT.encode("utf-8").decode("utf-8-sig"))
    assert list(df.columns) == ["Region", "Vårdcentral", "År", "Månad", "Totalt antal", "Medelvärdet för väntetiden"]
    assert len(df) == 2
    assert df.loc[0, "Vårdcentral"] == " Alla vårdcentraler"  # leading space preserved
    assert df.loc[0, "Medelvärdet för väntetiden"] == "0,8"  # decimal comma preserved
    assert df.loc[1, "Totalt antal"] == "\u00ad\u00ad"  # suppression marker preserved


def test_to_snake_case():
    assert to_snake_case("Vårdcentral") == "vardcentral"
    assert to_snake_case("Andel (procent) besvarade samtal") == "andel_procent_besvarade_samtal"
    assert to_snake_case("10:e percentilen") == "c_10_e_percentilen"


def test_latest_complete_snapshot_ignores_incomplete_and_nested_folders():
    prefix = "waiting_times/first_contact/"
    client = FakeStorageClient([
        prefix + "snapshot_2026_10_15/part_1.csv",
        prefix + "snapshot_2026_10_15/_SUCCESS",
        prefix + "snapshot_2026_11_14/part_1.csv",  # upload in progress, no marker
        prefix + "old/snapshot_2026_12_01/_SUCCESS",  # not directly under the prefix
    ])
    snapshot = find_latest_complete_snapshot(client, "bucket", prefix)
    assert snapshot.snapshot_date == date(2026, 10, 15)


def test_list_part_blobs_sorts_numerically_and_skips_marker():
    prefix = "waiting_times/medical_assessment/"
    client = FakeStorageClient([
        prefix + "snapshot_2026_10_15/part_10.csv",
        prefix + "snapshot_2026_10_15/part_2.csv",
        prefix + "snapshot_2026_10_15/part_1.csv",
        prefix + "snapshot_2026_10_15/_SUCCESS",
    ])
    snapshot = find_latest_complete_snapshot(client, "bucket", prefix)
    names = [b.name.rsplit("/", 1)[-1] for b in list_part_blobs(client, "bucket", snapshot)]
    assert names == ["part_1.csv", "part_2.csv", "part_10.csv"]
