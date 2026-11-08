# Docker Desktop на Mac: запуск из любого проекта

Репозиторий контейнера и приватный VPN-комплект находятся в `~/ai`.
После обновления репозитория добавьте этот alias в `~/.zshrc`:

```bash
alias codex='docker run --rm \
    -it \
    -w /home/codex \
    --device /dev/net/tun \
    --security-opt seccomp=unconfined \
    --security-opt apparmor=unconfined \
    --cap-add SYS_ADMIN \
    --cap-add NET_ADMIN \
    --group-add 0 \
    -e VPN_PROFILE=msk \
    -e VPN_SSH_DIR=/run/vpn-ssh \
    -e VPN_PROFILE_HELPER=/opt/codex-container/vpn-profile.py \
    -v "${PWD}:/home/codex/project" \
    -v "${HOME}/www:/www" \
    -v "${HOME}/.codex:/home/codex/.codex" \
    -v "${HOME}/ai:/opt/codex-container:ro" \
    -v "${HOME}/ai/.private/vpn-client:/run/vpn-ssh:ro" \
    -v "${HOME}/ai/sing-box.example.json:/etc/sing-box/config.json:ro" \
    -v "${HOME}/ai/CONTEXT.md:/home/codex/CONTEXT.md:ro" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --entrypoint /bin/bash \
    ai-agent /opt/codex-container/entrypoint.sh codex --sandbox workspace-write -c sandbox_workspace_write.network_access=true'
```

Подготовка на Mac:

```bash
mkdir -p ~/www ~/.codex
cd ~/ai
git pull --ff-only
cp .private/vpn-client/client.json .vpn-client.json
chmod 600 .vpn-client.json .private/vpn-client/id_ed25519
source ~/.zshrc
```

Затем перейдите в нужный проект и выполните `codex`.
Текущий каталог доступен как `/home/codex/project`, весь `~/www` — как `/www`.
Путь к репозиторию `~/ai` в alias замените, если храните его в другом месте.
`VPN_PROFILE=msk` явно выбирает Москву → Германию; для прямой Германии
замените его на `VPN_PROFILE=de`. `.vpn-client.json` относится к каталогу `~/ai`.

Docker Desktop должен быть запущен в режиме Linux containers, а каталоги
из домашней папки доступны для bind mounts. Docker socket на Desktop обычно
использует GID0, поэтому прежний `--group-add 1` заменён на0.
Образ `ai-agent` нужен для архитектуры этого Mac (Apple Silicon/Intel).
Entry point подменяется файлом из репозитория, для этой правки rebuild не нужен.

Проверена только синтаксическая корректность alias и entrypoint. Запуск на Mac
и подключение нового VPN-клиента не проверялись по указанию пользователя.
