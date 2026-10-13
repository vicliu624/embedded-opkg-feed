import math
import scipy.special as special

assert abs(special.erf(1.0) - math.erf(1.0)) < 1e-12
previous = special.seterr(all="raise")
assert all(value == "raise" for value in special.geterr().values())
special.seterr(**previous)
print("SciPy final payload import, shared error state and erf: PASS")
