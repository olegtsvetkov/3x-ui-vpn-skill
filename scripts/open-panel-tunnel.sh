#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  open-panel-tunnel.sh --host <ssh_target> [--ssh-password <pass>] [--local-port 12053] [--panel-port 2053]

Open an SSH local port forward to the loopback-bound 3X-UI panel.
EOF
}

HOST=""
SSH_PASSWORD=""
LOCAL_PORT="12053"
PANEL_PORT="2053"

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
    --local-port)
      LOCAL_PORT="${2:-}"
      shift 2
      ;;
    --panel-port)
      PANEL_PORT="${2:-}"
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

echo "Opening tunnel to http://127.0.0.1:${LOCAL_PORT}"
echo "Remote panel target is 127.0.0.1:${PANEL_PORT} on ${HOST}"
echo "Press Ctrl+C to close the tunnel."

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SSH_RUNNER=(bash "${SCRIPT_DIR}/ssh-with-password.sh")
if [[ -n "${SSH_PASSWORD}" ]]; then
  SSH_RUNNER+=(--ssh-password "${SSH_PASSWORD}")
fi

exec "${SSH_RUNNER[@]}" -N -L "${LOCAL_PORT}:127.0.0.1:${PANEL_PORT}" "${HOST}"
