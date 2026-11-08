"""dbt models as Dagster assets.

Lives in src/dagster_project/defs/ so Dagster auto-loads it.
Runs the native dbt Fusion binary (installed standalone, not via pip/uv).
Override the location with the DBT_EXECUTABLE env var.
"""

import os
import shutil
from pathlib import Path

import dagster as dg
from dagster_dbt import DagsterDbtTranslator, DbtCliResource, dbt_assets

# repo root / dbt_project  (defs -> dagster_project -> src -> dagster_project -> repo root)
DBT_PROJECT_DIR = Path(__file__).resolve().parents[4] / "dbt_project"

# Native Fusion binary: explicit DBT_EXECUTABLE wins, otherwise the dbt on PATH.
# Don't install the pip `dbt` package into a venv: on Windows it recursively
# spawns `dbt internal get-distribution-info` and can exhaust memory.
DBT_EXECUTABLE = os.getenv("DBT_EXECUTABLE") or shutil.which("dbt")
if not DBT_EXECUTABLE:
    raise RuntimeError(
        "dbt Fusion not found. Install it standalone (see README) "
        "or set DBT_EXECUTABLE to the binary's path."
    )

# Manifest produced by `dbt parse` in dbt_project/ (see README).
DBT_MANIFEST = DBT_PROJECT_DIR / "target" / "manifest.json"

dbt_resource = DbtCliResource(
    project_dir=str(DBT_PROJECT_DIR),
    dbt_executable=DBT_EXECUTABLE,
    target=os.getenv("DBT_TARGET", "dev"),
)


class Translator(DagsterDbtTranslator):
    """Rebuild a dbt asset as soon as any of its upstream assets has new data."""

    def get_automation_condition(self, dbt_resource_props):
        return dg.AutomationCondition.eager()

    def get_group_name(self, dbt_resource_props):
        fqn = dbt_resource_props["fqn"]  # e.g. ['se_healthcare_analytics', 'marts', 'core', 'dim_kpi']
        if dbt_resource_props["resource_type"] == "seed":
            return "seeds"
        return fqn[-2] if len(fqn) > 2 else "dbt"


@dbt_assets(manifest=DBT_MANIFEST, dagster_dbt_translator=Translator())
def dbt_models(context: dg.AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream()


@dg.definitions
def defs() -> dg.Definitions:
    return dg.Definitions(
        assets=[dbt_models],
        resources={"dbt": dbt_resource},
    )