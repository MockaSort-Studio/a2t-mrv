# Deployment path analysis — cost and fit

Investigation for [#139](https://github.com/MockaSort-Studio/a2t-mrv/issues/139).
Compares three deployment paths against the current EC2 baseline on monthly cost
at current/near-term scale. Optimization target: lowest realistic cost, not
feature completeness or future headroom.

**Updated premise (#138):** `raw_measurements` runs on plain Postgres/PostGIS — no
TimescaleDB extension, no `create_hypertable`. AWS RDS/Aurora Postgres+PostGIS is
now a viable managed-DB target.

All prices are on-demand, eu-west-1 (Ireland), September 2026 list rates. ±10%
error margin is realistic; use these as relative indicators, not billing forecasts.

---

## Current setup

Terraform-provisioned AWS EC2 t3.small, Docker Compose stack (Caddy + livedata +
Postgres/PostGIS). Postgres data on an attached EBS gp3 volume.

| Component | Monthly cost |
|---|---|
| EC2 t3.small (2 vCPU / 2 GB, on-demand) | $16.64 |
| EBS gp3 root — 20 GB | $1.81 |
| EBS gp3 data (Postgres) — 20 GB | $1.81 |
| Elastic IP (attached, no charge) | $0 |
| VPC / IGW / SG | $0 |
| **Total** | **~$20 / month** |

---

## Path A — AWS-native, self-hosted DB

Same as the current stack but swap EC2 family to Graviton (t4g.small). Postgres
stays self-hosted on EBS.

| Component | Monthly cost |
|---|---|
| EC2 t4g.small (2 vCPU / 2 GB, Graviton, on-demand) | $13.43 |
| EBS gp3 root — 20 GB | $1.81 |
| EBS gp3 data (Postgres) — 20 GB | $1.81 |
| Elastic IP (attached) | $0 |
| VPC / IGW / SG | $0 |
| **Total** | **~$17 / month** |

### AWS managed services considered and excluded

The acceptance criteria requires justifying each AWS managed service included in
Path A — only services that beat the self-managed equivalent on cost are eligible.

| Service | Self-managed equivalent | Verdict |
|---|---|---|
| CloudWatch Logs ($0.57/GB ingested) | logrotate — $0 | **Excluded** — more expensive |
| AWS Backup ($0.095/GB/month for snapshots) | EBS snapshot API directly — same underlying cost | **Excluded** — identical cost, adds wrapper overhead |
| Elastic Load Balancing ($16.20/month base) | Caddy on EC2 — $0 | **Excluded** — far more expensive |
| Route 53 ($0.50/zone/month) | Cloudflare free tier — $0 | **Excluded** — more expensive |
| SSM Session Manager (free) | Port 22 open — $0 | Marginal security gain at zero cost; no cost impact either way |

**No AWS managed service beats its self-managed equivalent on cost at this scale.**
The savings in Path A come entirely from switching EC2 family (t3 → t4g, ~19%
cheaper per hour for the same throughput profile). With 1-year Reserved Instances
(no-upfront commitment), the EC2 line drops to ~$9.50/month — total ~$13/month —
at the cost of 12-month lock-in.

---

## Path B — Generic VPC provider, self-hosted DB

Non-AWS VPS. Hetzner CX22 is the cost floor for this workload class: 2 vCPU
(AMD EPYC), 4 GB RAM, 40 GB NVMe SSD. No separate volume needed — the DB fits
on the included disk at current data volumes.

| Component | Monthly cost |
|---|---|
| Hetzner CX22 (2 vCPU / 4 GB / 40 GB NVMe) | €3.79 ≈ $4.15 |
| Static IPv4 (Hetzner mandatory since March 2024) | €0.60 ≈ $0.66 |
| Additional storage | $0 (included) |
| **Total** | **~$5 / month** |

Supporting infrastructure (DNS, TLS via Let's Encrypt/Caddy, backups via cron +
rsync or Hetzner snapshots at €0.012/GB) is self-managed — the same ops posture
as the current EC2 setup.

DigitalOcean's comparable tier (Basic 4 GB / 2 vCPU) is $24/month — similar to
the current AWS cost. OVH VPS Comfort (4 GB / 4 vCPU) lands at ~$9/month.
Hetzner is the clear winner for raw price/spec at this scale.

---

## Path C — AWS-native, fully managed DB (RDS)

EC2 for the app (DB offloaded to RDS, so t3.micro is viable), RDS PostgreSQL with
PostGIS enabled (PostGIS is fully supported on RDS; this path became viable when
TimescaleDB was dropped in #138).

| Component | Monthly cost |
|---|---|
| EC2 t3.micro (2 vCPU / 1 GB, on-demand, app only) | $8.32 |
| EBS gp3 root — 20 GB | $1.81 |
| Elastic IP (attached) | $0 |
| RDS db.t4g.micro (2 vCPU / 1 GB, Single-AZ) | ~$13.87 |
| RDS gp3 storage — 20 GB ($0.115/GB) | $2.30 |
| RDS automated backups (7-day retention, 1× free) | $0 |
| **Total** | **~$26 / month** |

Note: t3.micro (1 GB RAM) is viable for the Phoenix app alone; with the DB
co-located it would be tight. If 1 GB proves insufficient, t3.small ($16.64)
brings the total to ~$34/month.

### AWS managed services considered and included

| Service | Self-managed equivalent | Verdict |
|---|---|---|
| RDS automated backups with PITR (1× storage free) | pg_dump cron + S3 — $0.023/GB | **Included** — saves ~$0.46/month on 20 GB DB storage and eliminates backup scripting; marginal but genuine |
| RDS minor version upgrades | Manual apt/nix update + restart | Ops savings, zero cost impact |
| RDS Multi-AZ (doubles DB cost to ~$28/month) | No equivalent self-hosted HA | **Excluded** — not justified at current/near-term scale; adds ~$14/month for HA that the self-hosted path doesn't have either |

The sole cost win for managed DB is backup storage (~$0.46/month). The real
managed-DB premium buys automated patching, built-in monitoring, and failover
readiness — ops value, not cost savings.

---

## Cost comparison

| Path | Monthly est. | vs. current | Notes |
|---|---|---|---|
| **Path B — Hetzner** | **~$5** | **−75%** | Clear winner on cost |
| Path A — AWS Graviton | ~$17 | −15% | Best AWS option; no managed services add value |
| Current — AWS EC2 t3.small | ~$20 | baseline | |
| Path C — AWS + RDS | ~$26–34 | +30–70% | Managed DB premium outweighs ops savings |

---

## Recommendation

**Path B (Hetzner CX22) at ~$5/month.** The cost gap is not marginal — it is 4×
cheaper than the current AWS setup for equal or better hardware specs (4 GB RAM
vs. 2 GB, same CPU count, local NVMe instead of networked EBS). The ops posture
is identical to the current setup: self-managed Postgres/PostGIS, Caddy, Docker
Compose. Migration complexity is a one-time data export + re-provision, not an
architectural change.

**If staying on AWS is a hard requirement**, Path A (t4g.small) reduces the bill by
~15% with zero ops change. Adding Reserved Instances drops it further to ~$13/month
with a 12-month commitment. No AWS managed service beats its self-managed
equivalent on cost at this scale — CloudWatch, ALB, AWS Backup, and Route 53 all
add cost, not save it.

**Path C is not recommended** at current scale. The RDS managed-DB premium adds
$14+/month for automated backups (the one concrete cost win, worth ~$0.46/month),
automated minor version patches, and failover readiness. Failover requires Multi-AZ
($28/month for DB alone), which doubles the DB cost again and brings the total to
~$40/month. The ops savings are real but do not justify a 75–100% cost increase
over the current baseline. If data volume grows substantially and DB ops burden
becomes non-trivial, re-evaluate Path C then.

### Cost/reliability tradeoffs, explicitly

| Path | Reliability posture | Cost/reliability tradeoff |
|---|---|---|
| Path B | Single-node, no managed HA, manual backups | Same as current. Lower cost, same risk profile. |
| Path A | Single-node, no managed HA, manual backups | 15% cheaper, no change in risk posture. |
| Path C (Single-AZ) | Managed automated backups + PITR, no HA | 30–70% more expensive; buys backup automation, not availability |
| Path C (Multi-AZ) | Managed HA with automated failover | ~100% more expensive than current; justified only if uptime SLA matters |

At current and near-term scale, the app has no documented uptime SLA. Path B's
risk posture matches the current production setup; the cost savings are real.

// Mergio 🤘 — AWS managed services that win on cost at this scale: zero.
