"""Check the actual source-built SoundFile payload platform and provider policy."""
import argparse
from email.parser import BytesParser
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("payload", type=Path)
args = parser.parse_args()
root = args.payload.resolve(strict=True)
wheels = list(root.rglob("*.dist-info/WHEEL"))
assert len(wheels) == 1, "SoundFile must own exactly one distribution record"
wheel = BytesParser().parsebytes(wheels[0].read_bytes())
tags = wheel.get_all("Tag", [])
assert tags and all(tag.endswith("-manylinux_2_28_riscv64") for tag in tags), tags
metadata = BytesParser().parsebytes(wheels[0].with_name("METADATA").read_bytes())
assert metadata["Name"].lower() == "soundfile" and metadata["Version"] == "0.14.0"
assert not list(root.rglob("libsndfile*")), "SoundFile must use the public libsndfile provider"
print("SoundFile actual target wheel identity and public libsndfile provider: PASS")
