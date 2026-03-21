#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bootstrap-host.sh --host <ssh_target> [--ssh-password <pass>] --domain <fqdn> --panel-username <user> --panel-password <pass> [--acme-email <email>] [--panel-port 2053] [--xray-backend-port 1234] [--xray-path /secret] [--render-dir <dir>] [--dry-run]

Deploy 3X-UI on a remote Ubuntu or Debian VPS over SSH.

Options:
  --host                SSH target, preferably root@host
  --ssh-password        Optional plain-text SSH password for password auth
  --domain              Public domain routed to the VPS
  --panel-username      3X-UI panel admin username
  --panel-password      3X-UI panel admin password
  --acme-email          Optional ACME account email
  --panel-port          Loopback-bound panel port (default: 2053)
  --xray-backend-port   Loopback backend port for Xray behind nginx (default: 1234)
  --xray-path           Secret nginx location path for XHTTP (default: randomized)
  --render-dir          Render docker-compose and nginx files locally for inspection or nginx -t
  --dry-run             Print the resolved settings and exit
  -h, --help            Show this help
EOF
}

HOST=""
SSH_PASSWORD=""
DOMAIN=""
PANEL_USERNAME=""
PANEL_PASSWORD=""
ACME_EMAIL=""
PANEL_PORT="2053"
XRAY_BACKEND_PORT="1234"
XRAY_PATH=""
RENDER_DIR=""
DRY_RUN="false"

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
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --panel-username)
      PANEL_USERNAME="${2:-}"
      shift 2
      ;;
    --panel-password)
      PANEL_PASSWORD="${2:-}"
      shift 2
      ;;
    --acme-email)
      ACME_EMAIL="${2:-}"
      shift 2
      ;;
    --panel-port)
      PANEL_PORT="${2:-}"
      shift 2
      ;;
    --xray-backend-port)
      XRAY_BACKEND_PORT="${2:-}"
      shift 2
      ;;
    --xray-path)
      XRAY_PATH="${2:-}"
      shift 2
      ;;
    --render-dir)
      RENDER_DIR="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
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

if [[ -z "$HOST" || -z "$DOMAIN" || -z "$PANEL_USERNAME" || -z "$PANEL_PASSWORD" ]]; then
  echo "--host, --domain, --panel-username, and --panel-password are required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$XRAY_PATH" ]]; then
  XRAY_PATH="/xhttp-$(openssl rand -hex 8)"
fi

if [[ ! "$XRAY_PATH" =~ ^/ ]]; then
  echo "--xray-path must start with '/'." >&2
  exit 1
fi

echo "Host: $HOST"
echo "Domain: $DOMAIN"
echo "Panel username: $PANEL_USERNAME"
echo "Panel port: $PANEL_PORT"
echo "Xray backend port: $XRAY_BACKEND_PORT"
echo "Xray path: $XRAY_PATH"
if [[ -n "$ACME_EMAIL" ]]; then
  echo "ACME email: $ACME_EMAIL"
fi
if [[ -n "$RENDER_DIR" ]]; then
  echo "Render dir: $RENDER_DIR"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  exit 0
fi

if [[ -n "$RENDER_DIR" ]]; then
  mkdir -p "$RENDER_DIR/certs" "$RENDER_DIR/acme-webroot"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$RENDER_DIR/certs/private.key" \
    -out "$RENDER_DIR/certs/fullchain.cer" \
    -days 1 \
    -subj "/CN=${DOMAIN}" >/dev/null 2>&1

  cat > "$RENDER_DIR/docker-compose.yml" <<EOF
services:
  3x-ui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3x-ui
    volumes:
      - ./3x-ui-data/db/:/etc/x-ui/
      - ./3x-ui-data/cert/:/root/cert/
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
EOF

  cat > "$RENDER_DIR/3x-ui-${DOMAIN}.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location ^~ /.well-known/acme-challenge/ {
        root ${RENDER_DIR}/acme-webroot;
        default_type text/plain;
    }

    location / {
        return 401;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate ${RENDER_DIR}/certs/fullchain.cer;
    ssl_certificate_key ${RENDER_DIR}/certs/private.key;

    location = ${XRAY_PATH} {
        grpc_pass grpc://127.0.0.1:${XRAY_BACKEND_PORT};
        grpc_set_header Host \$host;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto https;
        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        client_body_timeout 1h;
    }

    location ^~ ${XRAY_PATH}/ {
        grpc_pass grpc://127.0.0.1:${XRAY_BACKEND_PORT};
        grpc_set_header Host \$host;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto https;
        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        client_body_timeout 1h;
    }

    location / {
        return 401;
    }
}
EOF

  cat > "$RENDER_DIR/nginx.conf" <<EOF
events {}
http {
    access_log off;
    error_log stderr notice;
    include ${RENDER_DIR}/3x-ui-${DOMAIN}.conf;
}
EOF

  cat > "$RENDER_DIR/bootstrap.env" <<EOF
DOMAIN=${DOMAIN}
PANEL_PORT=${PANEL_PORT}
XRAY_BACKEND_PORT=${XRAY_BACKEND_PORT}
XRAY_PATH=${XRAY_PATH}
TRANSPORT=xhttp
SUB_PORT=2096
EOF

  echo "Rendered files in ${RENDER_DIR}"
  exit 0
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SSH_RUNNER=(bash "${SCRIPT_DIR}/ssh-with-password.sh")
if [[ -n "${SSH_PASSWORD}" ]]; then
  SSH_RUNNER+=(--ssh-password "${SSH_PASSWORD}")
fi

"${SSH_RUNNER[@]}" "$HOST" \
  "DOMAIN=$(printf '%q' "$DOMAIN") PANEL_USERNAME=$(printf '%q' "$PANEL_USERNAME") PANEL_PASSWORD=$(printf '%q' "$PANEL_PASSWORD") ACME_EMAIL=$(printf '%q' "$ACME_EMAIL") PANEL_PORT=$(printf '%q' "$PANEL_PORT") XRAY_BACKEND_PORT=$(printf '%q' "$XRAY_BACKEND_PORT") XRAY_PATH=$(printf '%q' "$XRAY_PATH") bash -s" <<'REMOTE'
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root on the remote host." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
WORKDIR="/opt/3x-ui"
CERT_DIR="${WORKDIR}/3x-ui-data/cert"
DB_DIR="${WORKDIR}/3x-ui-data/db"
ACME_WEBROOT="/var/www/acme"
NGINX_SITE="/etc/nginx/sites-available/3x-ui-${DOMAIN}.conf"
NGINX_LINK="/etc/nginx/sites-enabled/3x-ui-${DOMAIN}.conf"
DEFAULT_SITE="/etc/nginx/sites-enabled/default"
SSH_PORT="$(sshd -T 2>/dev/null | awk '/^port / && !seen { print $2; seen=1 }')"

if [[ -z "${SSH_PORT}" ]]; then
  SSH_PORT="22"
fi

write_http_only_nginx_site() {
  cat > "${NGINX_SITE}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_WEBROOT};
        default_type text/plain;
    }

    location / {
        return 401;
    }
}
EOF
}

# Preseed a cert-free nginx site before package configuration so a stale
# HTTPS config from an earlier run cannot break apt/nginx startup.
mkdir -p "${DB_DIR}" "${CERT_DIR}" "${ACME_WEBROOT}" "${WORKDIR}" \
  "$(dirname "${NGINX_SITE}")" "$(dirname "${NGINX_LINK}")"
write_http_only_nginx_site

if [[ -f "${DEFAULT_SITE}" ]]; then
  rm -f "${DEFAULT_SITE}"
fi

ln -sfn "${NGINX_SITE}" "${NGINX_LINK}"

apt-get update
apt-get install -y ca-certificates curl dnsutils gnupg nginx openssl socat sqlite3 ufw
dpkg --configure -a

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  for pkg in docker.io docker-compose docker-doc docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y "${pkg}" >/dev/null 2>&1 || true
  done

  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
fi

cat > "${WORKDIR}/docker-compose.yml" <<EOF
services:
  3x-ui:
    image: ghcr.io/mhsanaei/3x-ui:latest
    container_name: 3x-ui
    volumes:
      - ./3x-ui-data/db/:/etc/x-ui/
      - ./3x-ui-data/cert/:/root/cert/
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      XUI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
EOF

write_http_only_nginx_site
nginx -t
systemctl enable --now nginx
systemctl reload nginx

DOMAIN_A_RECORDS="$(dig +short A "${DOMAIN}" | awk 'NF')"
DOMAIN_AAAA_RECORDS="$(dig +short AAAA "${DOMAIN}" | awk 'NF')"

if [[ -z "${DOMAIN_A_RECORDS}${DOMAIN_AAAA_RECORDS}" ]]; then
  echo "Remote dig returned no A/AAAA records for ${DOMAIN}." >&2
  exit 1
fi

echo "Remote dig for ${DOMAIN}:"
if [[ -n "${DOMAIN_A_RECORDS}" ]]; then
  printf '  A    %s\n' ${DOMAIN_A_RECORDS}
fi
if [[ -n "${DOMAIN_AAAA_RECORDS}" ]]; then
  printf '  AAAA %s\n' ${DOMAIN_AAAA_RECORDS}
fi

if [[ ! -d "/root/.acme.sh" ]]; then
  curl -fsSL https://get.acme.sh | sh -s email="${ACME_EMAIL:-}"
fi

if [[ -n "${ACME_EMAIL}" ]]; then
  /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
fi

if ! /root/.acme.sh/acme.sh --issue -d "${DOMAIN}" -w "${ACME_WEBROOT}" --keylength ec-256; then
  EXISTING_ACME_CERT_DIR="/root/.acme.sh/${DOMAIN}_ecc"
  if [[ -f "${EXISTING_ACME_CERT_DIR}/fullchain.cer" && -f "${EXISTING_ACME_CERT_DIR}/${DOMAIN}.key" ]]; then
    echo "acme.sh issue skipped or returned non-zero, but an existing ECC certificate is present. Reusing it."
  else
    echo "acme.sh failed and no reusable certificate was found for ${DOMAIN}." >&2
    exit 1
  fi
fi
/root/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" --ecc \
  --fullchain-file "${CERT_DIR}/fullchain.cer" \
  --key-file "${CERT_DIR}/private.key" \
  --reloadcmd "systemctl reload nginx"

cat > "${NGINX_SITE}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location ^~ /.well-known/acme-challenge/ {
        root ${ACME_WEBROOT};
        default_type text/plain;
    }

    location / {
        return 401;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate ${CERT_DIR}/fullchain.cer;
    ssl_certificate_key ${CERT_DIR}/private.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:TLSCache:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location = ${XRAY_PATH} {
        grpc_pass grpc://127.0.0.1:${XRAY_BACKEND_PORT};
        grpc_set_header Host \$host;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto https;
        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        client_body_timeout 1h;
    }

    location ^~ ${XRAY_PATH}/ {
        grpc_pass grpc://127.0.0.1:${XRAY_BACKEND_PORT};
        grpc_set_header Host \$host;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header X-Forwarded-Proto https;
        grpc_read_timeout 1h;
        grpc_send_timeout 1h;
        client_body_timeout 1h;
    }

    location / {
        return 401;
    }
}
EOF

nginx -t
systemctl reload nginx

docker compose -f "${WORKDIR}/docker-compose.yml" pull
docker compose -f "${WORKDIR}/docker-compose.yml" up -d

sleep 5

docker exec \
  -e PANEL_USERNAME="${PANEL_USERNAME}" \
  -e PANEL_PASSWORD="${PANEL_PASSWORD}" \
  3x-ui sh -lc '/app/x-ui setting -listenIP 127.0.0.1 -port '"${PANEL_PORT}"' -username "$PANEL_USERNAME" -password "$PANEL_PASSWORD" >/tmp/x-ui-setting.log 2>&1 || x-ui setting -listenIP 127.0.0.1 -port '"${PANEL_PORT}"' -username "$PANEL_USERNAME" -password "$PANEL_PASSWORD" >/tmp/x-ui-setting.log 2>&1 || true'

sqlite3 "${DB_DIR}/x-ui.db" <<SQL
DELETE FROM settings WHERE key IN ('subPort', 'subListen');
INSERT INTO settings (key, value) VALUES ('subPort', '2096');
INSERT INTO settings (key, value) VALUES ('subListen', '127.0.0.1');
SQL

docker restart 3x-ui >/dev/null
sleep 5

ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow "${SSH_PORT}/tcp" >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null

cat > "${WORKDIR}/bootstrap.env" <<EOF
DOMAIN=${DOMAIN}
PANEL_PORT=${PANEL_PORT}
XRAY_BACKEND_PORT=${XRAY_BACKEND_PORT}
XRAY_PATH=${XRAY_PATH}
TRANSPORT=xhttp
SUB_PORT=2096
SSH_PORT=${SSH_PORT}
EOF

echo
echo "3X-UI deploy complete."
echo "Panel target: http://127.0.0.1:${PANEL_PORT}"
echo "Public domain: https://${DOMAIN}"
echo "Secret path: ${XRAY_PATH}"
echo
echo "Verification commands:"
echo "  ss -ltnp | egrep ':${PANEL_PORT} |:2096 |:${XRAY_BACKEND_PORT} '"
echo "  docker compose -f ${WORKDIR}/docker-compose.yml ps"
echo "  nginx -t"
echo "  ufw status numbered"
echo "  cat ${WORKDIR}/bootstrap.env"
REMOTE

cat <<EOF

Remote bootstrap finished.
Reuse this path in bootstrap-inbound.py:
  ${XRAY_PATH}

Useful next commands:
  $(dirname "$0")/open-panel-tunnel.sh --host ${HOST} --panel-port ${PANEL_PORT}
  python3 $(dirname "$0")/bootstrap-inbound.py --panel-url http://127.0.0.1:12053 --username <user> --password '<pass>' --public-domain ${DOMAIN} --backend-port ${XRAY_BACKEND_PORT} --path ${XRAY_PATH}
EOF
