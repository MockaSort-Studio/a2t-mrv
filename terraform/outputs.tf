output "public_ip" {
  description = "Elastic IP address of the production VM."
  value       = module.infra.public_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.infra.instance_id
}

output "data_volume_id" {
  description = "EBS volume ID mounted for the Postgres data directory."
  value       = module.infra.data_volume_id
}

output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)."
  value       = module.rds.db_endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN of the RDS master user credentials."
  value       = module.rds.db_secret_arn
}

output "secret_key_base_secret_arn" {
  description = "Secrets Manager ARN of the Phoenix SECRET_KEY_BASE."
  value       = module.rds.secret_key_base_secret_arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_endpoint" {
  description = "OIDC issuer URL for the Cognito User Pool."
  value       = module.cognito.user_pool_endpoint
}

output "cognito_app_client_id" {
  description = "Cognito app client ID."
  value       = module.cognito.app_client_id
}

output "cognito_client_secret_arn" {
  description = "Secrets Manager ARN for the Cognito app client credentials."
  value       = module.cognito.client_secret_arn
}
