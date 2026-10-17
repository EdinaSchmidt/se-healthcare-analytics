"""Client for the Kolada API v3 (open Swedish municipal and regional KPIs).

Kolada needs no authentication. Responses are paged: each page has `values`
and a `next_url` that is null on the last page.
"""

import time

import dagster as dg
import requests

# Primary care KPIs, scoped to match the waiting-time and NPE sources.
KPIS = {
    # Cost, kr per inhabitant (health centre cost = N71007 - N71020 - N71021 - N71010 - N71011)
    "N71007": "Net cost primary care total, excl. home care and medicines",
    "N71010": "Net cost inpatient primary care",
    "N71011": "Net cost other primary care",
    "N71020": "Net cost child health care (BVC), per total inhabitants",
    "N71021": "Net cost maternal health care (MVC), per total inhabitants",
    "N71018": "Net cost GP care incl. on-call",
    "N71009": "Net cost nurse care",
    "N71017": "Net cost physio- and occupational therapy",
    "N71029": "Region's purchased primary care, share of net cost (%)",
    # Volume, per 1000 inhabitants (excl. MVC/BVC)
    "N71808": "Doctor visits, own production",
    "N71809": "Doctor visits, other providers",
    "N71810": "Non-doctor visits",
    # Access (validation against Socialstyrelsen data)
    "N79173": "Medical assessment within 3 days (%)",
    "N79179": "Phone calls answered same day (%)",
}

RETRY_STATUS_CODES = {429, 500, 502, 503, 504}


class KoladaResource(dg.ConfigurableResource):
    base_url: str = "https://api.kolada.se/v3"
    timeout_seconds: int = 30
    max_retries: int = 4
    pause_seconds: float = 0.2  # be polite to a free public API

    def url(self, path: str) -> str:
        return f"{self.base_url}/{path}"

    def _get_json(self, url: str) -> dict:
        for attempt in range(self.max_retries):
            response = requests.get(url, headers={"Accept": "application/json"}, timeout=self.timeout_seconds)
            if response.status_code in RETRY_STATUS_CODES and attempt < self.max_retries - 1:
                time.sleep(2**attempt)
                continue
            response.raise_for_status()
            return response.json()
        raise RuntimeError(f"Unreachable: retries exhausted for {url}")

    def get_values(self, path: str) -> list[dict]:
        """GET a path and follow next_url, returning the `values` of every page."""
        url, values = self.url(path), []
        while url:
            page = self._get_json(url)
            values.extend(page.get("values", []))
            url = page.get("next_url")
            time.sleep(self.pause_seconds)
        return values


def flatten_kpi_values(records: list[dict]) -> list[dict]:
    """One output row per KPI, municipality/region, period and gender.

    Each API record holds a list of values, one per gender (T = total,
    K = women, M = men). Field names are kept as the API returns them.
    """
    rows = []
    for record in records:
        for item in record.get("values", []):
            rows.append(
                {
                    "kpi": record.get("kpi"),
                    "municipality": record.get("municipality"),
                    "period": record.get("period"),
                    "gender": item.get("gender"),
                    "count": item.get("count"),
                    "status": item.get("status"),
                    "value": item.get("value"),
                    "isdeleted": item.get("isdeleted"),
                }
            )
    return rows
