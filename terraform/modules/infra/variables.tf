variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access."
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks permitted inbound on port 22."
  type        = list(string)
}

variable "data_volume_size_gb" {
  description = "Size in GiB of the gp3 EBS data volume."
  type        = number
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for the RDS master-user credentials (from the rds module)."
  type        = string
}

variable "secret_key_base_secret_arn" {
  description = "Secrets Manager ARN for the Phoenix SECRET_KEY_BASE (from the rds module)."
  type        = string
}

variable "cognito_client_secret_arn" {
  description = "Secrets Manager ARN for the Cognito app-client credentials (from the cognito module)."
  type        = string
}

variable "storage_bucket_name" {
  description = "Name of the CRCF retention S3 bucket. Used to construct the IAM policy ARN without a module output reference."
  type        = string
}
