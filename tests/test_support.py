import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch


def load(name):
    path = Path(__file__).resolve().parents[1] / 'scripts' / (name + '.py')
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


wifi = load('bt_wifi_sync')
jack = load('jack_sense')


class SupportTests(unittest.TestCase):
    def test_wifi_any_active_sender_not_first_device(self):
        def transport(state):
            return {'org.bluez.MediaTransport1': {
                'State': state, 'UUID': '0000110b-0000-1000-8000-00805f9b34fb'}}
        self.assertTrue(wifi.is_streaming({'a': transport('idle'), 'b': transport('active')}))
        self.assertFalse(wifi.is_streaming({'a': transport('idle'), 'b': {}}))
        self.assertFalse(wifi.is_streaming({}))

    @patch.object(wifi, 'log')
    @patch.object(wifi.subprocess, 'check_call')
    @patch.object(wifi.subprocess, 'check_output', return_value=b'disabled\n')
    def test_wifi_retries_until_actual_state_matches(self, read, call, log):
        wifi.set_wifi(False)
        call.assert_not_called()
        wifi.set_wifi(True)
        call.assert_called_once_with(['nmcli', 'radio', 'wifi', 'on'], timeout=5)

    @patch.object(jack, 'log')
    @patch.object(jack.subprocess, 'check_call')
    def test_jack_named_ports_and_failed_switch(self, call, log):
        self.assertTrue(jack.set_pa_port(True))
        self.assertEqual(call.call_args.args[0],
                         ['pactl', 'set-sink-port', 'sink.primary', 'output-wired_headphone'])
        call.side_effect = subprocess.CalledProcessError(1, 'pactl')
        self.assertFalse(jack.set_pa_port(False))


if __name__ == '__main__':
    unittest.main()
