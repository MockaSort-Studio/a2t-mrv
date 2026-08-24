variable "aws_region" {
  description = "AWS region."
  type        = string
}

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
