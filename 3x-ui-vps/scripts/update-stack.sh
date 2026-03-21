#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  update-stack.sh --host <ssh_target> [--ssh-password <pass>]

Run safe package and 3X-UI image updates on the remote host.
EOF
}

HOST=""
SSH_PASSWORD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --ssh-password)
      SSH_PASSWORD="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$HOST" ]]; then
  echo "--host is required." >&2
  usage >&2
  exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SSH_RUNNER=(bash "${SCRIPT_DIR}/ssh-with-password.sh")
if [[ -n "${SSH_PASSWORD}" ]]; then
  SSH_RUNNER+=(--ssh-password "${SSH_PASSWORD}")
fi

"${SSH_RUNNER[@]}" "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root on the remote host." >&2
  exit 1
fi

WORKDIR="/opt/3x-ui"
DB="${WORKDIR}/3x-ui-data/db/x-ui.db"
BOOTSTRAP_ENV="${WORKDIR}/bootstrap.env"
PANEL_PORT="2053"
SSH_PORT="$(sshd -T 2>/dev/null | awk '/^port / && !seen { print $2; seen=1 }')"

if [[ -f "${BOOTSTRAP_ENV}" ]]; then
  # shellcheck disable=SC1090
  . "${BOOTSTRAP_ENV}"
fi

if [[ -z "${SSH_PORT}" ]]; then
  SSH_PORT="22"
fi

apt update
apt upgrade -y
docker compose -f "${WORKDIR}/docker-compose.yml" pull
docker compose -f "${WORKDIR}/docker-compose.yml" up -d

docker exec 3x-ui sh -lc "/app/x-ui setting -listenIP 127.0.0.1 -port ${PANEL_PORT} >/tmp/x-ui-setting.log 2>&1 || x-ui setting -listenIP 127.0.0.1 -port ${PANEL_PORT} >/tmp/x-ui-setting.log 2>&1 || true"

if [[ -f "${DB}" ]]; then
  sqlite3 "${DB}" <<'SQL'
DELETE FROM settings WHERE key IN ('subPort', 'subListen');
INSERT INTO settings (key, value) VALUES ('subPort', '2096');
INSERT INTO settings (key, value) VALUES ('subListen', '127.0.0.1');
SQL
fi

docker restart 3x-ui >/dev/null

if command -v ufw >/dev/null 2>&1; then
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow "${SSH_PORT}/tcp" >/dev/null
  ufw allow 80/tcp >/dev/null
  ufw allow 443/tcp >/dev/null
  ufw --force enable >/dev/null
fi

echo
echo "Package status:"
apt list --upgradable 2>/dev/null || true
echo
echo "Container status:"
docker compose -f "${WORKDIR}/docker-compose.yml" ps
echo
echo "Listener status:"
ss -ltnp | egrep ":${PANEL_PORT} |:2096 |:1234 " || true
echo
echo "UFW status:"
ufw status numbered 2>/dev/null || true
echo
echo "Image digest:"
docker image inspect ghcr.io/mhsanaei/3x-ui:latest --format "{{.Id}}" 2>/dev/null || true
REMOTE
