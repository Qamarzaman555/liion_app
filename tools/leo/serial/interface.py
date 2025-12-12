from logging import getLogger
from re import split
from os.path import isfile
import serial
from pathlib import Path
import time
import threading

from xmodem import XMODEM

from leo import CoreDevice


log = getLogger(__name__)


class SerialDevice(CoreDevice):
    """Represents the Leo Serial device."""

    def __init__(self, port, baud_rate=115200):
        super().__init__()
        self.serial_conn = serial.Serial(port, baud_rate, timeout=1)
        self.is_connected = True

        self.reading_serial = False
        self.reading_lock = threading.Lock()  # Prevents parallel reads during Xmodem

        self.serial_thread = threading.Thread(target=self._read_serial, daemon=True)
        self.serial_thread.start()

    def _read_serial(self):
        """Continuously reads data from serial port in a non-blocking way."""
        buffer = ""
        while self.is_connected:
            try:
                while self.reading_lock.locked():
                    time.sleep(0.1)

                if self.serial_conn.in_waiting > 0:
                    data = self.serial_conn.read(self.serial_conn.in_waiting)
                    log.debug("Raw: '%r'" % data)
                    buffer += data.decode("utf-8", errors="ignore")

                    # Sample response: 'hwversion\r\nOK hwversion 1.5\r\n\r\n#'
                    lines = split(r"\r\n", buffer)

                    # Keep the last part in buffer in case it’s incomplete
                    if not buffer.endswith("\r\n"):
                        buffer = lines.pop()  # Save incomplete data for next read
                    else:
                        buffer = ""

                    # Remove command found on the first line of the response
                    # if lines and lines[0].strip() == self.last_command:
                    #     lines.pop(0)

                    for line in lines:
                        formatted_line = line.strip("#").strip()
                        if formatted_line:
                            self.consume_response(formatted_line)

            except serial.SerialException as e:
                log.exception("❌ Serial error: %s" % e)
                break
            except OSError as e:
                log.exception("❌ OSError: %s" % e)
                break
            finally:
                self.reading_serial = False

            time.sleep(0.1)

    def send_command(self, command: str):
        if self.serial_conn and self.serial_conn.is_open:
            try:
                formatted_command = command.strip() + "\r\n"
                log.info("📨 Serial -> Sending command: '%s'" % (command))
                self.serial_conn.write(formatted_command.encode())
            except Exception as e:
                log.exception("❌ Serial write error: %s" % e)

    def disconnect(self):
        """Close the serial connection and stop reading thread."""
        self.is_connected = False

        if self.serial_thread and self.serial_thread.is_alive():
            self.serial_thread.join(timeout=2)

        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()

    def py_ldx(self, filename: str) -> str:
        if not isfile(filename):
            log.error("❌ Update failed. Unable to find %s" % filename)
            return

        # self.send_command(f"py_ldx {Path('filename').name}")
        self.send_command(f"py_ldx cm.py")

        time.sleep(1)  # Wait for device to enter Xmodem mode

        try:
            def _getc(size, timeout=1):
                """Read function for Xmodem (reads from serial)."""
                result = self.serial_conn.read(size)
                log.info(f"_getc: {result}")
                return result or None

            def _putc(data, timeout=1):
                """Write function for Xmodem (writes to serial)."""
                log.info(f"_putc: {data}")
                self.serial_conn.write(data)
                return len(data)

            self.reading_lock.acquire()  # Pause serial reading

            modem = XMODEM(_getc, _putc)

            with open(filename, "rb") as f:
                log.info(f"📂 Sending file: {filename} via Xmodem...")
                success = modem.send(f)

            if success:
                log.info("✅ File transfer complete!")
            else:
                log.error("❌ File transfer failed!")

        except Exception as e:
            log.exception("❌ Error during file transfer: %s" % e)

        finally:
            self.reading_lock.release()

    def stream(self, filename: str, reference: int) -> str:
        pass

    def stream_file(self, filename: str, reference: int):
        pass
