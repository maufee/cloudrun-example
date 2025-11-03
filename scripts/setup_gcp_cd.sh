#!/bin/bash
set -euo pipefail
# Check for gcloud CLI
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud command not found. Please install the Google Cloud SDK and ensure it's in your PATH." >&2
    exit 1
fi

# Description: This script performs the one-time setup in a Google Cloud project
# to enable Continuous Deployment from a GitHub repository using Workload Identity Federation.

# --- Configuration ---
# These values must be set as environment variables before running the script.
# SERVICE_ACCOUNT is optional and defaults to "github-cd-sa".

# Check and set PROJECT_ID
if [ -z "${PROJECT_ID}" ]; then
  echo "Error: PROJECT_ID environment variable is not set." >&2
  echo "Please set it (e.g., export PROJECT_ID=\"your-gcp-project-id\") and re-run the script." >&2
  exit 1
fi

# Check and set REPO
if [ -z "${REPO}" ]; then
  echo "Error: REPO environment variable is not set." >&2
  echo "Please set it (e.g., export REPO=\"your-github-username/your-repo-name\") and re-run the script." >&2
  exit 1
fi

# Set SERVICE_ACCOUNT with a default if not provided
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-github-cd-sa}"

# --- Validate Inputs ---
# Basic validation to prevent command injection.
if ! [[ "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    echo "Error: Invalid PROJECT_ID format." >&2
    exit 1
fi
if ! [[ "$REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
    echo "Error: Invalid REPO format. Expected 'owner/repository'." >&2
    exit 1
fi
if ! [[ "$SERVICE_ACCOUNT" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    echo "Error: Invalid SERVICE_ACCOUNT format." >&2
    exit 1
fi

echo "--- Google Cloud CD Setup ---"
echo "Project ID: ${PROJECT_ID}"
echo "Repository: ${REPO}"
echo "Service Account: ${SERVICE_ACCOUNT}"
echo "---------------------------"

# --- Script Body ---

# 1. Enable necessary APIs
echo "Enabling required Google Cloud services..."
gcloud services enable iam.googleapis.com \
    iamcredentials.googleapis.com \
    cloudresourcemanager.googleapis.com \
    run.googleapis.com \
    --project="$PROJECT_ID"

# 2. Create the Service Account if it doesn't exist
echo "Checking for service account: $SERVICE_ACCOUNT"
gcloud iam service-accounts describe "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null || \
    (echo "Service account not found, creating..." && \
    gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
        --project="$PROJECT_ID" \
        --display-name="GitHub Actions CD Service Account")

# 3. Grant the Service Account roles to deploy to Cloud Run
echo "Granting roles to service account..."

# Function to idempotently grant a project-level IAM role.
grant_project_iam_binding() {
    local member=$1
    local role=$2

    echo "Ensuring project role '$role' is granted to '$member'..."
    if ! gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.role='$role' AND bindings.members:'$member'" --format="value(bindings.role)" | grep -q "."; then
        gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$member" --role="$role" --condition=None > /dev/null
    fi
}

# Function to idempotently grant a role on a service account.
grant_sa_iam_binding() {
    local sa_email=$1
    local member=$2
    local role=$3

    echo "Ensuring SA role '$role' is granted to '$member' on '$sa_email'..."
    if ! gcloud iam service-accounts get-iam-policy "$sa_email" --project="$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.role='$role' AND bindings.members:'$member'" --format="value(bindings.role)" | grep -q "."; then
        gcloud iam service-accounts add-iam-policy-binding "$sa_email" --project="$PROJECT_ID" --member="$member" --role="$role" --condition=None > /dev/null
    fi
}

CD_SA_EMAIL="$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
grant_project_iam_binding "serviceAccount:$CD_SA_EMAIL" "roles/run.developer"

# Grant the CD service account permission to act as the Cloud Run runtime service account
# This is required for new revisions of the service to be able to start.
echo "Granting permission to impersonate the Cloud Run runtime service account..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
# Default to the Compute Engine default SA, but allow overriding via an environment variable.
RUNTIME_SA_EMAIL="${GCP_RUNTIME_SA:-${PROJECT_NUMBER}-compute@developer.gserviceaccount.com}"
grant_sa_iam_binding "$RUNTIME_SA_EMAIL" "serviceAccount:$CD_SA_EMAIL" "roles/iam.serviceAccountUser"


# 4. Create a Workload Identity Pool and Provider if they don't exist
echo "Checking for Workload Identity Pool 'github-pool'..."
gcloud iam workload-identity-pools describe "github-pool" --project="$PROJECT_ID" --location="global" >/dev/null || \
    (echo "Pool not found, creating..." && \
    gcloud iam workload-identity-pools create "github-pool" \
        --project="$PROJECT_ID" \
        --location="global" \
        --display-name="GitHub Actions Pool")

POOL_ID=$(gcloud iam workload-identity-pools describe "github-pool" --project="$PROJECT_ID" --location="global" --format="value(name)")

echo "Checking for Workload Identity Provider 'github-provider'..."
gcloud iam workload-identity-pools providers describe "github-provider" --project="$PROJECT_ID" --location="global" --workload-identity-pool="github-pool" >/dev/null || \
    (echo "Provider not found, creating..." && \
    gcloud iam workload-identity-pools providers create-oidc "github-provider" \
        --project="$PROJECT_ID" \
        --location="global" \
        --workload-identity-pool="github-pool" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
        --attribute-condition="attribute.repository != ''")

# 5. Allow authentications from your GitHub repo's production environment
echo "Allowing authentications from GitHub repository..."

# Remove old, less secure binding if it exists
OLD_MEMBER="principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:ref:refs/heads/main"
OLD_ROLE="roles/iam.workloadIdentityUser"
if gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:'$OLD_MEMBER' AND bindings.role:'$OLD_ROLE'" --format="value(bindings.role)" | grep -q "."; then
    echo "Removing old, less secure WIF binding..."
    gcloud iam service-accounts remove-iam-policy-binding "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
        --project="$PROJECT_ID" \
        --role="$OLD_ROLE" \
        --member="$OLD_MEMBER"
fi

# Add new, more secure binding if it doesn't exist
grant_sa_iam_binding "$CD_SA_EMAIL" "principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:environment:production" "roles/iam.workloadIdentityUser"


# 6. Output the values needed for GitHub Secrets
echo "---"
echo "Setup complete! Copy these values into your GitHub repository's 'production' environment secrets:"
echo "GCP_PROJECT_ID: $PROJECT_ID"
WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe "github-provider" \
    --project="$PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --format="value(name)")
echo "GCP_WORKLOAD_IDENTITY_PROVIDER: $WIF_PROVIDER"
echo "GCP_SERVICE_ACCOUNT: $SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
