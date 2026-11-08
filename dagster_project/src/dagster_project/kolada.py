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
    # Population on 31 December; N01951 is the denominator of the per-inhabitant KPIs above
    "N01951": "Inhabitants, total",
    "N01938": "Inhabitants 65+",
    "N01960": "Inhabitants 65+, share (%)",
    "N01957": "Inhabitants 80+",
    "N01813": "Inhabitants 80+, share (%)",
    # SCB population projections, stored under their base year (new base year every third year).
    # 65+ is only projected 5 years ahead; the 10-year age bands are 67-79 and 80+.
    "N02907": "Projected inhabitants in 5 years",
    "N02912": "Projected inhabitants 65+ in 5 years",
    "N02914": "Projected inhabitants 80+ in 5 years",
    "N02834": "Projected inhabitants in 10 years",
    "N02837": "Projected inhabitants 80+ in 10 years",
    # Care need and health (CNI 1 = national level; no row for the whole country)
    "N00992": "Care Need Index (CNI)",
    "N00923": "Life expectancy, men (5-year average)",
    "N00925": "Life expectancy, women (5-year average)",
    # Public opinion, Hälso- och sjukvårdsbarometern (residents, not only patients)
    "U70450": "Reasonable waiting time to health centre (%)",
    "U71458": "Trust in health centres (%)",
    # Workforce: region employees in November, so staff of private providers are excluded.
    # No data for Gotland; gaps for Norrbotten, Skåne and Östergötland in some years.
    "N71200": "Permanent monthly-paid staff (%)",
    "N71201": "Temporary monthly-paid staff (%)",
    "N71202": "Temporary hourly-paid staff (%)",
    "N71204": "Hours worked by temporary monthly-paid staff (%)",
    "N71205": "Hours worked by temporary hourly-paid staff (%)",
    "N71206": "Employed full time (%)",
    "N71207": "Employed part time 75-99 % (%)",
    "N71208": "Employed part time 1-74 % (%)",
    "N71209": "Working full time (%)",
    "N71210": "Working part time 75-99 % (%)",
    "N71211": "Working part time 1-74 % (%)",
    "N71212": "Staff aged 34 or younger (%)",
    "N71213": "Staff aged 35-54 (%)",
    "N71214": "Staff aged 55+ (%)",
    "N71218": "Staff aged 55-64 (%)",
    "N71219": "Staff aged 65+ (%)",
    "N71217": "Foreign-born staff vs population, balance ratio",
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
