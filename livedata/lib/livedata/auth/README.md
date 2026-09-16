# Livedata.Auth — authentication

Modules implementing USER_PASSWORD_AUTH against Cognito and session management.
Credentials are managed through the admin console at `/admin/users`.

## Modules

| Module | Role |
|---|---|
| `Livedata.Auth.Provider` | Public entry point — `authenticate/2` and `refresh_token/2`. Callers use only this. |
| `Livedata.Auth.ProviderBehaviour` | Behaviour contract for authentication backends |
| `Livedata.Auth.Cognito` | Production backend: USER_PASSWORD_AUTH via Cognito InitiateAuth API |
| `Livedata.Auth.CognitoMock` | Dev/test/preview backend: accepts any username with the configured bypass password |
| `Livedata.Auth.Secrets` | Fetches and caches Cognito credentials from AWS Secrets Manager and SSM |
| `Livedata.Auth.SessionBridge` | Short-lived ETS token bridge from LiveView to Plug session cookie |
| `Livedata.Auth.UserManagementBehaviour` | Behaviour contract for user pool management |
| `Livedata.Auth.UserManagementProvider` | Dispatcher for user management operations |
| `Livedata.Auth.CognitoUserManagement` | Production user management: AdminCreateUser, AdminDisableUser, etc. |
| `Livedata.Auth.CognitoMockUserManagement` | In-memory user management for dev/test |

The session-level API (store/retrieve/delete user identity, check token expiry) lives in
`Livedata.Auth` (`lib/livedata/auth.ex`).

## Auth flow

```
Browser → POST /login (LiveView form)
  → Provider.authenticate/2
    → Cognito.authenticate/2  (or CognitoMock in dev/test)
  → SessionBridge.store/1 → redirect to /auth/session/:token
  → AuthController.session/2 → Auth.put_session_user/2 → redirect to return_to
```

New-password challenge (FORCE_CHANGE_PASSWORD):

```
Cognito returns NEW_PASSWORD_REQUIRED challenge
  → login LiveView renders new-password form
  → Provider.respond_new_password/3
    → Cognito issues tokens → normal session flow continues
```

## Backend selection

The active backend is configured via `:auth_provider` in application config:

| Environment | Backend |
|---|---|
| Production (EC2) | `Livedata.Auth.Cognito` |
| Dev / test / Render preview | `Livedata.Auth.CognitoMock` |

## Configuration

| Key | Source |
|---|---|
| `auth_provider` | `config/*.exs` or `runtime.exs` |
| `auth_bypass_password` | `AUTH_BYPASS_PASSWORD` env var (CognitoMock only) |
| `cognito_issuer_url` | SSM `/a2t-mrv/cognito/region` + `/user-pool-id`, or `COGNITO_ISSUER_URL` env var |
| `cognito_secret_name` | `COGNITO_SECRET_NAME` env var (default: `a2t-mrv/cognito/client-secret`) |
| `cognito_credentials` | Fetched from Secrets Manager, cached in Application env |

In dev and test, `cognito_credentials` can be set directly in config to bypass Secrets Manager.

## Password policy

Defined in `terraform/modules/cognito/main.tf`:

| Rule | Value |
|---|---|
| Minimum length | 12 characters |
| Required character classes | uppercase, lowercase, digit |
| Symbols | not required |
| Temporary password validity | 7 days |

The temporary password for admin-invited and force-reset accounts is `Changeme1234!`,
communicated to the user out of band. The user must set a permanent password on first login.

## Token policy

Defined on the Cognito app client in `terraform/modules/cognito/main.tf`:

| Token | Lifetime |
|---|---|
| Access token | 60 minutes |
| ID token | 60 minutes |
| Refresh token | 1 day |

Token revocation is enabled. `AdminUserGlobalSignOut` is called on both block and
delete operations, which invalidates all refresh tokens immediately. The current
access token remains valid until its TTL expires — this is a Cognito constraint
and cannot be shortened without a server-side token blocklist.

## User groups

Two groups are provisioned in Terraform (`terraform/modules/cognito/main.tf`):

- **`users`** — every admin-created account is added here automatically on creation.
- **`admins`** — grants access to `/admin/*` routes. Managed per-user in the admin
  console via `AdminAddUserToGroup` / `AdminRemoveUserFromGroup`. The `cognito:groups`
  JWT claim is read at login to derive the `is_admin` session flag.

Role changes take effect on the user's next login — existing tokens are not invalidated.

## User statuses

Cognito tracks two orthogonal fields: `UserStatus` and `Enabled`. The admin UI
collapses them into a single effective status via `effective_status/1`:

| Effective status | Condition | Available admin actions |
|---|---|---|
| `CONFIRMED` | `Enabled: true`, status `CONFIRMED` | Force password reset, Disable |
| `UNCONFIRMED` | `Enabled: true`, status `UNCONFIRMED` | Confirm (`AdminConfirmSignUp`) |
| `FORCE_CHANGE_PASSWORD` | `Enabled: true`, status `FORCE_CHANGE_PASSWORD` | Disable |
| `DISABLED` | `Enabled: false` (any status) | Re-enable |

`AdminConfirmSignUp` is only valid for `UNCONFIRMED` users — calling it on
`FORCE_CHANGE_PASSWORD` returns `InvalidParameterException`.

## Dev / test accounts

Seeded by `CognitoMockUserManagement`:

| Email | Password | Role | Status |
|---|---|---|---|
| `admin@example.com` | bypass password (`config/dev.exs`) | Admin | CONFIRMED |
| `user@example.com` | bypass password | User | CONFIRMED |
| `pending@example.com` | — | User | UNCONFIRMED |

The bypass password authenticates any confirmed user without hitting Cognito.
For `FORCE_CHANGE_PASSWORD` users the bypass password still triggers the
new-password challenge, so the reset flow can be tested end-to-end.
To test the invite flow: add a user in the admin console, then log in as that
user with `Changeme1234!`.
