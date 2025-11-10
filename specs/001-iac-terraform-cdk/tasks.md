# Tasks: Adopt Infrastructure as Code with Terraform CDK

**Input**: Design documents from `/specs/001-iac-terraform-cdk/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No functional tests were requested, but validation tasks are included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Paths shown below assume single project structure.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create the `iac/` directory for the Terraform CDK application.
- [x] T002 Create a `pyproject.toml` file in the `iac/` directory with `cdktf` and `google-auth` as dependencies.
- [x] T003 Create a `.gitignore` file in the `iac/` directory to ignore terraform state and cache files (`.terraform/`, `cdktf.out/`, `terraform.tfstate*`).

---

## Phase 2: User Story 1 - Migrate to IaC (Priority: P1) 🎯 MVP

**Goal**: Manage all GCP resources using a Terraform CDK Python application.

**Independent Test**: The `cdktf deploy` command successfully creates all required infrastructure in a GCP project.

### Implementation for User Story 1

- [x] T004 [US1] Create the main application file `iac/main.py`.
- [x] T005 [US1] In `iac/main.py`, implement input handling to read `PROJECT_ID`, `REPO`, and optional `GCP_RUNTIME_SA` from environment variables.
- [x] T006 [US1] In `iac/main.py`, implement the SHA256 hash logic to generate the Workload Identity Provider ID from the `REPO` variable.
- [x] T007 [US1] In `iac/main.py`, implement the logic to determine the runtime service account email (use `GCP_RUNTIME_SA` if provided, otherwise construct the default Compute Engine SA email).
- [x] T008 [US1] In `iac/main.py`, implement the code to enable all required GCP APIs (`iam.googleapis.com`, `iamcredentials.googleapis.com`, `cloudresourcemanager.googleapis.com`, `run.googleapis.com`, and `compute.googleapis.com`).
- [x] T009 [P] [US1] In `iac/main.py`, implement the code to create the `github-cd-sa` service account.
- [x] T010 [P] [US1] In `iac/main.py`, implement the code to create the `cloud-build-sa` service account.
- [x] T011 [P] [US1] In `iac/main.py`, implement the code to create the `githubCdDeployer` custom IAM role.
- [x] T012 [P] [US1] In `iac/main.py`, implement the code to create the `github-pool` Workload Identity Pool.
- [x] T013 [US1] In `iac/main.py`, implement the code to create the Workload Identity Provider, dependent on T012.
- [x] T014 [US1] In `iac/main.py`, grant the following project-level IAM roles to the `github-cd-sa`: `roles/artifactregistry.writer`, `roles/cloudbuild.builds.editor`, `roles/storage.admin`, `roles/serviceusage.serviceUsageConsumer`, and the custom `githubCdDeployer` role.
- [x] T015 [US1] In `iac/main.py`, grant the following project-level IAM roles to the `cloud-build-sa`: `roles/artifactregistry.writer`, `roles/iam.serviceAccountUser`, `roles/storage.objectViewer`, and the custom `githubCdDeployer` role.
- [x] T016 [US1] In `iac/main.py`, grant the `roles/serviceusage.serviceUsageConsumer` role to the default Cloud Build service account.
- [x] T017 [US1] In `iac/main.py`, grant the `roles/iam.serviceAccountUser` role to both `github-cd-sa` and `cloud-build-sa` on the runtime service account.
- [x] T018 [US1] In `iac/main.py`, grant the `roles/iam.workloadIdentityUser` role to the Workload Identity principal on the `github-cd-sa`.

---

## Phase 3: Validation (Post-MVP)

**Goal**: Verify that the IaC deployment created the necessary resources correctly.

- [x] T019 [P] Add a validation step to the CI workflow (or a local script) to verify the existence of the `github-cd-sa` service account using `gcloud iam service-accounts describe`.
- [x] T020 [P] Add a validation step to verify the existence of the `githubCdDeployer` custom role using `gcloud iam roles describe`.
- [x] T021 [P] Add a validation step to verify the Workload Identity Pool and Provider exist using `gcloud iam workload-identity-pools describe` and `gcloud iam workload-identity-pools providers describe`.

---

## Phase 4: User Story 2 - Update Documentation (Priority: P2)

**Goal**: Update all project documentation to reflect the new IaC process.

**Independent Test**: A new developer can follow the `README.md` to successfully set up the project infrastructure.

### Implementation for User Story 2

- [x] T022 [P] [US2] Update `README.md` to replace the section on running `setup_gcp_cd.sh` with the new instructions for setting up and running the Terraform CDK application from `quickstart.md`.
- [x] T023 [P] [US2] Update `GEMINI.md` to describe the new IaC process using Terraform CDK instead of the shell script.

---

## Phase 5: User Story 3 - Update Constitution (Priority: P3)

**Goal**: Update the project constitution to include "Infrastructure as Code" as a core principle.

**Independent Test**: The `.specify/memory/constitution.md` file contains the new principle.

### Implementation for User Story 3

- [x] T024 [US3] Amend `.specify/memory/constitution.md` to add a new core principle for "Infrastructure as Code", stating that all infrastructure MUST be managed declaratively using version-controlled code.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup and project-wide updates.

- [x] T025 Delete the old setup script at `scripts/setup_gcp_cd.sh`.
- [x] T026 Generate and sync a `requirements.txt` file within the `iac/` directory using `uv pip compile`.
