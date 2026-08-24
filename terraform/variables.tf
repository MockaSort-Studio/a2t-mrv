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
