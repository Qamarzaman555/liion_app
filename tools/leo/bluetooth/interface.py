from os.path import isfile
from logging import getLogger
from queue import Queue, Empty
from re import split
from time import time, sleep

from xmodem import XMODEM
from click import progressbar

from leo import CoreDevice, timing, notification_exception


log = getLogger(__name__)


class BleDevice(CoreDevice):
    """
    Represents the Leo BLE device, handling communication and operations.

    Attributes:
        bt_manager(BluetoothManager): Manage the bluetooth connection.
        client (BleakClient): The active Bluetooth client.
        services (BluetoothServiceHandler): The available bluetooth services.
    """

    class BluetoothServiceHandler():
        """Handles Bluetooth communication services (UART, OTA, Streaming)."""

        def __init__(self, service_name, service_uuid, device):
            self.service_name = service_name
            self.service_uuid = service_uuid
            self.device = device
            self.bt_manager = device.bt_manager
            self.message_queue = Queue()
            self.notification_handles = set()

        def enable_notifications(self, handle, handler=None):
            """Enable notifications for a characteristic."""

            def _default_notification_handler(sender, data):
                """Basic handler for incoming notifications."""
                log.info(data.decode("utf-8", errors="ignore"))

            if handler is None:
                handler = _default_notification_handler

            self.notification_handles.add(handle)

            self.bt_manager.run_async(
                self.device.client.start_notify(handle, handler)
            )

        def send_command(self, cmd):
            """Send a command over the Bluetooth service."""
            log.info("📨 BLE [%s] -> Sending command: '%s'" % (self.service_name, cmd))

        def disconnect(self):
            """
            Cleanup from any service notifications.
            """
            log.debug("Cleaning up %s" % self.service_name)
            for handle in self.notification_handles:
                log.debug("Stop notify for %s" % handle)
                self.bt_manager.run_async(
                    self.device.client.stop_notify(handle)
                )

    class UartHandler(BluetoothServiceHandler):
        """Handles UART communication with the Leo device."""

        SERVICE_NAME = "UART"
        SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
        WRITE_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
        CHARACTERISTIC_NOTIFY = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

        def __init__(self, device, service):
            super().__init__(self.SERVICE_NAME, self.SERVICE_UUID, device)

            self.xmodem_transfer = False
            self.data_queue = Queue()

            @notification_exception()
            def _notification_handler(sender, data):
                """Handle UART incoming notifications."""
                if self.xmodem_transfer:
                    for byte in data:
                        self.data_queue.put(byte)  # Store each byte in the queue
                else:
                    response = data.decode("utf-8", errors="ignore")
                    lines = split(r"\r\n", response)
                    for line in lines:
                        self.device.consume_response(line)

            for characteristic in service.characteristics:
                if characteristic.uuid == self.WRITE_UUID:
                    self.uart_rx_handle = characteristic.handle
                elif characteristic.uuid == self.CHARACTERISTIC_NOTIFY:
                    self.uart_tx_handle = characteristic.handle
                    self.enable_notifications(self.uart_tx_handle, _notification_handler)

        def send_command(self, cmd):
            """Send a UART command."""
            super().send_command(cmd)

            cmd = cmd.strip() + "\r\n"

            self.bt_manager.send_data(self.uart_rx_handle, cmd.encode())

        def send_file_xmodem(self, filename):
            """Send a file using the Xmodem protocol over BLE."""
            if not isfile(filename):
                log.error("❌ Update failed. Unable to find %s" % filename)
                return

            self.send_command(f"py_ldx {filename}")

            sleep(1)  # Wait for device to enter Xmodem mode

            try:
                self.xmodem_transfer = True

                def getc(size, timeout=1):
                    """Xmodem read function (waits for data from notification queue)."""
                    buffer = bytearray()
                    try:
                        for _ in range(size):
                            buffer.append(self.data_queue.get(timeout=timeout))
                    except Empty:
                        log.debug("getc: None")
                        return None  # No data available

                    log.debug("getc: %x" % bytes(buffer))
                    return bytes(buffer)

                def putc(data, timeout=1):
                    """Write function for Xmodem using BLE write."""
                    log.debug("putc: %s" % data)
                    self.bt_manager.send_data(self.uart_rx_handle, data)
                    # chunk_size = 20  # BLE typically supports 20-byte MTU
                    # for i in range(0, len(data), chunk_size):
                    #     chunk = data[i:i+chunk_size]
                    #     print(f"putc chunk: {chunk}")
                    #     self.bt_manager.run_async(
                    #         self.device.client.write_gatt_char(self.uart_rx_handle, data)
                    #     )
                    #     sleep(0.05)  # Short delay to prevent BLE buffer overflow
                    return len(data)

                modem = XMODEM(getc, putc)

                with open(filename, "rb") as f:
                    log.info("📂 Sending file: {filename} via Xmodem over BLE..")
                    success = self.bt_manager.run_async(modem.send(f))

                if success:
                    log.info("✅ File transfer complete!")
                else:
                    log.error("❌ File transfer failed!")

            except Exception as e:
                log.exception("❌ Unexpected exception during file transfer: %s" % e)

            finally:
                self.xmodem_transfer = False

    class OtaHandler(BluetoothServiceHandler):
        """OTA Service for updating the firmware on Leo."""

        SERVICE_NAME = "OTA"
        SERVICE_UUID = "d6f1d96d-594c-4c53-b1c6-144a1dfde6d8"
        CONTROL_UUID = "7ad671aa-21c0-46a4-b722-270e3ae3d830"  # Read, write, notify
        WRITE_UUID = "23408888-1f40-4cd8-9b89-ca8d45f8a5b0"

        # OTA message codes
        OTA_NOP = bytearray.fromhex("00")
        OTA_REQUEST = bytearray.fromhex("01")
        OTA_REQUEST_ACK = bytearray.fromhex("02")
        OTA_REQUEST_NAK = bytearray.fromhex("03")
        OTA_DONE = bytearray.fromhex("04")
        OTA_DONE_ACK = bytearray.fromhex("05")
        OTA_DONE_NAK = bytearray.fromhex("06")

        def __init__(self, device, service):
            super().__init__(self.SERVICE_NAME, self.SERVICE_UUID, device)

            @notification_exception()
            def _notification_handler(sender: int, data: bytearray):
                """Handle incoming OTA notifications."""
                if data == self.OTA_REQUEST_ACK:
                    log.info("📩 OTA request acknowledged.")
                    self.message_queue.put("ack")
                elif data == self.OTA_REQUEST_NAK:
                    log.info("📩 OTA request NOT acknowledged.")
                    self.message_queue.put("nak")
                elif data == self.OTA_DONE_ACK:
                    log.info("📩 OTA done acknowledged.")
                    self.message_queue.put("ack")
                elif data == self.OTA_DONE_NAK:
                    log.info("📩 OTA done NOT acknowledged.")
                    self.message_queue.put("nak")
                else:
                    log.warning("⚠️ Unexpected OTA reply: %s\n'%s'" % (sender, data))

            for char in service.characteristics:
                if "notify" in char.properties:
                    self.enable_notifications(char.handle, _notification_handler)

        def send_ota(self, firmware_path):
            """Send OTA update over BLE to Leo."""
            if not self.device.is_connected:
                log.warning("❌ No Bluetooth connection.")
                return

            log.info("📦 Starting OTA update with %s..." % firmware_path)

            try:
                att_header_size_bytes = 3

                # Force a larger mtu_size
                mtu_size = 256 if True else self.device.client.mtu_size

                packet_size = mtu_size - att_header_size_bytes

                with open(firmware_path, "rb") as f:
                    firmware = f.read()

                total_size = len(firmware)
                num_chunks = (total_size + packet_size - 1) // packet_size

                log.info("📨 Write packet size")
                self.bt_manager.send_data(self.WRITE_UUID, packet_size.to_bytes(2, "little"))

                log.info("📨 Sending OTA request")
                self.bt_manager.send_data(self.CONTROL_UUID, self.OTA_REQUEST)

                response = self.message_queue.get()
                self.message_queue.task_done()

                if response == "ack":
                    # Send the firmware to OTA data in chunck
                    with progressbar(range(num_chunks), label="📦") as progress_bar:
                        for i in progress_bar:
                            chunk = firmware[i * packet_size: (i + 1) * packet_size]

                            self.bt_manager.send_data(self.WRITE_UUID, chunk)

                            # sleep(0.05)  # Delay to prevent BLE buffer overflow

                    log.info("📨 Sending OTA done")
                    self.bt_manager.send_data(self.CONTROL_UUID, self.OTA_DONE)

                    response = self.message_queue.get()
                    self.message_queue.task_done()

                    if response == "ack":
                        log.info("✅ OTA Update Complete")
                    else:
                        log.error("❌ OTA Update Failed")
                else:
                    log.error("❌ Failed to start OTA")

            except Exception as e:
                log.exception("❌ Unexpected exception during OTA update: %s" % e)

    class StreamingHandler(BluetoothServiceHandler):
        """Streaming Service for downloading files off Leo."""

        SERVICE_NAME = "Streaming"
        SERVICE_UUID = "41e2b910-d0e0-4880-8988-5d4a761b9dc7"
        CHARACTERISTIC_NOTIFY = "94d2c6e0-89b3-4133-92a5-15cced3ee729"
        WRITE_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

        FILE_CODE_STX = 0x02
        FILE_CODE_ETX = 0x03

        def __init__(self, device, service):
            super().__init__(self.SERVICE_NAME, self.SERVICE_UUID, device)

            self.is_streaming = False

            def _notification_handler(sender, data):
                """Handle incoming streaming information."""
                self.message_queue.put(data)

            for char in service.characteristics:
                if char.uuid == self.WRITE_UUID:
                    self.streaming_rx_handle = char.handle
                if "notify" in char.properties:
                    self.enable_notifications(char.handle, _notification_handler)

        def send_command(self, cmd):
            """Send a streaming command."""
            super().send_command(cmd)

            if not self.device.is_connected:
                log.warning("❌ No device connected.")
                return

            cmd = cmd.strip() + "\r\n"

            self.bt_manager.send_data(self.streaming_rx_handle, cmd.encode())

        def stream_to_file(self, filename, reference) -> bool:
            self.send_command(f"stream {filename} {reference}")

            with open(filename, "w", encoding="utf-8") as f:
                is_streaming = True
                timeout = 30
                start_time = time()

                try:
                    while is_streaming:
                        data = self.message_queue.get(timeout=timeout)

                        if self.FILE_CODE_STX in data:
                            log.info("▶️ Stream Start")
                            data[1:]  # Strip the STX code from the start
                            is_streaming = True
                            f.seek(0)
                            f.truncate()  # Clear existing content

                        if self.FILE_CODE_ETX in data:
                            data[:-1]  # Strip the ETX code from the end
                            is_streaming = False

                        message = data.decode("utf-8")
                        log.info("'%s'" % message)

                        if not is_streaming:
                            log.info("⏹️ Stream End")

                        f.write(message)
                        f.flush()
                        self.message_queue.task_done()

                        # TODO: Replace with stream response
                        # Streaming file: [/storage/725.CSV] file_no: 725
                        # start stream: -1
                        if time() - start_time > timeout:
                            raise RuntimeError

                        sleep(0.01)
                except RuntimeError:
                    log.exception("❌ Failed to get FILE_CODE_ETX for %s" % filename)
                    return False
                except Empty:
                    log.warning("❌ Failed to retrieve file %s" % filename)
                    return False

            log.info("✅ File retrieved and saved as: %s" % filename)
            return True

    class BleHandler(BluetoothServiceHandler):
        """Bluetooth Low Energy Service."""

        SERVICE_NAME = "BLE"
        SERVICE_UUID = "00001801-0000-1000-8000-00805f9b34fb"
        CHARACTERISTIC_RW = "00002b29-0000-1000-8000-00805f9b34fb"
        CHARACTERISTIC_R = "00002b3a-0000-1000-8000-00805f9b34fb"
        CHARACTERISTIC_I = "00002a05-0000-1000-8000-00805f9b34fb"

        def __init__(self, device, service):
            super().__init__(self.SERVICE_NAME, self.SERVICE_UUID, device)

    class AlertNotificationHandler(BluetoothServiceHandler):
        """Alert Notification Service."""

        SERVICE_NAME = "Alert Notification"
        SERVICE_UUID = "00001811-0000-1000-8000-00805f9b34fb"
        CONTROL_POINT_UUID = "00002a44-0000-1000-8000-00805f9b34fb"  # Write
        UNREAD_ALERT_UUID = "00002a45-0000-1000-8000-00805f9b34fb"  # Notify
        NEW_ALERT_UUID = "00002a46-0000-1000-8000-00805f9b34fb"  # Notify
        SUPPORTED_NEW_ALERT_UUID = "00002a47-0000-1000-8000-00805f9b34fb"  # Read
        SUPPORTED_UNREAD_ALERT_UUID = "00002a48-0000-1000-8000-00805f9b34fb"  # Read

        def __init__(self, device, service):
            super().__init__(self.SERVICE_NAME, self.SERVICE_UUID, device)

    class DeviceInfoHandler(BluetoothServiceHandler):
        """Device Information Service."""

        SERVICE_NAME = "Device Information"
        SERVICE_UUID = "0000180a-0000-1000-8000-00805f9b34fb"
        MODEL_NUMBER_UUID = "00002a24-0000-1000-8000-00805f9b34fb"  # Read
        MANUFACTURER_UUID = "00002a29-0000-1000-8000-00805f9b34fb"  # Read

        def __init__(self, device, service):
            super().__init__(self.SERVICE_NAME, self.SERVICE_UUID, device)

    def __init__(self, bt_manager, client):
        super().__init__()

        self.bt_manager = bt_manager
        self.client = client

        self.is_connected = client.is_connected if client else False

        def _init_service(client, service_uuid):
            known_service_map = {
                self.UartHandler.SERVICE_UUID: self.UartHandler,
                self.OtaHandler.SERVICE_UUID: self.OtaHandler,
                self.StreamingHandler.SERVICE_UUID: self.StreamingHandler,
                self.BleHandler.SERVICE_UUID: self.BleHandler,
                self.AlertNotificationHandler.SERVICE_UUID: self.AlertNotificationHandler,
                self.DeviceInfoHandler.SERVICE_UUID: self.DeviceInfoHandler,
            }

            if service_uuid not in known_service_map:
                log.warning("Requesting unknown service: %s" % service_uuid)
                return None

            device_service_map = {service.uuid: service for service in client.services}

            if service_uuid not in device_service_map:
                log.warning("Service unavailable on device: %s" % service_uuid)
                return None

            return known_service_map[service_uuid](self, device_service_map[service_uuid])

        self.services = {
            "UART": _init_service(client, self.UartHandler.SERVICE_UUID),
            "OTA": _init_service(client, self.OtaHandler.SERVICE_UUID),
            "STREAMING": _init_service(client, self.StreamingHandler.SERVICE_UUID),
            "BLE": _init_service(client, self.BleHandler.SERVICE_UUID),
            "ALERT_NOTIFICATION": _init_service(client, self.AlertNotificationHandler.SERVICE_UUID),
            "DEVICE_INFO": _init_service(client, self.DeviceInfoHandler.SERVICE_UUID)
        }

    def send_command(self, cmd: str):
        self.services["UART"].send_command(f"{cmd}")

    def disconnect(self):
        for service in self.services.values():
            if service is not None:
                service.disconnect()

    #  TODO find a new home for me
    @timing
    def get_all_files(self, index_start=2892, index_end=3166) -> str:
        failed_count = 0
        success_count = 0
        for file_number in range(index_start, index_end):
            if self.stream(f"{file_number}.CSV", file_number):
                success_count += 1
            else:
                failed_count += 1

        log.info("✅ Downloaded: %d" % success_count)
        log.info("❌ Failed: %s" % failed_count)

    def py_ldx(self, filename: str) -> str:
        self.services["UART"].send_file_xmodem(filename)

    def stream(self, filename: str, reference: int) -> bool:
        return self.services["STREAMING"].stream_to_file(filename, reference)

    def stream_file(self, filename: str, reference: int) -> bool:
        self.services["STREAMING"].stream_to_file(filename, reference)

    def ota(self, firmware_path: str):
        self.services["OTA"].send_ota(firmware_path)
