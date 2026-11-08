#!/usr/bin/env bash
set -euo pipefail

update=0
no_cache=0
vpn=0
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--update)
      update=1
      shift
      ;;
    --no-cache)
      no_cache=1
      shift
      ;;
    --vpn)
      vpn=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-u|--update] [--no-cache] [--vpn]"
      echo "  --vpn: build through running VPN_CONTAINER (default: ai-agent), load into host Docker"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [-u|--update] [--no-cache] [--vpn]" >&2
      exit 1
      ;;
  esac
done

build_args=()
if [[ "$no_cache" -eq 1 ]]; then
  build_args+=(--no-cache)
fi
if [[ "$update" -eq 1 ]]; then
  build_args+=(--build-arg "CACHE_BUST=$(date +%s)")
fi

if [[ "$vpn" -eq 1 ]]; then
  vpn_container="${VPN_CONTAINER:-ai-agent}"
  container_id="$(docker inspect --type container --format '{{if .State.Running}}{{.Id}}{{end}}' "$vpn_container")"
  if [[ -z "$container_id" ]]; then
    echo "VPN container is not running: $vpn_container" >&2
    exit 1
  fi
  # Each recreated VPN container needs a builder bound to its new network namespace.
  builder="ai-vpn-${container_id:0:12}"
  if ! docker buildx inspect "$builder" >/dev/null 2>&1; then
    docker buildx create --name "$builder" --driver docker-container \
      --driver-opt "network=container:$container_id" \
      --buildkitd-flags '--allow-insecure-entitlement network.host'
  fi
  echo "Build network: VPN container $vpn_container; image destination: host Docker"
  docker buildx build --builder "$builder" --load \
    --network host --allow network.host \
    "${build_args[@]}" -t ai-agent -f ai.Dockerfile .
  exit 0
fi

# Read only the proxy value; never execute the contents of the env file.
proxy_env_file="${PROXY_ENV_FILE:-/www/utopy/.agent/.env}"
if [[ -z "${SOCKS5_PROXY:-}" && -r "$proxy_env_file" ]]; then
  SOCKS5_PROXY="$(python3 - "$proxy_env_file" <<'PY'
import re
import shlex
import sys

with open(sys.argv[1]) as env_file:
    for line in env_file:
        match = re.match(r'^\s*(?:export\s+)?SOCKS5_PROXY\s*=\s*(.*)$', line)
        if match:
            parts = shlex.split(match.group(1), comments=True)
            if len(parts) > 1:
                sys.exit('Invalid SOCKS5_PROXY value in proxy env file')
            print(parts[0] if parts else '')
            break
PY
  )"
fi
if [[ -n "${SOCKS5_PROXY:-}" ]]; then
  export SOCKS5_PROXY
  build_args+=(--secret id=xray_proxy,env=SOCKS5_PROXY)
  echo "Xray downloads: proxy enabled"
fi

docker build "${build_args[@]}" -t ai-agent -f ai.Dockerfile .
