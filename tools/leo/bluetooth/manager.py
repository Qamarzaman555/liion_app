import asyncio
from logging import getLogger
import threading

from bleak import BleakScanner, BleakClient
from bleak.exc import BleakDeviceNotFoundError, BleakDBusError, BleakError

from leo import DeviceManager


log = getLogger(__name__)


class BluetoothManager(DeviceManager):
    """
    Manages Bluetooth scanning, connecting, and disconnecting.

    Attributes:
        available_clients (dict): A dictionary storing discovered Bluetooth devices.
        client (BleakClient or None): The current active Bluetooth client.
        loop (asyncio.AbstractEventLoop or None): The asyncio event loop.
        ble_thread (threading.Thread or None): Thread handling BLE operations.
    """

    def __init__(self):
        super().__init__()
        self.available_clients = {}
        self.client = None
        self.loop = None
        self.ble_thread = None
        self.device = None
        self.address = None

    def __enter__(self):
        """Start BLE loop automatically when entering context."""
        self.start_ble_loop()
        return self

    def start_ble_loop(self):
        """Starts the BLE operations in a separate thread to handle async tasks."""
        def loop_runner():
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
            self.loop.run_forever()

        self.ble_thread = threading.Thread(target=loop_runner, daemon=True)
        self.ble_thread.start()
        log.debug("BLE thread started.")

    def run_async(self, coro):
        """Run an async function in the BLE event loop safely."""
        result = None
        try:
            if self.loop and self.loop.is_running():
                future = asyncio.run_coroutine_threadsafe(coro, self.loop)
                result = future.result()  # Wait for the result
            else:
                result = asyncio.run(coro)  # Run normally if loop isn't running
        except BleakDBusError:
            log.exception("BLE stack error. Try restarting Bluetooth service.")
        except BleakError as e:
            log.exception("BleakError: %s" % e)
            # self.reconnect()

        return result

    def send_data(self, handle, data, response=True):
        """
        """
        log.debug("Sending data to service %s: '%s'" % (handle, data))
        self.run_async(self.client.write_gatt_char(handle, data, response))

    def scan(self, scan_time=3) -> {}:
        """
        Scans for available Bluetooth devices and stores them in available_clients.
        """
        log.info("🔍 Scanning for Bluetooth devices...")

        if self.ble_thread is None:
            self.start_ble_loop()

        async def _scan_async():
            """Scan for Bluetooth devices asynchronously."""
            clients = await BleakScanner.discover(timeout=scan_time)
            return {c.name: c for c in clients if c.name and "Leo" in c.name}

        self.available_clients = self.run_async(_scan_async())

        return self.available_clients

    def connect(self, device_id):
        """
        Connects to a Leo BLE device using its device_id.

        Args:
            device_id (str): The serial name of the Leo device.

        Returns:
            bool: True if the connection is successful, False otherwise.
        """
        from .interface import BleDevice
        if self.ble_thread is None:
            self.start_ble_loop()

        try:
            if len(self.available_clients) == 0:
                self.scan()

            # Support passing either the raw ID (e.g. "O3HBOR0BO") or full name ("Leo USB O3HBOR0BO")
            lookup_key = device_id.strip()
            if lookup_key in self.available_clients:
                pass
            elif lookup_key.startswith("Leo USB "):
                lookup_key = lookup_key
            else:
                prefixed = f"Leo USB {lookup_key}"
                if prefixed in self.available_clients:
                    lookup_key = prefixed

            self.address = self.available_clients[lookup_key].address
            log.info("🔌 Connecting to %s" % device_id)

            self.client = BleakClient(self.address)

            self.run_async(self.client.connect())
            self.device = BleDevice(self, self.client)
        except (BleakDeviceNotFoundError, KeyError):
            log.warning("❌ %s not found" % device_id)
        except BleakDBusError:
            log.exception("BLE stack error. Try restarting Bluetooth service.")
        except BleakError as e:
            log.exception("Bleak BLE connection error: %s" % e)
        except Exception as e:
            log.exception("Unexpected exception: %s" % e)
        else:
            log.info("🔌 Connected to %s" % device_id)

        return self.device

    def reconnect(self):
        """
        """
        from .interface import BleDevice
        try:
            log.info("🔌 Reconnecting to %s" % self.address)
            self.client = BleakClient(self.address)
            self.run_async(self.client.connect())
            self.device = BleDevice(self, self.client)
        except (BleakDeviceNotFoundError, KeyError):
            log.warning("❌ %s not found" % self.address)
        except BleakDBusError:
            log.exception("BLE stack error. Try restarting Bluetooth service.")
        except BleakError as e:
            log.exception("Bleak BLE connection error: %s" % e)
        except Exception as e:
            log.exception("Unexpected exception: %s" % e)
        else:
            log.info("🔌 Connected to %s" % self.address)

        return

    def disconnect(self):
        """
        Disconnects the currently connected Bluetooth device.
        """

        if self.device:
            self.device.disconnect()

        async def _client_disconnect_async():
            await self.client.disconnect()

        if self.client:
            log.info("Disconnecting from %s" % self.address)
            self.run_async(_client_disconnect_async())
        if self.loop:
            self.loop.call_soon_threadsafe(self.loop.stop)
        if self.ble_thread:
            self.ble_thread.join()
            log.debug("BLE thread ended.")

        log.info("🔌 Bluetooth Disconnected.")
