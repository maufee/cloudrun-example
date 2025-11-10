# Data Model: GCP Resources

This document lists the Google Cloud Platform resources that will be managed by the Terraform CDK application. These entities correspond to the resources currently created by the `scripts/setup_gcp_cd.sh` script.

## Entities

- **GCP Project Services**
  - Description: The necessary GCP APIs that must be enabled to allow the creation and management of other resources.
  - Attributes:
    - `iam.googleapis.com`
    - `iamcredentials.googleapis.com`
    - `cloudresourcemanager.googleapis.com`
    - `run.googleapis.com`
    - `compute.googleapis.com` (conditionally enabled for default runtime SA)

- **CD Service Account (`github-cd-sa`)**
  - Description: An IAM Service Account for the GitHub Actions workflow to authenticate with Google Cloud.
  - Type: `google_service_account`

- **Build Service Account (`cloud-build-sa`)**
  - Description: An IAM Service Account for the Cloud Build process to execute the build and deployment.
  - Type: `google_service_account`

- **Custom IAM Role (`githubCdDeployer`)**
  - Description: A custom IAM role with the minimal permissions required to deploy a new version of a Cloud Run service.
  - Permissions:
    - `run.services.get`
    - `run.services.update`
  - Type: `google_project_iam_custom_role`

- **Workload Identity Federation**
  - Description: A pool and provider to trust the GitHub Actions OIDC provider, allowing keyless authentication.
  - Components:
    - Workload Identity Pool (`github-pool`)
    - Workload Identity Provider (dynamically named based on repo hash)
  - Type: `google_iam_workload_identity_pool`, `google_iam_workload_identity_pool_provider`

- **Cloud Run Runtime Service Account**
  - Description: The service account that the Cloud Run service uses at runtime. Can be a custom SA or the default Compute Engine SA.

## Relationships and IAM Bindings

### `github-cd-sa` (GitHub Actions CD Service Account)

- **Project-level roles:**
  - `projects/<PROJECT_ID>/roles/githubCdDeployer` (Custom role)
  - `roles/artifactregistry.writer`
  - `roles/cloudbuild.builds.editor`
  - `roles/storage.admin`
  - `roles/serviceusage.serviceUsageConsumer`
- **Service Account-level roles (on Cloud Run Runtime SA):**
  - `roles/iam.serviceAccountUser` (allows impersonation of the runtime SA)
- **Workload Identity User (on `github-cd-sa` itself):**
  - `roles/iam.workloadIdentityUser` (for the GitHub Actions principal)

### `cloud-build-sa` (Cloud Build Service Account)

- **Project-level roles:**
  - `roles/artifactregistry.writer`
  - `projects/<PROJECT_ID>/roles/githubCdDeployer` (Custom role)
  - `roles/iam.serviceAccountUser`
  - `roles/storage.objectViewer`
- **Service Account-level roles (on Cloud Run Runtime SA):**
  - `roles/iam.serviceAccountUser` (allows impersonation of the runtime SA)

### Default Cloud Build Service Account (`<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com`)

- **Project-level roles:**
  - `roles/serviceusage.serviceUsageConsumer`

### Workload Identity Provider

- Configured to allow principals from the specified GitHub repository (`repo:<REPO>:environment:production`) to impersonate the `github-cd-sa`.