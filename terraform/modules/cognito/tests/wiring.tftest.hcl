# Verifies internal wiring of the cognito module without any real AWS calls.
# Requires Terraform >= 1.11.0 (override_during support).

mock_provider "aws" {}

variables {
  app_name      = "a2t-mrv"
  domain_prefix = "a2t-mrv"
  callback_urls = ["https://example.com/auth/cognito/callback"]
  logout_urls   = ["https://example.com/"]
  tags          = { Environment = "test" }
}

run "user_pool_uses_email_as_username" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool.main.username_attributes, "email")
    error_message = "User pool must use email as the username attribute"
  }
}

run "user_pool_verifies_email" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool.main.auto_verified_attributes, "email")
    error_message = "User pool must auto-verify email"
  }
}

run "app_client_uses_authorization_code_flow" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool_client.main.allowed_oauth_flows, "code")
    error_message = "App client must allow the authorization_code (code) flow"
  }
}

run "app_client_has_no_implicit_flow" {
  command = plan

  assert {
    condition     = !contains(aws_cognito_user_pool_client.main.allowed_oauth_flows, "implicit")
    error_message = "App client must not allow the implicit flow"
  }
}

run "app_client_generates_secret" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_client.main.generate_secret == true
    error_message = "App client must be a confidential client (generate_secret = true)"
  }
}

run "app_client_supports_only_cognito_idp" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_client.main.supported_identity_providers == toset(["COGNITO"])
    error_message = "App client must only support the built-in COGNITO identity provider (no federation)"
  }
}

run "app_client_has_oidc_scopes" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool_client.main.allowed_oauth_scopes, "openid")
    error_message = "App client must include the openid scope"
  }
}

run "secret_stored_separately_from_infra" {
  command = plan

  assert {
    condition     = strcontains(aws_secretsmanager_secret.cognito_client.name, "cognito")
    error_message = "Secrets Manager secret name must contain 'cognito' to distinguish it from the DB credential secret"
  }
}

run "domain_prefix_matches_var" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_domain.main.domain == var.domain_prefix
    error_message = "User pool domain prefix must match var.domain_prefix"
  }
}
