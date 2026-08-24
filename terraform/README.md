# terraform

Terraform root module for a2t-mrv AWS infrastructure.

Provisions the production VM via [`modules/infra`](modules/infra/README.md): VPC, subnet, internet gateway, route table, security group, EC2 instance, Elastic IP, and a gp3 EBS volume for the Postgres data directory.

## Prerequisites

- Terraform ≥ 1.6 or OpenTofu ≥ 1.6
- AWS credentials with EC2/VPC/EBS permissions
- An existing EC2 key pair in the target region

## Secrets required in GitHub Actions

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key with EC2/VPC/EBS permissions |
| `AWS_SECRET_ACCESS_KEY` | Matching IAM secret |

## Usage

```sh
cd terraform
terraform init
terraform plan -var="key_name=my-key"
terraform apply -var="key_name=my-key"
```

## Variables

| Name | Default | Description |
|---|---|---|
| `aws_region` | `eu-west-1` | AWS region |
| `instance_type` | `t3.small` | EC2 instance type |
| `key_name` | *(required)* | EC2 key pair name |
| `ssh_cidr_blocks` | `["0.0.0.0/0"]` | Restrict to known IPs in production |
| `data_volume_size_gb` | `20` | gp3 EBS volume size in GiB |
| `tags` | see variables.tf | Tags applied to all resources |
