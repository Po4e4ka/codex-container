# VPN switch — 2026-11-05

Запрос: ./switch ke и ./switch msk, выбор для следующего запуска.
Добавлены executable switch и helper vpn-profile.py; сохранение .vpn-profile
атомарным rename, в файле только имя профиля. Секреты не копируются.
entrypoint читает профиль, генерирует runtime TUN config с правильным исключением,
запускает SSH и выполняет прежние проверки. Старый VPN_TRANSPORT=xray сохранён.
msk: SSH jump Moscow→Germany, ke: SSH Kenya, de: прежняя прямая Germany.

Проверка: все3TUN configs проходят sing-box check; ke/msk выбор сохраняется;
новый msk контейнер успешно поднялся и прошёл Codex account/read0.89секунды,
exit171.22.119.96. Существующий контейнер не менялся.
KenyaSSHtimeout: это недоступный сервер, успешный runtime ke не заявляется.

Откат выбора: ./switch de. Следующий выбранный профиль сейчас msk.
entrypoint до изменения: backups/20261105-switch/entrypoint.sh.
