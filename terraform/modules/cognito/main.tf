
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
# Retained intentionally: removing a Cognito domain triggers an immediate
# deletion with no grace period, which would break any bookmarked hosted-UI
# URLs. OAuth flows are not used by the app client, but the domain is kept to
# avoid an irreversible disruptive change.
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# ── App client (confidential, USER_PASSWORD_AUTH / REFRESH_TOKEN_AUTH) ────────
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.app_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

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

# ── Admin user ────────────────────────────────────────────────────────────────
# Setting `password` (not `temporary_password`) creates the user directly in
# CONFIRMED state. Rotate the password externally after first apply:
#   aws cognito-idp admin-set-user-password --permanent ...
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.admin_username
  password     = var.admin_password

  # Suppress the welcome email — password is managed via Terraform variables,
  # not delivered to the inbox.
  message_action = "SUPPRESS"

  attributes = {
    email          = var.admin_username
    email_verified = "true"
  }
}
