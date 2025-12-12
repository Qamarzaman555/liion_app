from serial.tools import list_ports
from logging import getLogger

from leo import DeviceManager


log = getLogger(__name__)


class SerialManager(DeviceManager):
    """Manages serial scanning, connecting, and disconnecting."""

    def __init__(self):
        super().__init__()

    def scan(self):
        serials = list_ports.comports()
        filtered = [serial for serial in serials if "CP2103" in serial.description]
        return filtered

    def connect(self, port, baud_rate=115200):
        from .interface import SerialDevice
        self.device = SerialDevice(port, baud_rate)
        return self.device

    def disconnect(self):
        """Disconnect the serial devices."""
        if self.device:
            self.device.disconnect()
        self.device = None
        log.info("🔌 Serial Disconnected.")
