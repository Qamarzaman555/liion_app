from functools import wraps
from logging import getLogger
from queue import Empty
from threading import Thread
from time import time
import warnings

from .utils import parse_reply


log = getLogger(__name__)


def timing(f):
    @wraps(f)
    def wrap(*args, **kw):
        ts = time()
        result = f(*args, **kw)
        te = time()
        print("func:%r args:[%r, %r] took: %2.4f sec" % (f.__name__, args, kw, te - ts))
        return result

    return wrap


def deprecated(reason: str = "This method is deprecated."):
    """
    A decorator to mark functions as deprecated.

    It will emit a warning when the function is used.

    Parameters:
        reason (str): Explanation of the deprecation.
    """
    def decorator(func):
        @wraps(func)
        def wrapped(*args, **kwargs):
            warnings.warn(f"⚠️ {func.__name__} is deprecated: {reason}",
                          category=DeprecationWarning, stacklevel=2)
            return func(*args, **kwargs)
        return wrapped
    return decorator


def wait_for_response(match=None, timeout=2.0, model=None):
    """
    Decorator that blocks until a matching response is found.

    Parameters:
        match (str): Substring to look for in response lines.
        timeout (float): Max time (in seconds) to wait for the response.
        model (type or bool): Type to cast to (e.g. int, float, str, namedtuple, dataclass).
    """
    def decorator(func):
        @wraps(func)
        def wrapper(self, *args, **kwargs):

            # Clear buffer to avoid stale data
            while not self.response_queue.empty():
                try:
                    self.response_queue.get_nowait()
                except Empty:
                    break

            func(self, *args, **kwargs)
            result = False

            try:
                while True:
                    reply = self.response_queue.get(timeout=timeout)
                    if not match or match in reply:
                        cleaned_reply = reply.removeprefix(match).strip()
                        log.debug(f"{cleaned_reply=}")

                        if not cleaned_reply:
                            result = True
                            break
                        else:
                            result = parse_reply(cleaned_reply, model)
                            break

            except Empty:
                log.warning("No response matching '%s' within %.1f seconds." % (match, timeout))
            finally:
                log.info("%s -> '%s' (%s)" % (func.__name__, result, type(result).__name__))
                return result

        return wrapper
    return decorator


def notification_exception(default_return=None):
    """Decorator to handle notification exception managment."""
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                sender, data = args
                log.error(f"\n❌ Error handling notification for {sender}: {data.hex()} (Error: {e})")
                return default_return
        return wrapper
    return decorator


def run_in_thread(label=None):
    """Decorator to run a method in a background thread, optionally with logging."""
    def decorator(func):
        @wraps(func)
        def wrapper(self, *args, **kwargs):
            def thread_target():
                try:
                    if label:
                        log.debug(f"🧵 {label}: Started")
                    func(self, *args, **kwargs)
                    if label:
                        log.debug(f"🧵 {label}: Complete")
                except Exception as e:
                    log.exception(f"❌ Error in {label or func.__name__}: {e}")

            thread = Thread(target=thread_target, daemon=True)
            thread.start()

            if hasattr(self, "active_threads"):
                self.active_threads.append(thread)

        return wrapper
    return decorator
