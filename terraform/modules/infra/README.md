# modules/infra

AWS compute, network, and storage primitives for the a2t-mrv production VM.

## Resources

| Resource | Purpose |
|---|---|
| `aws_vpc` | Isolated network (`10.0.0.0/16`) |
| `aws_subnet` | Single public subnet (`10.0.1.0/24`) |
| `aws_internet_gateway` | Public internet egress/ingress |
| `aws_route_table` + association | Default route to IGW |
| `aws_security_group` | SSH (22), HTTP (80), HTTPS (443) inbound; all outbound |
| `aws_instance` | EC2 VM (Amazon Linux 2023, configurable type) |
| `aws_eip` | Static public IP bound to the instance |
| `aws_ebs_volume` | gp3 data volume for the Postgres data directory |
| `aws_volume_attachment` | Attaches the data volume at `/dev/sdf` |

## Inputs

| Name | Type | Description |
|---|---|---|
| `aws_region` | `string` | AWS region |
| `instance_type` | `string` | EC2 instance type |
| `key_name` | `string` | EC2 key pair name |
| `ssh_cidr_blocks` | `list(string)` | CIDR blocks allowed inbound on port 22 |
| `data_volume_size_gb` | `number` | gp3 volume size in GiB |
| `tags` | `map(string)` | Tags applied to all resources |

## Outputs

| Name | Description |
|---|---|
| `public_ip` | Elastic IP public address |
| `instance_id` | EC2 instance ID |
| `data_volume_id` | EBS volume ID |

## Constraints

Zero AWS managed-service resources (`aws_lambda_function`, `aws_db_instance`, `aws_ecs_*`, `aws_dynamodb_*`). Every resource type has a direct equivalent on at least one other Terraform provider.
