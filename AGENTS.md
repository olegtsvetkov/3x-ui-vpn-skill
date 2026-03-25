# 3X-UI VPS Agent Bundle

This repository publishes one canonical Agent Skill: [`3x-ui-vps`](skills/3x-ui-vps/SKILL.md).

Load and follow [`skills/3x-ui-vps/SKILL.md`](skills/3x-ui-vps/SKILL.md) when the task is to deploy, repair, harden, or update 3X-UI on a root-managed Ubuntu or Debian VPS with:

- Docker Compose
- nginx on public `80/443`
- ACME certificates
- SSH-only panel access
- loopback-only panel and subscription server
- Xray `VLESS + XHTTP` behind nginx

Hard rule:

- mutate the remote server only through the bundled scripts under [`skills/3x-ui-vps/scripts/`](skills/3x-ui-vps/scripts/)
- do not hand-edit remote configs or run ad-hoc server-side fixes
- if a script is wrong, patch the local script bundle first and rerun it

Reference material lives under [`skills/3x-ui-vps/references/`](skills/3x-ui-vps/references/).

Compatibility note:

- the repo-root [`3x-ui-vps`](3x-ui-vps) path is a transitional shim for one release
- treat [`skills/3x-ui-vps/`](skills/3x-ui-vps/) as the only canonical bundle path
