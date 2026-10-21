from pathlib import Path
import ast
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SetupTests(unittest.TestCase):
    def test_installer_preserves_bonds_and_quality(self):
        setup = (ROOT / 'setup.sh').read_text()
        self.assertNotIn('rm -rf /var/lib/bluetooth', setup)
        self.assertNotIn('resample-method = trivial', setup)
        self.assertIn('adb push scripts/receiver-daemon.conf', setup)
        self.assertNotIn('auto_output=false', setup)
        self.assertNotIn('usermod -p', setup)
        self.assertNotIn('sed -i "s/echo', setup)

    def test_services_do_not_require_wifi(self):
        for name in ('vol-sync', 'bt-agent', 'bt-wifi-sync', 'jack-sense', 'keep-awake'):
            service = (ROOT / 'scripts' / (name + '.conf')).read_text()
            self.assertIn('start on started dbus', service)
            self.assertNotIn('stopping unity8', service)
            self.assertIn('respawn limit', service)

    def test_volume_service_has_no_routing_commands(self):
        script = (ROOT / 'scripts/vol_sync.py').read_text()
        for forbidden in ('load-module', 'unload-module', 'set-card-profile', 'latency_msec'):
            self.assertNotIn(forbidden, script)

    def test_python_syntax_and_deployment_sources(self):
        for path in (ROOT / 'scripts').glob('*.py'):
            ast.parse(path.read_text(), filename=str(path))
        self.assertTrue((ROOT / 'scripts/keep_awake.py').exists())


if __name__ == '__main__':
    unittest.main()
