import os

import dagster as dg

from dagster_project.gcp import BigQueryResource, LandingBucketResource
from dagster_project.kolada import KoladaResource


@dg.definitions
def resources() -> dg.Definitions:
    # No key files: auth uses Application Default Credentials. Locally that is your
    # gcloud user login impersonating the Dagster service account; in production,
    # leave DAGSTER_IMPERSONATE_SA unset and the attached service account is used.
    impersonate = os.getenv("DAGSTER_IMPERSONATE_SA") or None
    project = dg.EnvVar("GCP_PROJECT")
    return dg.Definitions(
        resources={
            "landing": LandingBucketResource(
                project=project,
                bucket=dg.EnvVar("GCS_LANDING_BUCKET"),
                impersonate_service_account=impersonate,
            ),
            "bigquery": BigQueryResource(
                project=project,
                location="EU",
                impersonate_service_account=impersonate,
            ),
            "kolada": KoladaResource(),
        }
    )
