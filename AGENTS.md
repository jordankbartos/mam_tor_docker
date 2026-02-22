# Agent Guidelines: qBittorrent Docker Deployment

This repository manages the Docker deployment and maintenance scripts for a qBittorrent instance, optimized for privacy with WireGuard integration.

## 🧠 Core Philosophy
- **DRY (Don't Repeat Yourself):** Avoid logic duplication across scripts. Centralize shared variables or logic if used more than twice.
- **KISS (Keep It Simple, Stupid):** Prefer readable, standard shell commands over complex abstractions or obscure one-liners.
- **Single Responsibility:** Each script should do one thing well (e.g., fixing network routes vs. updating MAM session).

## 🚀 Environment & Tooling
- **Isolation:** All development tools (linting, validation) are isolated within the **Dev Container**. Do not install dev dependencies directly on the host.
- **Pre-commit:** Linting is automated via `pre-commit`. Ensure hooks pass before suggesting or making a commit.
- **ShellCheck:** Essential for shell script safety. It runs automatically on commit.

## 🛠 Common Commands
- **Run all checks:** `pre-commit run --all-files`
- **Test a script (debug mode):** `bash -x path/to/script.sh`
- **Check Docker config:** `docker compose config`
- **Verify VPN inside container:** `docker compose exec qbittorrent curl -I https://www.google.com`

## 🎨 Code Style
- **Indentation:**
    - Shell scripts: 4 spaces (enforced by `shfmt`).
    - YAML/JSON: 2 spaces.
- **Naming:**
    - Scripts: `kebab-case.sh`.
    - Variables: `UPPER_SNAKE_CASE`. Always quote variables: `"$VAR"`.
- **Scripts:** Use `#!/bin/bash` or `#!/bin/sh` explicitly. Prefer `$(...)` over backticks.

## 📝 Documentation Rule
**CRITICAL:** Any change to project architecture, script logic, or deployment flow **MUST** trigger a review of `README.md`.
- Keep `README.md` minimalist and human-readable.
- Focus on "What" and "How", not every minute detail.
- If a change is complex, ensure the README points the user in the right direction.

## 📁 Project Structure
- `scripts/`: Logic for network maintenance and MAM automation.
- `templates/`: Configuration templates (WireGuard, qBittorrent).
- `config/`: [Git-ignored] Application data, logs, and session state.
- `.devcontainer/`: Isolated development environment configuration.
- `docker-compose.yml`: Core service definition.
