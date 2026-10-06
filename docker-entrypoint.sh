#!/bin/sh
set -eu

dashboard_username="${HERMES_DASHBOARD_BASIC_AUTH_USERNAME:-${ADMIN_USERNAME:-admin}}"
dashboard_password="${HERMES_DASHBOARD_BASIC_AUTH_PASSWORD:-${ADMIN_PASSWORD:-}}"

if [ -z "$dashboard_password" ]; then
    dashboard_password="$(python -c 'import secrets; print(secrets.token_urlsafe(16))')"
    echo "Generated admin password: $dashboard_password"
fi

dashboard_secret="${HERMES_DASHBOARD_BASIC_AUTH_SECRET:-}"
if [ -z "$dashboard_secret" ]; then
    dashboard_secret="$(
        ADMIN_PASSWORD="$dashboard_password" python -c \
            'import base64, hashlib, os; print(base64.b64encode(hashlib.sha256(("hermes-dashboard-session:" + os.environ["ADMIN_PASSWORD"]).encode()).digest()).decode())'
    )"
fi

export HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-${PORT:-8080}}"
export HERMES_DASHBOARD_BASIC_AUTH_USERNAME="$dashboard_username"
export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="$dashboard_password"
export HERMES_DASHBOARD_BASIC_AUTH_SECRET="$dashboard_secret"

if command -v git >/dev/null 2>&1; then
    mkdir -p "$(dirname "$GIT_CONFIG_GLOBAL")"

    # Do not store the token in .git-credentials.
    git config --global credential.helper ""
fi

# Configure GitHub authentication at container startup.
# GITHUB_TOKEN must be configured as a Railway secret variable.
if [ -n "${GITHUB_TOKEN:-}" ]; then
    if ! command -v git >/dev/null 2>&1; then
        echo "GITHUB_TOKEN is set, but git is not installed." >&2
        exit 1
    fi

    if [ ! -x /usr/local/bin/github-askpass ]; then
        echo "github-askpass helper is missing or not executable." >&2
        exit 1
    fi

    export GIT_ASKPASS=/usr/local/bin/github-askpass
    export GIT_TERMINAL_PROMPT=0

    # Keep Git configuration persistent, but never store the token itself.
    export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-${HERMES_HOME:-/data/.hermes}/gitconfig}"
    git config --global credential.helper ""
fi

exec /opt/hermes/docker/entrypoint-dispatch.sh "$@"
