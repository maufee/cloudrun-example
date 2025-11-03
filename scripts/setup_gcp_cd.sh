#!/bin/bash
set -euo pipefail

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
gcloud iam service-accounts describe "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" &>/dev/null || \
    (echo "Service account not found, creating..." && \
    gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
        --project="$PROJECT_ID" \
        --display-name="GitHub Actions CD Service Account")

# 3. Grant the Service Account roles to deploy to Cloud Run
echo "Granting roles to service account..."

# Function to grant IAM policy binding if it doesn't exist
grant_iam_binding() {
    local member=$1
    local role=$2
    local is_project_level=$3
    local policy_exists=false

    if [ "$is_project_level" = true ]; then
        if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:'$member' AND bindings.role='$role'" --format="value(bindings.role)" | grep -q "."; then
            policy_exists=true
        fi
    else
        if gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:'$member' AND bindings.role='$role'" --format="value(bindings.role)" | grep -q "."; then
            policy_exists=true
        fi
    fi

    if [ "$policy_exists" = false ]; then
        echo "Adding $role..."
        if [ "$is_project_level" = true ]; then
            gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$member" --role="$role" --condition=None > /dev/null
        else
            gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --member="$member" --role="$role" > /dev/null
        fi
    else
        echo "$role binding already exists, skipping."
    fi
}

grant_iam_binding "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" "roles/run.developer" true
grant_iam_binding "serviceAccount:$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" "roles/iam.serviceAccountUser" true


# 4. Create a Workload Identity Pool and Provider if they don't exist
echo "Checking for Workload Identity Pool 'github-pool'..."
gcloud iam workload-identity-pools describe "github-pool" --project="$PROJECT_ID" --location="global" &>/dev/null || \
    (echo "Pool not found, creating..." && \
    gcloud iam workload-identity-pools create "github-pool" \
        --project="$PROJECT_ID" \
        --location="global" \
        --display-name="GitHub Actions Pool")

POOL_ID=$(gcloud iam workload-identity-pools describe "github-pool" --project="$PROJECT_ID" --location="global" --format="value(name)")

echo "Checking for Workload Identity Provider 'github-provider'..."
gcloud iam workload-identity-pools providers describe "github-provider" --project="$PROJECT_ID" --location="global" --workload-identity-pool="github-pool" &>/dev/null || \
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
if gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members='principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:ref:refs/heads/main' AND bindings.role='roles/iam.workloadIdentityUser'" --format="value(bindings.role)" | grep -q "."; then
    echo "Removing old, less secure WIF binding..."
    gcloud iam service-accounts remove-iam-policy-binding "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
        --project="$PROJECT_ID" \
        --role="roles/iam.workloadIdentityUser" \
        --member="principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:ref:refs/heads/main"
fi

# Add new, more secure binding if it doesn't exist
grant_iam_binding "principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:environment:production" "roles/iam.workloadIdentityUser" false


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
