# Implementation Plan: Adopt Infrastructure as Code with Terraform CDK

**Branch**: `001-iac-terraform-cdk` | **Date**: 2025-11-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/Users/feima/workspace/cloudrun-example/specs/001-iac-terraform-cdk/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

This plan outlines the migration of the project's GCP infrastructure setup from a shell script to an Infrastructure as Code (IaC) approach using the Terraform CDK for Python. This will make the infrastructure definition declarative, version-controlled, and more maintainable.

## Technical Context

**Language/Version**: Python 3.13
**Primary Dependencies**: `terraform-cdk`, `google-auth` (managed via `pyproject.toml` optional `iac` dependency group)
**Storage**: N/A
**Testing**: `pytest`
**Target Platform**: Google Cloud
**Project Type**: Single project
**Performance Goals**: N/A
**Constraints**: Must be functionally equivalent to the existing `setup_gcp_cd.sh` script.
**Scale/Scope**: Manages the CI/CD infrastructure for a single web application.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This plan introduces a new "Infrastructure as Code" principle, which strengthens the existing "Production-Ready Deployment" and "Automated CI/CD" principles. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-iac-terraform-cdk/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
```text
iac/
├── main.py
└── .gitignore
```

**Structure Decision**: A new `iac/` directory will be created at the root of the project to house the Terraform CDK application. This keeps the infrastructure code separate from the application code.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A       | N/A        | N/A                                 |