"""Check every Depends alternative against the candidate and installed image status.

Uses dpkg's Debian version comparison, shared by the opkg version grammar.
This is a static closure gate; target opkg transactions remain a separate gate.
"""
import argparse
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("packages", type=Path)
parser.add_argument("image_status", type=Path)
arguments = parser.parse_args()
records = []
candidate = []
for path, installed in ((arguments.packages, False), (arguments.image_status, True)):
    for block in path.read_text().split("\n\n"):
        fields = {}
        for line in block.splitlines():
            if line.startswith((" ", "\t")):
                continue
            if ": " in line:
                key, value = line.split(": ", 1)
                if key in fields:
                    raise ValueError("duplicate control field: " + key)
                fields[key] = value
        if "Package" not in fields:
            continue
        if installed:
            status = fields.get("Status", "").split()
            if len(status) != 3 or status[2] != "installed":
                continue
        if "Version" not in fields:
            raise ValueError("missing package version")
        records.append(fields)
        if not installed:
            candidate.append(fields)

providers = {}
atom = re.compile(r"([a-z0-9][a-z0-9+.-]*)(?:\s+\((<<|<=|=|>=|>>)\s+([^\s()]+)\))?")
for fields in records:
    providers.setdefault(fields["Package"], set()).add(fields["Version"])
    for value in fields.get("Provides", "").split(","):
        if not value.strip():
            continue
        match = atom.fullmatch(value.strip())
        if not match or (match[2] and match[2] != "="):
            raise ValueError("unsupported Provides: " + value)
        providers.setdefault(match[1], set()).add(match[3])

missing = []
for fields in candidate:
    for clause in fields.get("Depends", "").split(","):
        if not clause.strip():
            continue
        satisfied = False
        for alternative in clause.split("|"):
            match = atom.fullmatch(alternative.strip())
            if not match:
                raise ValueError("unsupported dependency: " + alternative)
            for version in providers.get(match[1], ()):
                if not match[2]:
                    satisfied = True
                elif version is not None and match[2] == "=":
                    satisfied |= version == match[3]
                elif version is not None:
                    operator = {"<<": "lt", "<=": "le", "=": "eq", ">=": "ge", ">>": "gt"}[match[2]]
                    result = subprocess.run(["dpkg", "--compare-versions", version, operator, match[3]])
                    if result.returncode not in (0, 1):
                        raise ValueError("invalid dependency version")
                    satisfied |= result.returncode == 0
        if not satisfied:
            missing.append(fields["Package"] + ": " + clause.strip())
if missing:
    raise SystemExit("Declared dependency closure failed:\n" + "\n".join(missing))
print("Declared dependency closure: PASS", len(candidate), "candidate packages")
