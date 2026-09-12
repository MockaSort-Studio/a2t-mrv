output "user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN."
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "OIDC issuer URL (https://<endpoint>)."
  value       = "https://${aws_cognito_user_pool.main.endpoint}"
}

output "cognito_domain" {
  description = "Hosted UI base URL for the authorization_code flow."
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "app_client_id" {
  description = "Cognito app client ID."
  value       = aws_cognito_user_pool_client.main.id
}

output "client_secret_arn" {
  description = "Secrets Manager ARN holding the app client credentials (client_id + client_secret)."
  value       = aws_secretsmanager_secret.cognito_client.arn
}

data "aws_region" "current" {}
