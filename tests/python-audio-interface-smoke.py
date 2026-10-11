"""Load the public PortAudio interface without opening a hardware stream."""
from importlib.metadata import version
import sounddevice as sd

assert version("sounddevice") == "0.5.6"
number, description = sd.get_portaudio_version()
assert number >= 190700 and "PortAudio" in description
assert len(sd.query_hostapis()) >= 1
print("SoundDevice/PortAudio metadata, library load and host API enumeration: PASS")
