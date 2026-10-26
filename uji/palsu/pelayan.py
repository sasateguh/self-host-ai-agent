#!/usr/bin/env python3
"""Pelayan palsu untuk alat ujian (PRD K5): penyedia model serasi OpenAI + Telegram Bot API, satu port, stdlib sahaja.

Tiada kunci sebenar dan tiada rangkaian luar: jawapan model ditentukan (gema mesej pengguna terakhir), dan mesej Telegram
yang "dihantar" disimpan dalam ingatan supaya ujian boleh menyemak ejen benar-benar menjawab.

    python3 pelayan.py --port 8000 [--mesej-awal "/start"]

--mesej-awal = satu mesej pengguna sudah menunggu dalam getUpdates sejak mula, seperti pembaca yang menghantar mesej kepada
bot baharunya dari telefon sebelum menjalankan langkah yang mencari ID sembang.

Laluan:
  GET  /v1/models                      senarai satu model palsu
  POST /v1/chat/completions            jawapan tetap; "stream": true = SSE
  POST /bot<token>/getMe               bot palsu
  POST /bot<token>/getUpdates          mesej dalam baris gilir (tambah dengan /_palsu/masuk); gilir kosong + "timeout" =
                                       tunggu sehingga MAX_TUNGGU_S, seperti tinjauan panjang Telegram
  POST /bot<token>/sendMessage         disimpan; lihat /_palsu/rekod
  POST /_palsu/masuk {"text": "..."}   letak satu mesej pengguna ke baris gilir getUpdates
  GET  /_palsu/rekod                   kiraan permintaan + mesej yang dihantar bot
Kunci model mesti ada (Authorization: Bearer ...), sama seperti penyedia sebenar; tanpa kunci = 401.
"""
from __future__ import annotations

import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl

MODEL = "palsu-model"
KUNCI = threading.Condition()
MAX_TUNGGU_S = 5
KEADAAN: dict = {"kiraan": {}, "dihantar": [], "gilir": [], "update_id": 0}


def kira(nama: str) -> None:
    with KUNCI:
        KEADAAN["kiraan"][nama] = KEADAAN["kiraan"].get(nama, 0) + 1


def jawapan_model(badan: dict) -> str:
    pengguna = [m for m in badan.get("messages", []) if m.get("role") == "user"]
    isi = pengguna[-1].get("content", "") if pengguna else ""
    if isinstance(isi, list):   # format bahagian: [{"type": "text", "text": ...}]
        isi = " ".join(b.get("text", "") for b in isi if isinstance(b, dict))
    return f"palsu: {isi}".strip()


def telegram(kaedah: str, badan: dict) -> dict:
    if kaedah == "getMe":
        return {"id": 123456, "is_bot": True, "first_name": "Palsu", "username": "palsu_bot"}
    if kaedah == "getUpdates":
        with KUNCI:
            KUNCI.wait_for(lambda: KEADAAN["gilir"], timeout=min(float(badan.get("timeout") or 0), MAX_TUNGGU_S))
            keluar, KEADAAN["gilir"] = KEADAAN["gilir"], []
        return keluar
    if kaedah == "sendMessage":
        with KUNCI:
            KEADAAN["dihantar"].append({"chat_id": badan.get("chat_id"), "text": badan.get("text", "")})
        return {"message_id": len(KEADAAN["dihantar"]), "date": int(time.time()),
                "chat": {"id": badan.get("chat_id"), "type": "private"}, "text": badan.get("text", "")}
    return True   # deleteWebhook, setMyCommands, sendChatAction dan lain-lain: terima sahaja


def masuk(teks: str) -> None:
    """Letak satu mesej pengguna ke baris gilir getUpdates."""
    with KUNCI:
        KEADAAN["update_id"] += 1
        KEADAAN["gilir"].append({"update_id": KEADAAN["update_id"], "message": {
            "message_id": KEADAAN["update_id"], "date": int(time.time()), "text": teks,
            "chat": {"id": 1001, "type": "private"}, "from": {"id": 1001, "is_bot": False, "first_name": "Ujian"}}})
        KUNCI.notify_all()


class Pengendali(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):   # senyap: log bekas hanya membawa baris "sedia"
        pass

    def hantar(self, kod: int, data, jenis: str = "application/json") -> None:
        badan = data if isinstance(data, bytes) else json.dumps(data).encode()
        self.send_response(kod)
        self.send_header("Content-Type", jenis)
        self.send_header("Content-Length", str(len(badan)))
        self.end_headers()
        self.wfile.write(badan)

    def badan(self) -> dict:
        n = int(self.headers.get("Content-Length") or 0)
        mentah = self.rfile.read(n) if n else b""
        if not mentah:
            return {}
        try:
            return json.loads(mentah)
        except json.JSONDecodeError:   # Telegram juga menerima borang (curl -d chat_id=... -d text=...)
            return dict(parse_qsl(mentah.decode()))

    def ada_kunci(self) -> bool:
        return (self.headers.get("Authorization") or "").startswith("Bearer ") and len(self.headers["Authorization"]) > 7

    def do_GET(self):
        self.laluan({})

    def do_POST(self):
        self.laluan(self.badan())

    def laluan(self, badan: dict) -> None:
        p = self.path.split("?", 1)[0]
        if p == "/_palsu/rekod":
            with KUNCI:
                return self.hantar(200, {"kiraan": KEADAAN["kiraan"], "dihantar": KEADAAN["dihantar"]})
        if p == "/_palsu/masuk":
            masuk(badan.get("text", ""))
            return self.hantar(200, {"ok": True})
        if p.startswith("/bot") and "/" in p[4:]:
            kaedah = p[4:].split("/", 1)[1]
            kira(f"telegram.{kaedah}")
            return self.hantar(200, {"ok": True, "result": telegram(kaedah, badan)})
        if p.startswith("/v1/"):
            if not self.ada_kunci():
                kira("openai.401")
                return self.hantar(401, {"error": {"message": "kunci tiada", "type": "invalid_request_error"}})
            if p == "/v1/models":
                kira("openai.models")
                return self.hantar(200, {"object": "list", "data": [{"id": MODEL, "object": "model", "owned_by": "palsu"}]})
            if p == "/v1/chat/completions":
                kira("openai.chat")
                return self.sembang(badan)
        self.hantar(404, {"error": {"message": f"tiada laluan {p}"}})

    def sembang(self, badan: dict) -> None:
        teks, model, cipta = jawapan_model(badan), badan.get("model", MODEL), int(time.time())
        if not badan.get("stream"):
            return self.hantar(200, {
                "id": "palsu-1", "object": "chat.completion", "created": cipta, "model": model,
                "choices": [{"index": 0, "finish_reason": "stop", "message": {"role": "assistant", "content": teks}}],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}})
        cebisan = [{"role": "assistant", "content": teks}, {}]
        baris = []
        for i, delta in enumerate(cebisan):
            baris.append("data: " + json.dumps({
                "id": "palsu-1", "object": "chat.completion.chunk", "created": cipta, "model": model,
                "choices": [{"index": 0, "delta": delta, "finish_reason": "stop" if i else None}]}))
        self.hantar(200, ("\n\n".join(baris + ["data: [DONE]"]) + "\n\n").encode(), "text/event-stream")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--mesej-awal", default="")
    a = ap.parse_args()
    if a.mesej_awal:
        masuk(a.mesej_awal)
    pelayan = ThreadingHTTPServer(("0.0.0.0", a.port), Pengendali)
    print(f"palsu: sedia port {a.port}", flush=True)
    pelayan.serve_forever()


if __name__ == "__main__":
    main()
