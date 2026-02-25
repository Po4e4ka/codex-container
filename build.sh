#!/usr/bin/env bash
set -euo pipefail

update=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--update)
      update=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [-u|--update]" >&2
      exit 1
      ;;
  esac
done

build_args=()
if [[ "$update" -eq 1 ]]; then
  build_args+=(--build-arg "CACHE_BUST=$(date +%s)")
fi

docker build "${build_args[@]}" -t ai-agent -f ai.Dockerfile .
