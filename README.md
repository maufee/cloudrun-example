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

## How to Run Locally

1. **Install `uv`**:
   Follow the official instructions to install `uv`.

2. **Create a virtual environment**:
   ```bash
   uv venv
   ```

3. **Activate the virtual environment**:
   ```bash
   source .venv/bin/activate
   ```

4. **Install dependencies**:
   ```bash
   uv pip sync --all-extras
   ```

5. **Run the development server**:
   ```bash
   uv run flask run
   ```
   The application will be available at `http://127.0.0.1:8080`.

## Testing and Linting

This project uses `ruff` for linting and `pytest` for testing. Both are configured as development dependencies.

- **To run the linter**:
  ```bash
  uv run ruff check .
  ```

- **To run the tests**:
  ```bash
  uv run pytest
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
