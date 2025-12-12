from dataclasses import is_dataclass
from enum import Enum
from logging import getLogger
from typing import Union, Type


log = getLogger(__name__)


def parse_reply(reply: str, model: Union[Type, None] = None) -> Union[int, float, str, list, object]:
    """
    Parses a space-separated reply string into a model, list, or a single value.

    Args:
        reply (str): The device reply string.
        model (type or None): Optional type (e.g., int, float, namedtuple, dataclass) to parse into.

    Returns:
        Parsed result: Either a single value, list, or model instance.
    """
    def _cast(value: str):
        try:
            if "." in value:
                return float(value)
            return int(value)
        except ValueError:
            return value.strip()

    parsed = [_cast(part) for part in reply.strip().split()]
    log.debug(f"'{parsed=}'")

    if model:
        # Handle dataclasses and namedtuples
        if hasattr(model, "_fields") or is_dataclass(model):
            return model(*parsed)
        if isinstance(model, type) and issubclass(model, Enum):
            try:
                return model(int(reply))  # attempt int conversion
            except ValueError:
                return model(reply)  # fall back to string name
        if model in (int, float, str) and len(parsed) == 1:
            return model(parsed[0])
        return reply  # Return the reply unparsed
    else:
        return parsed[0] if len(parsed) == 1 else parsed


def format_cmd(*args):
    return " ".join(str(arg) for arg in args if arg not in (None, ""))
