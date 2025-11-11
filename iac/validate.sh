#!/bin/bash
set -euo pipefail

echo "--- Validating IaC Deployment ---"

if [ -z "${PROJECT_ID:-}" ]; then
  echo "Error: PROJECT_ID environment variable is not set." >&2
  exit 1
fi

echo "Verifying 'github-cd-sa' service account..."
gcloud iam service-accounts describe "github-cd-sa@${PROJECT_ID}.iam.gserviceaccount.com" --project="${PROJECT_ID}" >/dev/null
echo "✅ 'github-cd-sa' service account exists."

echo "Verifying 'githubCdDeployer' custom role..."
gcloud iam roles describe "githubCdDeployer" --project="${PROJECT_ID}" >/dev/null
echo "✅ 'githubCdDeployer' custom role exists."

echo "Verifying Workload Identity Pool and Provider..."
if [ -z "${REPO:-}" ]; then
  echo "Error: REPO environment variable is not set." >&2
  exit 1
fi
gcloud iam workload-identity-pools describe "github-pool" --project="${PROJECT_ID}" --location="global" >/dev/null
echo "✅ 'github-pool' Workload Identity Pool exists."

if command -v sha256sum >/dev/null 2>&1; then
    sha_cmd="sha256sum"
else
    sha_cmd="shasum -a 256"
fi
PROVIDER_ID="gh-p-$(echo -n "$REPO" | $sha_cmd | cut -c1-25)"
gcloud iam workload-identity-pools providers describe "${PROVIDER_ID}" --project="${PROJECT_ID}" --location="global" --workload-identity-pool="github-pool" >/dev/null
echo "✅ Workload Identity Provider for repo '${REPO}' exists."

