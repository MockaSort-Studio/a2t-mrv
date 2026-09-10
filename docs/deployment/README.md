# Deployment path analysis — cost and fit

Investigation for [#139](https://github.com/MockaSort-Studio/a2t-mrv/issues/139).
Two-part document: §1–5 compare three deployment paths on monthly cost at
current/near-term pre-MVP scale. §6 projects the same paths against the
platform's stated objective — production, enterprise-grade MRV — and introduces
the dimensions the pre-MVP snapshot deliberately deferred: data growth, multiple
applications, role-based authentication, security compliance, and infra
management effort. Both parts conclude with a recommendation.

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

### Aurora PostgreSQL — considered and excluded

Aurora was raised in review as an omitted option. Addressing it explicitly:

Aurora PostgreSQL is a proprietary AWS storage engine with 6-way replication
across three AZs, up to 15 read replicas, and HA failover typically under 30
seconds — built in, without Multi-AZ as an add-on. Two pricing modes exist:

**Aurora Provisioned (smallest useful tier: db.t4g.medium, 2 vCPU / 4 GB):**

| Component | Monthly cost |
|---|---|
| EC2 t3.micro (app) | $8.32 |
| Aurora db.t4g.medium (Graviton, Single writer) | ~$47.00 |
| Aurora storage — 20 GB ($0.10/GB incl. I/O) | $2.00 |
| Aurora backup (100% of storage free for 1× retention) | $0 |
| **Total** | **~$57 / month** |

Aurora has no micro/nano provisioned tier — the smallest offered is t3.medium
($0.073/hr, non-Graviton) or t4g.medium ($0.065/hr). At this workload size, the
instance is substantially over-provisioned.

**Aurora Serverless v2 (auto-scaling from 0.5 ACU minimum):**

| Component | Monthly cost |
|---|---|
| EC2 t3.micro (app) | $8.32 |
| Aurora Serverless v2 — minimum 0.5 ACU ($0.06/ACU-hr) | ~$22 (floor) |
| Aurora storage — 20 GB | $2.00 |
| **Total** | **~$32 / month (floor; scales up under load)** |

Serverless v2 autoscales — useful for spiky workloads, but the floor is already
above RDS at this data volume, and it cannot scale to zero (0.5 ACU minimum).

**Aurora verdict: excluded at current/near-term scale.**
Aurora costs 2–4× RDS for features (multi-AZ HA, read replicas) the platform
does not yet require. The cost premium makes sense when uptime SLA demands
automatic failover with no manual intervention — a milestone this MVP has not
reached. Aurora's value proposition is at scale, which §6 addresses.

---

## Cost comparison (pre-MVP snapshot)

| Path | Monthly est. | vs. current | Notes |
|---|---|---|---|
| **Path B — Hetzner** | **~$5** | **−75%** | Clear winner on cost |
| Path A — AWS Graviton | ~$17 | −15% | Best AWS option; no managed services add value |
| Current — AWS EC2 t3.small | ~$20 | baseline | |
| Path C — AWS + RDS | ~$26–34 | +30–70% | Managed DB premium outweighs ops savings |
| Path C — AWS + Aurora Provisioned | ~$57 | +185% | HA built-in; overkill at current scale |
| Path C — AWS + Aurora Serverless v2 | ~$32+ | +60%+ | Auto-scales; floor still above RDS |

---

## Recommendation (pre-MVP)

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
automated minor version patches, and failover readiness. Aurora further doubles or
triples that premium for built-in HA that is not yet justified by any uptime SLA.

### Cost/reliability tradeoffs, explicitly

| Path | Reliability posture | Cost/reliability tradeoff |
|---|---|---|
| Path B | Single-node, no managed HA, manual backups | Same as current. Lower cost, same risk profile. |
| Path A | Single-node, no managed HA, manual backups | 15% cheaper, no change in risk posture. |
| Path C (RDS Single-AZ) | Managed automated backups + PITR, no HA | 30–70% more expensive; buys backup automation, not availability |
| Path C (RDS Multi-AZ) | Managed HA with automated failover | ~100% more expensive than current; justified only if uptime SLA matters |
| Path C (Aurora Serverless v2) | Built-in 6-way replication, sub-30s failover | 60%+ more expensive; the right HA posture, at a price |
| Path C (Aurora Provisioned) | Same as Serverless v2, fixed capacity | 185%+ more expensive; sized for a workload 5–10× current |

At current and near-term scale, the app has no documented uptime SLA. Path B's
risk posture matches the current production setup; the cost savings are real.

---

## Enterprise scale trajectory

The pre-MVP snapshot above deliberately optimized for the cheapest option that
works today. This section evaluates each path against the platform's actual
objective: a production enterprise-grade MRV platform, which introduces four
dimensions the pre-MVP analysis set aside.

### Data growth and retention policy

The `raw_measurements` table is append-only by design (CRCF-25, -26). Audit
records are never deleted — superseded measurements stay on disk. The `provenance`
and `values` JSONB columns carry variable-size payloads (satellite imagery
metadata, model outputs). Conservative growth estimate: 1–5 GB/year at current
pilot scale; 50–500 GB/year at multi-project production scale.

**Variable retention policies** — CRCF requires full audit trails indefinitely for
compliance records but permits tiering of non-audit raw data to cheaper storage.
This means the platform will eventually need a hot/warm/cold storage split:

| Tier | Data | Storage cost |
|---|---|---|
| Hot (Postgres on SSD) | Last 12 months of measurements | $0.10–0.115/GB/month |
| Warm (S3 Standard-IA) | 1–7 years, infrequently queried | $0.0125/GB/month |
| Cold (S3 Glacier Instant Retrieval) | 7+ years, compliance archive | $0.004/GB/month |

**Impact by path:**

- **Path B (Hetzner):** NVMe disk scales up only by node upgrade (CX32 at ~$10/month doubles RAM and disk, CX42 at ~$22/month further), or adding a network volume (€0.052/GB/month). No native S3-compatible tiering — a separate Hetzner Object Storage bucket (€0.006/GB/month, S3-compatible API) can serve as warm/cold tier. Disk management and tiering automation are fully DIY.
- **Path A (EC2):** EBS scales freely, but at $0.08/GB/month (gp3). S3 tiering hooks naturally — lifecycle rules, no custom code. CloudWatch can alert on disk fill thresholds.
- **Path C (RDS/Aurora):** Aurora storage auto-scales to 128 TiB with zero intervention. S3 tiering via application-level export or Aurora export to S3 (built-in feature). At large DB sizes, Aurora's per-GB storage cost ($0.10/GB) stays competitive with gp3 ($0.115/GB).

**Assessment:** Path B's disk management becomes a recurring ops task at scale. AWS S3 lifecycle policies automate the warm/cold split with no code. Aurora's auto-scaling storage removes the most common DBA intervention at large DB sizes.

### Multiple Elixir applications

The current stack is one Phoenix app (livedata). A methodology engine is planned
as a second service. Both are Elixir/OTP processes; they may share a DB or use
separate ones; they communicate over HTTP or directly via Phoenix PubSub/RPC.

**Compute options for two services:**

| Option | Path B (Hetzner) | Path A/C (AWS) | Notes |
|---|---|---|---|
| Single larger node | CX32 (4 vCPU / 8 GB) ~$10/month | t4g.medium (2 vCPU / 4 GB) ~$24/month | Run both apps as Docker containers on one host. Cheapest. No isolation between services. |
| Two separate nodes | 2× CX22 ~$10/month | 2× t4g.small ~$27/month | Full isolation; independent scaling; double the ops burden |
| Managed compute (AWS) | N/A | ECS Fargate (0.25 vCPU / 0.5 GB each) ~$9/month | No instance management; scales to zero; cold-start latency for Elixir releases (~10–30s) can be a problem for real-time MRV |

**Assessment:** For two always-on Elixir services, ECS Fargate is viable if
cold-start latency is acceptable. For real-time data ingestion (continuous
measurement streams), always-on instances are safer. The Hetzner multi-node option
remains cheapest. AWS becomes cost-competitive when factoring in ops labor savings.

### Role-based authentication

RBAC is deferred from the MVP but is a hard requirement for enterprise: CRCF audit
trails must be attributable to authenticated principals, and certification bodies
need controlled, scoped access distinct from developer access.

Candidate options:

| Option | Monthly cost | Notes |
|---|---|---|
| **Keycloak (self-hosted)** | $8–16 (dedicated t4g.small/medium) | Open source, OIDC + SAML + LDAP. De facto enterprise auth standard. Memory-hungry (1.5–2 GB minimum for JVM). Needs own managed DB or embedded H2 (not for production). High configurability, high ops burden. |
| **Authentik / Zitadel (self-hosted)** | $4–8 (t4g.micro) | Lighter-weight FOSS alternatives. OIDC + SAML. Go/Python. Less ecosystem integration than Keycloak, lower resource footprint. |
| **AWS Cognito** | $0 (first 50K MAUs free) | OIDC/OAuth2-native; integrates with IAM for AWS resource access; SAML federation. Advanced Security Features (MFA, anomaly detection) add $0.0275/MAU. For an enterprise MRV platform likely well under 50K MAUs → effectively free. Limited customizability; vendor lock-in to AWS. |
| **Managed FOSS (Zitadel Cloud / Ory)** | $25–250/month depending on plan | Zero ops; OIDC + SAML; dedicated tenants available. Middle ground between DIY and Cognito. |

**Impact by path:**

- **Path B (Hetzner):** Keycloak or Authentik on a second Hetzner node ($4–8/month). Total with auth: ~$9–13/month. Still cheapest, but ops surface grows: OS updates, JVM tuning, Keycloak DB backup — all manual.
- **Path A (EC2):** Same self-hosted auth options; t4g.micro ($4.60/month) for Authentik or t4g.small ($8.26/month) for Keycloak. SSM + CloudWatch give audit-ready logs at no extra cost. Cognito also viable for AWS-native OIDC integration.
- **Path C (AWS):** Cognito is the natural fit — integrates with ALB, API Gateway, and IAM natively. At low MAU counts it's free. For certification-body access with SAML federation, Cognito + Keycloak SAML bridge is a documented pattern.

**Assessment:** Cognito is a strong choice for AWS-native paths at this MAU scale
(free tier likely holds through early production). On Hetzner, Authentik on a
second micro node adds ~$4/month with reasonable ops overhead; Keycloak is more
capable but costs more to run and maintain.

### Security, compliance, and infra management effort

Enterprise MRV carries regulatory requirements that translate directly into infra
constraints:

**CRCF audit requirements (from the saga design doc):**
- Every state change requires a full audit trail (CRCF-25, -26, -28)
- Cross-scheme deduplication (future) — attributable to authenticated principals
- Data residency — EU data residency for CRCF certification bodies; all three paths have EU region options (AWS eu-west-1, Hetzner EU)

**Security compliance across paths:**

| Control | Path B (Hetzner) | Path A (EC2) | Path C (RDS/Aurora) |
|---|---|---|---|
| Encryption at rest | DIY (LUKS/dm-crypt on NVMe, manual setup) | EBS encryption (1-click, KMS-backed) | RDS encryption enabled by default |
| Encryption in transit | TLS via Caddy (manual cert renewal or Let's Encrypt auto) | Same; ALB terminates TLS if added | Same; RDS enforces TLS |
| API audit trail | auditd (manual install/configure) | CloudTrail (free for management events) | CloudTrail + RDS audit log (additional) |
| Vulnerability scanning | Manual apt updates + unattended-upgrades | AWS Inspector ($0.03–0.15/instance/month) | Inspector for EC2; RDS auto-patched |
| Secret management | Environment variables / HashiCorp Vault (self-hosted) | AWS Secrets Manager ($0.40/secret/month) or Parameter Store (free) | Same |
| DDoS protection | Provider-level (Hetzner DDoS mitigation, no SLA) | AWS Shield Standard (free, SLA-backed) | Same |
| Compliance reporting | Manual (custom audit scripts) | AWS Security Hub ($0.0010/finding, first 10K free) | Same |

**Infra management effort — honest assessment:**

| Dimension | Path B (Hetzner) | Path A (EC2) | Path C (RDS/Aurora) |
|---|---|---|---|
| OS patching | Full responsibility — unattended-upgrades + periodic manual | Same | EC2 OS: same; DB: managed by AWS |
| DB maintenance | Full — vacuums, index maintenance, extension updates | Same | Managed — automated minor version patches |
| Backup + restore | DIY — cron + rsync/S3 + restore testing | DIY for EC2; RDS PITR for DB | PITR + point-in-time restore built-in |
| Disk scaling | Upgrade node or add Hetzner volume (requires downtime or migration) | EBS resize live (no downtime) | Aurora: transparent, no limit |
| Monitoring | Prometheus + Grafana (self-hosted) or third-party | CloudWatch built-in; plus third-party | Same + RDS Performance Insights |
| Incident response | Fully manual; no on-call tooling included | CloudWatch alarms + SNS; PagerDuty integration | Same |

For a small team with strong DevOps capacity, Path B's ops burden is manageable
during the pre-MVP phase. As the platform moves toward enterprise certification and
24/7 operational expectations, the accumulated ops surface — OS patching, backup
testing, incident tooling, compliance evidence collection — shifts from manageable
to expensive in engineering hours.

### Enterprise recommendation

The pre-MVP recommendation (Path B, ~$5/month) holds while the platform has no
uptime SLA, a small team, and a data volume under ~20 GB. It is the right choice
to minimize cash burn during the validation phase.

The migration decision point: **when the first of these milestones is reached:**
- Data volume exceeds 100 GB, and DB disk management is costing engineering hours
- A second Elixir service (methodology engine) is deployed
- RBAC is introduced (auth adds $4–16/month to the Hetzner path)
- An enterprise customer demands ISO 27001 or SOC 2 evidence (compliance tooling on Hetzner is fully DIY)
- An uptime SLA is documented (single-node Hetzner has no managed failover)

**Enterprise-grade target architecture** when those milestones are reached:

| Component | Choice | Monthly est. |
|---|---|---|
| Compute | 2× EC2 t4g.small (app + methodology engine) or ECS Fargate | $17–27 |
| Database | Aurora PostgreSQL Serverless v2 (PostGIS enabled) | $22–60 (scales with load) |
| Authentication | AWS Cognito (< 50K MAU free; SAML for cert bodies) | $0–20 |
| Storage tiering | S3 Standard-IA + Glacier lifecycle rules | $1–10 (depends on volume) |
| Observability | CloudWatch + CloudTrail (CloudTrail management events free) | $5–15 |
| Secret management | AWS Secrets Manager | $2–5 |
| **Total (moderate load)** | | **~$47–137 / month** |

This is 10–27× the Hetzner floor — and worth it when the ops labor offset (DB
patching, backup testing, incident tooling, compliance evidence) is factored in.
Aurora's built-in HA removes the last single-point-of-failure without Multi-AZ
pricing gymnastics. Cognito's free MAU tier covers the platform through early
production. The S3 lifecycle chain solves retention policy compliance without
custom code.

**Path B is the right call now. AWS-native managed services are the right call at
the first enterprise milestone.** The migration path (Postgres → Aurora PostgreSQL)
is a one-time data export + import — no schema changes required, since the app
uses standard Postgres features only.

---

// Mergio 🤘 — cheapest today, not cheapest forever; know which game you're in.
