# Python Flask Web App on Google Cloud Run

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)  
[![python](https://img.shields.io/badge/python-3.13-blue)](https://www.python.org/)

A minimal "Hello World" Flask application intended for deployment to Google Cloud Run using source deployment (Cloud Buildpacks).

Why this project
- Demonstrates a small, production-ready Python/Flask layout suitable for Cloud Run.
- Uses `gunicorn` in production (via `Procfile`) and the Flask dev server for local work.
- Dependency-friendly: development uses `uv`/`pyproject.toml`, while `requirements.txt` supports Buildpacks.

Quick overview
- Main app: `app.py` (Flask application instance `app`)
- Start command (Cloud Run / production): `gunicorn --bind :$PORT --workers 1 --threads 8 app:app` (see `Procfile`)

Local development (use uv)

This repository uses `uv` as the authoritative local dependency manager. Always use `uv` for creating the virtual environment and installing development tools and dependencies to ensure parity across developer machines.

Recommended local workflow:
```bash
# create a uv-managed virtual environment (uses python3)
python3 -m uv venv
# activate the venv
source .venv/bin/activate
# install runtime deps and dev extras from pyproject.toml
uv pip sync --extra dev
# run the dev server
python app.py
```

Run tests and lint locally (after activating .venv):
```bash
# run ruff linter
ruff check .
# run pytest
pytest -q
```

Local production run (Gunicorn):
```bash
# Ensure dependencies installed (requirements.txt)
# Run gunicorn on the same interface as Cloud Run uses
gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 app:app
```

CI note
- The GitHub Actions workflow uses the runner's Python environment and installs dependencies directly with `pip install -r requirements.txt` for speed and reproducibility in CI. Creating an additional virtual environment inside the runner (for example via `uv venv`) is unnecessary because Actions already provides an isolated Python environment per job.
- `uv` is recommended for local developer workflows where you want `pyproject.toml` to be the single source of truth for dependencies; it's optional for CI unless you specifically want CI to mirror the developer `uv` workflow.

Deploy to Google Cloud Run (source deploy)
```bash
# replace PROJECT and REGION as appropriate
gcloud run deploy cloudrun-example \
  --source . \
  --project=YOUR_PROJECT_ID \
  --region=us-west1 \
  --platform=managed
```
Cloud Run will use buildpacks to detect Python, install dependencies from `requirements.txt`, and run the process from `Procfile`.

Project structure
```
.
├── app.py              # Main Flask application (app:app)
├── Procfile            # Production start command used by Cloud Run (gunicorn)
├── pyproject.toml      # Project definition and development dependencies for `uv`
├── requirements.txt    # Pinned dependencies for production (used by buildpacks)
├── LICENSE             # MIT license
└── README.md           # This file
```

Notes and recommendations
- If you depend on system packages (ffmpeg, imagemagick, etc.) or need full control over the runtime, provide a `Dockerfile` and build a custom image instead of relying on buildpacks.
- For private dependencies, prefer Artifact Registry or authenticated build steps rather than embedding credentials in source.
- Keep `requirements.txt` updated if you change pinned production dependencies.

Contributing
- Open issues or pull requests.
- If you're adding functionality, include tests and update `requirements.txt` (or the `pyproject.toml` source) accordingly.

License
This project is licensed under the MIT License - see the `LICENSE` file for details.
