# Session Context

This project describes the environment in which the Codex agent (me) runs as a Docker container. I will communicate with the user in Russian.

## Project Selection — Critical
- First read `/home/codex/CONTEXT.md`; it is the authoritative context for the current session and environment.
- If the user explicitly specifies a project directory, work in exactly that directory.
- If the user does not specify a project directory, use `/home/codex/project` (`~/project`) as the active project.
- Do not infer the active project from other available workspace roots, the presence of `AGENTS.md`, Git repositories, writable paths, or context remembered from earlier sessions.
- After selecting the active project, read and follow the context and agent instructions applicable to that directory.

## Where I Run
- I run inside a Docker container from the `ai-agent` image.
- The container starts via `entrypoint.sh`, which brings up a VPN and then runs the command as user `codex`.

## Run Configuration (docker run)
The run command is defined in `etp.sh`:
- The container runs interactively (`-it`) and is removed on exit (`--rm`).
- Working directory: `/home/codex`.
- Device `/dev/net/tun` is passed through and `NET_ADMIN` capability is added for WireGuard.
- Volumes:
  - `${PWD}` → `/home/codex/project` (current project/session volume).
  - `${HOME}/.codex` → `/home/codex/.codex` (Codex config and data).

## Important Paths Inside the Container
- Working directory: `/home/codex`.
- Project/session volume: if the user has not explicitly specified a project directory, use `/home/codex/project` (`~/project`); if the user has specified a project directory, work in that directory instead.
- Codex configs: `/home/codex/.codex`.
- VPN config: `/home/codex/project/wg-config.conf` (fallback: `/etc/wireguard/wg-config.conf`).

## Entrypoint
`entrypoint.sh` performs:
1. Starts WireGuard using `wg-quick up /home/codex/project/wg-config.conf` (fallback: `/etc/wireguard/wg-config.conf`).
2. Waits up to 20 seconds for the `wg-config` interface.
3. Prints the current IP via `ifconfig.me` (if available).
4. Executes the command as the `codex` login user (`su - codex -s /bin/bash -c "$*"`).

## Base Image and User
- Base image: `ubuntu:latest`.
- Default user is renamed from `ubuntu` to `codex`.
  - `APP_USER=codex`, `APP_UID=1000`, `APP_GID=1000`.
- Home directory: `/home/codex`.

## Installed Packages (Key)
The image includes core utilities, languages, and dev tools, including:
- `git`, `curl`, `wget`, `jq`, `ripgrep`, `fd`, `tree`, `tmux`, `screen`, `zip/unzip`, `htop`.
- `nodejs`, `npm`, `python3`, `pip`, `venv`, `python3-dev`, `php-cli`, `composer`.
- `sqlite3`, `postgresql-client`, `redis-tools`.
- `wireguard-tools`, `resolvconf`, and networking tools (`iproute2`, `iputils-ping`).
- Build and dev libraries (`build-essential`, `libssl-dev`, `zlib1g-dev`, etc.).
- Media libraries: `imagemagick`, `ffmpeg`.
- Python packages from apt: `pillow`, `requests`, `numpy`, `pandas`, `pydantic`, `lxml`, `imageio`.

## Tooling Usage
I can use all installed tools and runtimes available in the container (e.g., Python, Node.js, CLI utilities) to execute tasks during the session.

## Project Volume Semantics
The mounted volume at `/home/codex/project` is not just “context.” It is the default active project when the user has not explicitly specified another project directory. You invoke me across different projects, and each time `project` may contain whatever you are working on for that session. The selected project may include its own context files, or it may not.

## Summary
I am a process inside the `ai-agent` container, started via `entrypoint.sh` under the `codex` user. I use the project directory explicitly specified by the user; otherwise, the active session project is `/home/codex/project`.
