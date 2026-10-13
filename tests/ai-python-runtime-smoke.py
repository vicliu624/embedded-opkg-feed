"""Run on the target; tests actual extension loading and numerical/image work."""
import argparse
import io
import numpy as np
import scipy
from scipy import fft, integrate, linalg, ndimage, optimize, signal, sparse, spatial
from PIL import Image, features
import cv2

parser = argparse.ArgumentParser()
parser.add_argument('--cpu1', action='store_true')
args = parser.parse_args()

matrix = np.array([[3.0, 1.0], [1.0, 2.0]])
vector = np.array([9.0, 8.0])
assert np.allclose(matrix @ np.linalg.solve(matrix, vector), vector)
assert np.allclose(matrix @ linalg.solve(matrix, vector), vector)
assert np.allclose(sparse.csr_matrix(matrix).dot([2.0, 3.0]), vector)
assert np.allclose(fft.ifft(fft.fft([1.0, 2.0, 3.0, 4.0])).real, [1, 2, 3, 4])
assert np.isclose(integrate.quad(lambda x: x*x, 0, 1)[0], 1/3)
assert np.isclose(optimize.brentq(lambda x: x*x-4, 0, 3), 2)
assert spatial.KDTree([[0,0], [2,2]]).query([1.9,1.9])[1] == 1
assert ndimage.gaussian_filter(np.ones((8,8)), 1).shape == (8,8)
assert signal.resample(np.ones(16), 8).shape == (8,)
print('NumPy/SciPy target numerical operations: PASS', np.__version__, scipy.__version__)

image = Image.new('RGB', (32, 24), (20, 80, 160))
for format in ['PNG', 'JPEG', 'TIFF', 'WEBP']:
    encoded = io.BytesIO()
    image.save(encoded, format=format)
    encoded.seek(0)
    assert Image.open(encoded).size == image.size
print('Pillow four-codec target round trips: PASS')

array = np.zeros((32, 24, 3), np.uint8)
gray = cv2.cvtColor(array, cv2.COLOR_BGR2GRAY)
assert cv2.resize(gray, (12,16)).shape == (16,12)
for format in ['.png', '.jpg', '.tiff', '.webp']:
    success, data = cv2.imencode(format, array)
    assert success and cv2.imdecode(data, cv2.IMREAD_COLOR).shape == array.shape
print('OpenCV Python target operations: PASS', cv2.__version__)

if args.cpu1:
    from tdvp_ai import Client
    with Client() as client:
        response, output = client.fft([(0,0)]*64)
    assert output == [(0,0)]*64
    print('Python CPU1 asynchronous protocol result: PASS', response.id)
