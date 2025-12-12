from abc import ABC, abstractmethod
from queue import Queue
from logging import getLogger


log = getLogger(__name__)


class DeviceManager(ABC):
    """
    Abstract base class for managing the connection lifecycle of a device.

    Defines context manager entry and exit behavior, and requires
    scan/connect/disconnect to be implemented.
    """
    def __init__(self):
        self.device = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.disconnect()

    @abstractmethod
    def scan(self, *args, **kwargs):
        """
        Scan for available devices.

        Returns:
            list: A list of found devices.
        """
        pass

    @abstractmethod
    def connect(self, *args, **kwargs):
        """
        Connect to the device.

        Returns:
            Device: An instance of the device.
        """
        pass

    @abstractmethod
    def disconnect(self):
        """
        Disconnect from the device.
        """
        pass


class Device(ABC):
    """
    Abstract base class representing the command interface of a device.

    Includes high-level command methods, dynamic dispatch via __call__, and a
    range of device-specific commands.
    """
    def __init__(self):
        self.is_connected = False
        self.response_queue = Queue()

    def __call__(self, cmd, *args):
        """Dynamically handle commands."""
        try:
            if hasattr(self, cmd):
                return getattr(self, cmd)(*args)
        except TypeError:
            log.warning(f"⚠️ Unknown parameters {args} for '{cmd}'")
        else:
            log.warning("⚠️ Unknown command '%s'" % cmd)

        # Let's send it anyway
        self.send_command(f"{cmd} {' '.join(map(str, args))}" if args else f"{cmd}")
        return None

    @abstractmethod
    def send_command(self, cmd: str):
        """
        Send a command to the device.

        Parameters:
            cmd (str): The command string to send.
        """
        pass

    @abstractmethod
    def disconnect(self):
        """
        Disconnect from the device.
        """
        pass

    def consume_response(self, line):
        """
        """
        log.info(line)
        self.response_queue.put(line)
