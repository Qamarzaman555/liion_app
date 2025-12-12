#!/usr/bin/env python3
"""
Bluetooth and Serial CLI Tool for Leo Devices

This script provides a command-line interface (CLI) to interact with Leo devices.
It supports the following operations:

- **scan**: Scan for available Bluetooth/Serial devices.
- **connect**: Establish a connection and start an interactive session.
- **ota**: Perform an over-the-air (OTA) firmware update.

Usage:
    python3 connect.py [command] [options]

Examples:
    - Connect to a device over serial:
        python connect.py --serial /dev/ttyUSB0

    - Perform a firmware update over bluetooth:
        python connect.py --bluetooth EVNCLM8KZ --ota Release_v1.5.22.img

    - Scan for available serial devices:
        python connect.py --scan serial

Dependencies:
    - Requires the `click` library for CLI functionality.
    - Requires the `leo` module providing `BluetoothManager`.
"""
import sys
import logging
import click

from leo.bluetooth import BluetoothManager
from leo.serial import SerialManager


@click.command()
@click.option('--bluetooth', help="Connect to a Bluetooth device (e.g. EVNCLM8KZ).", default=None)
@click.option('--serial', help="Connect to a Serial device (e.g. '/dev/ttyUSB0').", default=None)
@click.option('--scan', type=click.Choice(["bluetooth", "serial"], case_sensitive=False),
              default=None, is_flag=False,
              help="Scan for available devices. ('bluetooth' or 'serial').")
@click.option('--ota', help="Firmware file for OTA update.")
@click.option('--update', help="Update the cm.py script.")
@click.option('--verbose', is_flag=True, help="Increase the logging level to maximum")
def main(bluetooth, serial, scan, ota, update, verbose):
    """CLI tool for interacting with Leo via Bluetooth or Serial."""
    if verbose:
        logging.basicConfig(
            level=logging.DEBUG,
            format="%(asctime)s [%(levelname)s] %(name)s [%(lineno)d] - %(message)s",
            datefmt="%H:%M:%S"
        )
    else:
        logging.basicConfig(level=logging.INFO, format="%(message)s")

    # Enforce mutually exclusive options
    connect_options = sum([bool(bluetooth), bool(serial), bool(scan)])
    if connect_options != 1:
        click.echo("Choose ONE option: --bluetooth, --serial, or --scan.", err=True)
        sys.exit(1)

    scan_devices(scan) if scan else connect_device(bluetooth, serial, ota, update)

    sys.exit(0)


def scan_devices(scan):
    if scan == "serial":
        with SerialManager() as serial_manager:
            available_ports = serial_manager.scan()
            if available_ports:
                click.echo("\n🔌 Available Serial devices:")
                for port in available_ports:
                    click.echo(f"  🔹 {port.device} - {port.description}")
            else:
                click.echo("❌ No Serial devices found.")
    elif scan == "bluetooth":
        with BluetoothManager() as bt_manager:
            available_clients = bt_manager.scan(3)
            if available_clients:
                click.echo("\n📡 Available Bluetooth devices:")
                for _, name in enumerate(available_clients):
                    click.echo(f"  🔹 '{name}' ({available_clients[name].address})")
            else:
                click.echo("❌ No Bluetooth devices found.")


def connect_device(bluetooth, serial, ota, update):
    device_manager = None
    kwargs = {}

    if bluetooth:
        device_manager = BluetoothManager
        kwargs = {"device_id": bluetooth}
    elif serial:
        device_manager = SerialManager
        kwargs = {"port": serial, "baud_rate": 115200}

    with device_manager() as manager:
        device = manager.connect(**kwargs)

        if device:
            if ota:
                device.ota(ota)
            elif update:
                device.py_ldx(update)
            else:
                interactive_session(device)


def interactive_session(device):
    """User input for interacting with Leo."""
    while device is not None and device.is_connected:
        cmd_str = click.prompt(">", prompt_suffix=" ")

        if cmd_str.lower() == "exit":
            device.is_connected = False
        else:
            tokens = cmd_str.strip().split()
            device(tokens[0], *tokens[1:])


if __name__ == "__main__":
    main()  # pylint: disable=no-value-for-parameter
