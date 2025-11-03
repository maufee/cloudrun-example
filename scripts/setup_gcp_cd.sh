#!/bin/bash
set -euo pipefail

# --- Helper Functions ---

# Check for gcloud CLI
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        echo "Error: gcloud command not found. Please install the Google Cloud SDK and ensure it's in your PATH." >&2
        exit 1
    fi
}

# Validate input variables
validate_inputs() {
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
}

# Function to idempotently grant a project-level IAM role.
grant_project_iam_binding() {
    local member=$1
    local role=$2

    echo "Ensuring project role '$role' is granted to '$member'..."
    local check
    check=$(gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings" --filter="bindings.role = '$role' AND bindings.members:'$member' AND NOT bindings.condition" --format="value(bindings.role)")
    if [ -z "$check" ]; then gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="$member" --role="$role" --condition=None --no-user-output-enabled > /dev/null; fi
}

# Function to idempotently grant a role on a service account.
grant_sa_iam_binding() {
    local sa_email=$1
    local member=$2
    local role=$3

    echo "Ensuring SA role '$role' is granted to '$member' on '$sa_email'..."
    local check
    check=$(gcloud iam service-accounts get-iam-policy "$sa_email" --project="$PROJECT_ID" --flatten="bindings" --filter="bindings.role = '$role' AND bindings.members:'$member' AND NOT bindings.condition" --format="value(bindings.role)")
    if [ -z "$check" ]; then gcloud iam service-accounts add-iam-policy-binding "$sa_email" --project="$PROJECT_ID" --member="$member" --role="$role" --condition=None --no-user-output-enabled > /dev/null; fi
}

# Enable necessary APIs
enable_apis() {
    echo "Enabling required Google Cloud services..."
    gcloud services enable iam.googleapis.com \
        iamcredentials.googleapis.com \
        cloudresourcemanager.googleapis.com \
        run.googleapis.com \
        --project="$PROJECT_ID"
}

# Create the Service Account if it doesn't exist
create_service_account() {
    echo "Checking for service account: $SERVICE_ACCOUNT"
    gcloud iam service-accounts describe "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" >/dev/null || \
        (echo "Service account not found, creating..." && \
        gcloud iam service-accounts create "$SERVICE_ACCOUNT" \
            --project="$PROJECT_ID" \
            --display-name="GitHub Actions CD Service Account" --no-user-output-enabled)
}

# Grant the Service Account roles to deploy to Cloud Run
grant_roles() {
    echo "Granting roles to service account..."
    local CD_SA_EMAIL="$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
    grant_project_iam_binding "serviceAccount:$CD_SA_EMAIL" "roles/run.developer"

    echo "Granting permission to impersonate the Cloud Run runtime service account..."
    local PROJECT_NUMBER
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
    if [ -z "$PROJECT_NUMBER" ]; then
      echo "Error: Failed to retrieve project number for project '$PROJECT_ID'." >&2
      exit 1
    fi

    if [ -n "${GCP_RUNTIME_SA:-}" ]; then
      echo "Validating provided GCP_RUNTIME_SA: ${GCP_RUNTIME_SA}..."
      if ! gcloud iam service-accounts describe "${GCP_RUNTIME_SA}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
        echo "Error: The service account specified in GCP_RUNTIME_SA ('${GCP_RUNTIME_SA}') does not exist in project '${PROJECT_ID}'." >&2
        exit 1
      fi
    fi

    local RUNTIME_SA_EMAIL="${GCP_RUNTIME_SA:-${PROJECT_NUMBER}-compute@developer.gserviceaccount.com}"

    if [ -z "${GCP_RUNTIME_SA:-}" ]; then
      echo "Verifying default Compute Engine service account (${RUNTIME_SA_EMAIL}) exists..."
      if ! gcloud iam service-accounts describe "${RUNTIME_SA_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
        echo "Error: The default Compute Engine service account was not found." >&2
        echo "This can happen on new projects. Please either:" >&2
        echo "1. Enable the Compute Engine API on project '${PROJECT_ID}' by running:" >&2
        echo "   gcloud services enable compute.googleapis.com --project=\"${PROJECT_ID}\""> &2
        echo "2. Or, create a dedicated runtime service account and provide it via the 'GCP_RUNTIME_SA' environment variable." >&2
        exit 1
      fi
    fi
    grant_sa_iam_binding "$RUNTIME_SA_EMAIL" "serviceAccount:$CD_SA_EMAIL" "roles/iam.serviceAccountUser"
}

# Create a Workload Identity Pool and Provider if they don't exist
create_wif() {
    echo "Checking for Workload Identity Pool 'github-pool'..."
    gcloud iam workload-identity-pools describe "github-pool" --project="$PROJECT_ID" --location="global" >/dev/null || \
        (echo "Pool not found, creating..." && \
        gcloud iam workload-identity-pools create "github-pool" \
            --project="$PROJECT_ID" \
            --location="global" \
            --display-name="GitHub Actions Pool" --no-user-output-enabled)

    POOL_ID=$(gcloud iam workload-identity-pools describe "github-pool" --project="$PROJECT_ID" --location="global" --format="value(name)")
    if [ -z "$POOL_ID" ]; then
        echo "Error: Failed to retrieve Workload Identity Pool ID for 'github-pool'." >&2
        exit 1
    fi

    echo "Checking for Workload Identity Provider '$PROVIDER_ID'..."
    gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" --project="$PROJECT_ID" --location="global" --workload-identity-pool="github-pool" >/dev/null || \
        (echo "Provider not found, creating..." && \
        gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
            --project="$PROJECT_ID" \
            --location="global" \
            --workload-identity-pool="github-pool" \
            --issuer-uri="https://token.actions.githubusercontent.com" \
            --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
            --attribute-condition="attribute.repository == '$REPO'" --no-user-output-enabled)
}

# Allow authentications from your GitHub repo's production environment
allow_auth() {
    echo "Allowing authentications from GitHub repository..."
    local CD_SA_EMAIL="$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"

    local OLD_MEMBER="principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:ref:refs/heads/main"
    local OLD_ROLE="roles/iam.workloadIdentityUser"
    local old_binding_exists
    old_binding_exists=$(gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --flatten="bindings[].members" --filter="bindings.members:'$OLD_MEMBER' AND bindings.role:'$OLD_ROLE'" --format="value(bindings.role)")
    if [ -n "$old_binding_exists" ]; then
        echo "Removing old, less secure WIF binding..."
        gcloud iam service-accounts remove-iam-policy-binding "$SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
            --project="$PROJECT_ID" \
            --role="$OLD_ROLE" \
            --member="$OLD_MEMBER" --no-user-output-enabled
    fi

    grant_sa_iam_binding "$CD_SA_EMAIL" "principal://iam.googleapis.com/$POOL_ID/subject/repo:$REPO:environment:production" "roles/iam.workloadIdentityUser"
}

# Output the values needed for GitHub Secrets
print_results() {
    echo "---"
    echo "Setup complete! Copy these values into your GitHub repository's 'production' environment secrets:"
    echo "GCP_PROJECT_ID: $PROJECT_ID"
    local WIF_PROVIDER
    WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
        --project="$PROJECT_ID" \
        --location="global" \
        --workload-identity-pool="github-pool" \
        --format="value(name)")
    echo "GCP_WORKLOAD_IDENTITY_PROVIDER: $WIF_PROVIDER"
    echo "GCP_SERVICE_ACCOUNT: $SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
}

# --- Main Execution ---

main() {
    check_gcloud

    # --- Configuration ---
    if [ -z "${PROJECT_ID:-}" ]; then
      echo "Error: PROJECT_ID environment variable is not set." >&2
      echo "Please set it (e.g., export PROJECT_ID=\"your-gcp-project-id\") and re-run the script." >&2
      exit 1
    fi

    if [ -z "${REPO:-}" ]; then
      echo "Error: REPO environment variable is not set." >&2
      echo "Please set it (e.g., export REPO=\"your-github-username/your-repo-name\") and re-run the script." >&2
      exit 1
    fi

    SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-github-cd-sa}"
    if command -v sha256sum >/dev/null; then
        PROVIDER_HASH=$(echo -n "$REPO" | sha256sum | cut -c1-25)
    elif command -v shasum >/dev/null; then
        PROVIDER_HASH=$(echo -n "$REPO" | shasum -a 256 | cut -c1-25)
    else
        echo "Error: 'sha256sum' or 'shasum' command not found. Please install one to continue." >&2
        exit 1
    fi
    PROVIDER_ID="gh-p-${PROVIDER_HASH}"

    validate_inputs

    echo "--- Google Cloud CD Setup ---"
    echo "Project ID: ${PROJECT_ID}"
    echo "Repository: ${REPO}"
    echo "Service Account: ${SERVICE_ACCOUNT}"
    echo "Provider ID: ${PROVIDER_ID}"
    echo "---------------------------"

    enable_apis
    create_service_account
    grant_roles
    create_wif
    allow_auth
    print_results
}

main "$@"
