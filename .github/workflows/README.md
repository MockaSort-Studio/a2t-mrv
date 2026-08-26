# `.github/workflows/`

CI/CD workflows for this repository.

## Permanent infrastructure

These workflows are core to the development and contribution process and are not
expected to go away:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`env-image.yml`](env-image.yml) | Push to `main` (when `docker/Dockerfile` changes) | Builds and pushes `ghcr.io/mockasort-studio/a2t-mrv-env:latest` — the CI container used for Hall agent dispatch and the `test-livedata` job. See [`docker/README.md`](../docker/README.md). |
| [`test-livedata.yml`](test-livedata.yml) | PR and merge queue | Runs `mix compile --warnings-as-errors` and `mix test --warnings-as-errors` inside the env container. Skipped on PRs that touch no `livedata/` paths. |
| [`loc-check.yml`](loc-check.yml) | PR and merge queue | Enforces the net-LOC diff gate — rejects PRs that add more than the configured line budget. |
| [`devenv-container-check.yml`](devenv-container-check.yml) | PR (when `devenv.nix`, `livedata/`, or `deploy/` change) | PR gate: builds the livedata OCI image from `devenv.nix` — no push, no deploy. Fails fast on invalid Nix or Mix compilation errors before they reach the production deploy path. |
| [`terraform.yml`](terraform.yml) | Push to `main` and PR (when `terraform/` changes) | Runs `terraform fmt`, `validate`, and `plan` against the AWS infrastructure root; posts the plan as a PR comment. Also enforces the no-managed-services policy check. See [`terraform/README.md`](../terraform/README.md). |

## Production deployment

The app runs on a Terraform-provisioned AWS VM. The workflow below handles every
push-to-main deploy; the canonical references for the full stack are:

- **VM setup and Docker Compose stack:** [`deploy/README.md`](../deploy/README.md)
- **AWS infrastructure (VPC, EC2, EBS):** [`terraform/README.md`](../terraform/README.md)
- **PR-preview path (Render + Neon):** [`docs/contributing/deployment.md`](../docs/contributing/deployment.md)

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`deploy-livedata.yml`](deploy-livedata.yml) | Push to `main` (when `livedata/`, `devenv.nix`, or `deploy/` change) | Builds the livedata OCI image via `devenv container build`, pushes to GHCR, SSH-deploys to the production VM, and health-checks the live endpoint. |

## PR-preview infrastructure

`preview.yml` and its helpers give each pull request a short-lived deployment
against its own Neon database branch. This is a convenience path for review, not
production. Full details in [`docs/contributing/deployment.md`](../docs/contributing/deployment.md).

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`preview.yml`](preview.yml) | PR opened / closed / merged | Repoints the single free-tier Render service at the PR branch and a Neon database branch, then restores `main` when the PR closes. |

The supporting shell helpers in [`.github/scripts/`](scripts/README.md) are also
part of this preview infrastructure.

`render.yaml` at the repository root and `livedata/Dockerfile` exist for the
Render preview path only — not the production deployment.
