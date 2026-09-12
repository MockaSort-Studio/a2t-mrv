# storage

S3 bucket with CRCF-compliant lifecycle tiering (hot → warm → cold) for the a2t-mrv platform.

## What it provisions

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` | CRCF retention bucket |
| `aws_s3_bucket_versioning` | Versions all objects — required for audit trail |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE-S3 (AES-256) — encryption at rest |
| `aws_s3_bucket_public_access_block` | Blocks all public access |
| `aws_s3_bucket_lifecycle_configuration` | Hot → Standard-IA (warm) → Glacier (cold) |
| `aws_s3_bucket_policy` | EC2 role access + HTTPS-only (created when `ec2_instance_role_arn` is set) |

## Encryption choice

SSE-S3 (AES-256). No per-API-call cost (unlike SSE-KMS) and no KMS key to manage. Switch to SSE-KMS only if a regulatory audit requires explicit key management trails.

## Lifecycle tiers (CRCF-31, CRCF-32)

| Tier | Storage class | Default |
|---|---|---|
| Hot | Standard | Day 0 |
| Warm | Standard-IA | Day 30 |
| Cold | Glacier | Day 90 |

`days_to_warm` and `days_to_cold` are configurable. Both current and noncurrent object versions follow the same schedule.

## Bucket policy

Created only when `ec2_instance_role_arn` is provided. Wire from the infra module IAM role output once issue-153 provisions the EC2 instance profile.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `bucket_name` | `string` | — | Globally unique bucket name |
| `ec2_instance_role_arn` | `string` | `""` | EC2 role ARN; policy skipped if empty |
| `days_to_warm` | `number` | `30` | Days to Standard-IA transition |
| `days_to_cold` | `number` | `90` | Days to Glacier transition |
| `tags` | `map(string)` | — | Tags applied to all resources |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | S3 bucket name |
| `bucket_arn` | Bucket ARN — referenced by EC2 instance profile in issue-153 |

