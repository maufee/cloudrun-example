# Python Flask Web App on Google Cloud Run

[![python](https://img.shields.io/badge/python-%3E%3D3.13-blue)](https://www.python.org/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A minimal "Hello World" Flask application intended for deployment to Google Cloud Run using source deployment (Cloud Buildpacks).

Why this project
- Demonstrates a small, production-ready Python/Flask layout suitable for Cloud Run.
- Uses `gunicorn` in production (via `Procfile`) and the Flask dev server for local work.
- Dependency-friendly: `uv` manages dependencies via `pyproject.toml` and `uv.lock` for local development, with `requirements.txt` generated for Cloud Run Buildpacks.

Quick overview
- Main app: `app.py` (Flask application instance `app`)
- Start command (Cloud Run / production): `gunicorn --bind :$PORT --workers 1 --threads 8 app:app` (see `Procfile`)

## How to Run Locally

This project uses `uv` to manage dependencies and the development workflow.

1. **Install `uv`**:
   Follow the official instructions to install `uv`.

2. **Create and Sync the Virtual Environment**:
   This command creates a virtual environment, generates the `uv.lock` file with exact package versions, and installs all production and development dependencies.
   ```bash
   uv sync --all-extras
   ```

3. **Activate the virtual environment**:
   ```bash
   source .venv/bin/activate
   ```

4. **Run the development server**:
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

- **To run the tests** (without coverage):
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

This project uses `pytest-cov` to measure code coverage. The coverage source (the `app` module) and the minimum coverage threshold (90%) are configured centrally in `pyproject.toml`.

Unlike the default test run, running a coverage analysis is an explicit action.

- **To run tests and enforce coverage**:
  Use the `--cov` flag. This will activate `pytest-cov`, which will then use the settings from `pyproject.toml` to measure coverage and fail if the threshold is not met.
  ```bash
  uv run python -m pytest --cov
  ```

### Test Timeout

This project uses `pytest-timeout` to prevent tests from running indefinitely, which can be crucial in CI/CD pipelines or large test suites.

- **Global Timeout:** A default global timeout is configured in `pyproject.toml` under `[tool.pytest.ini_options]` (e.g., `timeout = "10"` seconds).

- **Per-Test/Per-Module Timeout:** You can override the global timeout or set specific timeouts using `pytest` markers:
  ```python
  import pytest
  import time

  @pytest.mark.timeout(5) # This test will time out after 5 seconds
  def test_long_running_task():
      time.sleep(6) # This will cause a timeout
      assert True

  @pytest.mark.timeout(timeout=20, method="thread") # Use a thread-based timeout
  def test_another_long_task():
      time.sleep(15)
      assert True
  ```

- **To run tests with timeout enabled** (this is automatic when `pyproject.toml` is configured):
  ```bash
  uv run python -m pytest
  ```

## Local Production Run (Gunicorn)

To run the application locally using Gunicorn (mimicking the production environment), first ensure your dependencies are installed via `uv sync`. The `uv run` command will then execute Gunicorn from within your project's virtual environment.

```bash
uv run gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 app:app
```

- The application will be available at `http://127.0.0.1:8080`.
- Press `Ctrl-C` to perform a graceful shutdown of the server.

### Understanding the Gunicorn Command

- **`app:app`**: This tells Gunicorn how to find your application. The format is `<module_name>:<variable_name>`. In our case, it means: "in the `app.py` file, find the Flask object named `app`."

- **`--workers 1 --threads 8`**: This configures the concurrency model.
    - **Workers** are separate OS processes. Multiple workers allow your app to utilize multiple CPU cores and achieve true parallelism.
    - **Threads** are managed within a worker process. Multiple threads allow a single worker to handle multiple I/O-bound requests concurrently (e.g., requests waiting on a database or API call).
    - Our choice of 1 worker and 8 threads is a sensible default for a small, single-core environment, allowing one process to handle up to 8 concurrent connections.

## CI Workflow

This project includes a GitHub Actions workflow (`.github/workflows/ci.yml`) that automatically runs linting and tests on every push and pull request to the `main` branch.

The CI workflow:
- Checks out the code.
- Sets up Python 3.13.
- Installs `uv` using the official `astral-sh/setup-uv` action.
- Installs all project dependencies using `uv sync --locked --all-extras` to ensure the lock file is up-to-date.
- Runs `ruff` for linting.
- Runs `pytest` and enforces the minimum test coverage threshold defined in `pyproject.toml`.

## Deploy to Google Cloud Run (source deploy)

This project is deployed to Cloud Run using the **source deployment** method, where Google Cloud Buildpacks automatically build a container image from your source code.

### 1. Generate `requirements.txt`

Cloud Run's build process uses the standard `requirements.txt` file. To ensure the versions in this file exactly match your development environment (defined by `uv.lock`), generate it using the following command. The `--exclude-editable` flag prevents your local project from being included in the file.

```bash
uv pip freeze --exclude-editable > requirements.txt
```

### 2. Understand the `Procfile`

The `Procfile` is a critical file that tells Cloud Run what command to run to start your web server. Its content is:

```
web: gunicorn --bind :$PORT --workers 1 --threads 8 app:app
```

- The `web:` label is a **process type**. For web services, Cloud Run specifically looks for the `web` process type to start the server that will receive incoming HTTP traffic. For more details on the `Procfile` format and other possible process types, you can refer to [Heroku's Procfile documentation](https://devcenter.heroku.com/articles/procfile), which is the standard that Google Cloud Buildpacks follow.

### 3. Deploy

For convenience, it's best to export your Project ID and Region as environment variables.

```bash
# Set your project and region
export PROJECT_ID="YOUR_PROJECT_ID" # Replace with your Google Cloud Project ID
export REGION="us-west1"
```
Then, you can run the deployment command without modification.
```bash
# Deploy to Cloud Run
gcloud run deploy cloudrun-example \
  --source . \
  --project=$PROJECT_ID \
  --region=$REGION \
  --platform=managed
```

## Continuous Deployment (CD) with GitHub Actions

This project is configured for Continuous Deployment to Google Cloud Run using GitHub Actions. Once set up, any changes pushed to the `main` branch that pass the CI checks will be automatically deployed.

### How it Works

1.  **Trigger:** A push to the `main` branch triggers the workflow.
2.  **CI Checks:** The `test-and-lint` job runs, ensuring code quality and correctness.
3.  **CD Trigger:** If the `test-and-lint` job passes, the `deploy` job starts.
4.  **Authentication:** The `deploy` job securely authenticates to Google Cloud using Workload Identity Federation.
5.  **Deployment:** The application is deployed to Cloud Run using the `google-github-actions/deploy-cloudrun` action.

### One-Time Setup for CD

To enable Continuous Deployment, you need to perform a one-time setup in your Google Cloud project and GitHub repository.

> **Prerequisite:** Before you begin, ensure you have the [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and you are authenticated (`gcloud auth login`).
1. **In your Google Cloud Project:**

A helper script is provided to automate the creation of the necessary GCP resources (Service Account, Workload Identity Federation, IAM bindings).

1.  **Configure environment variables:** Before running the script, export the following environment variables in your terminal:
    ```bash
    export PROJECT_ID="your-gcp-project-id" # Replace with your Google Cloud Project ID
    export REPO="your-github-username/your-repo-name" # Replace with your GitHub repository (e.g., "octocat/Spoon-Knife")
    # export SERVICE_ACCOUNT="my-custom-sa" # Optional: defaults to "github-cd-sa"
    ```
2.  **Run the script:** Make the script executable and then run it.
    ```bash
    chmod +x ./scripts/setup_gcp_cd.sh
    ./scripts/setup_gcp_cd.sh
    ```

**2. In your GitHub Repository Settings:**

The script will output the exact names and values for the three secrets you need to create.

1.  Go to **`Settings > Environments`** and click **`New environment`**.
2.  Name it **`production`** and click **`Configure environment`**. (Note: This name must be exactly `production` for the CD workflow to authenticate.)
3.  In the environment settings, find the **`Environment secrets`** section and click **`Add secret`** for each of the three secrets (`GCP_PROJECT_ID`, `GCP_WORKLOAD_IDENTITY_PROVIDER`, and `GCP_SERVICE_ACCOUNT`).
4.  Copy the values that were printed in your terminal from the final step of the setup script.


## Project structure
```
.
├── .gcloudignore         # Specifies files to ignore when deploying to Google Cloud
├── app.py              # Main Flask application (app:app)
├── Procfile            # Production start command used by Cloud Run (gunicorn)
├── pyproject.toml      # Project definition and development dependencies for `uv`
├── requirements.txt    # Pinned dependencies for production (used by buildpacks)
├── LICENSE             # MIT license
└── README.md           # This file
```

## Notes and recommendations
- The `Procfile` must be in the project root directory for Cloud Run's buildpacks to find it. Other configuration files like `.gcloudignore` also reside in the root.
- The `.gcloudignore` file prevents specified files and directories from being uploaded to Google Cloud during deployment, reducing build times and preventing sensitive files from being exposed. It is similar in function to `.gitignore`.
- If you depend on system packages (ffmpeg, imagemagick, etc.) or need full control over the runtime, provide a `Dockerfile` and build a custom image instead of relying on buildpacks.
- For private dependencies, prefer Artifact Registry or authenticated build steps rather than embedding credentials in source.
- Keep `requirements.txt` updated if you change pinned production dependencies.

## Contributing

Contributions are welcome! This project follows a standard fork-and-pull request workflow. Branch protection is enabled for the `main` branch.

1.  **Fork** the repository to your own GitHub account.
2.  **Clone** your fork to your local machine.
3.  **Create a new branch** for your feature or bug fix (`git checkout -b my-new-feature`).
4.  **Set up the environment** by running `uv sync --all-extras`.
5.  **Make your changes.**
    - If you add or change a dependency, modify `pyproject.toml`, then run `uv sync --all-extras` to update the lock file and environment, and finally regenerate the production requirements with `uv pip freeze --exclude-editable > requirements.txt`.
6.  **Run checks locally** to ensure your changes pass before pushing.
    ```bash
    # Run the linter
    uv run ruff check .
    # Run the test suite with coverage
    uv run python -m pytest --cov
    ```
7.  **Commit and push** your changes to your fork.
8.  **Open a pull request** from your fork's branch to the `main` branch of the original repository.
9.  Your pull request will be reviewed after the automated CI checks have passed.

## License
This project is licensed under the MIT License - see the `LICENSE` file for details.

---

## Appendix: Architectural Choices FAQ

### Q: Why use `uv run python -m pytest` instead of just `uv run pytest`?

**A:** While `uv run pytest` often works, `uv run python -m pytest` is a more robust and explicit command that is guaranteed to work correctly across different developer machines and shell configurations.

- **The `pytest` command** relies on the shell finding the `pytest` executable script in the `PATH`. This can sometimes fail due to shell caching, `PATH` conflicts from other tools, or a corrupted executable script.
- **The `python -m pytest` command** directly uses the project's `python` interpreter to find and run the `pytest` module. This bypasses the shell's `PATH` search for the `pytest` script, instead using Python's own internal and more reliable module-finding mechanism.

In short, it's the canonical and safest way to run an installed Python module, which is why it is the standard used in this project.

**Further Reading:**
- [Python Command Line Documentation: `-m` switch](https://docs.python.org/3/using/cmdline.html#cmdoption-m)
- [PEP 338 -- Executing modules as scripts](https://peps.python.org/pep-0338/)

### Q: How can I apply a timeout only to the test function, not setup/teardown?

**A:** You can use the `timeout_func_only` configuration option. By default, `pytest-timeout` applies the timeout to the entire test item, including setup and teardown phases. Setting `timeout_func_only = true` is useful when you have a long-running setup fixture (e.g., initializing a database, preparing complex data) that you want to exclude from the test's execution time limit.

To enable this, add the following to your `pyproject.toml`:

```toml
[tool.pytest.ini_options]
timeout = "10"
timeout_func_only = true
```

### Q: Why did `uv.lock` and `requirements.txt` have different package versions?

**A:** You astutely observed that different `uv` commands can sometimes resolve dependencies to different versions. This can create a dangerous inconsistency between your local development environment and the production build.

**The Solution:** The workflow in this project is now designed to prevent this. We use `uv.lock` as the primary source of truth for the local environment, and then generate `requirements.txt` *from* that locked environment, ensuring a perfect match.

The correct workflow is:

1.  `uv sync` (To generate `uv.lock` and install exact versions locally)
2.  `uv pip freeze --exclude-editable > requirements.txt` (To generate a clean `requirements.txt` for production that matches the local environment)

This guarantees your local environment perfectly mirrors the one Cloud Run will build.

