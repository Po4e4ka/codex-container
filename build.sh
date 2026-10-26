#!/usr/bin/env bash
set -euo pipefail

update=0
no_cache=0
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
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [-u|--update] [--no-cache]" >&2
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
