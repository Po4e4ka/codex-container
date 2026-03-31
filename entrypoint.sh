#!/usr/bin/env bash
set -euo pipefail

WG_TARGET="${WIREGUARD_TARGET:-${WIREGUARD_CONFIG:-wg0}}"
if [[ "${WG_TARGET}" == *.conf ]]; then
  WG_INTERFACE_DEFAULT="$(basename "${WG_TARGET}" .conf)"
else
  WG_INTERFACE_DEFAULT="${WG_TARGET}"
fi
WG_INTERFACE="${WIREGUARD_INTERFACE:-${WG_INTERFACE_DEFAULT}}"

wg_down() {
  if ip link show "${WG_INTERFACE}" >/dev/null 2>&1; then
    echo "[+] Отключение WireGuard: ${WG_INTERFACE}"
    wg-quick down "${WG_INTERFACE}" >/dev/null 2>&1 || ip link delete dev "${WG_INTERFACE}" >/dev/null 2>&1 || true
  fi
}

trap wg_down EXIT INT TERM

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

if ip link show "${WG_INTERFACE}" >/dev/null 2>&1; then
  echo "[!] Интерфейс ${WG_INTERFACE} уже существует, перезапускаю"
  wg_down
fi

echo "[+] Подключение к WireGuard: ${WG_TARGET}"
wg-quick up "${WG_TARGET}"

echo -n '[+] Текущий IP: '
curl -s ifconfig.me || true
echo
set +e
su - codex -s /bin/bash -c "$*"
cmd_status=$?
set -e
exit "${cmd_status}"
