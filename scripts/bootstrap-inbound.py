#!/usr/bin/env python3
import argparse
import json
import secrets
import sys
import urllib.parse
import urllib.request
import uuid
from http.cookiejar import CookieJar


LOGIN_ENDPOINTS = ("/login", "/panel/login")
ADD_ENDPOINTS = (
    "/panel/api/inbounds/add",
    "/xui/inbound/add",
    "/panel/inbound/add",
    "/xui/API/inbounds/add",
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Bootstrap a VLESS XHTTP inbound in 3X-UI."
    )
    parser.add_argument("--panel-url", required=True, help="Panel base URL, usually the SSH tunnel URL")
    parser.add_argument("--username", required=True, help="3X-UI admin username")
    parser.add_argument("--password", required=True, help="3X-UI admin password")
    parser.add_argument("--public-domain", required=True, help="Public domain served by nginx")
    parser.add_argument("--backend-port", type=int, default=1234, help="Loopback backend port behind nginx")
    parser.add_argument("--path", default="", help="Secret path. Reuse the path from bootstrap-host.sh")
    parser.add_argument("--remark", default="vless-xhttp-tls", help="Inbound remark")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the generated payload and final client URL without calling the panel",
    )
    return parser


def normalize_path(value: str) -> str:
    if not value:
        return "/xhttp-" + secrets.token_hex(8)
    if value.startswith("/"):
        return value
    return "/" + value


def build_payload(domain: str, backend_port: int, path: str, remark: str) -> dict:
    client_id = str(uuid.uuid4())
    settings = {
        "clients": [{"id": client_id, "email": f"{remark}@{domain}", "flow": "", "limitIp": 0, "totalGB": 0, "expiryTime": 0, "enable": True, "tgId": "", "subId": secrets.token_hex(8), "reset": 0}],
        "decryption": "none",
        "fallbacks": [],
    }
    stream_settings = {
        "network": "xhttp",
        "security": "none",
        "externalProxy": [],
        "xhttpSettings": {
            "path": path,
            "host": domain,
            "mode": "auto",
        },
    }
    sniffing = {"enabled": True, "destOverride": ["http", "tls", "quic"], "metadataOnly": False, "routeOnly": False}
    payload = {
        "up": 0,
        "down": 0,
        "total": 0,
        "remark": remark,
        "enable": True,
        "expiryTime": 0,
        "listen": "127.0.0.1",
        "port": backend_port,
        "protocol": "vless",
        "settings": json.dumps(settings, separators=(",", ":")),
        "streamSettings": json.dumps(stream_settings, separators=(",", ":")),
        "sniffing": json.dumps(sniffing, separators=(",", ":")),
    }
    return {"payload": payload, "client_id": client_id}


def build_vless_url(client_id: str, domain: str, path: str, remark: str) -> str:
    query = urllib.parse.urlencode(
        {
            "encryption": "none",
            "security": "tls",
            "sni": domain,
            "host": domain,
            "alpn": "h2",
            "type": "xhttp",
            "path": path,
        }
    )
    label = urllib.parse.quote(remark, safe="")
    return f"vless://{client_id}@{domain}:443?{query}#{label}"


def make_opener() -> urllib.request.OpenerDirector:
    jar = CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))


def request(opener, method: str, url: str, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    with opener.open(req, timeout=20) as response:
        body = response.read()
        return response.getcode(), response.headers, body


def try_login(opener, base_url: str, username: str, password: str):
    form = urllib.parse.urlencode({"username": username, "password": password}).encode()
    headers = {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"}
    last_error = None
    for endpoint in LOGIN_ENDPOINTS:
        url = urllib.parse.urljoin(base_url.rstrip("/") + "/", endpoint.lstrip("/"))
        try:
            code, _, body = request(opener, "POST", url, data=form, headers=headers)
            if 200 <= code < 400:
                return endpoint, body.decode(errors="replace")
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    raise RuntimeError(f"Login failed for endpoints {LOGIN_ENDPOINTS}: {last_error}")


def try_add_inbound(opener, base_url: str, payload: dict):
    last_error = None
    data = urllib.parse.urlencode(payload).encode()
    headers = {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"}
    for endpoint in ADD_ENDPOINTS:
        url = urllib.parse.urljoin(base_url.rstrip("/") + "/", endpoint.lstrip("/"))
        try:
            code, _, body = request(opener, "POST", url, data=data, headers=headers)
            body_text = body.decode(errors="replace")
            parsed = None
            if body_text:
                try:
                    parsed = json.loads(body_text)
                except json.JSONDecodeError:
                    parsed = {"raw": body_text}
            if (
                isinstance(parsed, dict)
                and "success" in parsed
                and not parsed["success"]
            ):
                last_error = RuntimeError(f"{endpoint} returned success=false: {parsed}")
                continue
            if 200 <= code < 300:
                return endpoint, parsed
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    raise RuntimeError(f"Inbound creation failed for endpoints {ADD_ENDPOINTS}: {last_error}")


def print_manual_fallback(domain: str, backend_port: int, path: str, remark: str, client_id: str):
    print("Manual fallback:")
    print(f"- Remark: {remark}")
    print("- Protocol: VLESS")
    print(f"- Listen IP: 127.0.0.1")
    print(f"- Port: {backend_port}")
    print("- Transport/Network: XHTTP")
    print(f"- Path: {path}")
    print("- Security on backend inbound: none")
    print("- Public TLS endpoint: nginx on 443")
    print(f"- Client UUID: {client_id}")
    print(f"- SNI/server name: {domain}")


def main() -> int:
    args = build_parser().parse_args()
    path = normalize_path(args.path)
    generated = build_payload(args.public_domain, args.backend_port, path, args.remark)
    payload = generated["payload"]
    client_id = generated["client_id"]
    vless_url = build_vless_url(client_id, args.public_domain, path, args.remark)

    if args.dry_run:
        print(json.dumps(payload, indent=2))
        print()
        print(vless_url)
        print()
        print_manual_fallback(
            args.public_domain,
            args.backend_port,
            path,
            args.remark,
            client_id,
        )
        return 0

    opener = make_opener()
    try:
        login_endpoint, _ = try_login(opener, args.panel_url, args.username, args.password)
        add_endpoint, response = try_add_inbound(opener, args.panel_url, payload)
    except Exception as exc:  # noqa: BLE001
        print(f"Automatic bootstrap failed: {exc}", file=sys.stderr)
        print()
        print_manual_fallback(args.public_domain, args.backend_port, path, args.remark, client_id)
        print()
        print(vless_url)
        return 1

    print(f"Login endpoint: {login_endpoint}")
    print(f"Inbound endpoint: {add_endpoint}")
    if response is not None:
        print("Panel response:")
        print(json.dumps(response, indent=2, ensure_ascii=True))
    print()
    print("Client URL:")
    print(vless_url)
    print()
    print_manual_fallback(args.public_domain, args.backend_port, path, args.remark, client_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
