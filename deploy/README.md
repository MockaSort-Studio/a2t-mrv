# livedata — VM deployment runbook

Docker Compose stack for the livedata Phoenix app on the Terraform-provisioned VM.
Covers first-time setup through `docker compose up`.

This is Item B of KR 6.2 (#85). Item C (automated deploy trigger on push) is out of scope here.

---

## Prerequisites

- The Terraform-provisioned VM is running (issue #86 closed)
- The EBS data volume is attached at `/dev/sdf`
- SSH access to the VM
- A registered domain pointed at the VM's Elastic IP
- The repository checked out on the VM (for `devenv container build`)

---

## Step 1 — Format and mount the EBS volume

Run once on the VM. Skip if already done (check `lsblk` and `df -h`).

```sh
# Confirm the device name (may be /dev/nvme1n1 on Nitro instances)
lsblk

# Format (destructive — only run on a fresh volume)
sudo mkfs.ext4 -L livedata-data /dev/sdf

# Mount
sudo mkdir -p /data
sudo mount /dev/sdf /data

# Persist across reboots
echo "LABEL=livedata-data /data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Create the Postgres data directory owned by the container's postgres user (uid 999)
sudo mkdir -p /data/postgres
sudo chown 999:999 /data/postgres
```

---

## Step 2 — Enable Docker via NixOS declarative config

Copy `deploy/docker.nix` from this repository to the VM alongside the **existing**
system config, then add one import line — do **not** replace `/etc/nixos/configuration.nix`:

```sh
# Copy the module into the NixOS config directory
sudo cp /path/to/repo/deploy/docker.nix /etc/nixos/docker.nix

# Add ./docker.nix to the imports list in /etc/nixos/configuration.nix, e.g.:
#   imports = [ ./hardware-configuration.nix ./docker.nix ];
# (The existing content of /etc/nixos/configuration.nix must be preserved in full —
# it contains EC2-specific bootloader, NVMe, and console settings required for a
# bootable instance. Replacing the file instead of importing would risk an
# unbootable VM on next restart.)
sudo $EDITOR /etc/nixos/configuration.nix

sudo nixos-rebuild switch
```

This declares `virtualisation.docker.enable = true` and survives reboots without
any further manual steps. The imperative `nix-env -iA nixpkgs.docker` approach
is session-only and must not be used — it is lost on reboot.

---

## Step 3 — Build the livedata OCI image

From the repository root on the VM (requires devenv):

```sh
devenv container build livedata --copy
```

**First run will fail** with a hash mismatch for `fetchMixDeps`:

```
error: hash mismatch in fixed-output derivation
  ...
  specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
       got:  sha256-<actual-hash>
```

Copy the `got:` value, update `devenv.nix` (`hash = "sha256-<actual-hash>";`), commit, then rebuild:

```sh
devenv container build livedata --copy
```

On success, load the image into Docker:

```sh
docker load < result
# Loaded image: livedata:latest
```

---

## Step 4 — Configure environment

```sh
cd deploy/
cp .env.example .env
# Edit .env — fill in POSTGRES_PASSWORD, PHX_HOST, SECRET_KEY_BASE, LIVEDATA_DOMAIN
$EDITOR .env
```

Generate `SECRET_KEY_BASE` (from the repo's devenv shell):

```sh
cd livedata/ && mix phx.gen.secret
```

---

## Step 5 — Start the stack

```sh
cd deploy/
docker compose up -d
```

Follow logs:

```sh
docker compose logs -f
```

Caddy acquires a Let's Encrypt certificate automatically on first start (HTTP-01 challenge; port 80 must be reachable). After the certificate is issued, `https://<domain>/` returns 200.

---

## Verify the acceptance criteria

```sh
# App reachable over HTTPS with valid certificate
curl -sS -o /dev/null -w '%{http_code}\n' https://<domain>/
# expect: 200

# Postgres data is on EBS, not root disk
docker inspect a2t-mrv-postgres-1 | grep -A2 '"Source"'
# expect: /data/postgres
df -h /data
# expect: the EBS volume, not rootfs

# Migrations ran on boot
docker compose logs livedata | grep -i migrat
```

Register a project through the UI to confirm PostGIS and TimescaleDB are working end-to-end.

---

## Redeployment (manual, after image rebuild)

```sh
devenv container build livedata --copy
docker load < result
docker compose up -d --no-deps livedata
```

Caddy and Postgres keep running; only the livedata container is replaced.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `eafnosupport` in livedata logs | IPv6 disabled on host | Change `ip` in `runtime.exs` to `{0, 0, 0, 0}` and rebuild image |
| `ACME challenge failed` in Caddy logs | Port 80 not reachable | Check security group (Terraform) and VM firewall |
| `ssl error` in livedata DB logs | `DATABASE_SSL` not set to `"false"` | Verify `.env` contains `DATABASE_SSL=false` |
| Postgres exits immediately | `/data/postgres` wrong ownership | `sudo chown 999:999 /data/postgres` |
| `tailwindcss: wrong version` at image build | nixpkgs has tailwind v3 | Use `pkgs.nodePackages."@tailwindcss/cli"` in `devenv.nix` instead of `pkgs.tailwindcss` |
