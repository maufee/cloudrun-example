#!/usr/bin/env python
import os
import hashlib
import warnings
from constructs import Construct
from cdktf import App, TerraformStack, TerraformOutput
from cdktf_cdktf_provider_google.provider import GoogleProvider
from cdktf_cdktf_provider_google.data_google_project import DataGoogleProject
from cdktf_cdktf_provider_google.project_service import ProjectService
from cdktf_cdktf_provider_google.service_account import ServiceAccount
from cdktf_cdktf_provider_google.project_iam_custom_role import (
    ProjectIamCustomRole,
)
from cdktf_cdktf_provider_google.iam_workload_identity_pool import (
    IamWorkloadIdentityPool,
)
from cdktf_cdktf_provider_google.iam_workload_identity_pool_provider import (
    IamWorkloadIdentityPoolProvider,
)
from cdktf_cdktf_provider_google.project_iam_member import ProjectIamMember
from cdktf_cdktf_provider_google.service_account_iam_member import (
    ServiceAccountIamMember,
)

warnings.filterwarnings(
    "ignore", category=UserWarning, module="cdktf_cdktf_provider_google"
)


class MyStack(TerraformStack):
    def __init__(self, scope: Construct, id: str) -> None:
        super().__init__(scope, id)

        project_id = os.environ.get("PROJECT_ID")
        repo = os.environ.get("REPO")
        gcp_runtime_sa = os.environ.get("GCP_RUNTIME_SA")

        if not project_id or not repo:
            raise ValueError("PROJECT_ID and REPO environment variables must be set")

        provider_id = f"gh-p-{hashlib.sha256(repo.encode()).hexdigest()[:25]}"

        GoogleProvider(self, "google", project=project_id)

        project = DataGoogleProject(self, "project")

        apis_to_enable = [
            "iam.googleapis.com",
            "iamcredentials.googleapis.com",
            "cloudresourcemanager.googleapis.com",
            "run.googleapis.com",
            "compute.googleapis.com",
        ]
        enabled_apis = {}
        for api in apis_to_enable:
            enabled_apis[api] = ProjectService(
                self, f"enable-{api.replace('.', '-')}", service=api, project=project_id
            )

        if gcp_runtime_sa:
            if "@" not in gcp_runtime_sa or "." not in gcp_runtime_sa:
                raise ValueError(
                    "GCP_RUNTIME_SA must be a valid service account email address"
                )
            runtime_sa_email = gcp_runtime_sa
        else:
            runtime_sa_email = f"{project.number}-compute@developer.gserviceaccount.com"

        github_cd_sa = ServiceAccount(
            self,
            "github-cd-sa",
            account_id="github-cd-sa",
            display_name="GitHub Actions CD Service Account",
            project=project_id,
            depends_on=[enabled_apis["iam.googleapis.com"]],
        )

        cloud_build_sa = ServiceAccount(
            self,
            "cloud-build-sa",
            account_id="cloud-build-sa",
            display_name="Cloud Build Service Account",
            project=project_id,
            depends_on=[enabled_apis["iam.googleapis.com"]],
        )

        ProjectIamCustomRole(
            self,
            "github-cd-deployer",
            role_id="githubCdDeployer",
            title="GitHub CD Deployer",
            description=(
                "Minimal permissions for deploying to Cloud Run via GitHub Actions"
            ),
            permissions=["run.services.get", "run.services.update"],
            stage="GA",
            project=project_id,
            depends_on=[enabled_apis["iam.googleapis.com"]],
        )

        custom_role_full_name = f"projects/{project_id}/roles/githubCdDeployer"

        # Create Workload Identity Pool
        pool = IamWorkloadIdentityPool(
            self,
            "github-pool",
            workload_identity_pool_id="github-pool",
            display_name="GitHub Actions Pool",
            project=project_id,
            depends_on=[enabled_apis["iam.googleapis.com"]],
        )

        # Create Workload Identity Provider
        IamWorkloadIdentityPoolProvider(
            self,
            "github-provider",
            workload_identity_pool_id=pool.workload_identity_pool_id,
            workload_identity_pool_provider_id=provider_id,
            display_name="GitHub Actions Provider",
            attribute_mapping={
                "google.subject": "assertion.sub",
                "attribute.repository": "assertion.repository",
            },
            attribute_condition=f"attribute.repository == '{repo}'",
            oidc={"issuer_uri": "https://token.actions.githubusercontent.com"},
            project=project_id,
            depends_on=[pool],
        )

        # Grant project-level IAM roles to github-cd-sa
        github_cd_sa_roles = [
            "roles/artifactregistry.writer",
            "roles/cloudbuild.builds.editor",
            "roles/storage.objectAdmin",
            "roles/serviceusage.serviceUsageConsumer",
            custom_role_full_name,
        ]
        for i, role in enumerate(github_cd_sa_roles):
            ProjectIamMember(
                self,
                f"github-cd-sa-iam-{role.split('/')[-1].replace('.', '-')}",
                project=project_id,
                role=role,
                member=github_cd_sa.member,
            )

        # Grant project-level IAM roles to cloud-build-sa
        cloud_build_sa_roles = [
            "roles/artifactregistry.writer",
            "roles/iam.serviceAccountUser",
            "roles/storage.objectViewer",
            custom_role_full_name,
        ]
        for i, role in enumerate(cloud_build_sa_roles):
            ProjectIamMember(
                self,
                f"cloud-build-sa-iam-{role.split('/')[-1].replace('.', '-')}",
                project=project_id,
                role=role,
                member=cloud_build_sa.member,
            )



        runtime_sa_full_name = (
            f"projects/{project_id}/serviceAccounts/{runtime_sa_email}"
        )

        # Grant serviceAccountUser role on runtime SA
        ServiceAccountIamMember(
            self,
            "github-cd-sa-runtime-sa-iam",
            service_account_id=runtime_sa_full_name,
            role="roles/iam.serviceAccountUser",
            member=github_cd_sa.member,
        )
        ServiceAccountIamMember(
            self,
            "cloud-build-sa-runtime-sa-iam",
            service_account_id=runtime_sa_full_name,
            role="roles/iam.serviceAccountUser",
            member=cloud_build_sa.member,
        )

        # Grant workloadIdentityUser role to the WIF principal
        ServiceAccountIamMember(
            self,
            "wif-iam",
            service_account_id=github_cd_sa.name,
            role="roles/iam.workloadIdentityUser",
            member=f"principal://iam.googleapis.com/{pool.name}/subject/repo:{repo}:environment:production",
        )

        TerraformOutput(
            self,
            "gcp_project_id",
            value=project_id,
            description="The GCP project ID.",
        )
        TerraformOutput(
            self,
            "gcp_workload_identity_provider",
            value=f"projects/{project.number}/locations/global/workloadIdentityPools/github-pool/providers/{provider_id}",
            description="The Workload Identity Provider.",
        )
        TerraformOutput(
            self,
            "gcp_service_account",
            value=github_cd_sa.email,
            description="The service account for GitHub Actions.",
        )

app = App()
MyStack(app, "iac")

app.synth()
