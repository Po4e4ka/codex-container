#!/usr/bin/env bash
set -euo pipefail

docker_args=()
if [[ -S /var/run/docker.sock ]]; then
    docker_args+=(
        -v /var/run/docker.sock:/var/run/docker.sock
        --group-add "$(stat -c '%g' /var/run/docker.sock)"
    )
fi

docker run --rm \
    -it \
    -w /home/codex \
    --userns=host \
    --device /dev/net/tun \
    --cap-add=NET_ADMIN \
    -v ${PWD}:/home/codex/project \
    -v ${HOME}/.codex:/home/codex/.codex \
    "${docker_args[@]}" \
    ai-agent
