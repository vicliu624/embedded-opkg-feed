"""Exercise target-installed HTTP/2 state, HPACK and frame providers."""
from importlib.metadata import version
from hpack import Encoder, Decoder
from hpack.exceptions import HPACKDecodingError
from hyperframe.frame import DataFrame, Frame
from hyperframe.exceptions import InvalidFrameError
from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import RequestReceived, ResponseReceived, DataReceived, StreamEnded
from h2.exceptions import ProtocolError

assert version('h2') == '4.4.1'
assert version('hpack') == '4.2.0'
assert version('hyperframe') == '6.1.0'
headers = [(':method', 'GET'), (':path', '/tdvp'), (':authority', 'localhost'), ('x-tdvp', 'header-test')]
encoder, decoder = Encoder(), Decoder()
for unused in range(2):
    assert decoder.decode(encoder.encode(headers, huffman=True)) == headers
try:
    Decoder().decode(b'\xff')
except HPACKDecodingError:
    pass
else:
    raise AssertionError('truncated HPACK index accepted')
frame = DataFrame(1)
frame.data = b'tdvp-frame'
frame.flags.add('END_STREAM')
wire = frame.serialize()
decoded, length = Frame.parse_frame_header(memoryview(wire[:9]))
decoded.parse_body(memoryview(wire[9:]))
assert length == len(frame.data) and decoded.data == frame.data and 'END_STREAM' in decoded.flags
try:
    Frame.parse_frame_header(memoryview(wire[:8]))
except InvalidFrameError:
    pass
else:
    raise AssertionError('short HTTP/2 frame header accepted')
client = H2Connection(config=H2Configuration(client_side=True, header_encoding='utf-8'))
server = H2Connection(config=H2Configuration(client_side=False, header_encoding='utf-8'))
client.initiate_connection()
server.initiate_connection()
server.receive_data(client.data_to_send())
client.receive_data(server.data_to_send())
server.receive_data(client.data_to_send())
for stream in (1, 3):
    client.send_headers(stream, [(':method', 'GET'), (':scheme', 'https'), (':authority', 'localhost'), (':path', '/tdvp')], end_stream=True)
    incoming = server.receive_data(client.data_to_send())
    assert any(isinstance(event, RequestReceived) and event.stream_id == stream for event in incoming)
    server.send_headers(stream, [(':status', '200'), ('content-type', 'application/octet-stream')])
    server.send_data(stream, b'tdvp-http2', end_stream=True)
    incoming = client.receive_data(server.data_to_send())
    assert any(isinstance(event, ResponseReceived) and event.headers[0] == (':status', '200') for event in incoming)
    assert b''.join(event.data for event in incoming if isinstance(event, DataReceived)) == b'tdvp-http2'
    assert any(isinstance(event, StreamEnded) and event.stream_id == stream for event in incoming)
try:
    client.send_headers(4, [(':method', 'GET'), (':scheme', 'https'), (':authority', 'localhost'), (':path', '/')])
except ProtocolError:
    pass
else:
    raise AssertionError('invalid client stream ID accepted')
print('Python HTTP/2: PASS pinned versions, HPACK dynamic/Huffman roundtrip, frame roundtrip, two streams and malformed/protocol rejection')
