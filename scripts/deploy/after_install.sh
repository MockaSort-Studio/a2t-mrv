#!/usr/bin/env bash
# AfterInstall: extract the Mix release, fetch secrets from Secrets Manager,
# write the env file, and write/refresh the systemd unit.
# Runs after CodeDeploy has copied revision files to /opt/livedata/install/.
set -euo pipefail

REGION=$(curl -sf http://169.254.169.254/latest/meta-data/placement/region)

get_ssm() {
  aws ssm get-parameter --name "$1" --region "$REGION" --query 'Parameter.Value' --output text
}
get_secret() {
  aws secretsmanager get-secret-value --secret-id "$1" --region "$REGION" \
    --query SecretString --output text
}

# ── Extract release ───────────────────────────────────────────────────────────
echo "Extracting Mix release..."
rm -rf /opt/livedata/current
mkdir -p /opt/livedata/current
tar -xzf /opt/livedata/install/livedata.tar.gz \
  -C /opt/livedata/current --strip-components=1
chown -R livedata:livedata /opt/livedata/current

# ── Fetch runtime config from SSM ────────────────────────────────────────────
echo "Fetching runtime configuration from SSM..."
DB_SECRET_ARN=$(get_ssm /a2t-mrv/deploy/db-secret-arn)
SKB_ARN=$(get_ssm /a2t-mrv/deploy/secret-key-base-arn)
COGNITO_POOL_ID=$(get_ssm /a2t-mrv/runtime/cognito-user-pool-id)
COGNITO_DOMAIN_PREFIX=$(get_ssm /a2t-mrv/runtime/cognito-domain-prefix)
PHX_HOST=$(get_ssm /a2t-mrv/runtime/phx-host)

# ── Fetch secrets from Secrets Manager ───────────────────────────────────────
echo "Fetching secrets from Secrets Manager..."
DB_CREDS=$(get_secret "$DB_SECRET_ARN")
DB_HOST=$(echo "$DB_CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
DB_PORT=$(echo "$DB_CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
DB_NAME=$(echo "$DB_CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dbname','livedata'))")
DB_USER=$(echo "$DB_CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo "$DB_CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

SECRET_KEY_BASE=$(get_secret "$SKB_ARN")

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
