import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import subprocess

BUS_NAME = 'org.bluez'
AGENT_INTERFACE = 'org.bluez.Agent1'
AGENT_PATH = "/test/agent"

class Agent(dbus.service.Object):
    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        print("AuthorizeService ({}, {})".format(device, uuid))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print("RequestPinCode ({})".format(device))
        return "0000"

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print("RequestConfirmation ({}, {:06d})".format(device, passkey))
        # Set the device as trusted so it can reconnect automatically next time
        try:
            props = dbus.Interface(bus.get_object("org.bluez", device), "org.freedesktop.DBus.Properties")
            props.Set("org.bluez.Device1", "Trusted", True)
        except Exception as e:
            print("Error trusting device: {}".format(e))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print("RequestAuthorization ({})".format(device))
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        print("Cancel")

def set_adapter_props():
    try:
        # Force adapter to be discoverable and pairable
        objects = bus.get_object("org.bluez", "/").GetManagedObjects(dbus_interface="org.freedesktop.DBus.ObjectManager")
        for path, interfaces in objects.items():
            if "org.bluez.Adapter1" in interfaces:
                props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
                props.Set("org.bluez.Adapter1", "Discoverable", True)
                props.Set("org.bluez.Adapter1", "Pairable", True)
                print("Adapter {} set to Discoverable/Pairable".format(path))
    except Exception as e:
        print("Error setting adapter props: {}".format(e))

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)

    obj = bus.get_object(BUS_NAME, "/org/bluez")
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
    manager.RequestDefaultAgent(AGENT_PATH)

    print("Bluetooth Auto-Agent Registered.")
    
    # Periodically ensure we are discoverable
    GLib.timeout_add_seconds(10, lambda: [set_adapter_props(), True][1])
    
    mainloop = GLib.MainLoop()
    mainloop.run()
