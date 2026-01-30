#!/usr/bin/env bash
set -e

openvpn --config /etc/openvpn/client.ovpn --daemon
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