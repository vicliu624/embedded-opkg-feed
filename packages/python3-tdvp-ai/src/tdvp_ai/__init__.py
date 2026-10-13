"""Published CPU1 AI ABI v1 client. KPU currently means pinned KWS, not YOLO/STT.

Calls on one Client must be serialized. A wait timeout does not cancel CPU1
work; receive its result before submitting another job. No physical addresses,
model pointers or hardware register values are exposed.
"""
import asyncio
import ctypes as C
import os
import struct


class Request(C.LittleEndianStructure):
    _fields_ = [(name, C.c_uint32) for name in ('magic', 'version', 'bytes', 'operation')] + [
        (name, C.c_uint64) for name in ('owner_cookie', 'peer_cookie', 'client_cookie', 'id')
    ] + [(name, C.c_uint32) for name in (
        'input_bytes', 'output_capacity', 'budget_ms', 'flags',
        'input_width', 'input_height', 'output_width', 'output_height',
        'crop_x', 'crop_y', 'crop_width', 'crop_height',
        'pad_left', 'pad_right', 'pad_top', 'pad_bottom'
    )] + [('pad_value', C.c_uint32 * 3), ('format', C.c_uint32)]


class Response(C.LittleEndianStructure):
    _fields_ = [(name, C.c_uint64) for name in ('owner_cookie', 'peer_cookie', 'client_cookie', 'id')] + [
        ('result', C.c_int32)
    ] + [(name, C.c_uint32) for name in ('output_bytes', 'operation', 'output_width', 'output_height', 'format')] + [
        ('duration_ms', C.c_uint64), ('hardware_starts', C.c_uint32),
        ('hardware_completions', C.c_uint32), ('reserved', C.c_uint32 * 14)
    ]


if C.sizeof(Request) != 128 or C.sizeof(Response) != 128:
    raise RuntimeError('unsupported CPU1 AI ABI structure layout')


def _check(result):
    if result < 0:
        raise OSError(-result, os.strerror(-result))
    return result


def _library():
    lib = C.CDLL('libtdvp-ai-client.so.1')
    lib.tdvp_ai_client_protocol_version.restype = C.c_uint
    if lib.tdvp_ai_client_protocol_version() != 1:
        raise RuntimeError('Python client requires CPU1 AI ABI v1')
    lib.tdvp_ai_client_open.argtypes = [C.POINTER(C.c_void_p), C.c_char_p]
    lib.tdvp_ai_client_fd.argtypes = [C.c_void_p]
    lib.tdvp_ai_client_submit.argtypes = [C.c_void_p, C.POINTER(Request), C.c_void_p, C.c_size_t]
    lib.tdvp_ai_client_wait.argtypes = [C.c_void_p, C.c_uint]
    lib.tdvp_ai_client_receive.argtypes = [C.c_void_p, C.POINTER(Response), C.c_void_p, C.c_size_t]
    lib.tdvp_ai_client_close.argtypes = [C.c_void_p]
    lib.tdvp_ai_client_close.restype = None
    return lib


class Client:
    def __init__(self, device=None):
        self._lib = _library()
        self._handle = C.c_void_p()
        _check(self._lib.tdvp_ai_client_open(C.byref(self._handle), os.fsencode(device) if device else None))

    def _require_open(self):
        if not self._handle.value:
            raise ValueError('AI client is closed')

    def fileno(self):
        self._require_open()
        return _check(self._lib.tdvp_ai_client_fd(self._handle))

    def submit(self, request, data):
        self._require_open()
        data = bytes(data)
        if len(data) > 0x300000 or len(data) != request.input_bytes:
            raise ValueError('input does not match the bounded request')
        buffer = C.create_string_buffer(data)
        _check(self._lib.tdvp_ai_client_submit(self._handle, C.byref(request), buffer, len(data)))

    def wait(self, timeout_ms=5000):
        self._require_open()
        if not 0 <= timeout_ms <= 60000:
            raise ValueError('timeout must be between 0 and 60000 ms')
        _check(self._lib.tdvp_ai_client_wait(self._handle, timeout_ms))

    async def wait_async(self, timeout_ms=5000):
        self._require_open()
        if not 0 <= timeout_ms <= 60000:
            raise ValueError('timeout must be between 0 and 60000 ms')
        loop = asyncio.get_running_loop()
        ready = loop.create_future()
        fd = self.fileno()
        def readable():
            if not ready.done():
                ready.set_result(None)
        loop.add_reader(fd, readable)
        try:
            await asyncio.wait_for(ready, timeout_ms / 1000)
            self.wait(0)  # propagate driver error/hangup as well as readability
        finally:
            loop.remove_reader(fd)

    def receive(self, capacity):
        self._require_open()
        if not 0 < capacity <= 0x300000:
            raise ValueError('output capacity must be bounded')
        response, output = Response(), C.create_string_buffer(capacity)
        _check(self._lib.tdvp_ai_client_receive(self._handle, C.byref(response), output, capacity))
        return response, output.raw[:response.output_bytes]

    def fft(self, samples, inverse=False, stage_shifts=0, budget_ms=5000):
        samples = list(samples)
        count = len(samples)
        if count < 64 or count > 4096 or count & (count - 1):
            raise ValueError('FFT length must be a power of two between 64 and 4096')
        data = struct.pack('<' + 'hh' * count, *(value for pair in samples for value in pair))
        request = Request(magic=0x31494154, version=1, bytes=128, operation=3,
                          input_bytes=len(data), output_capacity=len(data), budget_ms=budget_ms,
                          flags=int(inverse) | (stage_shifts << 8), input_width=count,
                          input_height=1, output_width=count, output_height=1, format=0x36314943)
        self.submit(request, data)
        self.wait(min(60000, budget_ms + 1000))
        response, output = self.receive(len(data))
        return response, list(struct.iter_unpack('<hh', output))

    def kws(self, features, state, budget_ms=5000):
        features, state = list(features), list(state)
        if len(features) != 1200 or len(state) != 26880:
            raise ValueError('pinned KWS requires 1200 features and 26880 state floats')
        data = struct.pack('<28080f', *(features + state))
        request = Request(magic=0x31494154, version=1, bytes=128, operation=2,
                          input_bytes=len(data), output_capacity=107760, budget_ms=budget_ms,
                          input_width=40, input_height=30, output_width=2, output_height=30,
                          format=0x3153574b)
        self.submit(request, data)
        self.wait(min(60000, budget_ms + 1000))
        response, output = self.receive(107760)
        values = struct.unpack('<26940f', output)
        return response, values[:60], values[60:]

    def close(self):
        if self._handle.value:
            self._lib.tdvp_ai_client_close(self._handle)
            self._handle = C.c_void_p()

    def __enter__(self):
        return self

    def __exit__(self, *exception):
        self.close()
