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

Quick start (development)

Prerequisites:
- Python 3.11+ (this project targets 3.13)
- Recommended: install `uv` for dependency management; fallback to `pip` + `venv` if you prefer.

Using uv (recommended):
```bash
# create a venv managed by uv
uv venv
# activate it
source .venv/bin/activate
# install runtime deps from pyproject.toml (or requirements.txt if you prefer)
uv pip sync
# run dev server
python app.py
```

Fallback using standard venv and pip:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Local production run (Gunicorn):
```bash
# Ensure dependencies installed (requirements.txt)
# Run gunicorn on the same interface as Cloud Run uses
gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 app:app
```

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
