# modules/cognito

Cognito User Pool for email/password authentication. Consumed by KR 8.3 (app-side Cognito integration).

No SAML, no external identity providers, no Lambda triggers — those belong to OKR 4.

## Resources

| Resource | Purpose |
|---|---|
| `aws_cognito_user_pool` | User Pool with email/password sign-in and email verification |
| `aws_cognito_user_pool_domain` | Hosted UI domain for the authorization_code / OIDC flow |
| `aws_cognito_user_pool_client` | Confidential app client (authorization_code, OIDC scopes) |
| `aws_secretsmanager_secret` | Secret container for app client credentials |
| `aws_secretsmanager_secret_version` | Stores `client_id` + `client_secret` as JSON |

## Inputs

| Name | Type | Description |
|---|---|---|
| `app_name` | `string` | Prefix for resource names |
| `domain_prefix` | `string` | Globally unique Cognito hosted UI domain prefix |
| `callback_urls` | `list(string)` | OAuth2 redirect URIs |
| `logout_urls` | `list(string)` | Sign-out redirect URIs |
| `tags` | `map(string)` | Tags applied to all resources |

## Outputs

| Name | Description |
|---|---|
| `user_pool_id` | User Pool ID |
| `user_pool_arn` | User Pool ARN |
| `user_pool_endpoint` | OIDC issuer URL |
| `cognito_domain` | Hosted UI base URL |
| `app_client_id` | App client ID |
| `client_secret_arn` | Secrets Manager ARN for client credentials |

## Auth flow

The app client is configured for `authorization_code` grant with OIDC scopes (`openid`, `email`, `profile`). The Phoenix app (KR 8.3) will redirect users to the Cognito Hosted UI, receive the authorization code, and exchange it for tokens using the client credentials from Secrets Manager.

The client secret is stored in Secrets Manager as JSON: `{"client_id": "...", "client_secret": "..."}`. The app fetches both in a single Secrets Manager call.
