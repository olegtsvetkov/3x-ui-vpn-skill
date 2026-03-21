# Architecture

This skill uses a simple split:

- `3X-UI` container runs with `network_mode: host`
- panel binds to `127.0.0.1:<panel_port>`
- subscription server binds to `127.0.0.1:2096`
- nginx owns public `80/443`
- nginx terminates TLS for the user's domain
- nginx proxies one secret path to the local Xray backend port with `grpc_pass`
- `ufw` allows only SSH, HTTP, and HTTPS from the internet
- panel access happens through SSH local forwarding

## Data paths

Host paths:

- `/opt/3x-ui/3x-ui-data/db/` -> mounted into `/etc/x-ui/`
- `/opt/3x-ui/3x-ui-data/cert/` -> mounted into `/root/cert/`

The certificate is issued on the host with `acme.sh`, then installed into the mounted cert directory so nginx and 3X-UI can reference the same files.

For repeat deploys on the same domain, treat an existing valid ACME certificate as reusable state. If `acme.sh --issue` reports that the domain has not changed, the deploy should continue by reinstalling the existing certificate into the mounted cert directory instead of failing early.

## Public traffic

Public traffic model:

1. Client connects to `https://<domain>:443`
2. nginx presents the ACME certificate
3. nginx proxies only the configured secret path to `grpc://127.0.0.1:<xray_backend_port>`
4. every other route returns `401`

That keeps the public surface intentionally narrow.

## Panel isolation

The panel must not listen on `0.0.0.0`.

After deploy, verify:

```bash
ss -ltnp | grep ':2053 '
```

Expected result: a listener on `127.0.0.1:2053` only.

The subscription server should also stay local:

```bash
ss -ltnp | grep ':2096 '
```

Expected result: a listener on `127.0.0.1:2096` only.

Open the panel only through:

```bash
ssh -L 12053:127.0.0.1:2053 root@vps
```

If password-auth SSH is in use, prefer the bundled tunnel script rather than hand-writing `ssh -L`.

Operational note:

- some hosts may temporarily refuse or close fresh SSH sessions after several rapid retries
- prefer serial SSH operations when opening the panel tunnel and calling the panel API
- if a tunnel dies immediately, wait briefly and retry one connection instead of starting several in parallel

Local validation for the tunnel:

```bash
lsof -nP -iTCP:12053 -sTCP:LISTEN
```

Expected result: a local listener on `127.0.0.1:12053` or `[::1]:12053`.

## Xray transport note

The public connection is TLS because nginx terminates TLS on `443`.

The backend Xray inbound behind nginx should stay plain `XHTTP` on loopback. Do not enable inbound TLS on the backend listener unless you intentionally redesign the nginx routing. The client still uses a TLS `vless://` URL because the public edge is nginx.

When adding more users later, prefer appending clients to the existing inbound instead of creating duplicate inbounds with the same backend port, host, and path. The stable tuple is:

- public domain
- secret XHTTP path
- backend loopback port
