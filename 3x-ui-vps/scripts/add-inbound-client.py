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
LIST_ENDPOINTS = ("/panel/api/inbounds/list",)
GET_ENDPOINTS = ("/panel/api/inbounds/get/{id}",)
UPDATE_ENDPOINTS = ("/panel/api/inbounds/update/{id}",)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Add another client to an existing 3X-UI inbound."
    )
    parser.add_argument("--panel-url", required=True, help="Panel base URL, usually the SSH tunnel URL")
    parser.add_argument("--username", required=True, help="3X-UI admin username")
    parser.add_argument("--password", required=True, help="3X-UI admin password")
    parser.add_argument("--inbound-id", type=int, help="Existing inbound ID. If omitted and only one inbound exists, it will be used.")
    parser.add_argument("--public-domain", default="", help="Override public domain used in the generated client URL")
    parser.add_argument("--client-name", default="", help="Readable client label for email and URL fragment")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the generated update payload and final client URL without calling the panel",
    )
    return parser


def make_opener() -> urllib.request.OpenerDirector:
    jar = CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))


def request(opener, method: str, url: str, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    with opener.open(req, timeout=20) as response:
        body = response.read()
        return response.getcode(), response.headers, body


def decode_json_body(body: bytes):
    body_text = body.decode(errors="replace")
    if not body_text:
        return None
    try:
        return json.loads(body_text)
    except json.JSONDecodeError:
        return {"raw": body_text}


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


def try_get_json(opener, base_url: str, endpoints):
    last_error = None
    for endpoint in endpoints:
        url = urllib.parse.urljoin(base_url.rstrip("/") + "/", endpoint.lstrip("/"))
        try:
            code, _, body = request(opener, "GET", url)
            parsed = decode_json_body(body)
            if 200 <= code < 300:
                return endpoint, parsed
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    raise RuntimeError(f"GET failed for endpoints {endpoints}: {last_error}")


def try_post_form(opener, base_url: str, endpoints, payload: dict):
    last_error = None
    data = urllib.parse.urlencode(payload).encode()
    headers = {"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"}
    for endpoint in endpoints:
        url = urllib.parse.urljoin(base_url.rstrip("/") + "/", endpoint.lstrip("/"))
        try:
            code, _, body = request(opener, "POST", url, data=data, headers=headers)
            parsed = decode_json_body(body)
            if isinstance(parsed, dict) and "success" in parsed and not parsed["success"]:
                last_error = RuntimeError(f"{endpoint} returned success=false: {parsed}")
                continue
            if 200 <= code < 300:
                return endpoint, parsed
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    raise RuntimeError(f"POST failed for endpoints {endpoints}: {last_error}")


def select_inbound_id(list_response, requested_id: int | None) -> int:
    items = []
    if isinstance(list_response, dict):
        obj = list_response.get("obj")
        if isinstance(obj, list):
            items = obj
    if requested_id is not None:
        return requested_id
    if len(items) == 1 and isinstance(items[0], dict) and "id" in items[0]:
        return int(items[0]["id"])
    raise RuntimeError("Inbound ID is required when the panel has zero or multiple inbounds.")


def parse_json_field(value, field_name: str):
    if isinstance(value, str):
        return json.loads(value)
    if isinstance(value, dict):
        return value
    raise RuntimeError(f"Unexpected {field_name} format: {type(value).__name__}")


def infer_domain(stream_settings: dict, explicit_domain: str) -> str:
    if explicit_domain:
        return explicit_domain
    xhttp_settings = stream_settings.get("xhttpSettings", {})
    host = xhttp_settings.get("host")
    if isinstance(host, str) and host:
        return host
    raise RuntimeError("Could not infer public domain from inbound stream settings. Pass --public-domain.")


def infer_path(stream_settings: dict) -> str:
    xhttp_settings = stream_settings.get("xhttpSettings", {})
    path = xhttp_settings.get("path")
    if isinstance(path, str) and path:
        return path
    raise RuntimeError("Could not infer XHTTP path from inbound stream settings.")


def next_client_name(existing_clients: list, default_prefix: str) -> str:
    return f"{default_prefix}-client-{len(existing_clients) + 1}"


def make_client(client_name: str, domain: str) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "email": f"{client_name}@{domain}",
        "flow": "",
        "limitIp": 0,
        "totalGB": 0,
        "expiryTime": 0,
        "enable": True,
        "tgId": "",
        "subId": secrets.token_hex(8),
        "reset": 0,
    }


def build_update_payload(inbound: dict, updated_settings: dict) -> dict:
    fields = (
        "up",
        "down",
        "total",
        "remark",
        "enable",
        "expiryTime",
        "listen",
        "port",
        "protocol",
        "streamSettings",
        "sniffing",
        "allocate",
    )
    payload = {}
    for field in fields:
        if field in inbound and inbound[field] is not None:
            payload[field] = inbound[field]
    payload["settings"] = json.dumps(updated_settings, separators=(",", ":"))
    return payload


def build_vless_url(client_id: str, domain: str, path: str, label: str) -> str:
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
    return f"vless://{client_id}@{domain}:443?{query}#{urllib.parse.quote(label, safe='')}"


def main() -> int:
    args = build_parser().parse_args()

    opener = make_opener()
    try:
        login_endpoint, _ = try_login(opener, args.panel_url, args.username, args.password)
        list_endpoint, list_response = try_get_json(opener, args.panel_url, LIST_ENDPOINTS)
        inbound_id = select_inbound_id(list_response, args.inbound_id)
        get_endpoint, get_response = try_get_json(
            opener,
            args.panel_url,
            tuple(endpoint.format(id=inbound_id) for endpoint in GET_ENDPOINTS),
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to load inbound context: {exc}", file=sys.stderr)
        return 1

    if not isinstance(get_response, dict) or not isinstance(get_response.get("obj"), dict):
        print(f"Unexpected inbound response: {get_response}", file=sys.stderr)
        return 1

    inbound = get_response["obj"]
    settings = parse_json_field(inbound.get("settings", "{}"), "settings")
    stream_settings = parse_json_field(inbound.get("streamSettings", "{}"), "streamSettings")
    clients = settings.setdefault("clients", [])
    if not isinstance(clients, list):
        print("Inbound settings.clients is not a list.", file=sys.stderr)
        return 1

    domain = infer_domain(stream_settings, args.public_domain)
    path = infer_path(stream_settings)
    client_name = args.client_name or next_client_name(clients, inbound.get("remark", "client"))
    client = make_client(client_name, domain)
    clients.append(client)
    payload = build_update_payload(inbound, settings)
    client_url = build_vless_url(client["id"], domain, path, client_name)

    if args.dry_run:
        print(f"Login endpoint: {login_endpoint}")
        print(f"List endpoint: {list_endpoint}")
        print(f"Get endpoint: {get_endpoint}")
        print(f"Inbound ID: {inbound_id}")
        print(json.dumps(payload, indent=2, ensure_ascii=True))
        print()
        print(client_url)
        return 0

    try:
        update_endpoint, response = try_post_form(
            opener,
            args.panel_url,
            tuple(endpoint.format(id=inbound_id) for endpoint in UPDATE_ENDPOINTS),
            payload,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to update inbound: {exc}", file=sys.stderr)
        print()
        print(client_url)
        return 1

    print(f"Login endpoint: {login_endpoint}")
    print(f"List endpoint: {list_endpoint}")
    print(f"Get endpoint: {get_endpoint}")
    print(f"Update endpoint: {update_endpoint}")
    print(f"Inbound ID: {inbound_id}")
    if response is not None:
        print("Panel response:")
        print(json.dumps(response, indent=2, ensure_ascii=True))
    print()
    print("Client URL:")
    print(client_url)
    print()
    print("Client details:")
    print(f"- Name: {client_name}")
    print(f"- UUID: {client['id']}")
    print(f"- Email: {client['email']}")
    print(f"- Public domain: {domain}")
    print(f"- Path: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
