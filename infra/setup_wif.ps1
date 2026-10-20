# One-time setup: let GitHub Actions in EdinaSchmidt/se-healthcare-analytics act as dbt-sa without a key.
# Run in PowerShell, logged in with gcloud as your own user (project owner).

$PROJECT_ID = "se-healthcare-analytics"
$REPO       = "EdinaSchmidt/se-healthcare-analytics"
$DBT_SA     = "dbt-sa@$PROJECT_ID.iam.gserviceaccount.com"
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"

# APIs needed for token exchange and impersonation
gcloud services enable iamcredentials.googleapis.com sts.googleapis.com --project=$PROJECT_ID

# Pool for GitHub
gcloud iam workload-identity-pools create github `
  --project=$PROJECT_ID --location=global --display-name="GitHub Actions"

# Provider that trusts GitHub's OIDC tokens, restricted to this one repository
gcloud iam workload-identity-pools providers create-oidc se-healthcare-analytics `
  --project=$PROJECT_ID --location=global --workload-identity-pool=github `
  --display-name="se-healthcare-analytics repo" `
  --issuer-uri="https://token.actions.githubusercontent.com" `
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" `
  --attribute-condition="assertion.repository=='$REPO'"

# Allow workflows from this repository to act as dbt-sa
gcloud iam service-accounts add-iam-policy-binding $DBT_SA --project=$PROJECT_ID `
  --role="roles/iam.workloadIdentityUser" `
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/$REPO"

# The prod target impersonates dbt-sa. In CI the job already IS dbt-sa,
# so dbt-sa needs permission to mint tokens for itself.
gcloud iam service-accounts add-iam-policy-binding $DBT_SA --project=$PROJECT_ID `
  --role="roles/iam.serviceAccountTokenCreator" `
  --member="serviceAccount:$DBT_SA"

# Values for the GitHub repository variables
Write-Host ""
Write-Host "GCP_WIF_PROVIDER = projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/se-healthcare-analytics"
Write-Host "GCP_DBT_SA       = $DBT_SA"