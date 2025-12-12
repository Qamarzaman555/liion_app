from enum import Enum


class ChargingMode(Enum):
    SMART = 0
    GHOST = 1
    SAFE = 2


class PsuSw(Enum):
    OFF = 0
    A_ON = 1
    B_ON = 2
