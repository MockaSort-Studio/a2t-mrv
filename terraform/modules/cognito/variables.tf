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


