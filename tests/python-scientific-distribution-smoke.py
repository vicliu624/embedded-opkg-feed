"""Run against the final target payload, under QEMU or on the device."""
from importlib.metadata import requires, version

import numpy as np
from scipy import linalg, special

assert version("numpy") == np.__version__ == "2.2.6"
assert version("scipy") == "1.15.3"
assert "numpy<2.5,>=1.23.5" in requires("scipy")
solution = linalg.solve(np.array([[3.0, 1.0], [1.0, 2.0]]), np.array([9.0, 8.0]))
assert np.allclose(solution, [2.0, 3.0])
assert np.allclose(special.expit([0.0]), [0.5])
print("NumPy/SciPy target distribution metadata and numeric smoke: PASS")
