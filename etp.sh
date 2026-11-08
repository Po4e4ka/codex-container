#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for config in sing-box.example.json vpn-profile.py; do
    [[ -s "$script_dir/$config" ]] || { echo "Missing $script_dir/$config" >&2; exit 1; }
done

vpn_ssh_dir="${VPN_SSH_DIR:-$HOME/.ssh}"
if [[ -f "$script_dir/.vpn-client.json" ]]; then
    vpn_ssh_dir="$script_dir/.private/vpn-client"
fi
[[ -d "$vpn_ssh_dir" ]] || { echo "Missing SSH directory: $vpn_ssh_dir" >&2; exit 1; }
python3 "$script_dir/vpn-profile.py" preflight --ssh-dir "$vpn_ssh_dir"
singbox_config="$script_dir/sing-box.json"
[[ -f "$singbox_config" ]] || singbox_config="$script_dir/sing-box.example.json"

docker_args=()
if [[ -S /var/run/docker.sock ]]; then
    docker_args+=(
        -v /var/run/docker.sock:/var/run/docker.sock
        --group-add "$(stat -c '%g' /var/run/docker.sock)"
    )
fi
docker_args+=(-v "$vpn_ssh_dir:/run/vpn-ssh:ro")
if [[ -d "$HOME/.ssh" ]]; then
    docker_args+=(-v "$HOME/.ssh:/home/codex/.ssh")
fi
if [[ -f "$script_dir/xray-client.json" ]]; then
    docker_args+=(-v "$script_dir/xray-client.json:/etc/xray/client.json:ro")
fi
if [[ -d "$HOME/www" ]]; then
    docker_args+=(-v "$HOME/www:/www")
fi
if [[ $# -eq 0 ]]; then
    set -- codex --sandbox workspace-write -c sandbox_workspace_write.network_access=true
fi

exec docker run --rm \
    --name "${AGENT_CONTAINER_NAME:-ai-agent}" \
    -it \
    -w /home/codex \
    --userns=host \
    --device /dev/net/tun \
    --add-host=local.flami.pro:host-gateway \
    --security-opt seccomp=unconfined \
    --security-opt apparmor=unconfined \
    --cap-add=SYS_ADMIN \
    --cap-add=NET_ADMIN \
    --privileged \
    --group-add 65534 \
    -v "$script_dir:/home/codex/project" \
    -v "$HOME/.codex:/home/codex/.codex" \
    -v "$singbox_config:/etc/sing-box/config.json:ro" \
    -v "$script_dir/entrypoint.sh:/entrypoint.sh:ro" \
    -v "$script_dir/CONTEXT.md:/home/codex/CONTEXT.md:ro" \
    "${docker_args[@]}" \
    -e VPN_SSH_DIR=/run/vpn-ssh \
    -e "VPN_PROFILE=${VPN_PROFILE:-}" \
    --entrypoint /bin/bash \
    ai-agent /entrypoint.sh "$@"
