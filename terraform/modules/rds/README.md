# terraform/modules/rds

Provisions the AWS RDS PostgreSQL instance for a2t-mrv, with Secrets Manager credential rotation and observability.

## What this module creates

| Resource | Notes |
|---|---|
| `aws_db_subnet_group` | Spans two private subnets in different AZs |
| `aws_db_parameter_group` | PostgreSQL 15; `rds.allowed_extensions` whitelists PostGIS family |
| `aws_security_group` (RDS) | Inbound 5432 from app EC2 SG only |
| `aws_iam_role` + policy attachment | Enhanced Monitoring role (`AmazonRDSEnhancedMonitoringRole`) |
| `aws_db_instance` | `db.t4g.small`, Single-AZ, gp3, storage-autoscaling, deletion protection, 7-day backups, Performance Insights (7-day free), Enhanced Monitoring (60s), CloudWatch logs |
| `aws_secretsmanager_secret` (DB) | Created and rotated by RDS via `manage_master_user_password = true` |
| `aws_secretsmanager_secret` (app) | `a2t-mrv/secret-key-base` — placeholder; value set post-provision |

## Inputs

| Variable | Description |
|---|---|
| `vpc_id` | VPC to place the RDS SG in |
| `db_subnet_ids` | Two private subnet IDs in different AZs |
| `app_security_group_id` | EC2 SG allowed on port 5432 |
| `db_name` | Initial database name |
| `db_username` | Master username |
| `backup_retention_days` | Automated backup window (1–35 days) |
| `tags` | Tags applied to all resources |

## After provisioning

1. Retrieve the DB credentials from Secrets Manager: the ARN is in `terraform output db_secret_arn`.
2. Connect to the RDS instance and run `CREATE EXTENSION postgis;` as the master user.
3. Set the `SECRET_KEY_BASE` value: `aws secretsmanager put-secret-value --secret-id a2t-mrv/secret-key-base --secret-string "$(mix phx.gen.secret)"`.
