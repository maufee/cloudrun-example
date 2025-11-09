# Python Flask Web App on Google Cloud Run Constitution

## Core Principles

### I. Production-Ready Deployment
Every change MUST be suitable for a production deployment on Google Cloud Run. The application MUST use `gunicorn` for production serving, configured via a `Procfile`. Source-based deployment via Cloud Buildpacks is the standard method.

### II. Robust Dependency Management
Project dependencies MUST be managed using `uv`. Local development environments are defined by `pyproject.toml` and locked with `uv.lock`. Production dependencies for Cloud Run MUST be generated into `requirements.txt` from the locked configuration to ensure consistency.

### III. Mandatory Quality Gates
All code MUST pass linting with `ruff` and testing with `pytest` before being merged. Test coverage MUST meet the minimum threshold defined in `pyproject.toml`. Tests SHOULD include timeouts to prevent indefinite runs in CI.

### IV. Automated CI/CD
The project MUST maintain a fully automated Continuous Integration (CI) and Continuous Deployment (CD) pipeline using GitHub Actions. All pushes to the `main` branch that pass CI checks MUST be automatically deployed to production.

### V. Security First
Development practices MUST prioritize security. Flask's debug mode MUST NEVER be enabled in a production environment. All security warnings and best practices mentioned in the documentation are non-negotiable.

## Development and Deployment Standards

Local development SHOULD use the Flask development server with debug mode enabled for productivity. The production environment MUST be mimicked locally using `gunicorn`. Deployment to Google Cloud Run is performed using the `gcloud run deploy --source .` command, which relies on the `Procfile` and `requirements.txt`.

## Contribution Workflow

Contributions MUST follow a fork-and-pull-request workflow. All changes MUST be submitted via a pull request from a feature branch on a personal fork to the `main` branch of the upstream repository. CI checks must pass before a pull request can be reviewed and merged.

## Governance

This constitution is the source of truth for project standards and practices. All code contributions, reviews, and architectural decisions MUST adhere to the principles outlined herein. Amendments to this constitution require a pull request, discussion, and approval from project maintainers.

**Version**: 1.0.0 | **Ratified**: 2025-11-09 | **Last Amended**: 2025-11-09
