"""dbt models as Dagster assets.

Lives in src/dagster_project/defs/ so Dagster auto-loads it.
Runs the dbt v2 binary from dbt_project/.venv (never a dbt on PATH).
"""

import os
from pathlib import Path

import dagster as dg
from dagster_dbt import DagsterDbtTranslator, DbtCliResource, dbt_assets

# repo root / dbt_project  (defs -> dagster_project -> src -> dagster_project -> repo root)
DBT_PROJECT_DIR = Path(__file__).resolve().parents[4] / "dbt_project"

# dbt v2 binary inside the dbt project's own uv venv.
# Windows: .venv/Scripts/dbt.exe, Linux/macOS: .venv/bin/dbt. Override with DBT_EXECUTABLE.
_default_exe = (
    DBT_PROJECT_DIR / ".venv" / "Scripts" / "dbt.exe"
    if os.name == "nt"
    else DBT_PROJECT_DIR / ".venv" / "bin" / "dbt"
)
DBT_EXECUTABLE = os.getenv("DBT_EXECUTABLE", str(_default_exe))

# Manifest produced by `uv run dbt parse` in dbt_project/ (see README).
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