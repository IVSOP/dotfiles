"""Integration checks with fake Hyprland outputs; never touch the real session.

Run: python3 -m unittest discover -s hypr/scripts/tests -v
"""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest


SCRIPTS = Path(__file__).resolve().parents[1]
FAKE_HYPRCTL = r'''#!/usr/bin/env python3
import json, os, pathlib, re, sys
root = pathlib.Path(os.environ['FAKE_MONITORS'])
if sys.argv[1:] == ['-j', 'monitors', 'all']:
    print(root.read_text())
elif sys.argv[1] == 'eval':
    fields = re.findall(r'(\w+) = ("(?:[^"\\]|\\.)*"|true|false|-?[0-9.]+)', sys.argv[2])
    rule = {k: json.loads(v) for k, v in fields}
    with root.with_suffix('.rules').open('a') as out:
        out.write(json.dumps(rule) + '\n')
    if rule.get('mirror') and root.with_suffix('.fail').exists():
        print('error: rejected mirror')
        sys.exit(0)  # hyprctl may report eval errors without a nonzero exit.
    data = json.loads(root.read_text())
    for m in data:
        if m['name'] != rule['output']:
            continue
        for k in ('disabled', 'scale', 'transform'):
            if k in rule: m[k] = rule[k]
        if 'mirror' in rule: m['mirrorOf'] = rule['mirror'] or 'none'
        if 'position' in rule and rule['position'] != 'auto':
            m['x'], m['y'] = map(int, rule['position'].split('x'))
        if 'mode' in rule:
            if rule['mode'] == 'preferred':
                m['width'], m['height'], m['refreshRate'] = 1920, 1080, 60
            else:
                size, rate = rule['mode'].split('@')
                m['width'], m['height'] = map(int, size.split('x'))
                m['refreshRate'] = float(rate)
    root.write_text(json.dumps(data))
    print('ok')
else:
    sys.exit(2)
'''
FAKE_GUM = '''#!/usr/bin/env python3
import os, sys
if os.environ.get('CANCEL_PICKER'):
    sys.exit(130)
print(sys.argv[sys.argv.index('--') + 1])
'''
FAKE_DAEMON = '''#!/usr/bin/env python3
import os, pathlib, signal, time
with pathlib.Path(os.environ['DAEMON_LOG']).open('a') as out:
    out.write('start\\n')
signal.signal(signal.SIGTERM, lambda *_: exit(0))
while True: time.sleep(0.1)
'''


def display(name, disabled=False):
    return dict(name=name, make='Test', model=name, serial=name + '-serial',
                description='Test ' + name, width=2560, height=1440,
                refreshRate=144.0, x=0 if name == 'eDP-1' else 2560, y=0,
                scale=1.25, transform=0, disabled=disabled, mirrorOf='none')


class MonitorControlTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='monitor-test-')
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.scripts = self.home / '.config/hypr/scripts'
        self.scripts.mkdir(parents=True)
        for name in ('monitor-profile.sh', 'monitor-session.sh', 'monitor-mirror.py'):
            shutil.copy2(SCRIPTS / name, self.scripts / name)
        self.executable(self.scripts / 'apply-monitor-ui.sh', '#!/bin/sh\nexit 0\n')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.executable(self.bin / 'hyprctl', FAKE_HYPRCTL)
        self.executable(self.bin / 'gum', FAKE_GUM)
        self.executable(self.bin / 'hyprmoncfgd', FAKE_DAEMON)
        self.executable(self.bin / 'hyprmoncfg', '#!/bin/sh\nprintf "Configuration kept\\n"\n')
        self.state = self.root / 'outputs.json'
        self.state.write_text(json.dumps([display('eDP-1'), display('HDMI-A-1', True)]))
        self.runtime = self.root / 'runtime/hypr-monitor-ui'
        self.runtime.mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), XDG_RUNTIME_DIR=str(self.runtime.parent),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        FAKE_MONITORS=str(self.state), DAEMON_LOG=str(self.root / 'daemon.log'))
        self.session = None

    @staticmethod
    def executable(path, content):
        path.write_text(content)
        path.chmod(0o755)

    def tearDown(self):
        pidfile = self.runtime / 'session.pid'
        if pidfile.exists():
            pid = int(pidfile.read_text())
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            self.await_condition(lambda: not pidfile.exists())
        if self.session:
            self.session.wait(timeout=10)
        self.temp.cleanup()

    def await_condition(self, condition, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(0.05)
        self.fail('Timed out waiting for monitor session')

    def command(self, *args, expected=0, **extra_env):
        result = subprocess.run([str(self.scripts / 'monitor-profile.sh'), *args],
                                env=dict(self.env, **extra_env), capture_output=True, text=True, timeout=25)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout

    def mode_is(self, expected):
        file = self.runtime / 'daemon-mode'
        return file.exists() and file.read_text().strip() == expected

    def outputs(self):
        return json.loads(self.state.read_text())

    def test_pause_hotplug_resume_and_help(self):
        before = self.outputs()
        self.command('pause')
        self.assertEqual(before, self.outputs())
        self.assertEqual(self.command('mode').strip(), 'paused')
        self.state.write_text(json.dumps(before + [display('DP-2')]))
        time.sleep(2.5)
        self.assertTrue(self.mode_is('paused'))
        self.assertFalse((self.root / 'daemon.log').exists())
        self.command('resume')
        self.await_condition(lambda: (self.root / 'daemon.log').exists())
        self.command('stop')
        self.assertTrue(self.mode_is('paused'))
        self.command('start')
        self.assertTrue(self.mode_is('auto'))
        self.assertIn('mirror', self.command('--help', XDG_RUNTIME_DIR=''))

    def test_mirror_and_unmirror_restore_disabled_receiver_and_pause(self):
        self.command('pause')
        before = self.outputs()
        self.command('mirror')
        source, receiver = self.outputs()
        self.assertEqual(source, before[0])
        self.assertFalse(receiver['disabled'])
        self.assertEqual(receiver['mirrorOf'], source['name'])
        self.assertTrue(self.mode_is('mirror'))
        self.command('unmirror')
        self.await_condition(lambda: self.mode_is('paused'))
        self.assertEqual(self.outputs(), before)

    def test_receiver_disconnect_recovers_and_resumes_auto(self):
        self.command('mirror')
        source = self.outputs()[0]
        self.state.write_text(json.dumps([source]))
        self.await_condition(lambda: not (self.runtime / 'mirror.json').exists())
        self.await_condition(lambda: self.mode_is('auto'))
        self.assertEqual(self.outputs(), [source])
        # A stale mirror rule must not be left behind for the next connection.
        rules = [json.loads(line) for line in self.state.with_suffix('.rules').read_text().splitlines()]
        self.assertEqual(rules[-1]['mirror'], '')

    def test_source_disconnect_keeps_receiver_enabled(self):
        self.command('pause')
        self.command('mirror')
        receiver = self.outputs()[1]
        self.state.write_text(json.dumps([receiver]))
        self.await_condition(lambda: not (self.runtime / 'mirror.json').exists())
        self.await_condition(lambda: self.mode_is('paused'))
        receiver = self.outputs()[0]
        self.assertFalse(receiver['disabled'])
        self.assertEqual(receiver['mirrorOf'], 'none')

    def test_cancel_and_rejected_mirror_leave_no_temporary_state(self):
        self.command('pause')
        before = self.outputs()
        self.command('mirror', expected=130, CANCEL_PICKER='1')
        self.assertFalse((self.runtime / 'mirror.json').exists())
        self.state.with_suffix('.fail').touch()
        self.command('mirror', expected=1)
        self.await_condition(lambda: self.mode_is('paused'))
        self.assertEqual(self.outputs(), before)
        self.assertFalse((self.runtime / 'mirror.json').exists())

    def test_existing_active_receiver_settings_restore_and_resume_ends_mirror(self):
        before = [display('eDP-1'), display('HDMI-A-1')]
        before[1]['transform'] = 1
        self.state.write_text(json.dumps(before))
        self.command('mirror')
        self.assertEqual(self.outputs()[1]['transform'], 1)
        self.assertEqual(self.outputs()[1]['scale'], 1.25)
        self.command('resume')
        self.assertEqual(self.outputs(), before)
        self.assertFalse((self.runtime / 'mirror.json').exists())

    def test_paused_profile_apply_and_failed_apply_restore_pause(self):
        profile_dir = self.home / '.config/hypr/monitor-profiles/profiles'
        profile_dir.mkdir(parents=True)
        profile_dir.joinpath('test.json').write_text(json.dumps({
            'name': 'test', 'outputs': [{'enabled': True, 'match_key': 'Test|eDP-1|eDP-1-serial'}]}))
        self.command('pause')
        self.executable(self.bin / 'hyprmoncfg', '#!/bin/sh\nexit 1\n')
        self.command('apply', 'test', expected=1)
        self.await_condition(lambda: self.mode_is('paused'))
        self.executable(self.bin / 'hyprmoncfg', '#!/bin/sh\nprintf "Configuration kept\\n"\n')
        self.command('apply', 'test')
        self.assertEqual(self.command('mode').strip(), 'test')
        self.assertFalse((self.runtime / 'paused').exists())


if __name__ == '__main__':
    unittest.main()
