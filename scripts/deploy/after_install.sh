#!/usr/bin/env bash
# AfterInstall: extract the Mix release, fetch secrets, write the env file,
# and write/refresh the systemd unit.
set -euo pipefail

# Region written by user_data at first boot — no IMDS dependency.
REGION=$(cat /etc/livedata/region)

# Secret names written by user_data from Terraform variables — no hardcoding.
# shellcheck source=/dev/null
source /etc/livedata/secrets.conf

get_secret() {
  aws secretsmanager get-secret-value \
    --secret-id "$1" --region "$REGION" \
    --query SecretString --output text
}
get_ssm() {
  aws ssm get-parameter \
    --name "$1" --region "$REGION" \
    --query 'Parameter.Value' --output text
}
json_field() {
  python3 -c "import sys,json; print(json.load(sys.stdin)['$1'])"
}

# ── Extract release ───────────────────────────────────────────────────────────
echo "Extracting Mix release..."
rm -rf /opt/livedata/current
mkdir -p /opt/livedata/current
tar -xzf /opt/livedata/install/livedata.tar.gz \
  -C /opt/livedata/current --strip-components=1
chown -R livedata:livedata /opt/livedata/current

# ── Fetch DB credentials from Secrets Manager ─────────────────────────────────
echo "Fetching DB credentials ($DB_CREDENTIALS_SECRET)..."
DB_JSON=$(get_secret "$DB_CREDENTIALS_SECRET")
DB_USER=$(echo "$DB_JSON" | json_field username)
DB_PASS=$(echo "$DB_JSON" | json_field password)
DB_HOST=$(echo "$DB_JSON" | json_field host)
DB_PORT=$(echo "$DB_JSON" | json_field port)
DB_NAME=$(echo "$DB_JSON" | json_field dbname)

# ── Fetch app secrets from Secrets Manager ────────────────────────────────────
echo "Fetching app secrets ($SECRET_KEY_BASE_SECRET)..."
SECRET_KEY_BASE=$(get_secret "$SECRET_KEY_BASE_SECRET")

# ── Fetch non-secret runtime config from SSM ──────────────────────────────────
echo "Fetching runtime config from SSM..."
PHX_HOST=$(get_ssm /a2t-mrv/runtime/phx-host)
COGNITO_POOL_ID=$(get_ssm /a2t-mrv/runtime/cognito-user-pool-id)
COGNITO_DOMAIN_PREFIX=$(get_ssm /a2t-mrv/runtime/cognito-domain-prefix)

# ── Write env file ────────────────────────────────────────────────────────────
echo "Writing /etc/livedata/env..."
mkdir -p /etc/livedata
chmod 700 /etc/livedata
cat > /etc/livedata/env << EOF
PHX_SERVER=true
PHX_HOST=${PHX_HOST}
PORT=4000
DATABASE_URL_MAIN=ecto://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
DATABASE_SSL=true
POOL_SIZE=5
SECRET_KEY_BASE=${SECRET_KEY_BASE}
COGNITO_USER_POOL_ID=${COGNITO_POOL_ID}
COGNITO_DOMAIN_PREFIX=${COGNITO_DOMAIN_PREFIX}
COGNITO_REGION=${REGION}
LD_LIBRARY_PATH=/opt/livedata/current/lib/openssl
EOF
chmod 600 /etc/livedata/env

# ── Write systemd unit ────────────────────────────────────────────────────────
echo "Writing systemd unit..."
cat > /etc/systemd/system/livedata.service << 'UNIT'
[Unit]
Description=Livedata Phoenix Application
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=livedata
Group=livedata
WorkingDirectory=/opt/livedata/current
EnvironmentFile=/etc/livedata/env
ExecStart=/opt/livedata/current/bin/livedata start
ExecStop=/opt/livedata/current/bin/livedata stop
Restart=on-failure
RestartSec=5
SyslogIdentifier=livedata

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable livedata
echo "AfterInstall complete."
