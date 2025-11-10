# Feature Specification: Adopt Infrastructure as Code with Terraform CDK

**Feature Branch**: `001-iac-terraform-cdk`
**Created**: 2025-11-09
**Status**: Draft
**Input**: User description: "Adopt Infrastructure as Code Principle for this project. Use terraform-cdk Python SDK for Google Cloud. Migrate all setup from @setup_gcp_cd.sh to Python code using terraform-cdk. Update all related documents like @README.md @GEMINI.md and @.specify/memory/constitution.md for the new process."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Migrate to IaC (Priority: P1)

As a project maintainer, I want to manage all GCP resources using a Terraform CDK Python application so that the infrastructure setup is automated, version-controlled, and repeatable.

**Why this priority**: This is the core of the feature and enables all other benefits.

**Independent Test**: The Terraform CDK app can be run to deploy all required infrastructure to a new GCP project, and the CI/CD pipeline successfully runs on that infrastructure.

**Acceptance Scenarios**:

1. **Given** a GCP project, **When** the `cdktf deploy` command is run, **Then** all required Service Accounts, IAM roles, and Workload Identity Federation resources are created.
2. **Given** the infrastructure is deployed, **When** a commit is pushed to `main`, **Then** the existing CI/CD pipeline successfully deploys the application.

---

### User Story 2 - Update Documentation (Priority: P2)

As a new developer, I want to follow updated instructions in the `README.md` to set up the project's infrastructure so that I can get the project running without using outdated scripts.

**Why this priority**: Accurate documentation is crucial for onboarding and project maintenance.

**Independent Test**: A developer can follow the new instructions in `README.md` to deploy the infrastructure.

**Acceptance Scenarios**:

1. **Given** the `README.md`, **When** a developer follows the infrastructure setup guide, **Then** they can successfully deploy the infrastructure using the Terraform CDK application.

---

### User Story 3 - Update Constitution (Priority: P3)

As a project member, I want the project constitution to reflect the "Infrastructure as Code" principle so that all future development adheres to this standard.

**Why this priority**: This codifies the new best practice for the project's governance.

**Independent Test**: The `.specify/memory/constitution.md` file contains the new principle.

**Acceptance Scenarios**:

1. **Given** the project constitution, **When** viewed, **Then** it includes "Infrastructure as Code" as a core principle.

---

### Edge Cases

- What happens when the `cdktf deploy` command fails? The process should provide clear error messages from Terraform.
- How are infrastructure changes reviewed? Changes to the IaC code will be reviewed via pull requests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A Terraform CDK application MUST be created using the Python SDK.
- **FR-002**: The application MUST define all GCP resources currently created by `scripts/setup_gcp_cd.sh`.
- **FR-003**: The `scripts/setup_gcp_cd.sh` script MUST be deleted.
- **FR-004**: The `README.md` file MUST be updated to remove references to the old script and add instructions for using the Terraform CDK application.
- **FR-005**: The `GEMINI.md` file MUST be updated to reflect the new IaC process.
- **FR-006**: The `.specify/memory/constitution.md` file MUST be amended to add "Infrastructure as Code" as a new principle.
- **FR-007**: The Terraform CDK application MUST ensure all necessary GCP APIs (e.g., Cloud Run API, IAM API, Cloud Build API) are enabled in the project.

### Key Entities *(include if feature involves data)*

- GCP Service Account (`github-cd-sa` for GitHub Actions)
- GCP Service Account (`cloud-build-sa` for Cloud Build)
- GCP Custom IAM Role
- GCP Workload Identity Pool
- GCP Workload Identity Provider

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The time to set up the required GCP infrastructure is reduced to a single `cdktf deploy` command.
- **SC-002**: All infrastructure changes are visible and auditable through git history.
- **SC-003**: The project's CI/CD pipeline remains fully functional with the new infrastructure management.
- **SC-004**: Project documentation for infrastructure setup is clear and accurate.