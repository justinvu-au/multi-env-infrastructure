# Multi-Environment Infrastructure Pipeline

A demonstration of enterprise-grade Infrastructure as Code with three isolated Azure environments (dev, staging, prod), automated via Terraform and GitHub Actions with manual approval gates before production deployment.

---

## What it demonstrates

- Three fully isolated environments on Azure (separate resource groups, AKS clusters, container registries)
- Terraform remote state stored in Azure Blob Storage, partitioned per environment
- Automated CI/CD pipelines with environment-specific GitHub Actions workflows
- A manual approval gate before any change reaches production
- Per-environment configuration via Terraform variable files — same code, different values

---

## Architecture

---
git push → dev branch

↓ (automatic)

Terraform apply → dev environment

↓ build + deploy

plinfra-dev-aks (AKS)
git push → staging branch

↓ (automatic)

Terraform apply → staging environment

↓ build + deploy

plinfra-staging-aks (AKS)
git push → main branch

↓ (waits for manual approval)

⏸  Reviewer approves

↓

Terraform apply → prod environment

↓ build + deploy + smoke test

plinfra-prod-aks (AKS)

Each environment has its own:
- Resource group (`plinfra-{env}-rg`)
- AKS cluster (`plinfra-{env}-aks`)
- Container registry (`plinfra{env}acr`)
- Terraform state file (`{env}/terraform.tfstate` in shared blob storage)

---

## Tech stack

| Layer | Technology |
|---|---|
| App | FastAPI (minimal demo app) |
| Infrastructure as Code | Terraform with remote state |
| State backend | Azure Blob Storage |
| Container orchestration | Kubernetes (AKS) — one cluster per environment |
| Container registry | Azure Container Registry — one per environment |
| CI/CD | GitHub Actions with branch-based triggers |
| Approval gates | GitHub Environments (required reviewers on prod) |

---

## Project structure
---
multi-env-infrastructure/

├── app/

│   ├── main.py              # Minimal FastAPI app

│   ├── requirements.txt

│   └── Dockerfile

├── infra/

│   └── terraform/

│       ├── main.tf          # Resource group, AKS, ACR, role assignment

│       ├── variables.tf     # Variable definitions with validation

│       ├── outputs.tf

│       └── envs/

│           ├── dev.tfvars

│           ├── staging.tfvars

│           └── prod.tfvars

├── k8s/

│   ├── deployment.yaml      # Templated — env values injected by CI

│   └── service.yaml

└── .github/

└── workflows/

├── deploy-dev.yml       # Triggered on push to dev

├── deploy-staging.yml   # Triggered on push to staging

└── deploy-prod.yml      # Triggered on push to main, requires approval

---

## How the pipeline works

Each workflow runs two jobs:

**1. Terraform job** — provisions or updates the environment's infrastructure (resource group, AKS, ACR, role assignments), then exposes the cluster name and ACR login server as outputs for the next job.

**2. Build and deploy job** — builds the Docker image, tags it with the git commit SHA, pushes it to that environment's ACR, then templates the Kubernetes manifests with the correct image tag and environment name before applying them to that environment's AKS cluster.

The `prod` workflow targets the `prod` GitHub Environment on both jobs, which is configured with a required reviewer. The pipeline pauses after the `dev`/`staging`-equivalent stage and waits for a manual approval click before touching production infrastructure.

---

## Local development

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
curl http://localhost:8000/health
```

---

## Setting up a new environment

To add a fourth environment (e.g. `qa`):

1. Create `infra/terraform/envs/qa.tfvars`
2. Create `.github/workflows/deploy-qa.yml` (copy `deploy-staging.yml` and adjust the branch trigger and environment name)
3. Create a `qa` branch and a corresponding GitHub Environment
4. Push to the `qa` branch

No changes to the core Terraform or Kubernetes manifests are needed — the environment-specific values are entirely isolated to the `.tfvars` file and the workflow's `environment` variable.

---

## Cost management

Running three AKS clusters simultaneously costs roughly 3x a single-cluster setup. Stop all clusters when not actively demoing:

```bash
az aks stop --name plinfra-dev-aks --resource-group plinfra-dev-rg
az aks stop --name plinfra-staging-aks --resource-group plinfra-staging-rg
az aks stop --name plinfra-prod-aks --resource-group plinfra-prod-rg
```

Restart when needed:

```bash
az aks start --name plinfra-dev-aks --resource-group plinfra-dev-rg
az aks start --name plinfra-staging-aks --resource-group plinfra-staging-rg
az aks start --name plinfra-prod-aks --resource-group plinfra-prod-rg
```

Full teardown of an environment (state remains in blob storage, so it can be recreated identically):

```bash
cd infra/terraform
terraform init -backend-config="key=dev/terraform.tfstate"
terraform destroy -var-file="envs/dev.tfvars" -var="subscription_id=YOUR_SUB_ID"
```

---

## Key design decisions

**Why Terraform remote state instead of local state files** — GitHub Actions runs on a fresh, stateless virtual machine every time. A locally stored `.tfstate` file would be invisible to the pipeline, causing Terraform to attempt to recreate infrastructure that already exists. Remote state in Azure Blob Storage gives every pipeline run access to the current state of each environment.

**Why one state file per environment instead of one shared file** — keeps environments fully independent. A `terraform destroy` in dev can never accidentally affect staging or prod, because each environment's resources are tracked in a completely separate state file (`dev/terraform.tfstate`, `staging/terraform.tfstate`, `prod/terraform.tfstate`).

**Why a subscription-scoped service principal** — Terraform needs to create new resource groups for each environment, which requires permissions broader than a single resource group. In a larger organisation this would typically be split into per-environment service principals with narrower scopes; a single subscription-scoped principal is a reasonable simplification for a portfolio-scale project.

**Why GitHub Environments for the approval gate** — this is a native GitHub feature requiring no extra tooling. Any workflow job that specifies `environment: prod` automatically pauses for required reviewer approval if that protection rule is configured, giving a realistic change-management gate before production deployments.




