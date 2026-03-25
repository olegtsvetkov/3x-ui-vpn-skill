# Changelog

## 2.0.0 - 2026-03-25

- moved the canonical `3x-ui-vps` skill bundle to `skills/3x-ui-vps/`
- kept repo-root `3x-ui-vps/` as a one-release compatibility shim
- renamed the Claude plugin namespace to `3x-ui-vpn-skills`
- switched `3x-ui-vps` metadata to a manual-first invocation model for Claude and Codex/OpenAI surfaces
- updated install and packaging docs to treat the repository root as a multi-skill Claude plugin
- clarified that the root bundle path is legacy and no longer canonical

## 1.0.1 - 2026-03-23

- corrected platform-specific invocation examples in the user README files
- expanded end-user guidance with commands, prompts, and required inputs
- removed the `sshpass` binary dependency while keeping password-based SSH support through `SSH_ASKPASS`

## 1.0.0 - 2026-03-21

- packaged the canonical `3x-ui-vps` Agent Skill bundle
- added Claude Marketplace plugin manifests
- added Codex UI metadata in `agents/openai.yaml`
- added `AGENTS.md` for Cursor and other AGENTS-compatible systems
- added bilingual publication README files
