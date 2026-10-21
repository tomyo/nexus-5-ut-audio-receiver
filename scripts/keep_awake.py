import time
import os

WAKE_LOCK_FILE = "/sys/power/wake_lock"
WAKE_UNLOCK_FILE = "/sys/power/wake_unlock"
LOCK_NAME = "ut_audio_receiver_wakelock"

def is_plugged_in():
    # Check if any power supply is online (USB, AC, Wireless)
    try:
        power_supply_dir = "/sys/class/power_supply/"
        if os.path.exists(power_supply_dir):
            for ps in os.listdir(power_supply_dir):
                if ps.lower() == "battery":
                    continue
                online_path = os.path.join(power_supply_dir, ps, "online")
                if os.path.exists(online_path):
                    with open(online_path, "r") as f:
                        if f.read().strip() == "1":
                            return True
    except Exception as e:
        print("Error checking power supply:", e)

    # Fallback to checking battery status explicitly
    try:
        status_path = "/sys/class/power_supply/battery/status"
        if os.path.exists(status_path):
            with open(status_path, "r") as f:
                status = f.read().strip().lower()
                if status in ["charging", "full"]:
                    return True
    except Exception as e:
        print("Error checking battery status:", e)

    return False

def set_wakelock(enable):
    try:
        if enable:
            print("Acquiring wakelock...")
            with open(WAKE_LOCK_FILE, "w") as f:
                f.write(LOCK_NAME)
        else:
            print("Releasing wakelock...")
            with open(WAKE_UNLOCK_FILE, "w") as f:
                f.write(LOCK_NAME)
    except Exception as e:
        print("Failed to set wakelock ({}): {}".format(enable, e))

def main():
    print("Starting Keep Awake service...")
    was_plugged = None

    # Ensure wakelock is released on startup just in case
    set_wakelock(False)

    while True:
        plugged = is_plugged_in()

        if plugged != was_plugged:
            print("Power status changed. Plugged in: {}".format(plugged))
            set_wakelock(plugged)
            was_plugged = plugged

        time.sleep(5)

if __name__ == "__main__":
    main()
