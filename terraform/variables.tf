variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of the EC2 key pair to attach to the instance for SSH access."
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed inbound SSH. Restrict to known IPs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "data_volume_size_gb" {
  description = "Size in GiB of the gp3 EBS volume for the Postgres data directory."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Project   = "a2t-mrv"
    ManagedBy = "terraform"
  }
}

variable "db_name" {
  description = "Name of the initial database created on the RDS instance."
  type        = string
  default     = "livedata"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "livedata"
}

variable "backup_retention_days" {
  description = "Days to retain automated RDS backups (1-35)."
  type        = number
  default     = 7
}

variable "cognito_app_name" {
  description = "Application name prefix for Cognito resource names."
  type        = string
  default     = "a2t-mrv"
}

variable "cognito_domain_prefix" {
  description = "Globally unique prefix for the Cognito hosted UI domain."
  type        = string
  default     = "a2t-mrv"
}

variable "cognito_callback_urls" {
  description = "OAuth2 redirect URIs for the authorization_code flow."
  type        = list(string)
  default     = ["https://a2t-mrv.onrender.com/auth/cognito/callback"]
}

variable "cognito_logout_urls" {
  description = "Sign-out redirect URIs."
  type        = list(string)
  default     = ["https://a2t-mrv.onrender.com/"]
}
