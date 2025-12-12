from logging import getLogger

from .base import Device
from .enums import ChargingMode
from .models import MeasurementData
from .utils import format_cmd
from .decorators import wait_for_response, deprecated


log = getLogger(__name__)


class CoreDevice(Device):
    """Concrete implementation of Leo's commands."""

    @wait_for_response(match="Commands 1", model=str)
    def help(self):
        """
        Show a list of available commands.

        Returns:
            str: The list of available commands.
        """
        self.send_command("help")

    @wait_for_response(match="OK py_msg")
    def py_msg(self) -> str:
        """
        Retrieve information from a Python script for the app.

        Returns:
            str: The message from the script.
        """
        self.send_command("py_msg")

    @wait_for_response(match="OK version", model=str)
    def version(self) -> str:
        """
        Show the charge manager's version.

        Returns:
            str: The version string.
        """
        self.send_command("version")

    @wait_for_response(match="OK swversion", model=str)
    def swversion(self) -> str:
        """
        Show the GIT version / commit.

        Returns:
            str: The software version.
        """
        self.send_command("swversion")

    @wait_for_response(match="OK status", model=str)
    def status(self) -> str:
        """
        Show the system status.

        Returns:
            str: The current status of the charge manager.
        """
        self.send_command("status")

    @wait_for_response(match="OK serial", model=str)
    def serial(self) -> str:
        """
        Retrieve the serial number.

        Returns:
            str: The serial number.
        """
        self.send_command("serial")

    @wait_for_response(match="OK mac", model=str)
    def mac(self) -> str:
        """
        Retrieve the MAC address.

        Returns:
            str: The MAC address.
        """
        self.send_command("mac")

    @wait_for_response(match="OK button")
    def button(self) -> str:
        """
        Retrieve the button status.

        Read number of button pushes since last time this command was given (or
        since startup), short push status and long push status. Used for
        manufacturing testing. Example output (2 pushes, short push status set,
        long push status not set): 2 1 0 This command resets the push counter,
        short push status and long push status.

        Returns:
            str: The current button status.
        """
        self.send_command("button")

    @wait_for_response(match="OK hwversion", model=float)
    def hwversion(self) -> float:
        """
        Show the hardware version.

        Returns:
            float: The hardware version.
        """
        self.send_command("hwversion")

    @deprecated("Use py_ldx instead")
    def py_ld(self, filename: str) -> str:
        """
        Load the Python script.

        Parameters:
            filename (str): The name of the file to load.

        Returns:
            str: Status message indicating success or failure.
        """
        pass

    def py_ldx(self, filename: str) -> str:
        """
        Load the Python script using Xmodem.

        Parameters:
            filename (str): The name of the file to load.

        Returns:
            str: Status message indicating success or failure.
        """
        log.warning("⚠️ py_ldx should be overriden by child")

    @wait_for_response(match="OK py_kill")
    def py_kill(self) -> str:
        """
        Kill the currently running Python script.

        Returns:
            str: Status message confirming script termination.
        """
        self.send_command("py_kill")

    @wait_for_response(match="OK py_update")
    def py_update(self) -> str:
        """
        Read the Python script from flash storage.

        Returns:
            str: The Python script data or a status message.
        """
        self.send_command("py_update")

    @wait_for_response(match="OK measure", model=MeasurementData)
    def measure(self) -> MeasurementData:
        """
        Retrieve measurement data.

        Returns:
            MeasurementData: Parsed data with correct field types.
        """
        self.send_command("measure")

    @wait_for_response(match="OK mwh", model=int)
    def mwh(self) -> int:
        """
        Retrieve the total number of mWh charged.

        Returns:
            int: Total energy charged in mWh.
        """
        self.send_command("mwh")

    def ls(self, path: str = None) -> list:
        """
        List files stored in the system.

        Parameters:
            path (str): The name of the path to list files from.

        Returns:
            list: A list of filenames.
        """
        self.send_command(format_cmd("ls", path))

    def rm(self, filename: str) -> str:
        """
        Remove a specified file.

        Parameters:
            filename (str): The name of the file to remove.

        Returns:
            str: Status message indicating success or failure.
        """
        self.send_command(f"rm {filename}")

    def cat(self, filename: str) -> str:
        """
        Dump the contents of a file.

        Parameters:
            filename (str): The name of the file to read.

        Returns:
            str: The contents of the file.
        """
        self.send_command(f"cat {filename}")

    @wait_for_response(match="OK chmode", model=ChargingMode)
    def chmode(self, mode: int = None) -> ChargingMode:
        """
        Set the charging mode or get mode if no parameters sets?

        Parameters:
            mode (int): Charging mode (0 = smart, 1 = ghost, 2 = safe).
        """
        self.send_command(format_cmd("chmode", mode))

    @wait_for_response(match="OK script_stat")
    def script_stat(self) -> str:
        """
        Retrieve the script status.

        Returns:
            str: Status message regarding the running script.
        """
        self.send_command("script_stat")

    @wait_for_response(match="OK rgb")
    def rgb(self, led: int, r: int, g: int, b: int, fade_time_s: int = None) -> None:
        """
        Control the RGB LEDs.

        Parameters:
            led (int): LED position to set (0-4).
            r (int): Red component (0-255).
            g (int): Green component (0-255).
            b (int): Blue component (0-255).
            fade_time_s (int): Duration of fade time in seconds.
        """
        self.send_command(format_cmd("rgb", led, r, g, b, fade_time_s))

    @wait_for_response(match="OK eeval")
    def eeval(self, action: str, index: int, value="default") -> int:
        """
        Read or write EEPROM values.

        * LED_TIME_BEFORE_DIM = 0
        * SESSION_NUMBER = 1
        * FAKE_GHOST_MODE = 2
        * QUIET_MODE = 3
        * CHARGE_LIMIT = 4

        Usage:
            eeval <r | w> <index> <value | default>

        Parameters:
            action (str): r | w to read or write respectivly.
            index (int): EEPROM index.
            value (int, optional): Value to write. Use default to reset value.

        Returns:
            int: The stored EEPROM value.
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK vbus")
    def vbus(self, state: int) -> None:
        """
        Control the VBUS A-B switch.

        Parameters:
            state (int): Switch state (0 or 1).
        """
        self.send_command(f"vbus {state}")

    @wait_for_response(match="OK cc5k")
    def cc5k(self, enable: bool) -> None:
        """
        Enable or disable CC 5k.

        Parameters:
            enable (bool): True to enable, False to disable.
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK cc")
    def cc(self, state: int) -> None:
        """
        Control the CC A-B switch.

        Parameters:
            state (int): Switch state (0 or 1).
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK cc_con")
    def cc_con(self) -> str:
        """
        Retrieve CC connection status.

        Returns:
            str: The CC connection status.
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK umux")
    def umux(self, state: int) -> None:
        """
        Control USB mux.

        Parameters:
            state (int): Mux state (0 or 1).
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK resistor_36k")
    def resistor_36k(self, enable: bool) -> None:
        """
        Control 36k resistor.

        Parameters:
            enable (bool): True to enable, False to disable.
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK psu_sw")
    def psu_sw(self, state: int) -> None:
        """
        Control SW_PSUA / SW_PSUB switches.

        These switches make sure that the current for the internal circuitry of
        the charge manager is not measured by the current measuring circuitry.

        Parameters:
            state (PsuSw): Switch state (Off, PSU A on, PSU B on).
        """
        log.warning("⚠️ TODO: Implement")

    def stream(self, filename: str, reference: int) -> str:
        """
        Stream a log file.

        Parameters:
            file (str): The filename.
            reference (int): Reference number.

        Returns:
            str: Streaming status message.
        """
        log.warning("⚠️ stream should be overriden by child")

    @wait_for_response(match="OK sm")
    def sm(self, mode: int) -> None:
        """
        Set the startup mode.

        Parameters:
            mode (int): Startup mode setting.
        """
        log.warning("⚠️ TODO: Implement")

    @wait_for_response(match="OK rf_off")
    def rf_off(self) -> None:
        """
        Turn the transmitter off.
        """
        self.send_command("rf_off")

    @wait_for_response(match="OK ps")
    def ps(self) -> str:
        """
        Print a process list.

        Returns:
            str: The list of active processes.
        """
        self.send_command("ps")

    @wait_for_response(match="OK reboot")
    def reboot(self) -> str:
        """
        Restart Leo.
        """
        self.send_command("reboot")

    def app_msg(self, *args) -> str:
        """
        Retrieve a message from the app.

        Parameters:
            args ([str]): Command and arguments.

        Returns:
            str: The message string.
        """
        self(args[0], *args[1:])

    @wait_for_response(match="OK app_msg soc")
    def soc(self, soc: int) -> None:
        """
        Store the mobile phone's State of Charge (SOC) if in 'app controlled
        charge limit' mode.

        Parameters:
            soc (int): The current SOC value of the phone.
        """
        self.send_command(format_cmd("app_msg", "soc", soc))

    def limit(self, limit: int, soc: int, is_charging: int, charge_time_s: int) -> None:
        """
        Enable app-controlled charging limit.

        Parameters:
            limit (int): Charge limit (0 if custom charge limit is OFF).
            soc (int): Current battery charge value.
            is_charging (int): Phone charging status (0 = not charging, 1 = charging).
            charge_time_s (int): Time in seconds since charging started.
        """
        cmd_str = format_cmd("app_msg", "limit", limit, soc, is_charging, charge_time_s)
        self.send_command(cmd_str)

    @wait_for_response(match="OK app_msg led_time_before_dim")
    def led_time_before_dim(self, time_s: int = None) -> int:
        """
        Get or set the duration before LEDs dim after starting.

        Parameters:
            time (int, optional): Time in seconds before the LEDs dim.
                                  If not provided, the current value is returned.

        Returns:
            int: The current LED dim time setting (if `time` is not provided).
        """
        self.send_command(format_cmd("app_msg", "led_time_before_dim", time_s))

    def script_ver(self) -> str:
        """
        Retrieve the script version.

        Returns:
            str: The script version. (Not implemented yet)
        """
        self.send_command("app_msg script_ver")

    def get_files(self) -> tuple:
        """
        Retrieve the first and last file stored in the system.

        Returns:
            tuple: A tuple containing:
                - First file number (int)
                - Last file number (int)
        """
        self.send_command("app_msg get_files")

    def stream_file(self, filename: str, reference: int) -> int:
        """
        Start streaming the specified file.

        Parameters:
            filename (str): The name of the file to stream.
            referece (int): Reference number of the file.

        Returns:
            int: Streaming status
                - 1: File is being streamed
                - -1: File does not exist
        """
        log.warning("⚠️ stream_file should be overriden by child")

    @wait_for_response(match="OK app_msg ghost_mode")
    def ghost_mode(self, mode: int = None) -> int:
        """
        Get or set ghost mode.

        Parameters:
            mode (int, optional): Set ghost mode (0 = fake, 1 = real).
                                  If not provided, the current value is returned.

        Returns:
            int: The current ghost mode setting (0 or 1).
        """
        self.send_command(format_cmd("app_msg", "ghost_mode", mode))

    @wait_for_response(match="OK app_msg quiet_mode")
    def quiet_mode(self, mode: int = None) -> int:
        """
        Get or set quiet mode.

        Parameters:
            mode (int, optional): Quiet mode setting.
                                  0 = disabled (default)
                                  1 = enabled (Bluetooth turns off after 3 minutes of no connection)

        Returns:
            int: The current quiet mode setting (0 or 1).
        """
        self.send_command(format_cmd("app_msg", "quiet_mode", mode))

    @wait_for_response(match="OK app_msg charge_limit")
    def charge_limit(self, limit: int = None) -> int:
        """
        Get or set the charge limit detection method for smart charging.

        Parameters:
            method (int, optional): Charge limit detection method.
                                    0 = Stop charging when CC to CV transition is detected.
                                    1 = Stop charging when current drops to 50% of CC phase current (default).

        Returns:
            int: The current charge limit detection method (0 or 1).
        """
        self.send_command(format_cmd("app_msg", "charge_limit", limit))
