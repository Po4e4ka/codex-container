
import os
import json
import base64
import socket
import shutil
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit, parse_qs, unquote

root = Path.home() / "ai"
xray_path = root / "xray-client.json"
sing_path = root / "sing-box.json"

url = os.environ["SUB_URL"]

request = urllib.request.Request(
    url, headers={"User-Agent": "Xray"}
)
with urllib.request.urlopen(request, timeout=20) as response:
    data = response.read().decode("utf-8-sig").strip()

# Подписки часто возвращают Base64 со списком VLESS-ссылок.
if not data.startswith(("vless://", "vmess://")):
    try:
        decoded = base64.b64decode(
            "".join(data.split()) + "=" * (-len("".join(data.split())) % 4)
        ).decode("utf-8")
        if "vless://" in decoded:
            data = decoded
    except (ValueError, UnicodeError):
        pass

links = [
    line.strip()
    for line in data.splitlines()
    if line.strip().startswith("vless://")
]

compatible = []
for link in links:
    parsed = urlsplit(link)
    q = parse_qs(parsed.query)
    def param(key, default=""):
        return q.get(key, [default])[0]

    if (param("security") == "reality"
            and param("type", "tcp") == "tcp"
            and param("flow", "xtls-rprx-vision")
                in ("", "xtls-rprx-vision")
            and param("pbk")):
        compatible.append((parsed, q))

if not compatible:
    raise SystemExit(
        "Нет подходящего VLESS + REALITY TCP подключения. "
        "Возможно, подписка использует другой формат."
    )

print("Найдены совместимые серверы:")
for i, (p, _) in enumerate(compatible, 1):
    print(f"{i}. {unquote(p.fragment) or p.hostname}")

choice = int(input("Номер сервера [1]: ") or "1")
if not 1 <= choice <= len(compatible):
    raise SystemExit("Неверный номер сервера")

p, q = compatible[choice - 1]
def param(key, default=""):
    return q.get(key, [default])[0]

if not p.hostname or not p.port or not p.username:
    raise SystemExit("Неполная ссылка VLESS")

# Используем IPv4 для корректного исключения адреса из TUN.
server_ip = socket.gethostbyname(p.hostname)

with xray_path.open() as f:
    xray = json.load(f)
with sing_path.open() as f:
    sing = json.load(f)

old_address = xray["outbounds"][0]["settings"].get("address")

out = xray["outbounds"][0]
out["protocol"] = "vless"
out["settings"].update({
    "address": server_ip,
    "port": p.port,
    "id": unquote(p.username),
    "encryption": param("encryption", "none"),
})

if param("flow"):
    out["settings"]["flow"] = param("flow")
else:
    out["settings"].pop("flow", None)

out["streamSettings"] = {
    "network": "tcp",
    "security": "reality",
    "realitySettings": {
        "serverName": param("sni", p.hostname),
        "fingerprint": param("fp", "chrome"),
        "password": param("pbk"),
        "shortId": param("sid"),
        "spiderX": param("spx", "/"),
    }
}

tun = next(
    i for i in sing["inbounds"] if i["type"] == "tun"
)
excluded = tun.setdefault("route_exclude_address", [])

if old_address:
    excluded = [
        item for item in excluded
        if item != f"{old_address}/32"
    ]

if f"{server_ip}/32" not in excluded:
    excluded.append(f"{server_ip}/32")

tun["route_exclude_address"] = excluded

# Создаём резервные копии до изменения файлов.
shutil.copy2(xray_path, str(xray_path) + ".bak")
shutil.copy2(sing_path, str(sing_path) + ".bak")

for path, config in ((xray_path, xray), (sing_path, sing)):
    with path.open("w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")
    path.chmod(0o600)

print(f"Готово. Новый сервер: {server_ip}:{p.port}")
print("Оба конфига обновлены, резервные копии созданы.")
