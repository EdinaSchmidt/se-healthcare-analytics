"""Sensor factory shared by all snapshot-based landing sources."""

import dagster as dg

from dagster_project.gcp import LandingBucketResource
from dagster_project.landing import find_latest_complete_snapshot

DAILY = 24 * 60 * 60


def build_snapshot_sensor(
    name: str,
    prefix: str,
    target: dg.AssetsDefinition,
    minimum_interval_seconds: int = DAILY,
) -> dg.SensorDefinition:
    """Request one run per new complete snapshot (folder with _SUCCESS) under `prefix`."""

    @dg.sensor(
        name=name,
        target=target,
        minimum_interval_seconds=minimum_interval_seconds,
        description=f"Loads the newest complete snapshot under {prefix}",
    )
    def _sensor(context: dg.SensorEvaluationContext, landing: LandingBucketResource):
        snapshot = find_latest_complete_snapshot(landing.get_client(), landing.bucket, prefix)
        if snapshot is None:
            return dg.SkipReason("No complete snapshot yet")

        snapshot_id = snapshot.snapshot_date.isoformat()
        if context.cursor == snapshot_id:
            return dg.SkipReason(f"Latest snapshot {snapshot_id} already requested")

        context.update_cursor(snapshot_id)
        return dg.RunRequest(run_key=f"{name}:{snapshot_id}")

    return _sensor
