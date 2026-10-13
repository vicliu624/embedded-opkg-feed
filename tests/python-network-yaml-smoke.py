import importlib.metadata
from pathlib import Path
import certifi
import charset_normalizer
import idna
import requests
import socks
import urllib3
import yaml
from packaging.requirements import Requirement
from requests.utils import select_proxy

# Validate the installed upstream requirements, including both version bounds.
for project in ("requests", "urllib3", "idna", "charset-normalizer", "certifi", "PySocks", "PyYAML"):
    for declaration in importlib.metadata.requires(project) or []:
        required = Requirement(declaration)
        if required.marker and not required.marker.evaluate({"extra": "socks" if project in ("requests", "urllib3") else ""}):
            continue
        actual = importlib.metadata.version(required.name)
        assert actual in required.specifier, (project, declaration, actual)
assert idna.encode("bücher.example") == b"xn--bcher-kva.example"
decoded = charset_normalizer.from_bytes("你好，TDVP".encode("utf-8")).best()
assert decoded is not None and "TDVP" in str(decoded)
assert Path(certifi.where()).read_bytes().count(b"BEGIN CERTIFICATE") > 20
prepared = requests.Request("GET", "https://example.invalid/api", params={"q": "视觉"}).prepare()
assert "%E8%A7%86" in prepared.url
assert select_proxy(prepared.url, {"https": "socks5h://127.0.0.1:1080"}).startswith("socks5h:")
assert socks.PROXY_TYPE_SOCKS5 == 2
assert yaml.__with_libyaml__, "native YAML extension was not loaded"
document = {"name": "TDVP", "models": ["vision", "audio"], "enabled": True}
wire = yaml.dump(document, Dumper=yaml.CSafeDumper)
assert yaml.load(wire, Loader=yaml.CSafeLoader) == document
try:
    yaml.load("!!python/object/apply:os.system ['false']", Loader=yaml.CSafeLoader)
except yaml.constructor.ConstructorError:
    pass
else:
    raise AssertionError("unsafe YAML construction was accepted")
print("Python recursive requirement versions, HTTP preparation, SOCKS, CA data and native safe YAML: PASS")
