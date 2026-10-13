"""Run against final package payloads or normally installed target packages."""
import io
import logging
from importlib import metadata

import coloredlogs
import humanfriendly
import six
from packaging.requirements import Requirement
from packaging.version import Version

assert six.__version__ == "1.17.0"
assert humanfriendly.__version__ == "10.0"
assert coloredlogs.__version__ == "15.0.1"
assert six.ensure_text(b"tdvp") == "tdvp"
assert list(six.iteritems({"a": 1})) == [("a", 1)]
assert humanfriendly.parse_size("2 MiB", binary=True) == 2 * 1024 * 1024
assert humanfriendly.parse_timespan("2 minutes") == 120
stream = io.StringIO()
logger = logging.getLogger("tdvp-infrastructure-smoke")
coloredlogs.install(level="INFO", logger=logger, stream=stream, isatty=False)
logger.info("TDVP logging functional")
assert "TDVP logging functional" in stream.getvalue()

# Traverse upstream runtime metadata, including dependencies of dependencies.
# Optional extras remain inactive unless the candidate explicitly enables them.
pending = ["six", "humanfriendly", "coloredlogs"]
checked = set()
while pending:
    name = pending.pop()
    canonical = name.lower().replace("_", "-")
    if canonical in checked:
        continue
    distribution = metadata.distribution(name)
    checked.add(canonical)
    for raw in distribution.requires or []:
        requirement = Requirement(raw)
        if requirement.marker and not requirement.marker.evaluate({"extra": ""}):
            continue
        installed = metadata.version(requirement.name)
        assert Version(installed) in requirement.specifier, (
            f"{name} requires {raw}, installed {installed}"
        )
        pending.append(requirement.name)
assert {"six", "humanfriendly", "coloredlogs"} <= checked
print("Python infrastructure functionality and recursive upstream dependency versions: PASS")
