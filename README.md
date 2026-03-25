[English](README.md) | [Русский](README_RU.md)

# Run your own Xray VPN in 10 minutes using AI agent

Set up an Xray VLESS VPN on your own server or VPS with one command, using the 3X-UI panel for installation and management.

You need:

- a VPS running Ubuntu 24 or newer at any hosting provider
- `1 vCPU`
- `512 MB` memory
- `10 GB` disk space
- about `10 minutes`

The canonical skill bundle lives in [`skills/3x-ui-vps/`](skills/3x-ui-vps/).

Architecture details: [`skills/3x-ui-vps/references/architecture.md`](skills/3x-ui-vps/references/architecture.md)

This repository root is also a Claude Code plugin with namespace `3x-ui-vpn-skills`. The `3x-ui-vps` skill inside it is manual-first because it changes remote infrastructure.

## What The Skill Can Do

The skill includes 5 workflows:

1. `Fresh deploy` configures your server from scratch, including dependency installation, port hardening, and base setup.
2. `Panel access` opens an SSH tunnel from the server to your computer so you can access the 3X UI panel.
3. `Quick inbound bootstrap` creates an Xray VLESS inbound on port `443` with nginx in front of it.
4. `Add another client to an existing inbound` adds a client to an existing inbound so you can connect one more device.
5. `Updates` updates the system (`apt update` and `apt upgrade`) and 3X UI.

## How To Use It

Install the skill using the instructions below and then use it in chat.

Examples:

- `Codex`: `$3x-ui-vps, set up a VPN for me`
- `Claude Code`: `/3x-ui-vpn-skills:3x-ui-vps set up a VPN for me`
- `Cursor`: `Set up a VPN for me using the instructions in AGENTS.md`
- `OpenClaw`: `Set up a VPN for me using the 3x-ui-vps skill`

Example prompt:

```text
$3x-ui-vps, set up a VPN for me
```

## Information You Will Be Asked For

After launch, the skill will ask for additional information:

- `SSH target`: the SSH user and IP in the format `root@X.Y.Z.A`; the `root` user is required to install all dependencies
- `SSH password`: the `root` password; not needed if key-based authentication is already configured
- `Domain`: your domain or subdomain where the VPN will be set up; buy any domain from a domain seller
- `Panel Username`: the username for the 3X UI panel
- `Panel Password`: the password for the 3X UI panel
- `ACME Email`: your email for issuing a Let's Encrypt SSL certificate for the domain above; optional

## Included Files

- [`skills/3x-ui-vps/SKILL.md`](skills/3x-ui-vps/SKILL.md): canonical Agent Skills bundle
- [`skills/3x-ui-vps/scripts/`](skills/3x-ui-vps/scripts/): the only allowed remote mutation interface
- [`skills/3x-ui-vps/references/`](skills/3x-ui-vps/references/): on-demand reference docs
- [`skills/3x-ui-vps/agents/openai.yaml`](skills/3x-ui-vps/agents/openai.yaml): Codex/OpenAI UI metadata
- [`3x-ui-vps`](3x-ui-vps): transitional compatibility shim to the canonical `skills/3x-ui-vps/` bundle
- [`AGENTS.md`](AGENTS.md): lightweight entry point for Cursor and AGENTS-compatible tools
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json): Claude plugin manifest
- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json): Claude marketplace manifest

## Install In Claude Marketplace

Install it from the Claude plugin UI or with:

```bash
claude plugin install 3x-ui-vpn-skills@olegtsvetkov-plugins
```

For local development, load the repository root as the plugin:

```bash
claude --plugin-dir .
```

Then invoke the skill with:

```text
/3x-ui-vpn-skills:3x-ui-vps
```

## Install In OpenClaw

Install it with:

```bash
clawhub install 3x-ui-vps
```

## Install In Codex

Codex installs user skills into `$CODEX_HOME/skills` (usually `~/.codex/skills`).

Inside Codex, the simplest path is the built-in `$skill-installer` with the GitHub subdirectory URL:

```text
$skill-installer install https://github.com/olegtsvetkov/3x-ui-vpn-skill/tree/master/skills/3x-ui-vps
```

Manual installation also works:

1. Copy or clone [`skills/3x-ui-vps/`](skills/3x-ui-vps/) into `~/.codex/skills/3x-ui-vps`.
2. Restart Codex.

## Install In Cursor

Cursor reads root-level [`AGENTS.md`](AGENTS.md).

Project-level installation:

1. Copy [`AGENTS.md`](AGENTS.md) to the root of your Cursor project.
2. Copy the full [`skills/3x-ui-vps/`](skills/3x-ui-vps/) folder into `skills/3x-ui-vps/` next to it.
3. Open or reload the project in Cursor.

Repository-level installation also works: clone this repository and open it directly in Cursor.

## Install In Any Agent Skills-Compatible System

Use the canonical [`skills/3x-ui-vps/`](skills/3x-ui-vps/) directory as the portable skill bundle.

Requirements:

- keep the directory name exactly `3x-ui-vps`
- keep [`SKILL.md`](skills/3x-ui-vps/SKILL.md), `scripts/`, `references/`, and `agents/` together
- install or copy that directory into the target product's skills folder or import flow

This layout follows the open Agent Skills specification and keeps the skill self-contained.

Compatibility note:

- the repo-root [`3x-ui-vps`](3x-ui-vps) path is a one-release shim for clones of this repository
- do not use the shim as the canonical install source for new integrations

## Usage Notes

- The skill is intentionally script-first. Remote server changes must go through the bundled scripts.
- The panel and subscription server are intended to stay loopback-only.
- nginx remains the public edge on `80/443`.
- The client-facing VPN transport is `VLESS + XHTTP` behind nginx.

## License

This repository and the bundled skill are released under the MIT License. See [LICENSE](LICENSE) and [`skills/3x-ui-vps/LICENSE.txt`](skills/3x-ui-vps/LICENSE.txt).
