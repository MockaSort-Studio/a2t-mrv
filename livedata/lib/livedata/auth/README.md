# Livedata.Auth — Cognito OIDC authentication

Modules implementing the Cognito `authorization_code` OIDC flow and session management.

## Modules

| Module | Role |
|---|---|
| `Livedata.Auth.Cognito` | OIDC flow via `assent`: builds authorization URL, exchanges code for tokens |
| `Livedata.Auth.CognitoBehaviour` | Behaviour contract — enables Mox-based testing |
| `Livedata.Auth.Secrets` | Fetches and caches Cognito client credentials from AWS Secrets Manager |

The session-level API (store/retrieve/delete user identity, check token expiry) lives in the parent module `Livedata.Auth` (`lib/livedata/auth.ex`).

## Flow

```
Browser → GET /auth/cognito → AuthController.new/2 → Cognito.authorize_url/0
  → redirect to Cognito Hosted UI
Cognito → GET /auth/cognito/callback → AuthController.callback/2 → Cognito.exchange_code/2
  → Auth.put_session_user/2 → redirect to auth_return_to path
```

## Auth return-to

The `store_return_to` plug in the `:browser` pipeline (router.ex) stores the
requested path in the session on every GET request, so the callback can redirect
there after login.

## Configuration

| Key | Source |
|---|---|
| `cognito_issuer_url` | `COGNITO_USER_POOL_ID` + `COGNITO_REGION` env vars |
| `cognito_redirect_uri` | derived from `PHX_HOST` |
| `cognito_hosted_ui_base` | `COGNITO_DOMAIN_PREFIX` + `COGNITO_REGION` env vars |
| `cognito_secret_name` | `COGNITO_SECRET_NAME` env var (default: `a2t-mrv/cognito/client-secret`) |
| `cognito_credentials` | fetched from Secrets Manager, cached in Application env |

In dev and test, `cognito_credentials` can be set directly in config to bypass Secrets Manager.
