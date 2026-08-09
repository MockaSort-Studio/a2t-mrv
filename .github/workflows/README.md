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

## Temporary deployment infrastructure

> **This section describes platform-testing infrastructure, not the development
> environment.** Day-to-day development runs on devenv and Nix — see
> [`SETUP.md`](../../SETUP.md) and [`livedata/README.md`](../livedata/README.md).
> The Render + Neon deployment exists solely to validate the platform as an
> example instance and is expected to be replaced or removed once that
> evaluation is complete.

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`preview.yml`](preview.yml) | PR opened / closed / merged | Repoints the single free-tier Render service at the PR branch and a Neon database branch, then restores `main` when the PR closes. Owned by [`docs/contributing/deployment.md`](../docs/contributing/deployment.md). |

The supporting shell helpers in [`.github/scripts/`](scripts/README.md) are also
part of this temporary infrastructure.

`render.yaml` at the repository root and `livedata/Dockerfile` are likewise
temporary: they exist to run the app on Render for platform evaluation, not as
the long-term deployment story.
