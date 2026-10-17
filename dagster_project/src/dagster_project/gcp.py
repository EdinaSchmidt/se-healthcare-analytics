"""GCP resources that authenticate without key files.

Credentials come from Application Default Credentials (ADC):
- locally: your own user login (`gcloud auth application-default login`),
  used to impersonate the pipeline's service account;
- in production (Cloud Run, a VM, GKE): the attached service account,
  so `impersonate_service_account` is left empty.
"""

from collections.abc import Iterator
from contextlib import contextmanager

import dagster as dg
import google.auth
from google.auth import impersonated_credentials
from google.auth.credentials import Credentials
from google.cloud import bigquery, storage

CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform"


class GcpResource(dg.ConfigurableResource):
    project: str
    impersonate_service_account: str | None = None

    def get_credentials(self) -> Credentials:
        source, _ = google.auth.default(scopes=[CLOUD_PLATFORM_SCOPE])
        if not self.impersonate_service_account:
            return source
        return impersonated_credentials.Credentials(
            source_credentials=source,
            target_principal=self.impersonate_service_account,
            target_scopes=[CLOUD_PLATFORM_SCOPE],
        )


class LandingBucketResource(GcpResource):
    """The GCS bucket where manually downloaded extracts are dropped."""

    bucket: str

    def get_client(self) -> storage.Client:
        return storage.Client(project=self.project, credentials=self.get_credentials())


class BigQueryResource(GcpResource):
    location: str = "EU"

    @contextmanager
    def get_client(self) -> Iterator[bigquery.Client]:
        client = bigquery.Client(
            project=self.project, location=self.location, credentials=self.get_credentials()
        )
        try:
            yield client
        finally:
            client.close()
