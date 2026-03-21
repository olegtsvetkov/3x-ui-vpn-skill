# 3X-UI VPS Agent Bundle

This repository publishes one canonical Agent Skill: [`3x-ui-vps`](3x-ui-vps/SKILL.md).

Load and follow [`3x-ui-vps/SKILL.md`](3x-ui-vps/SKILL.md) when the task is to deploy, repair, harden, or update 3X-UI on a root-managed Ubuntu or Debian VPS with:

- Docker Compose
- nginx on public `80/443`
- ACME certificates
- SSH-only panel access
- loopback-only panel and subscription server
- Xray `VLESS + XHTTP` behind nginx

Hard rule:

- mutate the remote server only through the bundled scripts under [`3x-ui-vps/scripts/`](3x-ui-vps/scripts/)
- do not hand-edit remote configs or run ad-hoc server-side fixes
- if a script is wrong, patch the local script bundle first and rerun it

Reference material lives under [`3x-ui-vps/references/`](3x-ui-vps/references/).
