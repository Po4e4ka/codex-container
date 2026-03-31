#!/usr/bin/env bash
set -euo pipefail

WG_TARGET="${WIREGUARD_TARGET:-${WIREGUARD_CONFIG:-wg0}}"
if [[ "${WG_TARGET}" == *.conf ]]; then
  WG_INTERFACE_DEFAULT="$(basename "${WG_TARGET}" .conf)"
else
  WG_INTERFACE_DEFAULT="${WG_TARGET}"
fi
WG_INTERFACE="${WIREGUARD_INTERFACE:-${WG_INTERFACE_DEFAULT}}"
WG_CONFIG_FILE=""
WG_UP_TARGET="${WG_TARGET}"
TMP_WG_CONFIG=""

wg_down() {
  if ip link show "${WG_INTERFACE}" >/dev/null 2>&1; then
    echo "[+] Отключение WireGuard: ${WG_INTERFACE}"
    wg-quick down "${WG_INTERFACE}" >/dev/null 2>&1 || ip link delete dev "${WG_INTERFACE}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${TMP_WG_CONFIG}" && -f "${TMP_WG_CONFIG}" ]]; then
    rm -f "${TMP_WG_CONFIG}"
  fi
}

trap wg_down EXIT INT TERM

resolve_wg_config() {
  if [[ "${WG_TARGET}" == *.conf ]]; then
    if [[ -f "${WG_TARGET}" ]]; then
      WG_CONFIG_FILE="${WG_TARGET}"
      return 0
    fi
  else
    if [[ -f "/home/codex/project/${WG_TARGET}.conf" ]]; then
      WG_CONFIG_FILE="/home/codex/project/${WG_TARGET}.conf"
      return 0
    fi

    if [[ -f "/etc/wireguard/${WG_TARGET}.conf" ]]; then
      WG_CONFIG_FILE="/etc/wireguard/${WG_TARGET}.conf"
      return 0
    fi
  fi

  echo "[!] Не найден WireGuard конфиг для ${WG_TARGET}" >&2
  exit 1
}

prepare_wg_target() {
  resolve_wg_config

  # In Ubuntu containers /usr/sbin/resolvconf is often a systemd-resolved
  # compatibility alias, which fails without a system bus. We already manage
  # /etc/resolv.conf manually below, so strip DNS lines before wg-quick up.
  if grep -qiE '^[[:space:]]*DNS[[:space:]]*=' "${WG_CONFIG_FILE}"; then
    TMP_WG_CONFIG="$(mktemp "/tmp/${WG_INTERFACE}.XXXXXX.conf")"
    grep -viE '^[[:space:]]*DNS[[:space:]]*=' "${WG_CONFIG_FILE}" > "${TMP_WG_CONFIG}"
    chmod 600 "${TMP_WG_CONFIG}"
    WG_UP_TARGET="${TMP_WG_CONFIG}"
    echo "[!] DNS= удалён из временного WireGuard конфига, чтобы не вызывать resolvconf/resolvectl без systemd"
  fi
}

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

if ip link show "${WG_INTERFACE}" >/dev/null 2>&1; then
  echo "[!] Интерфейс ${WG_INTERFACE} уже существует, перезапускаю"
  wg_down
fi

prepare_wg_target

echo "[+] Подключение к WireGuard: ${WG_UP_TARGET}"
wg-quick up "${WG_UP_TARGET}"

echo -n '[+] Текущий IP: '
curl -s ifconfig.me || true
echo
set +e
su - codex -s /bin/bash -c "$*"
cmd_status=$?
set -e
exit "${cmd_status}"
