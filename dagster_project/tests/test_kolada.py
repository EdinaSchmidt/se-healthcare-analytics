from unittest import mock

from dagster_project.kolada import KoladaResource, flatten_kpi_values


def test_flatten_kpi_values_one_row_per_gender():
    records = [
        {
            "kpi": "N79173",
            "municipality": "0001",
            "period": 2024,
            "values": [
                {"gender": "T", "count": 1, "status": "", "value": 81.2, "isdeleted": False},
                {"gender": "K", "count": 1, "status": "", "value": 80.1, "isdeleted": False},
                {"gender": "M", "count": 1, "status": "", "value": None, "isdeleted": False},
            ],
        }
    ]
    rows = flatten_kpi_values(records)
    assert [r["gender"] for r in rows] == ["T", "K", "M"]
    assert all(r["kpi"] == "N79173" and r["municipality"] == "0001" and r["period"] == 2024 for r in rows)
    assert rows[2]["value"] is None


def test_get_values_follows_next_url():
    pages = {
        "https://api.kolada.se/v3/municipality": {"values": [{"id": "0001"}], "next_url": "https://next"},
        "https://next": {"values": [{"id": "0003"}], "next_url": None},
    }
    response = lambda url, **kwargs: mock.Mock(status_code=200, json=lambda: pages[url], raise_for_status=lambda: None)
    with mock.patch("dagster_project.kolada.requests.get", side_effect=response):
        values = KoladaResource(pause_seconds=0).get_values("municipality")
    assert [v["id"] for v in values] == ["0001", "0003"]


def test_get_values_retries_on_rate_limit():
    responses = iter([
        mock.Mock(status_code=429),
        mock.Mock(status_code=200, json=lambda: {"values": [{"id": "0001"}], "next_url": None}, raise_for_status=lambda: None),
    ])
    with mock.patch("dagster_project.kolada.requests.get", side_effect=lambda url, **kw: next(responses)), \
         mock.patch("dagster_project.kolada.time.sleep"):
        assert KoladaResource().get_values("municipality") == [{"id": "0001"}]
