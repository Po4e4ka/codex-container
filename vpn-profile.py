"""Shared startup profiles; contains only public endpoints and key file paths."""
import argparse
import json
import os
from pathlib import Path
import shlex
import sys

ROOT = Path(__file__).resolve().parent
PROFILES = {
    'de': {'address': '171.22.119.96', 'jump': None, 'label': 'Германия напрямую'},
    'msk': {'address': '171.22.119.96', 'jump': '82.148.239.182', 'label': 'Москва → Германия'},
    'ke': {'address': '185.240.51.6', 'jump': None, 'label': 'Кения'},
}
STATE = ROOT / '.vpn-profile'
CLIENT = ROOT / '.vpn-client.json'


def client_settings():
    return json.loads(CLIENT.read_text()) if CLIENT.exists() else {}


def selected():
    value = os.environ.get('VPN_PROFILE') or (STATE.read_text().strip() if STATE.exists() else 'de')
    if value not in PROFILES:
        raise SystemExit('Неизвестный VPN профиль: ' + value)
    return value


def ssh_args(profile):
    settings = client_settings()
    key_root = os.environ.get('VPN_SSH_DIR', '/home/codex/.ssh')
    user = settings.get('user', 'root')
    key_name = settings.get('key', 'id_rsa')
    common = ['ssh', '-F', '/dev/null', '-i', key_root + '/' + key_name,
              '-o', 'UserKnownHostsFile=' + key_root + '/known_hosts',
              '-o', 'StrictHostKeyChecking=yes', '-o', 'BatchMode=yes',
              '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=15',
              '-o', 'ServerAliveCountMax=3']
    p = PROFILES[profile]
    args = common + ['-N', '-T', '-D', '127.0.0.1:1081', '-o', 'ExitOnForwardFailure=yes']
    if p['jump']:
        args += ['-o', 'ProxyCommand=' + shlex.join(common + ['-T', '-W', '%h:%p', user + '@' + p['jump']])]
    return args + [user + '@' + p['address']]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['show', 'select', 'ssh', 'tun', 'preflight'])
    parser.add_argument('profile', nargs='?', choices=list(PROFILES))
    parser.add_argument('--config')
    parser.add_argument('--output')
    parser.add_argument('--ssh-dir')
    args = parser.parse_args()
    profile = args.profile or selected()
    if args.action == 'preflight':
        key_root = Path(args.ssh_dir or os.environ.get('VPN_SSH_DIR', '/home/codex/.ssh'))
        for name in (client_settings().get('key', 'id_rsa'), 'known_hosts'):
            if not (key_root / name).is_file():
                raise SystemExit('Missing SSH file: ' + str(key_root / name))
        print('SSH client files present; selected profile: ' + profile)
    elif args.action == 'select':
        if args.profile is None:
            parser.error('Нужен профиль ke, msk или de')
        temporary = ROOT / ('.vpn-profile.' + str(os.getpid()))
        temporary.write_text(profile + '\n')
        temporary.replace(STATE)
        print('Следующий запуск: ' + profile + ' — ' + PROFILES[profile]['label'])
        print('Текущий контейнер не переключён. Закройте сессию и запустите ./etp.sh на хосте.')
        if profile == 'ke':
            print('Если Кения недоступна, запуск остановится. Возврат: ./switch msk')
    elif args.action == 'show':
        print(profile + ' — ' + PROFILES[profile]['label'])
    elif args.action == 'ssh':
        command = ssh_args(profile)
        os.execvp(command[0], command)
    else:
        if not args.config or not args.output:
            parser.error('Нужны --config и --output')
        data = json.loads(Path(args.config).read_text())
        tunnel = next(i for i in data['inbounds'] if i['type'] == 'tun')
        endpoints = {'171.22.119.96/32', '82.148.239.182/32', '185.240.51.6/32'}
        excluded = [i for i in tunnel.get('route_exclude_address', []) if i not in endpoints]
        p = PROFILES[profile]
        excluded.append((p['jump'] or p['address']) + '/32')
        tunnel['route_exclude_address'] = excluded
        Path(args.output).write_text(json.dumps(data, indent=2) + '\n')


if __name__ == '__main__':
    main()
