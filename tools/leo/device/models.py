from collections import namedtuple
from typing import Optional
from dataclasses import dataclass


@dataclass
class DeviceInfo:
    serial: Optional[str] = None
    mac: Optional[str] = None
    version: Optional[str] = None
    sw_version: Optional[str] = None
    hw_version: Optional[str] = None
    status: Optional[str] = None


@dataclass
class LedControl:
    position: [int]
    red: [int]
    green: [int]
    blue: [int]
    fade_time_s: Optional[int] = None


@dataclass
class ButtonData:
    push_count: Optional[int] = 0
    short_push_status: Optional[int] = 0
    long_push_status: Optional[int] = 0


ChargeLogEntry = namedtuple(
    "ChargeLogEntry",
    [
        "timestamp",
        "session",
        "current",
        "volt",
        "soc",
        "wh",
        "mode",
        "charge_phase",
        "charge_time",
        "temperature",
        "fault_flags",
        "flags",
        "charge_limit"
    ]
)


MeasurementData = namedtuple(
    "MeasurementData",
    [
        "vbus_a",
        "vbus_b",
        "current",
        "vcc1_a",
        "vcc2_a",
        "vcc1_b",
        "vcc2_b",
        "temperature",
        "charge_mode",
        "py_msg"
    ]
)
