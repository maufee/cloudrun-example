# Research: IAM Best Practices for GitHub Actions and Google Cloud Run

## Question

Is the custom IAM role `githubCdDeployer` with `run.services.get` and `run.services.update` permissions, as defined in `scripts/setup_gcp_cd.sh`, still the best practice for deploying to Google Cloud Run from GitHub Actions? Or is there a predefined IAM role that should be used instead?

## Findings

A review of the latest Google Cloud documentation and community best practices confirms the following:

1.  **Workload Identity Federation (WIF) is the standard**: The current approach of using WIF to grant GitHub Actions access to GCP without service account keys is the correct and most secure method.

2.  **The Principle of Least Privilege is paramount**: All sources emphasize granting only the minimum necessary permissions to the service account used by the CI/CD pipeline.

3.  **Predefined vs. Custom Roles**:
    *   Google provides predefined roles like `roles/run.admin` and `roles/run.developer`.
    *   `roles/run.admin` grants full control over all Cloud Run resources, which is too permissive for a deployment pipeline.
    *   `roles/run.developer` grants broad read and write access, which is also more permissive than what is strictly required for deploying a new version of an existing service.
    *   The custom role `githubCdDeployer` with only `run.services.get` and `run.services.update` permissions is precisely scoped to what the CD pipeline needs to do: fetch the existing service configuration and update it with a new image.

## Decision

**The current approach of creating a custom IAM role (`githubCdDeployer`) is the correct and recommended best practice.**

- **Rationale**: It adheres strictly to the principle of least privilege by granting only the two permissions required for deploying a new version of a Cloud Run service. Using a broader predefined role like `roles/run.developer` would grant unnecessary permissions, increasing the potential security risk.
- **Alternatives Considered**: Using the predefined `roles/run.developer` role was considered. It was rejected because it provides wider access than necessary for the deployment task, violating the principle of least privilege.

The Terraform CDK implementation should therefore replicate the creation of this custom role as it is defined in the `setup_gcp_cd.sh` script.