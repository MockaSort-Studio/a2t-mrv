# Verifies internal wiring of the cognito module without any real AWS calls.
# Requires Terraform >= 1.11.0 (override_during support).

mock_provider "aws" {}

variables {
  app_name       = "a2t-mrv"
  domain_prefix  = "a2t-mrv"
  admin_username = "admin@example.com"
  admin_password = "Temp!Pass123"
  tags           = { Environment = "test" }
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

run "app_client_allows_user_password_auth" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool_client.main.explicit_auth_flows, "ALLOW_USER_PASSWORD_AUTH")
    error_message = "App client must allow USER_PASSWORD_AUTH so InitiateAuth can be called directly"
  }
}

run "app_client_allows_refresh_token_auth" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool_client.main.explicit_auth_flows, "ALLOW_REFRESH_TOKEN_AUTH")
    error_message = "App client must allow REFRESH_TOKEN_AUTH for token refresh"
  }
}

run "app_client_has_no_srp_auth" {
  command = plan

  assert {
    condition     = !contains(aws_cognito_user_pool_client.main.explicit_auth_flows, "ALLOW_USER_SRP_AUTH")
    error_message = "App client must not enable SRP auth — the app uses USER_PASSWORD_AUTH only"
  }
}

run "app_client_generates_secret" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_client.main.generate_secret == true
    error_message = "App client must be a confidential client (generate_secret = true)"
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

run "admin_user_username_matches_var" {
  command = plan

  assert {
    condition     = aws_cognito_user.admin.username == var.admin_username
    error_message = "Admin user username must match var.admin_username"
  }
}

run "admin_user_password_set" {
  command = plan

  assert {
    condition     = aws_cognito_user.admin.password != null
    error_message = "Admin user must have a password set (CONFIRMED state provisioning)"
  }
}

run "admin_user_email_verified" {
  command = plan

  assert {
    condition     = aws_cognito_user.admin.attributes["email_verified"] == "true"
    error_message = "Admin user email must be pre-verified"
  }
}

run "admin_user_suppresses_welcome_email" {
  command = plan

  assert {
    condition     = aws_cognito_user.admin.message_action == "SUPPRESS"
    error_message = "Admin user creation must suppress the welcome email"
  }
}
