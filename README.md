# Run your own Xray VPN in 10 minutes using AI agent

Set up an Xray VLESS VPN on your own server or VPS with one command, using the 3X-UI panel for installation and management.

You need:

- a VPS running Ubuntu 24 or newer at any hosting provider
- `1 vCPU`
- `512 MB` memory
- `10 GB` disk space
- about `10 minutes`

The canonical skill bundle lives in [`3x-ui-vps/`](3x-ui-vps/).

Architecture details: [`3x-ui-vps/references/architecture.md`](3x-ui-vps/references/architecture.md)

## Included Files

- [`3x-ui-vps/SKILL.md`](3x-ui-vps/SKILL.md): canonical Agent Skills bundle
- [`3x-ui-vps/scripts/`](3x-ui-vps/scripts/): the only allowed remote mutation interface
- [`3x-ui-vps/references/`](3x-ui-vps/references/): on-demand reference docs
- [`3x-ui-vps/agents/openai.yaml`](3x-ui-vps/agents/openai.yaml): Codex/OpenAI UI metadata
- [`AGENTS.md`](AGENTS.md): lightweight entry point for Cursor and AGENTS-compatible tools
- [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json): Claude plugin manifest
- [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json): Claude marketplace manifest

## Install In Claude Marketplace

Install it from the Claude plugin UI or with:

```bash
claude plugin install 3x-ui-vps
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
$skill-installer install https://github.com/olegtsvetkov/3x-ui-vpn-skill/tree/master/3x-ui-vps
```

Manual installation also works:

1. Copy or clone [`3x-ui-vps/`](3x-ui-vps/) into `~/.codex/skills/3x-ui-vps`.
2. Restart Codex.

## Install In Cursor

Cursor reads root-level [`AGENTS.md`](AGENTS.md).

Project-level installation:

1. Copy [`AGENTS.md`](AGENTS.md) to the root of your Cursor project.
2. Copy the full [`3x-ui-vps/`](3x-ui-vps/) folder next to it.
3. Open or reload the project in Cursor.

Repository-level installation also works: clone this repository and open it directly in Cursor.

## Install In Any Agent Skills-Compatible System

Use the canonical [`3x-ui-vps/`](3x-ui-vps/) directory as the portable skill bundle.

Requirements:

- keep the directory name exactly `3x-ui-vps`
- keep [`SKILL.md`](3x-ui-vps/SKILL.md), `scripts/`, `references/`, and `agents/` together
- install or copy that directory into the target product's skills folder or import flow

This layout follows the open Agent Skills specification and keeps the skill self-contained.

## Usage Notes

- The skill is intentionally script-first. Remote server changes must go through the bundled scripts.
- The panel and subscription server are intended to stay loopback-only.
- nginx remains the public edge on `80/443`.
- The client-facing VPN transport is `VLESS + XHTTP` behind nginx.

## License

This repository and the bundled skill are released under the MIT License. See [LICENSE](LICENSE) and [`3x-ui-vps/LICENSE.txt`](3x-ui-vps/LICENSE.txt).
