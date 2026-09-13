# scripts/deploy/

CodeDeploy lifecycle hook scripts referenced by `appspec.yml`. Each script has a
single responsibility matching its lifecycle event.

| Script | Hook | What it does |
|---|---|---|
| `stop.sh` | ApplicationStop | `docker compose stop livedata` (tolerates not-running) |
| `before_install.sh` | BeforeInstall | Authenticates with GHCR, pulls the new image digest |
| `start.sh` | ApplicationStart | `docker compose up -d --no-deps livedata` with new image |
| `validate.sh` | ValidateService | Curls `https://$PHX_HOST/`, retries 12×10 s before failing |

## Runtime files (not committed)

The deploy workflow writes two files into this directory before zipping the revision:

| File | Source | Content |
|---|---|---|
| `image_ref` | `needs.build-push.outputs.image` | Full GHCR image reference with SHA tag |
| `ghcr_token` | `secrets.GITHUB_TOKEN` | Short-lived token for `docker login ghcr.io` |

These files are present in the S3 revision zip but are not committed to git.

## Environment variables

All scripts respect `DEPLOY_PATH` (default: `/root/a2t-mrv/deploy`) to locate
the `docker compose` stack on the EC2 host.

`validate.sh` reads `PHX_HOST` from `$DEPLOY_PATH/.env` if not set in the
hook's environment.
