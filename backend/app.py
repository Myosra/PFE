"""Fish feeding tracker - Flask + Socket.IO backend.

Events (client -> server)
  start_detection {source, mode, conf}   source: video path or camera index
  stop_detection
Events (server -> client)
  frame   {frame: <base64 jpeg>, stats: {...}}
  status  {state: running|finished, ...}
  error   {message}
"""
import json
import logging

from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit

from config import settings
from detector import build_detector
from session import TrackingSession

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("app")

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")

sessions: dict[str, TrackingSession] = {}


@app.get("/health")
def health():
    return jsonify(status="ok", weights_found=settings.weights_path.exists())


@app.get("/api/sessions")
def list_sessions():
    """Summaries of past runs, newest first."""
    out = []
    if settings.sessions_dir.exists():
        for f in sorted(settings.sessions_dir.glob("*.json"), reverse=True):
            out.append({"id": f.stem, **json.loads(f.read_text())})
    return jsonify(out)


@socketio.on("connect")
def on_connect():
    log.info("Client connected: %s", request.sid)


@socketio.on("disconnect")
def on_disconnect():
    _stop(request.sid)
    log.info("Client disconnected: %s", request.sid)


def _stop(sid: str):
    s = sessions.pop(sid, None)
    if s:
        s.stop()


@socketio.on("start_detection")
def on_start(data):
    data = data or {}
    sid = request.sid
    source = str(data.get("source", "")).strip().strip('"')
    mode = data.get("mode", "yolo")
    conf = float(data.get("conf", settings.conf_threshold))

    if not source:
        emit("error", {"message": "Choose a video file or camera index first."})
        return
    _stop(sid)  
    try:
        detector = build_detector(mode, settings)
    except Exception as e: 
        log.exception("Detector init failed")
        emit("error", {"message": str(e)})
        return

    session = TrackingSession(socketio, sid, source, mode, conf, detector, settings)
    sessions[sid] = session
    session.start()


@socketio.on("stop_detection")
def on_stop():
    _stop(request.sid)


if __name__ == "__main__":
    log.info("Serving on http://%s:%s", settings.host, settings.port)
    socketio.run(app, host=settings.host, port=settings.port, allow_unsafe_werkzeug=True)
