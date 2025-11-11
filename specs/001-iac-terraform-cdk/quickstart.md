# Quickstart: Infrastructure Setup with Terraform CDK

This guide explains how to set up and run the Terraform CDK application to deploy the project's required GCP infrastructure.

## Prerequisites

1.  **Install Node.js and npm**: The `cdktf-cli` tool is distributed via npm. Follow the official instructions to install Node.js and npm for your operating system.
2.  **Install `cdktf-cli`**: Install the command-line tool globally.
    ```bash
    npm install -g cdktf-cli
    ```
3.  **Google Cloud SDK**: Ensure you have `gcloud` installed and authenticated.
    ```bash
    gcloud auth login
    gcloud config set project YOUR_PROJECT_ID
    ```
4.  **Python and Pip**: Ensure you have Python 3.13+ and pip installed.

## Configuration

Before proceeding, set the following environment variables:

```bash
export PROJECT_ID="YOUR_GCP_PROJECT_ID" # Replace with your Google Cloud Project ID
export REPO="YOUR_GITHUB_USERNAME/YOUR_REPO_NAME" # Replace with your GitHub repository (e.g., "octocat/Spoon-Knife")
# export GCP_RUNTIME_SA="your-run-sa@your-gcp-project-id.iam.gserviceaccount.com" # Optional: The runtime SA for your Cloud Run service.
```

## Setup

1.  **Navigate to the IaC directory**:
    ```bash
    cd iac
    ```

2.  **Compile and install Python dependencies for the IaC application**:
    This command creates a `requirements.txt` file from the `iac/pyproject.toml` and then installs the dependencies into your environment.
    ```bash
    uv pip compile pyproject.toml --output-file requirements.txt
    uv pip install -r requirements.txt
    ```

3.  **Generate Terraform providers**: This command downloads the necessary providers and generates the Python provider bindings.
    ```bash
    uv run cdktf get
    ```

4.  **Synthesize the Terraform configuration**: This command converts your Python code into a Terraform JSON configuration.
    ```bash
    uv run cdktf synth
    ```

## Deployment

1.  **Deploy the infrastructure**: This command will show you a plan of the resources to be created and prompt for confirmation before applying.
    ```bash
    uv run cdktf deploy
    ```
    Enter `yes` to approve the deployment.

## Destroying Infrastructure

To tear down all the resources created by the application, run the following command and confirm by typing `yes`.

```bash
uv run cdktf destroy
```
