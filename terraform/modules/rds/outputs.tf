output "db_endpoint" {
  description = "RDS instance endpoint (host:port)."
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "RDS instance port."
  value       = aws_db_instance.main.port
}

output "db_secret_arn" {
  description = "Secrets Manager ARN of the RDS master user credentials (managed by RDS rotation)."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "secret_key_base_secret_arn" {
  description = "Secrets Manager ARN of the Phoenix SECRET_KEY_BASE."
  value       = aws_secretsmanager_secret.secret_key_base.arn
}
