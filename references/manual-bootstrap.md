# Manual Bootstrap

Use this when `bootstrap-inbound.py` cannot create the inbound through the 3X-UI API.

## Pre-checks

- nginx is already serving the public domain on `443`
- nginx secret path matches the path you will enter in 3X-UI
- panel is reachable only through the SSH tunnel
- backend port is not already occupied
- the panel tunnel has a live local listener such as `127.0.0.1:12053`

Quick local checks:

```bash
lsof -nP -iTCP:12053 -sTCP:LISTEN
curl -I http://127.0.0.1:12053/
```

Notes:

- a panel root `404` is acceptable and still confirms that the tunnel reaches 3X-UI
- if the SSH tunnel closes immediately, avoid parallel SSH retries, wait briefly, and reopen one tunnel only

## Panel path

1. Open the panel through the SSH tunnel.
2. Go to `Inbounds`.
3. Click `Add Inbound`.

## Field mapping

Use these values:

- `Remark`: any readable name, for example `vless-xhttp-tls`
- `Enable`: on
- `Protocol`: `VLESS`
- `Listen IP`: `127.0.0.1`
- `Port`: backend port from deploy, for example `1234`
- `Client UUID`: generated UUID
- `Client Email`: any label, for example `vless-xhttp-tls@domain`
- `Transmission` or `Network`: `XHTTP`
- `Path`: exact secret path from nginx, for example `/xhttp-1234567890abcdef`
- `Host`: public domain
- `TLS` on backend inbound: disabled or `none`
- `Sniffing`: enabled

If the UI still exposes older transport naming, choose the path-based `XHTTP` variant that lets you set the same `path` and `host` values.

## Client output

Build the client link like this:

```text
vless://<uuid>@<domain>:443?encryption=none&security=tls&sni=<domain>&host=<domain>&alpn=h2&type=xhttp&path=%2F<secret>#vless-xhttp-tls
```

## Validation

After saving the inbound:

1. Confirm the inbound is enabled.
2. Confirm nginx path and inbound path are identical.
3. Confirm the backend listens on loopback.
4. Test the generated `vless://` URL in a client before changing anything else.

Useful checks:

```bash
ssh <target> 'ss -ltnp | egrep ":2053 |:2096 |:1234 "'
curl -k -I https://<domain>/
```

Expected result:

- `127.0.0.1:1234` is listening for the backend inbound
- `https://<domain>/` returns `401` for unmatched traffic

## Add Another Client Manually

Use this when the inbound already exists and you only need one more client.

1. Open the panel through the SSH tunnel.
2. Go to `Inbounds`.
3. Edit the existing VLESS XHTTP inbound instead of creating a new inbound.
4. Add one more client entry under the inbound clients list.

Use these values for the new client:

- `Client UUID`: generated UUID
- `Client Email`: unique label, for example `client-2@domain`
- `Enable`: on
- `Expiry`: unlimited unless the operator asked for limits
- `IP limit` and traffic limits: leave at `0` unless the operator asked for limits

Do not change these existing inbound values while adding a client:

- `Listen IP`
- `Port`
- `Transmission` or `Network`
- `Path`
- `Host`
- backend `TLS` setting

Build the new client link with the existing domain and path:

```text
vless://<new-uuid>@<domain>:443?encryption=none&security=tls&sni=<domain>&host=<domain>&alpn=h2&type=xhttp&path=%2F<secret>#<client-label>
```
