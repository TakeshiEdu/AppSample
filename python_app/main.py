import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from yt_dlp import YoutubeDL


class ApiHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
        else:
            self.send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/download":
            self.send_json(404, {"error": "not found"})
            return
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            request = json.loads(self.rfile.read(content_length).decode("utf-8"))
            url = request["url"]
            role = request["role"]
            if not isinstance(url, str) or not url.startswith(("https://", "http://")):
                raise ValueError("有効なURLを入力してください。")
            if role not in ("original", "instrumental"):
                raise ValueError("音源の種類が不正です。")

            output_directory = os.path.join(os.getcwd(), "downloads")
            os.makedirs(output_directory, exist_ok=True)
            output_template = os.path.join(
                output_directory,
                f"{time.time_ns()}_{role}_%(id)s.%(ext)s",
            )
            options = {
                "format": "bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio",
                "outtmpl": output_template,
                "noplaylist": True,
                "overwrites": True,
                "quiet": True,
                "no_warnings": True,
            }
            with YoutubeDL(options) as downloader:
                info = downloader.extract_info(url, download=True)
                output_path = downloader.prepare_filename(info)
            if not os.path.isfile(output_path):
                raise RuntimeError("ダウンロード結果が見つかりません。")
            self.send_json(200, {"path": output_path})
        except Exception as error:
            self.send_json(500, {"error": str(error)})


ThreadingHTTPServer(("127.0.0.1", 8765), ApiHandler).serve_forever()
