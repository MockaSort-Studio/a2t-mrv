#!/bin/bash
# Claude Code wrapper: drops from root to runner (UID 1001) before invoking CC.
#
# GHA container jobs always run as root. CC 2.1.186+ refuses
# --dangerously-skip-permissions as root, so every invocation must be
# non-root. Root can su to runner without a password.

set -e

CC_BIN="/opt/claude/.local/share/claude/versions/$CC_VERSION"

# Workspace files are root-owned after checkout. Give them to runner so CC
# can create branches, write files, and commit.
if [ -n "$GITHUB_WORKSPACE" ]; then
    chown -R runner:runner "$GITHUB_WORKSPACE" 2>/dev/null || true
fi

# The action writes CC settings to /github/home/.claude/ as root. Copy them
# to a runner-owned temp HOME so CC can read and write its own state there.
CC_HOME=$(mktemp -d /tmp/cc-home-XXXXXX)
mkdir -p "$CC_HOME/.claude"
cp -a /github/home/.claude/. "$CC_HOME/.claude/" 2>/dev/null || true
chown -R runner:runner "$CC_HOME"

# Write a small runner script so positional args pass cleanly through su.
# su -s /bin/bash user SCRIPTFILE ARG1 ... → bash runs SCRIPTFILE with $1=ARG1.
# Expanding CC_HOME and CC_BIN here (root context) avoids env var leakage.
RUNSCRIPT=$(mktemp /tmp/cc-run-XXXXXX.sh)
cat > "$RUNSCRIPT" << SCRIPT
#!/bin/bash
HOME="$CC_HOME" exec "$CC_BIN" "\$@"
SCRIPT
chmod 755 "$RUNSCRIPT"
chown runner:runner "$RUNSCRIPT"

# -m preserves the action's environment (GITHUB_TOKEN, CLAUDE_CODE_OAUTH_TOKEN,
# INPUT_* vars, etc.) so auth and action inputs work correctly under runner.
# -- ends su's own option parsing before the username and script args.
exec su -m -s /bin/bash -- runner "$RUNSCRIPT" "$@"
