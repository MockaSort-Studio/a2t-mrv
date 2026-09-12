variable "bucket_name" {
  description = "Globally unique S3 bucket name. Lowercase, 3-63 characters, no underscores."
  type        = string
}

variable "ec2_instance_role_arn" {
  description = "ARN of the EC2 instance IAM role granted read/write access. Empty string skips bucket policy creation — wire from infra module output after issue-153."
  type        = string
  default     = ""
}

variable "days_to_warm" {
  description = "Days before objects transition from Standard (hot) to Standard-IA (warm). Minimum 30."
  type        = number
  default     = 30
}

variable "days_to_cold" {
  description = "Days before objects transition from Standard-IA (warm) to Glacier (cold). Must exceed days_to_warm."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
}

