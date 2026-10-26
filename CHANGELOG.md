# Changelog

Changes that affect what a reader runs or reads. Each chapter also states the date its steps last passed.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- Shared chapters 1 to 9 for Ubuntu 24.04 LTS: choosing a VPS, a user account with key-only SSH, firewall and automatic
  security updates, Docker without bypassing the firewall, a domain with HTTPS, backups with a restore drill, a Telegram
  bot, keeping the model API key out of images and logs, and monitoring with updates and rollback.
- Agent chapter for Hermes Agent v0.22.5: install, connect a model provider and Telegram, back up, update, roll back and
  uninstall.
- Agent chapter for OpenClaw v2026.10.7, with the same steps and the agent's own backup command.
- Test runner that runs every chapter in a fresh Ubuntu container or virtual machine and saves the result in `bukti/`.
- English and Malay text for every chapter, generated from the same tested step files.
- Contributing guide with a template for adding an agent, and a security policy.
