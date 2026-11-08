#!/usr/bin/env bash
set -euo pipefail

XRAY_CONFIG="${XRAY_CONFIG:-/etc/xray/client.json}"
SINGBOX_CONFIG="${SINGBOX_CONFIG:-/etc/sing-box/config.json}"

XRAY_LOG=/tmp/xray.log
SINGBOX_LOG=/tmp/sing-box.log

APP_USER="${APP_USER:-codex}"
APP_UID="${APP_UID:-1000}"
APP_GID="${APP_GID:-1000}"

cleanup() {
    echo "[+] Остановка VPN..."

    if [[ -n "${SINGBOX_PID:-}" ]] && kill -0 "${SINGBOX_PID}" 2>/dev/null; then
        kill "${SINGBOX_PID}" 2>/dev/null || true
        wait "${SINGBOX_PID}" 2>/dev/null || true
    fi

    if [[ -n "${XRAY_PID:-}" ]] && kill -0 "${XRAY_PID}" 2>/dev/null; then
        kill "${XRAY_PID}" 2>/dev/null || true
        wait "${XRAY_PID}" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

VPN_TRANSPORT="${VPN_TRANSPORT:-ssh}"
if [[ "$VPN_TRANSPORT" != ssh && ! -f "${XRAY_CONFIG}" ]]; then
    echo "[!] Не найден Xray config: ${XRAY_CONFIG}" >&2
    exit 1
fi

if [[ ! -f "${SINGBOX_CONFIG}" ]]; then
    echo "[!] Не найден sing-box config: ${SINGBOX_CONFIG}" >&2
    exit 1
fi

if [[ "$VPN_TRANSPORT" == ssh ]]; then
    VPN_PROFILE_HELPER="${VPN_PROFILE_HELPER:-/home/codex/project/vpn-profile.py}"
    VPN_SELECTED_PROFILE="$(python3 "$VPN_PROFILE_HELPER" show | cut -d ' ' -f 1)"
    echo "[+] VPN профиль: $(python3 "$VPN_PROFILE_HELPER" show)"
    python3 "$VPN_PROFILE_HELPER" tun "$VPN_SELECTED_PROFILE" \
        --config "$SINGBOX_CONFIG" --output /tmp/sing-box-active.json
    SINGBOX_CONFIG=/tmp/sing-box-active.json
    python3 "$VPN_PROFILE_HELPER" ssh "$VPN_SELECTED_PROFILE" >"${XRAY_LOG}" 2>&1 &
else
    echo "[+] Запуск Xray VPN..."
    xray run -c "${XRAY_CONFIG}" >"${XRAY_LOG}" 2>&1 &
fi
XRAY_PID=$!

echo "[+] Ожидание SOCKS 127.0.0.1:1081..."

for i in $(seq 1 300); do
    if (echo >/dev/tcp/127.0.0.1/1081) >/dev/null 2>&1; then
        break
    fi

    if ! kill -0 "${XRAY_PID}" 2>/dev/null; then
        echo "[!] VPN транспорт завершился:"
        cat "${XRAY_LOG}"
        exit 1
    fi

    sleep 0.1
done

echo "[+] Проверка VPN через SOCKS..."

VPN_IP="$(curl -4fsS \
    --max-time 10 \
    --proxy socks5h://127.0.0.1:1081 \
    https://api.ipify.org || true)"

if [[ -z "${VPN_IP}" ]]; then
    echo "[!] VPN транспорт не работает:"
    cat "${XRAY_LOG}"
    exit 1
fi

echo "[+] SOCKS работает. IP: ${VPN_IP}"

# Не используем Docker DNS через 127.0.0.11,
# чтобы DNS также уходил через TUN.
printf '%s\n' \
    'nameserver 1.1.1.1' \
    'nameserver 8.8.8.8' \
    > /etc/resolv.conf

echo "[+] Запуск sing-box TUN..."

sing-box run -c "${SINGBOX_CONFIG}" >"${SINGBOX_LOG}" 2>&1 &
SINGBOX_PID=$!

for i in $(seq 1 100); do
    if ip link show vless0 >/dev/null 2>&1; then
        break
    fi

    if ! kill -0 "${SINGBOX_PID}" 2>/dev/null; then
        echo "[!] sing-box завершился:"
        cat "${SINGBOX_LOG}"
        exit 1
    fi

    sleep 0.1
done

if ! ip link show vless0 >/dev/null 2>&1; then
    echo "[!] TUN vless0 не появился"
    cat "${SINGBOX_LOG}"
    exit 1
fi

echo "[+] TUN поднят"

FINAL_IP="$(curl -4fsS --max-time 10 https://api.ipify.org || true)"

if [[ -z "${FINAL_IP}" ]]; then
    echo "[!] После поднятия TUN нет интернета"

    echo "===== Xray ====="
    cat "${XRAY_LOG}"

    echo "===== sing-box ====="
    cat "${SINGBOX_LOG}"

    exit 1
fi

if [[ "${FINAL_IP}" != "${VPN_IP}" ]]; then
    echo "[!] IP через TUN отличается от IP через Xray" >&2
    exit 1
fi

echo "[+] VPN готов"
echo "[+] Внешний IP контейнера: ${FINAL_IP}"

export HOME="/home/${APP_USER}"
export USER="${APP_USER}"
export LOGNAME="${APP_USER}"

set +e

setpriv \
    --reuid="${APP_UID}" \
    --regid="${APP_GID}" \
    --init-groups \
    -- "$@"

STATUS=$?

set -e
exit "${STATUS}"
