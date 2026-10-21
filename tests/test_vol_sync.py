import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "vol_sync", Path(__file__).resolve().parents[1] / "scripts/vol_sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


def transport(volume=76, state="active"):
    return {"org.bluez.MediaTransport1": {
        "State": state, "UUID": "0000110b-0000-1000-8000-00805f9b34fb",
        "Volume": volume}}


class VolumeTests(unittest.TestCase):
    @patch.object(sync.subprocess, "check_call")
    def test_only_volume_changes_and_no_repeated_writes(self, call):
        objects = {"/any/device/fd4": transport()}
        previous = sync.sync_volume(objects, None, {})
        sync.sync_volume(objects, previous, {})
        call.assert_called_once_with(
            ["pactl", "set-sink-volume", "sink.primary", "59%"], env={}, timeout=3)

    def test_idle_missing_invalid_and_ambiguous_are_ignored(self):
        for objects in ({}, {"a": transport(state="idle")},
                        {"a": transport(128)}, {"a": transport(), "b": transport()}):
            self.assertIsNone(sync.active_volume(objects))

    @patch.object(sync.subprocess, "check_call")
    def test_mute_and_max_and_reconnect(self, call):
        previous = sync.sync_volume({"a": transport(0)}, None, {})
        previous = sync.sync_volume({}, previous, {})
        sync.sync_volume({"b": transport(127)}, previous, {})
        self.assertEqual([c.args[0][-1] for c in call.call_args_list], ["0%", "100%"])


if __name__ == "__main__":
    unittest.main()
