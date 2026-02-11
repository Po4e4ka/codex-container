#!/usr/bin/env bash
set -e

# Build OpenVPN route directives in the config anchor block before connection.
OVPN_CONFIG=${OPENVPN_CONFIG:-/etc/openvpn/client.ovpn}
OPENAI_SPLIT_DOMAINS=${OPENAI_SPLIT_DOMAINS:-"ifconfig.me api.openai.com chatgpt.com auth.openai.com platform.openai.com files.oaiusercontent.com"}
ANCHOR_BEGIN="# OPENAI_ROUTES_ANCHOR_BEGIN"
ANCHOR_END="# OPENAI_ROUTES_ANCHOR_END"

echo "[+] Генерация route-блока для OpenVPN: ${OPENAI_SPLIT_DOMAINS}"
routes=$(
  for domain in ${OPENAI_SPLIT_DOMAINS}; do
    ips=$(getent ahostsv4 "${domain}" 2>/dev/null | awk '{print $1}' | sort -u)
    if [ -z "${ips}" ]; then
      echo "[!] DNS не вернул IPv4 для ${domain}" >&2
      continue
    fi
    for ip in ${ips}; do
      printf 'route %s 255.255.255.255\n' "${ip}"
    done
  done | sort -u
)

tmp_config=$(mktemp)
awk -v begin="${ANCHOR_BEGIN}" -v end="${ANCHOR_END}" -v routes="${routes}" '
  $0 == begin {
    print
    if (length(routes) > 0) {
      print routes
    }
    in_anchor = 1
    next
  }
  $0 == end {
    in_anchor = 0
    print
    next
  }
  !in_anchor { print }
' "${OVPN_CONFIG}" > "${tmp_config}"
mv "${tmp_config}" "${OVPN_CONFIG}"

openvpn --config "${OVPN_CONFIG}" --daemon
echo '[+] Подключение к VPN'
for i in {1..20}; do
  ip link show tun0 >/dev/null 2>&1 && break
  sleep 1
done
ip link show tun0 >/dev/null 2>&1 || (echo '[!] Подключиться не удалось')

echo -n '[+] Текущий IP: '
curl -s ifconfig.me || true
echo

exec su - codex -s /bin/bash -c "$*"
