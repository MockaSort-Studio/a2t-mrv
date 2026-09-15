variable "app_name" {
  description = "Application name used as a prefix for resource names and the Cognito domain."
  type        = string
}

variable "domain_prefix" {
  description = "Globally unique prefix for the Cognito hosted UI domain (e.g. 'a2t-mrv')."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
}

variable "admin_username" {
  description = "Email address used as the username for the admin Cognito user."
  type        = string
}

variable "admin_temp_password" {
  description = "Temporary password for the admin user. Rotate externally after first apply via admin-set-user-password --permanent."
  type        = string
  sensitive   = true
}
