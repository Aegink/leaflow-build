"""仅供CI：监听回环地址的固定WebSocket回显服务，校验握手与掩码。"""
import argparse
import base64
import hashlib
import io
import math
import socketserver
import struct
import wave
from pathlib import Path


def preview_wave():
    output = io.BytesIO()
    with wave.open(output, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(24000)
        audio.writeframes(b"".join(struct.pack("<h", int(1200 * math.sin(2 * math.pi * 440 * i / 24000))) for i in range(2400)))
    return output.getvalue()


class EchoHandler(socketserver.StreamRequestHandler):
    def handle(self):
        self.connection.settimeout(15)
        request = self.rfile.readline(4096).decode("ascii").strip()
        headers = {}
        while True:
            line = self.rfile.readline(8192)
            if line == b"\r\n":
                break
            if not line or b":" not in line:
                return
            key, value = line.decode("ascii").split(":", 1)
            headers[key.lower()] = value.strip()
        if request == "GET /preview.wav HTTP/1.1" and headers.get("x-t1602") == "fixed":
            payload = preview_wave()
            self.wfile.write(("HTTP/1.1 200 OK\r\nContent-Type: audio/wav\r\nContent-Length: "
                              + str(len(payload)) + "\r\nConnection: close\r\n\r\n").encode("ascii") + payload)
            print("固定WAV回环响应：2400帧/24000Hz/单声道", flush=True)
            return
        if request != "GET /audio HTTP/1.1" or headers.get("x-t1602") != "fixed":
            self.wfile.write(b"HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
            return
        key = headers.get("sec-websocket-key", "")
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        self.wfile.write(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
        while True:
            prefix = self.rfile.read(2)
            if len(prefix) != 2:
                return
            opcode = prefix[0] & 15
            length = prefix[1] & 127
            if not prefix[1] & 128:
                return
            if length == 126:
                length = struct.unpack("!H", self.rfile.read(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self.rfile.read(8))[0]
            if length > 65536:
                return
            mask = self.rfile.read(4)
            payload = self.rfile.read(length)
            if len(mask) != 4 or len(payload) != length:
                return
            payload = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
            if opcode == 8:
                self.send_frame(8, payload)
                return
            if opcode == 9:
                self.send_frame(10, payload)
            elif opcode in (1, 2):
                self.send_frame(opcode, payload)

    def send_frame(self, opcode, payload):
        size = len(payload)
        header = bytes([128 | opcode, size]) if size < 126 else bytes([128 | opcode, 126]) + struct.pack("!H", size)
        self.wfile.write(header + payload)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port-file", type=Path, required=True)
    args = parser.parse_args()
    with socketserver.ThreadingTCPServer(("127.0.0.1", 0), EchoHandler) as server:
        server.daemon_threads = True
        args.port_file.write_text(str(server.server_address[1]), encoding="ascii")
        print("回环WebSocket服务已就绪", flush=True)
        server.serve_forever()
