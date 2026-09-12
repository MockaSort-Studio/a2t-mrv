
# ── User Pool ─────────────────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "${var.app_name}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

# ── Hosted UI domain ──────────────────────────────────────────────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# ── App client (confidential, authorization_code / OIDC) ─────────────────────
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.app_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# ── Client secret in Secrets Manager ─────────────────────────────────────────
# Stores client_id alongside the secret so the app fetches both in one call.
resource "aws_secretsmanager_secret" "cognito_client" {
  name        = "${var.app_name}/cognito/client-secret"
  description = "Cognito app client credentials for ${var.app_name}"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "cognito_client" {
  secret_id = aws_secretsmanager_secret.cognito_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.main.id
    client_secret = aws_cognito_user_pool_client.main.client_secret
  })
}
