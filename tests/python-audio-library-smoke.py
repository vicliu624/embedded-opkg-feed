import io
import numpy as np
import cffi
import pycparser
import soundfile as sf
import sounddevice as sd

ffi = cffi.FFI()
ffi.cdef("int abs(int); size_t strlen(const char *);")
libc = ffi.dlopen(None)
assert libc.abs(-42) == 42
assert libc.strlen(ffi.new("char[]", b"tdvp-audio")) == 10
syntax = pycparser.CParser().parse("int square(int value) { return value * value; }")
assert syntax.ext[0].decl.name == "square"

samples = np.column_stack((np.linspace(-0.5, 0.5, 256), np.linspace(0.5, -0.5, 256)))
for encoding in ("WAV", "FLAC"):
    stream = io.BytesIO()
    sf.write(stream, samples, 16000, format=encoding, subtype="PCM_16")
    stream.seek(0)
    decoded, rate = sf.read(stream, dtype="float64", always_2d=True)
    assert rate == 16000 and decoded.shape == samples.shape
    assert np.max(np.abs(samples - decoded)) <= 1 / 32768
version, description = sd.get_portaudio_version()
assert version >= 190700 and "PortAudio" in description
assert len(sd.query_hostapis()) >= 1
# No stream is opened: physical audio and CPU1 ownership require device tests.
print("Native CFFI, C parser, WAV/FLAC memory roundtrip and PortAudio interface loading: PASS")
