# Deployment path analysis

Investigation for [#139](https://github.com/MockaSort-Studio/a2t-mrv/issues/139).
Two paths: **Path B** (Hetzner, current recommendation) and **full AWS lock-in** (enterprise target).
Updated premise (#138): TimescaleDB dropped — `raw_measurements` runs on plain Postgres/PostGIS.
AWS RDS and Aurora Postgres+PostGIS are now viable managed-DB targets.

Prices are on-demand, eu-west-1 (Ireland), September 2026 list rates. ±10% error margin.

---

## Current setup

AWS EC2 t3.small, Docker Compose (Caddy + livedata + Postgres/PostGIS). DB on attached EBS gp3.

| Component | Monthly |
|---|---|
| EC2 t3.small (2 vCPU / 2 GB, on-demand) | $16.64 |
| EBS gp3 root — 20 GB | $1.81 |
| EBS gp3 data — Postgres (20 GB) | $1.81 |
| **Total** | **~$20** |

---

## Path B — Hetzner (current recommendation)

Hetzner CX22: 2 vCPU / 4 GB RAM / 40 GB NVMe. Same ops posture as current
(Caddy + Docker Compose + self-hosted Postgres/PostGIS). Migration is a one-time
data export + re-provision.

| Component | Monthly |
|---|---|
| Hetzner CX22 (2 vCPU / 4 GB / 40 GB NVMe) | €3.79 ≈ $4.15 |
| Static IPv4 (mandatory since March 2024) | €0.60 ≈ $0.66 |
| **Total** | **~$5** |

4× cheaper than current EC2. Better hardware (4 GB RAM vs 2 GB). No AWS managed
service (CloudWatch, ALB, Backup, Route 53) beats its self-managed equivalent on
cost at this workload size.

Reliability posture: identical to current — single-node, no managed HA, manual backups.

---

## Full AWS lock-in — enterprise target

Two Elixir services (app + methodology engine) on EC2 Graviton, Aurora PostgreSQL
Serverless v2 for managed HA storage, Cognito for RBAC, S3 lifecycle for retention
tiering, CloudWatch for observability. Designed for the milestones that justify the
step up: first uptime SLA, second service, RBAC, and compliance audit.

| Component | Monthly est. |
|---|---|
| 2× EC2 t4g.small (app + methodology engine) | ~$17–27 |
| Aurora PostgreSQL Serverless v2 (PostGIS, 0.5 ACU min) | ~$22–60 |
| AWS Cognito (< 50K MAU free) | $0–20 |
| S3 Standard-IA + Glacier lifecycle (warm/cold tier) | ~$1–10 |
| CloudWatch + CloudTrail (management events free) | ~$5–15 |
| AWS Secrets Manager | ~$2–5 |
| **Total** | **~$47–137** |

Aurora Serverless v2 provides built-in 6-way replication and sub-30s failover without
Multi-AZ gymnastics. Storage auto-scales to 128 TiB with zero intervention. Migration
from Hetzner: Postgres → Aurora is a one-time export + import — no schema changes,
since the app uses standard Postgres features only.

---

## Key considerations

### Data growth and retention

`raw_measurements` is append-only (CRCF-25, -26). Audit records are never deleted.
Conservative growth: 1–5 GB/year at pilot scale; 50–500 GB/year at multi-project
production.

CRCF permits tiering non-audit raw data; compliance records must remain on hot storage
indefinitely.

| Tier | Data | Cost |
|---|---|---|
| Hot (Postgres/Aurora SSD) | Last 12 months of measurements | $0.10–0.115/GB/month |
| Warm (S3 Standard-IA) | 1–7 years, infrequently queried | $0.0125/GB/month |
| Cold (S3 Glacier Instant Retrieval) | 7+ years, compliance archive | $0.004/GB/month |

On Hetzner: disk scales only by node upgrade or a separate network volume
(€0.052/GB/month); tiering automation is fully DIY via Hetzner Object Storage
(€0.006/GB/month, S3-compatible). On AWS: S3 lifecycle rules automate warm/cold
natively; Aurora auto-scales storage, removing the most common DBA intervention.

### Multiple Elixir services

Current stack is one Phoenix app. A methodology engine is a planned second service.

| Option | Hetzner | AWS |
|---|---|---|
| Single larger node | CX32 (4 vCPU / 8 GB) ~$10/month | t4g.medium ~$24/month |
| Two nodes | 2× CX22 ~$10/month | 2× t4g.small ~$27/month |
| Managed compute | N/A | ECS Fargate ~$9/month (Elixir cold-start 10–30s; risk for real-time MRV streams) |

### Authentication (RBAC)

RBAC is deferred from MVP but is a hard requirement for enterprise: CRCF audit trails
must be attributable to authenticated principals.

| Option | Monthly | Notes |
|---|---|---|
| AWS Cognito | $0 (< 50K MAU) | OIDC/OAuth2-native; SAML federation for cert bodies; free tier holds through early production |
| Authentik (self-hosted, t4g.micro) | $4–8 | Lightweight FOSS; OIDC + SAML; lower ops burden than Keycloak |
| Keycloak (self-hosted, t4g.small) | $8–16 | De facto enterprise standard; memory-hungry (1.5–2 GB JVM min) |

Cognito is the natural fit for the AWS-native path — integrates with ALB and IAM,
free under 50K MAU, SAML federation covers certification-body access.

### Security and compliance

CRCF requires full audit trails attributable to authenticated principals. EU data
residency required; both paths have EU region options.

| Control | Hetzner | AWS-native |
|---|---|---|
| Encryption at rest | DIY (LUKS/dm-crypt, manual) | EBS/Aurora encryption by default (KMS-backed) |
| API audit trail | auditd (manual install) | CloudTrail (management events free) |
| Vulnerability scanning | Manual apt + unattended-upgrades | AWS Inspector ($0.03–0.15/instance/month) |
| Secret management | Env vars / self-hosted Vault | Secrets Manager ($0.40/secret) or Parameter Store (free) |
| DDoS protection | Provider-level (no SLA) | AWS Shield Standard (free, SLA-backed) |
| Compliance reporting | Manual (custom scripts) | AWS Security Hub ($0.001/finding, 10K free) |

### Infra management effort

| Dimension | Hetzner | AWS-native |
|---|---|---|
| OS patching | Full responsibility | EC2: same; Aurora: managed |
| DB maintenance | Full — vacuums, index maintenance, extension updates | Managed — automated minor version patches |
| Backup + restore | DIY cron + rsync + restore testing | Aurora PITR built-in |
| Disk scaling | Node upgrade (requires downtime) or network volume | EBS live resize; Aurora transparent, no limit |
| Monitoring | Self-hosted Prometheus/Grafana | CloudWatch + Performance Insights built-in |
| Incident response | Fully manual | CloudWatch alarms + SNS; PagerDuty integration |

---

## Migration decision point

**Stay on Path B until the first of these milestones:**

- DB data volume exceeds 100 GB and disk management is costing engineering hours
- Methodology engine deployed as a second Elixir service
- RBAC introduced (adds $4–16/month to the Hetzner path)
- Enterprise customer demands ISO 27001 or SOC 2 evidence
- Uptime SLA documented — single-node Hetzner has no managed failover

At that point, move to the full AWS stack (~$47–137/month). 10–27× Hetzner's floor —
worth it when the accumulated ops labor offset (DB patching, backup testing, incident
tooling, compliance evidence collection) is factored in. Aurora's built-in HA removes
the last single point of failure without Multi-AZ pricing gymnastics.

---

// Mergio 🤘 — cheapest today, not cheapest forever; know which game you're in.
