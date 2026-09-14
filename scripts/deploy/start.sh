#!/usr/bin/env bash
# ApplicationStart: start the livedata service. Runs migrations before starting
# by calling the release's eval command; a failed migration aborts the deploy.
set -euo pipefail

# Run Ecto migrations using the release's built-in migrate command.
# This runs in the same environment as the service (reads /etc/livedata/env).
set -a; source /etc/livedata/env; set +a
/opt/livedata/current/bin/livedata eval "Livedata.Release.migrate()"

systemctl start livedata
