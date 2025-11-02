# Python Flask Web App on Google Cloud Run

[![python](https://img.shields.io/badge/python-%3E%3D3.13-blue)](https://www.python.org/)

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
   uv sync --all-extras
   ```

5. **Run the development server**:
   ```bash
   FLASK_DEBUG=1 uv run flask run
   ```
   The application will be available at `http://127.0.0.1:5000`.

### Understanding Flask Debug Mode

Flask's debug mode is a powerful feature for local development that provides:
- **Interactive Debugger:** Catches unhandled exceptions and allows you to inspect the code state in your browser.
- **Automatic Reloader:** Automatically restarts the server when code changes are detected, so you don't have to manually restart it after every modification.

**Controlling Debug Mode:**
- By default, we've enabled it for local development using `FLASK_DEBUG=1`.
- To explicitly disable debug mode (e.g., for performance testing or if you prefer manual restarts), you can set `FLASK_DEBUG=0`:
  ```bash
  FLASK_DEBUG=0 uv run flask run
  ```

**⚠️ Important Security Warning:**
Never run Flask applications with debug mode enabled in a production environment. The interactive debugger can allow arbitrary code execution, posing a severe security risk. Debug mode is strictly for development purposes.

For more details, refer to the [Flask Debug Mode documentation](https://flask.palletsprojects.com/en/latest/server/#debug-mode).

#### The Debugger PIN

When you run the server in debug mode for the first time, you will see a "Debugger PIN" in your console output. If your application encounters an error, the interactive debugger will start in your browser. You will be prompted to enter this PIN to unlock the full interactive features. This is a security measure to prevent unauthorized users from executing code on your machine. This is another critical reason why debug mode must never be used in production.

## Testing and Linting

This project uses `ruff` for linting and `pytest` for testing. Both are configured as development dependencies.

- **To run the linter**:
  ```bash
  uv run ruff check .
  ```

- **To run the tests**:
  ```bash
  uv run python -m pytest
  ```

### Running Specific Tests

You can run specific tests by passing arguments to `pytest`:

- **Run all tests in a file**:
  ```bash
  uv run python -m pytest tests/test_app.py
  ```

- **Run a single test function by name**:
  ```bash
  uv run python -m pytest tests/test_app.py::test_root
  ```

### Test Coverage

This project uses `pytest-cov` to measure code coverage by our tests. This helps ensure that our tests are thorough.

- **To generate a coverage report in the terminal**:
  ```bash
  uv run python -m pytest --cov=app
  ```

- **To enforce a minimum coverage percentage**:
  You can make the test suite fail if coverage drops below a certain threshold (e.g., 90%). This is great for maintaining testing standards.
  ```bash
  uv run python -m pytest --cov=app --cov-fail-under=90
  ```

## Local Production Run (Gunicorn)

To run the application locally using Gunicorn (mimicking the production environment):

1. **Ensure dependencies are installed** (as per "How to Run Locally" section).
2. **Run Gunicorn**:
   ```bash
   uv run gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 app:app
   ```
   The application will be available at `http://127.0.0.1:8080`.

## CI Workflow

This project includes a GitHub Actions workflow (`.github/workflows/ci.yml`) that automatically runs linting and tests on every push and pull request to the `main` branch.

The CI workflow:
- Checks out the code.
- Sets up Python 3.13.
- Installs `uv`.
- Installs all project dependencies (including dev extras) using `uv pip sync pyproject.toml --all-extras`.
- Runs `ruff` for linting.
- Runs `pytest` for testing.

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
