"""Exercise source-built symbolic/numerical packages and dependency bounds."""
from importlib import metadata

import mpmath as mp
import sympy as sp
from packaging.requirements import Requirement
from packaging.version import Version

assert sp.__version__ == "1.14.0"
assert mp.__version__ == "1.3.0"
x = sp.symbols("x")
assert sp.factor(x**2 - 1) == (x - 1) * (x + 1)
assert sp.diff(sp.sin(x), x) == sp.cos(x)
assert sp.integrate(x**2, (x, 0, 3)) == 9
assert sp.solve(sp.Eq(x**2, 4), x) == [-2, 2]
assert sp.Matrix([[2, 1], [1, 3]]).det() == 5
with mp.workdps(40):
    assert abs(mp.quad(lambda value: value**2, [0, 1]) - mp.mpf(1) / 3) < mp.mpf("1e-35")
    assert abs(mp.findroot(lambda value: value**2 - 2, 1) - mp.sqrt(2)) < mp.mpf("1e-35")
pending = ["sympy"]
seen = set()
while pending:
    name = pending.pop()
    if name in seen:
        continue
    seen.add(name)
    for raw in metadata.requires(name) or []:
        requirement = Requirement(raw)
        if requirement.marker and not requirement.marker.evaluate({"extra": ""}):
            continue
        assert Version(metadata.version(requirement.name)) in requirement.specifier
        pending.append(requirement.name)
assert "mpmath" in seen
print("SymPy algebra, calculus, matrices, mpmath precision and recursive dependency bounds: PASS")
