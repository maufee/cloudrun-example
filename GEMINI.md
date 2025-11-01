# Gemini Context for cloudrun-example Project

## Project Overview
- **Description:** A simple Python Flask web application created to serve as a "Hello World" example for deployment to Google Cloud Run.
- **Status:** The application is complete and deployed.

## Deployment Details
- **Platform:** Google Cloud Run
- **Project ID:** `culture-guide`
- **Region:** `us-west1`
- **Service Name:** `gemini-cloudrun-app`
- **Deployment Method:** Source-based deployment using Google Cloud Buildpacks.

## Technical Stack
- **Language:** Python 3.13
- **Framework:** Flask
- **Dependency Manager:** `uv` is used for local development, with dependencies defined in `pyproject.toml`.
- **Production Dependencies:** A `requirements.txt` file is compiled from `pyproject.toml` for use by Cloud Run.
- **Production Server:** Gunicorn, configured via the `Procfile`.
- **Development Server:** The standard Flask development server.

## Key Decisions & History
- The project started as a basic Flask app.
- The user specifically requested to upgrade the project to use a production-grade server, leading to the introduction of **Gunicorn** and the `Procfile`.
- The user inquired about modern Python tooling, leading to the adoption of **`uv`** and `pyproject.toml` for dependency management.
- We discussed more advanced topics, but deferred implementation:
    - **Dockerfiles:** Decided that source deployment is sufficient for now.
    - **Private Dependencies:** Discussed strategies (vendoring, private git repos, Artifact Registry) but did not implement them.
